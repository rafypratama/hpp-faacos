<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Formula;
use App\Models\FormulaIngredient;
use App\Models\FormulaCost;
use App\Models\HppCalculation;
use App\Models\Ingredient;
use App\Models\Notification;
use App\Models\User;
use App\Models\AuditLog;
use App\Services\UnitConverterService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Exception;

class FormulaController extends Controller
{
    /**
     * Display a listing of formulas.
     */
    public function index()
    {
        $formulas = Formula::with(['creator:id,name,role', 'approver:id,name,role', 'hpp'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $formulas
        ]);
    }

    /**
     * Store a newly created formula (Costing Simulation).
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'batch_size' => 'required|numeric|gt:0',
            'ingredients' => 'required|array|min:1',
            'ingredients.*.ingredient_id' => 'required|exists:ingredients,id',
            'ingredients.*.quantity' => 'required|numeric|gt:0',
            'ingredients.*.unit' => 'required|string',
            'costs' => 'nullable|array',
            'costs.*.type' => 'required|in:labor,overhead,other',
            'costs.*.description' => 'required|string|max:255',
            'costs.*.cost_value' => 'required|numeric|min:0',
            'profit_margin_percent' => 'nullable|numeric|min:0'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();

            // Generate unique formula code: FOR-YYYYMMDD-XXXX
            $date = date('Ymd');
            $count = Formula::whereDate('created_at', date('Y-m-d'))->count() + 1;
            $code = 'FOR-' . $date . '-' . str_pad($count, 4, '0', STR_PAD_LEFT);

            // 1. Create Formula
            $formula = Formula::create([
                'code' => $code,
                'name' => $request->name,
                'batch_size' => $request->batch_size,
                'status' => 'draft',
                'created_by' => $user ? $user->id : null
            ]);

            // 2. Save Formula Ingredients & Costs
            $this->saveIngredientsAndCosts($formula, $request->ingredients, $request->costs ?? []);

            // 3. Compute HPP
            $this->calculateHpp($formula, $request->profit_margin_percent ?? 0.0);

            // Log formula creation
            AuditLog::logAction(
                $user ? $user->id : null,
                'create_formula',
                "R&D membuat simulasi costing formula baru: {$formula->name} ({$formula->code}) dengan ukuran batch {$formula->batch_size} kg/L.",
                $formula,
                [
                    'name' => $formula->name,
                    'batch_size' => $formula->batch_size,
                    'code' => $formula->code
                ]
            );

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Simulasi costing formula berhasil disimpan.',
                'data' => Formula::with(['creator', 'ingredients.ingredient', 'costs', 'hpp'])->find($formula->id)
            ], 210);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyimpan formula: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Display the specified formula.
     */
    public function show($id)
    {
        $formula = Formula::with(['creator', 'approver', 'ingredients.ingredient', 'costs', 'hpp'])->find($id);

        if (!$formula) {
            return response()->json([
                'status' => 'error',
                'message' => 'Formula tidak ditemukan.'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $formula
        ]);
    }

    /**
     * Pre-check stock availability in warehouse based on formula requirements.
     */
    public function preCheckStock($id, Request $request)
    {
        $formula = Formula::with('ingredients.ingredient')->find($id);

        if (!$formula) {
            return response()->json([
                'status' => 'error',
                'message' => 'Formula tidak ditemukan.'
            ], 404);
        }

        // Target quantity can be customized, defaults to formula batch size
        $targetQuantity = $request->input('target_quantity', $formula->batch_size);
        $factor = $targetQuantity / $formula->batch_size;

        $shortages = [];
        $sufficient = true;

        foreach ($formula->ingredients as $formulaIngredient) {
            $ingredient = $formulaIngredient->ingredient;
            
            // Calculate required quantity for the target production
            $requiredQuantity = $formulaIngredient->quantity_per_batch * $factor;
            $requiredUnit = $formulaIngredient->unit;

            // Get stock in master warehouse unit
            $masterStock = $ingredient->current_stock;
            $masterUnit = $ingredient->unit;

            // Convert master warehouse stock into the unit requested in the formula
            try {
                $availableStockInFormulaUnit = UnitConverterService::convert($masterStock, $masterUnit, $requiredUnit);
            } catch (Exception $e) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Terjadi kesalahan konversi satuan untuk bahan ' . $ingredient->name . ': ' . $e->getMessage()
                ], 500);
            }

