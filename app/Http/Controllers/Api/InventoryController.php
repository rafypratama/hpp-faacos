<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ingredient;
use App\Models\InventoryLog;
use App\Models\AuditLog;
use App\Services\UnitConverterService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Exception;

class InventoryController extends Controller
{
    /**
     * Display a listing of ingredients with current stock status.
     */
    public function index()
    {
        $ingredients = Ingredient::orderBy('type', 'asc')
            ->orderBy('name', 'asc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $ingredients
        ]);
    }

    /**
     * Display a listing of stock movement logs.
     */
    public function logs()
    {
        $logs = InventoryLog::with(['ingredient', 'user:id,name,role'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $logs
        ]);
    }

    /**
     * Perform a manual stock adjustment (Stock In, Stock Out, or Physical Stock Opname).
     */
    public function adjust(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'ingredient_id' => 'required|exists:ingredients,id',
            'type' => 'required|in:in,out,adjustment',
            'quantity' => 'required|numeric|min:0',
            'unit' => 'required|string',
            'notes' => 'nullable|string|max:500'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();
            $ingredient = Ingredient::find($request->ingredient_id);

            $qty = (float) $request->quantity;
            $inputUnit = $request->unit;
            $masterUnit = $ingredient->unit;

            // 1. Convert input quantity to standard warehouse/master unit
            $qtyInMaster = UnitConverterService::convert($qty, $inputUnit, $masterUnit);
            $oldStock = (float) $ingredient->current_stock;
            $newStock = $oldStock;

            // 2. Determine new stock balance based on adjustment type
            if ($request->type === 'in') {
                $newStock = $oldStock + $qtyInMaster;
            } elseif ($request->type === 'out') {
                if ($oldStock < $qtyInMaster) {
                    return response()->json([
                        'status' => 'error',
                        'message' => "Stok tidak mencukupi untuk dikeluarkan. Stok saat ini: {$oldStock} {$masterUnit}."
                    ], 400);
                }
                $newStock = $oldStock - $qtyInMaster;
            } elseif ($request->type === 'adjustment') {
                // Stock Opname: Override stock directly to the given physical amount
                $newStock = $qtyInMaster;
            }

            // 3. Update stock levels
            $ingredient->update(['current_stock' => $newStock]);

            // 4. Create Inventory Log entry
            $log = InventoryLog::create([
                'ingredient_id' => $ingredient->id,
                'type' => $request->type,
                'quantity' => $qty,
                'unit' => $inputUnit,
                'balance_after' => $newStock,
                'reference_type' => 'ManualAdjustment',
                'reference_id' => null,
                'notes' => $request->notes ?? 'Manual stock adjustment by ' . ($user ? $user->name : 'System'),
                'user_id' => $user ? $user->id : null
            ]);

            // 5. Create Audit Log entry
            AuditLog::logAction(
                $user ? $user->id : null, 
                'adjust_stock', 
                "Penyesuaian stok manual untuk bahan {$ingredient->name} ({$ingredient->code}) tipe '{$request->type}' sebesar {$qty} {$inputUnit}.", 
                $ingredient, 
                [
                    'type' => $request->type,
                    'quantity' => $qty,
                    'unit' => $inputUnit,
                    'old_stock' => $oldStock,
                    'new_stock' => $newStock,
                    'notes' => $request->notes
                ]
            );

            // Broadcast real-time stock adjustment event
            event(new \App\Events\RealTimeActionEvent(
                $user ? $user->name : 'Kepala Gudang',
                $user ? $user->role : 'kepala_gudang',
                'adjust_stock',
                "Kepala Gudang menyesuaikan stok '{$ingredient->name}' ({$ingredient->code}) tipe '{$request->type}' sebesar {$qty} {$inputUnit}."
            ));

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Stok bahan berhasil disesuaikan.',
                'data' => [
                    'ingredient' => $ingredient,
                    'log' => $log
                ]
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menyesuaikan stok: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Create a new raw material or packaging. If it already exists by code or name,
     * automatically merge the new initial stock with the existing remaining stock.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|max:50',
            'name' => 'required|string|max:100',
            'type' => 'required|in:raw_material,packaging',
            'unit' => 'required|string|max:20',
            'price_per_unit' => 'required|numeric|min:0',
            'current_stock' => 'required|numeric|min:0',
            'minimum_stock' => 'nullable|numeric|min:0',
            'expired_at' => 'nullable|date'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();
            $code = strtoupper(trim($request->code));
            $name = trim($request->name);

            // Check if ingredient with same code OR name already exists (case-insensitive)
            $existing = Ingredient::where('code', $code)
                ->orWhere(DB::raw('LOWER(name)'), strtolower($name))
                ->first();

            if ($existing) {
                // If it already exists: Merge the incoming stock with the sisa stock!
                $qty = (float) $request->current_stock;
                $inputUnit = $request->unit;
                $masterUnit = $existing->unit;

                // Convert incoming quantity to standard master unit of the existing item
                $qtyInMaster = UnitConverterService::convert($qty, $inputUnit, $masterUnit);
                $oldStock = (float) $existing->current_stock;
                $newStock = $oldStock + $qtyInMaster;

                // Update stock and price details
                $existing->update([
                    'current_stock' => $newStock,
                    'price_per_unit' => (float) $request->price_per_unit > 0 ? (float) $request->price_per_unit : $existing->price_per_unit
                ]);

                // Create Inventory Log showing the addition
                $log = InventoryLog::create([
                    'ingredient_id' => $existing->id,
                    'type' => 'in',
                    'quantity' => $qty,
                    'unit' => $inputUnit,
                    'balance_after' => $newStock,
                    'reference_type' => 'StockIn',
                    'reference_id' => null,
                    'notes' => 'Penerimaan bahan baku tambahan (otomatis digabung). Sisa stok lama: ' . $oldStock . ' ' . $masterUnit,
                    'user_id' => $user ? $user->id : null
                ]);

                // Log audit action
                AuditLog::logAction(
                    $user ? $user->id : null,
                    'adjust_stock',
                    "Penerimaan Bahan Baku Sama ({$existing->name}): Stok baru {$qty} {$inputUnit} digabungkan dengan sisa lama {$oldStock} {$masterUnit}.",
                    $existing,
                    [
                        'old_stock' => $oldStock,
                        'new_stock' => $newStock,
                        'added_quantity' => $qty,
                        'unit' => $inputUnit
                    ]
                );

                // Broadcast real-time event
                event(new \App\Events\RealTimeActionEvent(
                    $user ? $user->name : 'Kepala Gudang',
                    $user ? $user->role : 'kepala_gudang',
                    'adjust_stock',
                    "Kepala Gudang menerima bahan baru '{$existing->name}' ({$existing->code}) sebesar {$qty} {$inputUnit} (digabung dengan sisa lama)."
                ));

                DB::commit();

                return response()->json([
                    'status' => 'success',
                    'message' => "Bahan baku dengan kode/nama sama terdeteksi. Jumlah baru {$qty} {$inputUnit} telah digabung dengan sisa stok lama.",
                    'data' => [
                        'merged' => true,
                        'ingredient' => $existing,
                        'log' => $log
                    ]
                ]);
            }

            // If it does NOT exist: Create a new ingredient!
            $ingredient = Ingredient::create([
                'code' => $code,
                'name' => $name,
                'type' => $request->type,
                'unit' => $request->unit,
                'price_per_unit' => $request->price_per_unit,
                'current_stock' => $request->current_stock,
                'minimum_stock' => $request->minimum_stock ?? 0,
                'expired_at' => $request->expired_at,
            ]);

            // Create Inventory Log for initial stock
            $log = InventoryLog::create([
                'ingredient_id' => $ingredient->id,
                'type' => 'in',
                'quantity' => $request->current_stock,
                'unit' => $request->unit,
                'balance_after' => $request->current_stock,
                'reference_type' => 'InitialStock',
                'reference_id' => null,
                'notes' => 'Penerimaan stok awal untuk bahan baku baru.',
                'user_id' => $user ? $user->id : null
            ]);

            // Log audit action
            AuditLog::logAction(
                $user ? $user->id : null,
                'create_ingredient',
                "Penerimaan Bahan Baku Baru: {$ingredient->name} ({$ingredient->code}) dengan stok awal {$ingredient->current_stock} {$ingredient->unit}.",
                $ingredient
            );

            // Broadcast real-time event
            event(new \App\Events\RealTimeActionEvent(
                $user ? $user->name : 'Kepala Gudang',
                $user ? $user->role : 'kepala_gudang',
                'adjust_stock',
                "Kepala Gudang menambahkan bahan baku baru '{$ingredient->name}' ({$ingredient->code}) dengan stok awal {$request->current_stock} {$request->unit}."
            ));

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Bahan baku baru berhasil didaftarkan.',
                'data' => [
                    'merged' => false,
                    'ingredient' => $ingredient,
                    'log' => $log
                ]
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mendaftarkan bahan baku: ' . $e->getMessage()
            ], 500);
        }
    }
}
