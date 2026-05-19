<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Ingredient;
use App\Models\Formula;
use App\Models\Notification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FormulaWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Seed default users, suppliers, and ingredients using DatabaseSeeder
        $this->artisan('db:seed');
    }

    /**
     * Test successful login returning Bearer Sanctum tokens.
     */
    public function test_auth_login_api(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'rnd@faacos.com',
            'password' => 'password'
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'message',
                'data' => [
                    'user' => ['id', 'name', 'email', 'role'],
                    'access_token',
                    'token_type'
                ]
            ]);
    }

    /**
     * Test creating a formula which automatically calculates HPP with unit conversion (g -> kg).
     */
    public function test_create_formula_simulation_costing(): void
    {
        $user = User::where('role', 'rnd')->first();
        $niacinamide = Ingredient::where('code', 'RAW-001')->first(); // kg unit, Rp 350.000 per kg
        $water = Ingredient::where('code', 'RAW-003')->first(); // l unit, Rp 5.000 per l

        // Formula Batch: 100 kg
        // Niacinamide: 2000 g (converted to 2 kg -> cost = 2 * 350.000 = Rp 700.000)
        // Water: 98 l (cost = 98 * 5.000 = Rp 490.000)
        // Total ingredient cost = 700.000 + 490.000 = Rp 1.190.000
        // Labor cost = Rp 100.000
        // Overhead cost = Rp 50.000
        // Total HPP = Rp 1.340.000
        // HPP per unit = Rp 13.400
        // Selling price with 50% profit margin = Rp 20.100

        $payload = [
            'name' => 'Brightening Serum Formula A',
            'batch_size' => 100.0000,
            'ingredients' => [
                [
                    'ingredient_id' => $niacinamide->id,
                    'quantity' => 2000.0000, // in g
                    'unit' => 'g'
                ],
                [
                    'ingredient_id' => $water->id,
                    'quantity' => 98.0000, // in l
                    'unit' => 'l'
                ]
            ],
            'costs' => [
                [
                    'type' => 'labor',
                    'description' => 'Mixing R&D staff labor cost',
                    'cost_value' => 100000.00
                ],
                [
                    'type' => 'overhead',
                    'description' => 'Electricity & Laboratory machinery',
                    'cost_value' => 50000.00
                ]
            ],
            'profit_margin_percent' => 50.00
        ];

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/formulas', $payload);

        $response->assertStatus(210) // Custom response code or 201 depending on store config, we returned 210
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.hpp.total_ingredient_cost', '1190000.00')
            ->assertJsonPath('data.hpp.total_labor_cost', '100000.00')
            ->assertJsonPath('data.hpp.total_overhead_cost', '50000.00')
            ->assertJsonPath('data.hpp.total_hpp', '1340000.00')
            ->assertJsonPath('data.hpp.hpp_per_unit', '13400.00')
            ->assertJsonPath('data.hpp.selling_price', '20100.00');
    }

    /**
     * Test stock availability precheck correctly flags shortages.
     */
    public function test_pre_check_stock_insufficiency(): void
    {
        $user = User::where('role', 'rnd')->first();
        $centella = Ingredient::where('code', 'RAW-005')->first(); // current_stock is 0 ml

        $formula = Formula::create([
            'code' => 'FOR-TEST-001',
            'name' => 'Centella Serum B',
            'batch_size' => 10.0000,
            'status' => 'draft',
            'created_by' => $user->id
        ]);

        $formula->ingredients()->create([
            'ingredient_id' => $centella->id,
            'quantity_per_batch' => 500.0000,
            'unit' => 'ml',
            'unit_price' => $centella->price_per_unit,
            'subtotal' => 500.0000 * $centella->price_per_unit
        ]);

        $response = $this->actingAs($user, 'sanctum')->getJson("/api/formulas/{$formula->id}/pre-check-stock");

        $response->assertStatus(200)
            ->assertJsonPath('sufficient', false)
            ->assertJsonCount(1, 'shortages')
            ->assertJsonPath('shortages.0.code', 'RAW-005');
    }

    /**
     * Test attempting to ACC a formula with a shortage triggers automatic notification alerts to Gudang & Admin.
     */
    public function test_approve_formula_shortage_triggers_notifications(): void
    {
        $user = User::where('role', 'rnd')->first();
        $centella = Ingredient::where('code', 'RAW-005')->first(); // current_stock is 0 ml

        $formula = Formula::create([
            'code' => 'FOR-TEST-002',
            'name' => 'Centella Cream C',
            'batch_size' => 10.0000,
            'status' => 'draft',
            'created_by' => $user->id
        ]);

        $formula->ingredients()->create([
            'ingredient_id' => $centella->id,
            'quantity_per_batch' => 200.0000,
            'unit' => 'ml',
            'unit_price' => $centella->price_per_unit,
            'subtotal' => 200.0000 * $centella->price_per_unit
        ]);

        // Attempt approval
        $response = $this->actingAs($user, 'sanctum')->postJson("/api/formulas/{$formula->id}/approve");

        // Should return 422 with status 'insufficient_stock'
        $response->assertStatus(422)
            ->assertJsonPath('status', 'insufficient_stock');

        // Confirm database notifications were generated for admin and kepala_gudang
        $admin = User::where('role', 'admin')->first();
        $gudang = User::where('role', 'kepala_gudang')->first();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $admin->id,
            'type' => 'restock_alert'
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $gudang->id,
            'type' => 'restock_alert'
        ]);
    }
}