            if ($availableStockInFormulaUnit < $requiredQuantity) {
                $sufficient = false;
                $deficiency = $requiredQuantity - $availableStockInFormulaUnit;

                // Also format shortage details back to master unit for Gudang/Admin reference
                $deficiencyInMasterUnit = UnitConverterService::convert($deficiency, $requiredUnit, $masterUnit);

                $shortages[] = [
                    'ingredient_id' => $ingredient->id,
                    'code' => $ingredient->code,
                    'name' => $ingredient->name,
                    'type' => $ingredient->type,
                    'required_quantity' => round($requiredQuantity, 4),
                    'required_unit' => $requiredUnit,
                    'available_stock' => round($availableStockInFormulaUnit, 4),
                    'available_unit' => $requiredUnit,
                    'shortage_quantity' => round($deficiency, 4),
                    'shortage_unit' => $requiredUnit,
                    // Additional info in Master/Warehouse Unit
                    'shortage_in_master' => round($deficiencyInMasterUnit, 4),
                    'master_unit' => $masterUnit
                ];
            }
        }

        return response()->json([
            'status' => 'success',
            'sufficient' => $sufficient,
            'target_quantity' => $targetQuantity,
            'batch_size' => $formula->batch_size,
            'shortages' => $shortages
        ]);
    }

    /**
     * Approve formula internally by R&D (ACC Formula).
     */
    public function approve(Request $request, $id)
    {
        $formula = Formula::find($id);

        if (!$formula) {
            return response()->json([
                'status' => 'error',
                'message' => 'Formula tidak ditemukan.'
            ], 404);
        }

        if ($formula->status === 'approved') {
            return response()->json([
                'status' => 'error',
                'message' => 'Formula sudah disetujui sebelumnya.'
            ], 400);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();

            // 1. Perform stock check for the formula's base batch size
            $stockCheckResponse = $this->preCheckStock($id, $request);
            $stockCheckData = json_decode($stockCheckResponse->getContent(), true);

            if ($stockCheckData['status'] === 'error') {
                throw new Exception($stockCheckData['message']);
            }

            // 2. If stock is insufficient, send restock alerts and return dialog block payload
            if (!$stockCheckData['sufficient']) {
                $shortages = $stockCheckData['shortages'];
                
                // Formulate warning detail string
                $shortageDetails = [];
                foreach ($shortages as $s) {
                    $shortageDetails[] = "- " . $s['name'] . ": butuh " . $s['required_quantity'] . " " . $s['required_unit'] . " (kurang " . $s['shortage_quantity'] . " " . $s['shortage_unit'] . ")";
                }
                $shortageString = implode("\n", $shortageDetails);

                // Auto-notify all Warehouse Heads (Kepala Gudang) and Admins
                $recipients = User::whereIn('role', ['kepala_gudang', 'admin'])->get();
                foreach ($recipients as $recipient) {
                    Notification::create([
                        'user_id' => $recipient->id,
                        'type' => 'restock_alert',
                        'title' => 'Peringatan Kebutuhan Restock Bahan Baku',
                        'message' => "Divisi R&D sedang mengajukan ACC Formula '" . $formula->name . "' (" . $formula->code . "), namun persediaan stok di gudang tidak mencukupi.\n\nDetail kekurangan bahan:\n" . $shortageString . "\n\nMohon segera lakukan pengadaan / restock bahan baku tersebut."
                    ]);
                }

                // Log the insufficient stock attempt
                AuditLog::logAction(
                    $user ? $user->id : null,
                    'attempt_approve_insufficient_stock',
                    "R&D mencoba menyetujui formula {$formula->name} ({$formula->code}) tetapi dibatalkan karena kekurangan stok gudang.",
                    $formula,
                    ['shortages' => $shortages]
                );

                // Broadcast real-time stock alert
                event(new \App\Events\RealTimeActionEvent(
                    $user ? $user->name : 'R&D Scientist',
                    $user ? $user->role : 'rnd',
                    'restock_alert',
                    "Peringatan Kebutuhan Restock: Formula '{$formula->name}' ({$formula->code}) gagal di-ACC karena kekurangan stok!"
                ));

                DB::commit(); // Commit notifications safely

                return response()->json([
                    'status' => 'insufficient_stock',
                    'message' => 'Stok bahan baku tidak mencukupi untuk melakukan ACC formula ini.',
                    'shortages' => $shortages
                ], 422);
            }

            // 3. If stock is sufficient, finalize approval
            $formula->update([
                'status' => 'approved',
                'rnd_approved_by' => $user ? $user->id : null,
                'rnd_approved_at' => now()
            ]);

            // Log formula approval
            AuditLog::logAction(
                $user ? $user->id : null,
                'approve_formula',
                "R&D menyetujui (ACC) formula: {$formula->name} ({$formula->code}) untuk diproduksi.",
                $formula,
                [
                    'name' => $formula->name,
                    'code' => $formula->code
                ]
            );

            // Broadcast real-time formula ACC event
            event(new \App\Events\RealTimeActionEvent(
                $user ? $user->name : 'R&D Scientist',
                $user ? $user->role : 'rnd',
                'approve_formula',
                "R&D menyetujui (ACC) formula '{$formula->name}' ({$formula->code}) untuk diproduksi."
            ));

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Formula berhasil disetujui (ACC) dan diteruskan ke tahap produksi.',
                'data' => Formula::with(['approver', 'hpp'])->find($formula->id)
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyetujui formula: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Helper logic to save ingredients and costs.
     */
    private function saveIngredientsAndCosts(Formula $formula, array $ingredients, array $costs)
    {
        // Save ingredients
        foreach ($ingredients as $ing) {
            $ingredient = Ingredient::find($ing['ingredient_id']);
            if (!$ingredient) {
                throw new Exception("Bahan baku dengan ID " . $ing['ingredient_id'] . " tidak ditemukan.");
            }

            // Standardize prices. Formula quantity is converted to master ingredient unit to calculate subtotal
            $qty = (float) $ing['quantity'];
            $formulaUnit = $ing['unit'];
            $masterUnit = $ingredient->unit;
            $pricePerMasterUnit = (float) $ingredient->price_per_unit;

            // Convert quantity to master unit for cost multiplication
            $qtyInMasterUnit = UnitConverterService::convert($qty, $formulaUnit, $masterUnit);
            $subtotal = $qtyInMasterUnit * $pricePerMasterUnit;

            FormulaIngredient::create([
                'formula_id' => $formula->id,
                'ingredient_id' => $ingredient->id,
                'quantity_per_batch' => $qty,
                'unit' => $formulaUnit,
                'unit_price' => $pricePerMasterUnit, // price per master unit
                'subtotal' => $subtotal
            ]);
        }

        // Save costs
        foreach ($costs as $c) {
            FormulaCost::create([
                'formula_id' => $formula->id,
                'type' => $c['type'],
                'description' => $c['description'],
                'cost_value' => $c['cost_value']
            ]);
        }
    }

    /**
     * Compute and save HPP calculations.
     */
    private function calculateHpp(Formula $formula, float $profitMarginPercent)
    {
        // 1. Sum ingredients subtotal
        $totalIngredientCost = FormulaIngredient::where('formula_id', $formula->id)->sum('subtotal');

        // 2. Sum other cost sections
        $totalLaborCost = FormulaCost::where('formula_id', $formula->id)->where('type', 'labor')->sum('cost_value');
        $totalOverheadCost = FormulaCost::where('formula_id', $formula->id)->where('type', 'overhead')->sum('cost_value');
        $totalOtherCost = FormulaCost::where('formula_id', $formula->id)->where('type', 'other')->sum('cost_value');

        // 3. Sum total HPP
        $totalHpp = $totalIngredientCost + $totalLaborCost + $totalOverheadCost + $totalOtherCost;
        $hppPerUnit = $totalHpp / $formula->batch_size;

        // 4. Calculate selling price based on profit margin
        $profitAmount = $hppPerUnit * ($profitMarginPercent / 100);
        $sellingPrice = $hppPerUnit + $profitAmount;

        // Save/Update HppCalculation
        HppCalculation::updateOrCreate(
            ['formula_id' => $formula->id],
            [
                'total_ingredient_cost' => $totalIngredientCost,
                'total_labor_cost' => $totalLaborCost,
                'total_overhead_cost' => $totalOverheadCost,
                'total_other_cost' => $totalOtherCost,
                'total_hpp' => $totalHpp,
                'hpp_per_unit' => $hppPerUnit,
                'profit_margin_percent' => $profitMarginPercent,
                'selling_price' => $sellingPrice
            ]
        );
    }
}
