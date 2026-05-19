<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Formula;
use App\Models\Ingredient;
use App\Models\ProductionOrder;
use App\Models\AuditLog;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    /**
     * Fetch aggregated manufacturing metrics and live audit activities.
     */
    public function index(Request $request)
    {
        $totalFormulas = Formula::count();
        $approvedFormulas = Formula::where('status', 'approved')->count();

        // Material is low stock if active current_stock level falls under 20.0 base units
        $lowStockCount = Ingredient::where('current_stock', '<', 20.0)->count();

        // Ongoing manufacturing orders
        $activeProductions = ProductionOrder::whereIn('status', ['scheduled', 'material_requested', 'in_production'])->count();
        $completedProductions = ProductionOrder::where('status', 'done')->count();

        // Expiry date analytics
        $totalIngredients = Ingredient::count();
        
        $expiredItems = Ingredient::whereNotNull('expired_at')
            ->where('expired_at', '<', now()->toDateString())
            ->select('id', 'name', 'code', 'expired_at', 'current_stock', 'unit')
            ->get();

        $nearExpiryItems = Ingredient::whereNotNull('expired_at')
            ->where('expired_at', '>=', now()->toDateString())
            ->where('expired_at', '<=', now()->addDays(30)->toDateString())
            ->select('id', 'name', 'code', 'expired_at', 'current_stock', 'unit')
            ->get();

        // Handle auto-alert and Pusher broadcast for near-expiry ingredients when Kepala Gudang requests
        $user = $request->user();
        if ($user && $user->role === 'kepala_gudang') {
            foreach ($nearExpiryItems as $ing) {
                // Ensure we don't spam duplicate alerts by checking if a notification for this ingredient code was sent in the last 24 hours
                $notifExists = \App\Models\Notification::where('user_id', $user->id)
                    ->where('type', 'near_expiry')
                    ->where('message', 'like', "%{$ing->code}%")
                    ->where('created_at', '>=', now()->subDay())
                    ->exists();

                if (!$notifExists) {
                    \App\Models\Notification::create([
                        'user_id' => $user->id,
                        'type' => 'near_expiry',
                        'title' => 'Peringatan Kadaluarsa!',
                        'message' => "Bahan baku '{$ing->name}' ({$ing->code}) akan segera kadaluarsa pada tanggal " . ($ing->expired_at ? $ing->expired_at->format('d-m-Y') : '') . ". Harap segera digunakan!",
                    ]);

                    // Broadcast instant real-time event to Pusher channels
                    event(new \App\Events\RealTimeActionEvent(
                        'Sistem Gudang',
                        'system',
                        'near_expiry',
                        "Bahan baku '{$ing->name}' ({$ing->code}) mendekati tanggal kadaluarsa (" . ($ing->expired_at ? $ing->expired_at->format('d-m-Y') : '') . "). Harap segera digunakan!"
                    ));
                }
            }
        }

        // Fetch latest 10 audit logs with active user references
        $recentActivities = AuditLog::with('user:id,name,role')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => [
                'metrics' => [
                    'total_formulas' => $totalFormulas,
                    'approved_formulas' => $approvedFormulas,
                    'low_stock_materials_count' => $lowStockCount,
                    'active_productions_count' => $activeProductions,
                    'completed_productions_count' => $completedProductions,
                    'total_ingredients' => $totalIngredients,
                    'expired_count' => $expiredItems->count(),
                    'near_expiry_count' => $nearExpiryItems->count(),
                ],
                'expired_ingredients' => $expiredItems,
                'near_expiry_ingredients' => $nearExpiryItems,
                'recent_activities' => $recentActivities
            ]
        ]);
    }
}
