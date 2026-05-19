<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProductionOrder;
use App\Models\MaterialRequest;
use App\Models\MaterialRequestItem;
use App\Models\Formula;
use App\Models\Ingredient;
use App\Models\InventoryLog;
use App\Models\Notification;
use App\Models\AuditLog;
use App\Services\UnitConverterService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Exception;

class ProductionController extends Controller
{
    /**
     * Display a listing of production orders.
     */
    public function index()
    {
        $orders = ProductionOrder::with(['formula:id,code,name,batch_size', 'creator:id,name,role', 'materialRequest'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $orders
        ]);
    }

    /**
     * Store a newly scheduled production order and auto-generate its Material Request.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'formula_id' => 'required|exists:formulas,id',
            'target_quantity' => 'required|numeric|gt:0',
            'batch_count' => 'required|integer|gt:0',
            'scheduled_start_date' => 'nullable|date',
            'scheduled_end_date' => 'nullable|date|after_or_equal:scheduled_start_date',
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
            $formula = Formula::with('ingredients.ingredient')->find($request->formula_id);

            // Verify the formula is approved by R&D
            if ($formula->status !== 'approved') {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Hanya formula yang berstatus APPROVED yang dapat dijadwalkan untuk produksi.'
                ], 400);
            }

            // Generate unique production order code: PRO-YYYYMMDD-XXXX
            $date = date('Ymd');
            $pCount = ProductionOrder::whereDate('created_at', date('Y-m-d'))->count() + 1;
            $pCode = 'PRO-' . $date . '-' . str_pad($pCount, 4, '0', STR_PAD_LEFT);

            // 1. Create Production Order
            $order = ProductionOrder::create([
                'code' => $pCode,
                'formula_id' => $formula->id,
                'target_quantity' => $request->target_quantity,
                'batch_count' => $request->batch_count,
                'status' => 'scheduled',
                'scheduled_start_date' => $request->scheduled_start_date,
                'scheduled_end_date' => $request->scheduled_end_date,
                'created_by' => $user ? $user->id : null
            ]);

            // Generate unique material request code: MR-YYYYMMDD-XXXX
            $mrCount = MaterialRequest::whereDate('created_at', date('Y-m-d'))->count() + 1;
            $mrCode = 'MR-' . $date . '-' . str_pad($mrCount, 4, '0', STR_PAD_LEFT);

            // 2. Create Material Request
            $materialRequest = MaterialRequest::create([
                'code' => $mrCode,
                'production_order_id' => $order->id,
                'status' => 'pending',
                'created_by' => $user ? $user->id : null
            ]);

            // 3. Populate Material Request Items based on Production Target / Batch Size
            $factor = $request->target_quantity / $formula->batch_size;

            foreach ($formula->ingredients as $formulaIngredient) {
                $requiredQty = $formulaIngredient->quantity_per_batch * $factor;

                MaterialRequestItem::create([
                    'material_request_id' => $materialRequest->id,
                    'ingredient_id' => $formulaIngredient->ingredient_id,
                    'quantity_required' => $requiredQty,
                    'unit' => $formulaIngredient->unit,
                    'quantity_approved' => 0
                ]);
            }

            // 4. Update order status to match
            $order->update(['status' => 'material_requested']);

            // 5. Notify warehouse and admin about the new material request
            $warehouseStaff = \App\Models\User::whereIn('role', ['kepala_gudang', 'admin'])->get();
            foreach ($warehouseStaff as $staff) {
                Notification::create([
                    'user_id' => $staff->id,
                    'type' => 'material_request',
                    'title' => 'Permintaan Pengeluaran Bahan Baku Baru',
                    'message' => "Kepala Produksi mengajukan pengeluaran bahan baku untuk jadwal produksi '" . $order->code . "' (MR: " . $materialRequest->code . ")."
                ]);
            }

            // Log production scheduling
            AuditLog::logAction(
                $user ? $user->id : null,
                'schedule_production',
                "Kepala Produksi membuat jadwal produksi baru {$order->code} untuk formula {$formula->name} ({$formula->code}) sebesar {$order->target_quantity} kg/L.",
                $order,
                [
                    'code' => $order->code,
                    'formula_id' => $formula->id,
                    'target_quantity' => $order->target_quantity,
                    'batch_count' => $order->batch_count
                ]
            );

            // Broadcast real-time production scheduled event
            event(new \App\Events\RealTimeActionEvent(
                $user ? $user->name : 'Kepala Produksi',
                $user ? $user->role : 'kepala_produksi',
                'schedule_production',
                "Kepala Produksi mengajukan pengeluaran bahan baku untuk jadwal produksi '{$order->code}' (MR: {$materialRequest->code})."
            ));

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Jadwal produksi berhasil dibuat dan Permintaan Bahan Baku otomatis diajukan ke Gudang.',
                'data' => ProductionOrder::with(['formula', 'materialRequest.items.ingredient'])->find($order->id)
            ], 201);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal membuat jadwal produksi: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get all pending and processed material requests.
     */
    public function materialRequests()
    {
        $requests = MaterialRequest::with(['productionOrder.formula', 'creator:id,name,role', 'verifier:id,name,role'])
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $requests
        ]);
    }

    /**
     * Display a specific material request with itemized ingredients.
     */
    public function materialRequestDetail($id)
    {
        $mr = MaterialRequest::with(['productionOrder.formula', 'creator', 'verifier', 'items.ingredient'])
            ->find($id);

        if (!$mr) {
            return response()->json([
                'status' => 'error',
                'message' => 'Permintaan bahan baku tidak ditemukan.'
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => $mr
        ]);
    }

    /**
     * Verify (Approve / Reject) a pending Material Request (Warehouse Head action).
     */
    public function verifyMaterialRequest(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:approved,rejected',
            'rejection_reason' => 'required_if:status,rejected|nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors()
            ], 422);
        }

        $mr = MaterialRequest::with(['items.ingredient', 'productionOrder'])->find($id);

        if (!$mr) {
            return response()->json([
                'status' => 'error',
                'message' => 'Permintaan bahan baku tidak ditemukan.'
            ], 404);
        }

        if ($mr->status !== 'pending') {
            return response()->json([
                'status' => 'error',
                'message' => 'Permintaan bahan baku sudah diproses sebelumnya.'
            ], 400);
        }

        try {
            DB::beginTransaction();

            $user = $request->user();

            if ($request->status === 'rejected') {
                $mr->update([
                    'status' => 'rejected',
                    'rejection_reason' => $request->rejection_reason,
                    'verified_by' => $user ? $user->id : null,
                    'verified_at' => now()
                ]);

                // Reset production order status
                $mr->productionOrder->update(['status' => 'scheduled']);

                // Notify production head
                if ($mr->productionOrder->created_by) {
                    Notification::create([
                        'user_id' => $mr->productionOrder->created_by,
                        'type' => 'mr_rejected',
                        'title' => 'Permintaan Bahan Baku Ditolak',
                        'message' => "Permintaan bahan baku (" . $mr->code . ") ditolak oleh Kepala Gudang. Alasan: " . $request->rejection_reason
                    ]);
                }

                // Log the MR rejection
                AuditLog::logAction(
                    $user ? $user->id : null,
                    'reject_material_request',
                    "Kepala Gudang menolak permintaan bahan baku {$mr->code} untuk jadwal produksi {$mr->productionOrder->code}. Alasan: {$request->rejection_reason}",
                    $mr,
                    [
                        'code' => $mr->code,
                        'rejection_reason' => $request->rejection_reason
                    ]
                );

                // Broadcast real-time MR rejected event
                event(new \App\Events\RealTimeActionEvent(
                    $user ? $user->name : 'Kepala Gudang',
                    $user ? $user->role : 'kepala_gudang',
                    'mr_rejected',
                    "Kepala Gudang menolak permintaan bahan baku {$mr->code}. Alasan: {$request->rejection_reason}"
                ));

                DB::commit();

                return response()->json([
                    'status' => 'success',
                    'message' => 'Permintaan bahan baku berhasil ditolak.',
                    'data' => $mr
                ]);
            }

            // APPROVED workflow: Decrement stock, log inventory movements, update statuses
            foreach ($mr->items as $item) {
                $ingredient = $item->ingredient;

                // 1. Convert MR item quantity into standard master ingredient unit
                $reqQty = (float) $item->quantity_required;
                $reqUnit = $item->unit;
                $masterUnit = $ingredient->unit;

                $reqQtyInMaster = UnitConverterService::convert($reqQty, $reqUnit, $masterUnit);

                // 2. Perform double check on stock
                if ($ingredient->current_stock < $reqQtyInMaster) {
                    throw new Exception("Stok untuk bahan '" . $ingredient->name . "' tidak mencukupi di gudang. Dibutuhkan: " . $reqQtyInMaster . " " . $masterUnit . ", Tersedia: " . $ingredient->current_stock . " " . $masterUnit);
                }

                // 3. Decrement stock
                $oldStock = $ingredient->current_stock;
                $newStock = $oldStock - $reqQtyInMaster;
                $ingredient->update(['current_stock' => $newStock]);

                // 4. Log Inventory Movement
                InventoryLog::create([
                    'ingredient_id' => $ingredient->id,
                    'type' => 'production_release',
                    'quantity' => $reqQty,
                    'unit' => $reqUnit,
                    'balance_after' => $newStock, // in master unit
                    'reference_type' => 'MaterialRequest',
                    'reference_id' => $mr->id,
                    'notes' => 'Pengeluaran bahan untuk produksi order ' . $mr->productionOrder->code,
                    'user_id' => $user ? $user->id : null
                ]);

                // 5. Update MR item approved quantity
                $item->update(['quantity_approved' => $reqQty]);
            }

            // Update MR status
            $mr->update([
                'status' => 'approved',
                'verified_by' => $user ? $user->id : null,
                'verified_at' => now()
            ]);

            // Update Production Order status
            $mr->productionOrder->update(['status' => 'in_production']);

            // Notify production head
            if ($mr->productionOrder->created_by) {
                Notification::create([
                    'user_id' => $mr->productionOrder->created_by,
                    'type' => 'mr_approved',
                    'title' => 'Bahan Baku Telah Dikeluarkan',
                    'message' => "Permintaan bahan baku (" . $mr->code . ") telah disetujui. Bahan baku sudah dapat diambil di Gudang untuk mulai proses produksi."
                ]);
            }

            // Log the MR approval and material release
            AuditLog::logAction(
                $user ? $user->id : null,
                'approve_material_request',
                "Kepala Gudang menyetujui permintaan bahan baku {$mr->code} untuk jadwal produksi {$mr->productionOrder->code}. Stok didekremen otomatis.",
                $mr,
                [
                    'code' => $mr->code,
                    'production_order_code' => $mr->productionOrder->code
                ]
            );

            // Broadcast real-time MR approved event
            event(new \App\Events\RealTimeActionEvent(
                $user ? $user->name : 'Kepala Gudang',
                $user ? $user->role : 'kepala_gudang',
                'mr_approved',
                "Kepala Gudang menyetujui permintaan bahan baku {$mr->code} untuk jadwal produksi {$mr->productionOrder->code}."
            ));

            DB::commit();

            return response()->json([
                'status' => 'success',
                'message' => 'Permintaan bahan baku disetujui. Stok otomatis terpotong.',
                'data' => MaterialRequest::with('items.ingredient')->find($mr->id)
            ]);

        } catch (Exception $e) {
            DB::rollBack();
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal memproses verifikasi pengeluaran bahan: ' . $e->getMessage()
            ], 500);
        }
    }
}
