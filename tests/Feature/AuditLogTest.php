<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Ingredient;
use App\Models\Formula;
use App\Models\ProductionOrder;
use App\Models\MaterialRequest;
use App\Models\AuditLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditLogTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $rnd;
    private User $produksi;
    private User $gudang;
    private Ingredient $ingredient;

    protected function setUp(): void
    {
        parent::setUp();

        // 1. Seed users for role simulation
        $this->admin = User::factory()->create(['role' => 'admin', 'password' => bcrypt('password')]);
        $this->rnd = User::factory()->create(['role' => 'rnd']);
        $this->produksi = User::factory()->create(['role' => 'kepala_produksi']);
        $this->gudang = User::factory()->create(['role' => 'kepala_gudang']);

        // 2. Seed simple ingredient
        $this->ingredient = Ingredient::create([
            'code' => 'ING-TEST',
            'name' => 'Bahan Baku Uji Coba',
            'type' => 'raw_material',
            'current_stock' => 100.0,
            'unit' => 'kg',
            'price_per_unit' => 10000.00
        ]);
    }

    /**
     * Test Audit Log triggers upon successful authentication.
     */
    public function test_auth_logging()
    {
        // 1. Post to login
        $response = $this->postJson('/api/login', [
            'email' => $this->admin->email,
            'password' => 'password'
        ]);

        $response->assertStatus(200);

        // 2. Assert Login Audit Log is written
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->admin->id,
            'action' => 'login'
        ]);

        $token = $response->json('data.access_token');

        // 3. Post to logout
        $logoutResponse = $this->postJson('/api/logout', [], [
            'Authorization' => "Bearer {$token}"
        ]);

        $logoutResponse->assertStatus(200);

        // 4. Assert Logout Audit Log is written
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->admin->id,
            'action' => 'logout'
        ]);
    }

    /**
     * Test Audit Log triggers upon formula creation and approval.
     */
    public function test_formula_workflow_logging()
    {
        // 1. Create formula with actingAs R&D User
        $response = $this->actingAs($this->rnd, 'sanctum')->postJson('/api/formulas', [
            'name' => 'Formula Sunscreen Spf 50',
            'batch_size' => 10,
            'ingredients' => [
                [
                    'ingredient_id' => $this->ingredient->id,
                    'quantity' => 200, // 200 grams
                    'unit' => 'g'
                ]
            ],
            'costs' => [
                [
                    'type' => 'labor',
                    'description' => 'Packaging Labor',
                    'cost_value' => 5000
                ]
            ],
            'profit_margin_percent' => 30
        ]);

        $response->assertStatus(210);
        $formulaId = $response->json('data.id');

        // Assert 'create_formula' Audit Log
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->rnd->id,
            'action' => 'create_formula',
            'model_type' => Formula::class,
            'model_id' => $formulaId
        ]);

        // 2. Approve formula (ACC)
        $approveResponse = $this->actingAs($this->rnd, 'sanctum')->postJson("/api/formulas/{$formulaId}/approve", []);
        $approveResponse->assertStatus(200);

        // Assert 'approve_formula' Audit Log
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->rnd->id,
            'action' => 'approve_formula',
            'model_type' => Formula::class,
            'model_id' => $formulaId
        ]);
    }

    /**
     * Test Audit Log triggers upon production scheduling and warehouse verification.
     */
    public function test_production_and_warehouse_workflow_logging()
    {
        // 1. Establish an approved Formula
        $formula = Formula::create([
            'code' => 'FOR-001',
            'name' => 'Lip Balm Vanilla',
            'batch_size' => 10,
            'status' => 'approved',
            'created_by' => $this->rnd->id
        ]);

        $formula->ingredients()->create([
            'ingredient_id' => $this->ingredient->id,
            'quantity_per_batch' => 5,
            'unit' => 'kg',
            'unit_price' => 10000.0,
            'subtotal' => 50000.0
        ]);

        // 2. Production scheduling
        $response = $this->actingAs($this->produksi, 'sanctum')->postJson('/api/productions', [
            'formula_id' => $formula->id,
            'target_quantity' => 20, // 2x batch size
            'batch_count' => 2,
            'scheduled_start_date' => now()->toDateString()
        ]);

        $response->assertStatus(201);
        $prodOrderId = $response->json('data.id');
        $mrId = $response->json('data.material_request.id');

        // Assert 'schedule_production' Audit Log
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->produksi->id,
            'action' => 'schedule_production',
            'model_type' => ProductionOrder::class,
            'model_id' => $prodOrderId
        ]);

        // 3. Warehouse Verification Approval
        $verifyResponse = $this->actingAs($this->gudang, 'sanctum')->postJson("/api/material-requests/{$mrId}/verify", [
            'status' => 'approved'
        ]);

        $verifyResponse->assertStatus(200);

        // Assert 'approve_material_request' Audit Log
        $this->assertDatabaseHas('audit_logs', [
            'user_id' => $this->gudang->id,
            'action' => 'approve_material_request',
            'model_type' => MaterialRequest::class,
            'model_id' => $mrId
        ]);
    }

    /**
     * Test fetching dashboard metrics and live activities stream.
     */
    public function test_dashboard_analytics_fetching()
    {
        // 1. Trigger some audit logs
        AuditLog::logAction($this->admin->id, 'custom_action', 'Admin did something.');

        // 2. Fetch dashboard data
        $response = $this->actingAs($this->admin, 'sanctum')->getJson('/api/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonStructure([
                'data' => [
                    'metrics' => [
                        'total_formulas',
                        'approved_formulas',
                        'low_stock_materials_count',
                        'active_productions_count',
                        'completed_productions_count'
                    ],
                    'recent_activities' => [
                        '*' => [
                            'id',
                            'action',
                            'description',
                            'user' => [
                                'id',
                                'name',
                                'role'
                            ]
                        ]
                    ]
                ]
            ]);
    }
}
