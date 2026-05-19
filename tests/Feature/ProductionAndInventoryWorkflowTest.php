<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Ingredient;
use App\Models\Formula;
use App\Models\ProductionOrder;
use App\Models\MaterialRequest;
use App\Models\InventoryLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductionAndInventoryWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('db:seed');
    }

    /**
     * Test scheduling production order fails if formula is not approved.
     */
    public function test_schedule_production_fails_for_draft_formula(): void
    {
        $userProduksi = User::where('role', 'kepala_produksi')->first();
        $userRnd = User::where('role', 'rnd')->first();

        // Create a draft formula
        $formula = Formula::create([
            'code' => 'FOR-DRAFT',
            'name' => 'Draft Cream',
            'batch_size' => 100.0,
            'status' => 'draft',
            'created_by' => $userRnd->id
        ]);

        $response = $this->actingAs($userProduksi, 'sanctum')->postJson('/api/productions', [
            'formula_id' => $formula->id,
            'target_quantity' => 200.0,
            'batch_count' => 2
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('message', 'Hanya formula yang berstatus APPROVED yang dapat dijadwalkan untuk produksi.');
    }

    /**
     * Test scheduling production order succeeds for approved formula and auto-creates Material Request.
     */
    public function test_schedule_production_succeeds_and_creates_material_request(): void
    {
        $userProduksi = User::where('role', 'kepala_produksi')->first();
        $userRnd = User::where('role', 'rnd')->first();
        $niacinamide = Ingredient::where('code', 'RAW-001')->first(); // stock 15 kg

        // Create an approved formula
        $formula = Formula::create([
            'code' => 'FOR-APPROVED',
            'name' => 'Approved Cream',
            'batch_size' => 10.0,
            'status' => 'approved',
            'rnd_approved_by' => $userRnd->id,
            'rnd_approved_at' => now(),
            'created_by' => $userRnd->id
        ]);

        // Formula uses 1.5 kg Niacinamide per 10 kg batch
        $formula->ingredients()->create([
            'ingredient_id' => $niacinamide->id,
            'quantity_per_batch' => 1.5,
            'unit' => 'kg',
            'unit_price' => $niacinamide->price_per_unit,
            'subtotal' => 1.5 * $niacinamide->price_per_unit
        ]);

        // Schedule production for 20 kg (2x batch size factor)
        $response = $this->actingAs($userProduksi, 'sanctum')->postJson('/api/productions', [
            'formula_id' => $formula->id,
            'target_quantity' => 20.0,
            'batch_count' => 2,
            'scheduled_start_date' => date('Y-m-d')
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.status', 'material_requested')
            ->assertJsonStructure([
                'data' => [
                    'id', 'code', 'status', 'material_request' => [
                        'id', 'code', 'status', 'items'
                    ]
                ]
            ]);

        // Confirm Material Request Item has quantity adjusted by factor (1.5 kg * 2 = 3.0 kg required)
        $this->assertDatabaseHas('material_request_items', [
            'ingredient_id' => $niacinamide->id,
            'quantity_required' => 3.0000,
            'unit' => 'kg'
        ]);
    }

    /**
     * Test warehouse head verifying and approving material requests, triggering stock reductions and logs.
     */
    public function test_warehouse_approves_material_request(): void
    {
        $userProduksi = User::where('role', 'kepala_produksi')->first();
        $userGudang = User::where('role', 'kepala_gudang')->first();
        $niacinamide = Ingredient::where('code', 'RAW-001')->first(); // current_stock is 15.0000 kg

        // 1. Setup production and MR
        $formula = Formula::create([
            'code' => 'FOR-MR-TEST',
            'name' => 'MR Test Formula',
            'batch_size' => 10.0,
            'status' => 'approved'
        ]);

        $formula->ingredients()->create([
            'ingredient_id' => $niacinamide->id,
            'quantity_per_batch' => 2.0, // 2.0 kg per 10 kg batch
            'unit' => 'kg',
            'unit_price' => $niacinamide->price_per_unit,
            'subtotal' => 2.0 * $niacinamide->price_per_unit
        ]);

        // Production order of 10 kg
        $pResponse = $this->actingAs($userProduksi, 'sanctum')->postJson('/api/productions', [
            'formula_id' => $formula->id,
            'target_quantity' => 10.0,
            'batch_count' => 1
        ]);

        $mrId = $pResponse['data']['material_request']['id'];

        // 2. Verify and Approve MR as Warehouse Head
        $mrResponse = $this->actingAs($userGudang, 'sanctum')->postJson("/api/material-requests/{$mrId}/verify", [
            'status' => 'approved'
        ]);

        $mrResponse->assertStatus(200)
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.status', 'approved');

        // 3. Assert Niacinamide stock in warehouse is reduced: 15.0 - 2.0 = 13.0 kg
        $updatedNiacinamide = Ingredient::find($niacinamide->id);
        $this->assertEquals(13.0, (float) $updatedNiacinamide->current_stock);

        // 4. Assert inventory log is generated
        $this->assertDatabaseHas('inventory_logs', [
            'ingredient_id' => $niacinamide->id,
            'type' => 'production_release',
            'quantity' => 2.0,
            'unit' => 'kg',
            'balance_after' => 13.0
        ]);

        // 5. Assert production order status transitions to 'in_production'
        $poId = $pResponse['data']['id'];
        $updatedPO = ProductionOrder::find($poId);
        $this->assertEquals('in_production', $updatedPO->status);
    }

    /**
     * Test manual stock adjustment opname by Warehouse Head.
     */
    public function test_manual_stock_adjustment(): void
    {
        $userGudang = User::where('role', 'kepala_gudang')->first();
        $niacinamide = Ingredient::where('code', 'RAW-001')->first(); // current_stock is 15.0 kg

        // Adjust stock in: add 5 kg
        $responseIn = $this->actingAs($userGudang, 'sanctum')->postJson('/api/inventory/adjust', [
            'ingredient_id' => $niacinamide->id,
            'type' => 'in',
            'quantity' => 5.0,
            'unit' => 'kg',
            'notes' => 'Receiving 5 kg Niacinamide'
        ]);

        $responseIn->assertStatus(200)
            ->assertJsonPath('status', 'success');

        $this->assertEquals(20.0, (float) Ingredient::find($niacinamide->id)->current_stock);

        // Stock Opname: Set absolute stock physically to 2.5 kg
        $responseOpname = $this->actingAs($userGudang, 'sanctum')->postJson('/api/inventory/adjust', [
            'ingredient_id' => $niacinamide->id,
            'type' => 'adjustment',
            'quantity' => 2.5,
            'unit' => 'kg',
            'notes' => 'Monthly physical count opname'
        ]);

        $responseOpname->assertStatus(200);
        $this->assertEquals(2.5, (float) Ingredient::find($niacinamide->id)->current_stock);
    }
}
