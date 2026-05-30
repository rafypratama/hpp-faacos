<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SyncRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
use Exception;

class SyncController extends Controller
{
    /**
     * Process a batch of offline-queued items.
     * Each item is dispatched to its respective existing controller method,
     * preserving the full business logic, audit logging, and real-time broadcasts.
     */
    public function batch(SyncRequest $request)
    {
        $items = $request->input('items');
        $results = [];

        foreach ($items as $item) {
            $id = $item['id'] ?? null;
            $actionType = $item['action_type'];
            $payload = $item['payload'];
            $clientTimestamp = $item['timestamp'];

            try {
                $result = $this->processItem($request, $actionType, $payload, $clientTimestamp);
                $results[] = [
                    'id' => $id,
                    'status' => $result['status'],
                    'server_data' => $result['data'] ?? null,
                ];
            } catch (Exception $e) {
                $results[] = [
                    'id' => $id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ];
            }
        }

        return response()->json([
            'status' => 'success',
            'results' => $results,
        ]);
    }

    /**
     * Dispatch a single sync item to its respective controller action.
     * Uses internal sub-requests to reuse existing controller logic completely.
     */
    private function processItem(Request $parentRequest, string $actionType, array $payload, int $clientTimestamp): array
    {
        switch ($actionType) {
            case 'create_formula':
                return $this->handleCreateFormula($parentRequest, $payload);

            case 'approve_formula':
                return $this->handleApproveFormula($parentRequest, $payload, $clientTimestamp);

            case 'schedule_production':
                return $this->handleScheduleProduction($parentRequest, $payload);

            case 'verify_material_request':
                return $this->handleVerifyMaterialRequest($parentRequest, $payload, $clientTimestamp);

            case 'adjust_stock':
                return $this->handleAdjustStock($parentRequest, $payload);

            case 'add_ingredient':
                return $this->handleAddIngredient($parentRequest, $payload);

            default:
                throw new Exception("Unknown action type: {$actionType}");
        }
    }

    /**
     * Create formula via FormulaController@store.
     */
    private function handleCreateFormula(Request $parentRequest, array $payload): array
    {
        $subRequest = Request::create('/api/formulas', 'POST', $payload);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(FormulaController::class);
        $response = $controller->store($subRequest);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to create formula');
    }

    /**
     * Approve formula via FormulaController@approve.
     * Supports last-write-wins conflict detection.
     */
    private function handleApproveFormula(Request $parentRequest, array $payload, int $clientTimestamp): array
    {
        $formulaId = $payload['formula_id'];

        // Last-write-wins conflict check
        $formula = \App\Models\Formula::find($formulaId);
        if ($formula && $formula->updated_at) {
            $serverTimestamp = $formula->updated_at->getTimestampMs();
            if ($clientTimestamp <= $serverTimestamp && $formula->status === 'approved') {
                return ['status' => 'conflict', 'data' => $formula->toArray()];
            }
        }

        $subRequest = Request::create("/api/formulas/{$formulaId}/approve", 'POST', []);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(FormulaController::class);
        $response = $controller->approve($subRequest, $formulaId);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to approve formula');
    }

    /**
     * Schedule production via ProductionController@store.
     */
    private function handleScheduleProduction(Request $parentRequest, array $payload): array
    {
        $subRequest = Request::create('/api/productions', 'POST', $payload);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(ProductionController::class);
        $response = $controller->store($subRequest);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to schedule production');
    }

    /**
     * Verify material request via ProductionController@verifyMaterialRequest.
     * Supports last-write-wins conflict detection.
     */
    private function handleVerifyMaterialRequest(Request $parentRequest, array $payload, int $clientTimestamp): array
    {
        $mrId = $payload['material_request_id'];

        // Last-write-wins conflict check
        $mr = \App\Models\MaterialRequest::find($mrId);
        if ($mr && $mr->updated_at) {
            $serverTimestamp = $mr->updated_at->getTimestampMs();
            if ($clientTimestamp <= $serverTimestamp && in_array($mr->status, ['approved', 'rejected'])) {
                return ['status' => 'conflict', 'data' => $mr->toArray()];
            }
        }

        $verifyPayload = [
            'status' => $payload['status'],
            'rejection_reason' => $payload['rejection_reason'] ?? null,
        ];

        $subRequest = Request::create("/api/material-requests/{$mrId}/verify", 'POST', $verifyPayload);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(ProductionController::class);
        $response = $controller->verifyMaterialRequest($subRequest, $mrId);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to verify material request');
    }

    /**
     * Adjust stock via InventoryController@adjust.
     */
    private function handleAdjustStock(Request $parentRequest, array $payload): array
    {
        $subRequest = Request::create('/api/inventory/adjust', 'POST', $payload);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(InventoryController::class);
        $response = $controller->adjust($subRequest);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to adjust stock');
    }

    /**
     * Add ingredient via InventoryController@store.
     */
    private function handleAddIngredient(Request $parentRequest, array $payload): array
    {
        $subRequest = Request::create('/api/inventory', 'POST', $payload);
        $subRequest->setUserResolver(fn() => $parentRequest->user());
        $subRequest->headers->set('Accept', 'application/json');

        $controller = app(InventoryController::class);
        $response = $controller->store($subRequest);
        $data = json_decode($response->getContent(), true);

        if ($response->getStatusCode() >= 200 && $response->getStatusCode() < 300 && ($data['status'] ?? '') === 'success') {
            return ['status' => 'synced', 'data' => $data['data'] ?? null];
        }

        throw new Exception($data['message'] ?? 'Failed to add ingredient');
    }
}
