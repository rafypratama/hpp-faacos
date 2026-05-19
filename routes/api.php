<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\FormulaController;
use App\Http\Controllers\Api\ProductionController;
use App\Http\Controllers\Api\InventoryController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public Authentication Route
Route::post('/login', [AuthController::class, 'login']);

// Protected API Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/user', function (Request $request) {
        return response()->json([
            'status' => 'success',
            'data' => $request->user()
        ]);
    });

    // Real-time Business Analytics & Live Audit Logs
    Route::get('/dashboard', [DashboardController::class, 'index']);

    // Formula & HPP Costing Workflow (R&D)
    Route::get('/formulas', [FormulaController::class, 'index']);
    Route::post('/formulas', [FormulaController::class, 'store']);
    Route::get('/formulas/{id}', [FormulaController::class, 'show']);
    Route::get('/formulas/{id}/pre-check-stock', [FormulaController::class, 'preCheckStock']);
    Route::post('/formulas/{id}/approve', [FormulaController::class, 'approve'])->middleware('role:rnd');

    // Production Order & Material Requests (Kepala Produksi & Kepala Gudang)
    Route::get('/productions', [ProductionController::class, 'index']);
    Route::post('/productions', [ProductionController::class, 'store'])->middleware('role:kepala_produksi');
    Route::get('/material-requests', [ProductionController::class, 'materialRequests']);
    Route::get('/material-requests/{id}', [ProductionController::class, 'materialRequestDetail']);
    Route::post('/material-requests/{id}/verify', [ProductionController::class, 'verifyMaterialRequest'])->middleware('role:kepala_gudang');

    // Inventory Stock & Log Control (Kepala Gudang)
    Route::get('/inventory', [InventoryController::class, 'index']);
    Route::get('/inventory/logs', [InventoryController::class, 'logs']);
    Route::post('/inventory/adjust', [InventoryController::class, 'adjust'])->middleware('role:kepala_gudang');
    Route::post('/inventory', [InventoryController::class, 'store'])->middleware('role:kepala_gudang');

    // User & Role Management (Admin only)
    Route::middleware('role:admin')->group(function () {
        Route::apiResource('/users', UserController::class);
    });

    // Audit Logs (Transparency portal)
    Route::get('/audit-logs', function () {
        return response()->json([
            'status' => 'success',
            'data' => \App\Models\AuditLog::with('user:id,name,role')->orderBy('created_at', 'desc')->get()
        ]);
    });
});
