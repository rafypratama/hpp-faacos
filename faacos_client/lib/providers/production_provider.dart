import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/production_order_model.dart';
import '../models/material_request_model.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/sync_service.dart';

class ProductionProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<ProductionOrderModel> _productionOrders = [];
  List<MaterialRequestModel> _materialRequests = [];
  MaterialRequestModel? _activeMaterialRequest;
  bool _isLoading = false;

  List<ProductionOrderModel> get productionOrders => _productionOrders;
  List<MaterialRequestModel> get materialRequests => _materialRequests;
  MaterialRequestModel? get activeMaterialRequest => _activeMaterialRequest;
  bool get isLoading => _isLoading;

  /**
   * Fetch all scheduled production orders.
   */
  Future<void> fetchProductionOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/productions');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List;
        _productionOrders = list.map((p) => ProductionOrderModel.fromJson(p)).toList();
      }
    } catch (e) {
      // Silently ignore or attach error logger
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Fetch all Material Requests.
   */
  Future<void> fetchMaterialRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/material-requests');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List;
        _materialRequests = list.map((m) => MaterialRequestModel.fromJson(m)).toList();
      }
    } catch (e) {
      // Silently catch exceptions
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Fetch details for a specific Material Request.
   */
  Future<void> fetchMaterialRequestDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/material-requests/$id');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        _activeMaterialRequest = MaterialRequestModel.fromJson(response.data['data']);
      }
    } catch (e) {
      // Wither catch
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Create and schedule a new production order.
   */
  Future<Map<String, dynamic>> scheduleProduction({
    required int formulaId,
    required double targetQuantity,
    required int batchCount,
    String? scheduledStartDate,
    String? scheduledEndDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/productions', data: {
        'formula_id': formulaId,
        'target_quantity': targetQuantity,
        'batch_count': batchCount,
        'scheduled_start_date': scheduledStartDate,
        'scheduled_end_date': scheduledEndDate,
      });

      if (response.statusCode == 201 && response.data['status'] == 'success') {
        final newOrder = ProductionOrderModel.fromJson(response.data['data']);
        _productionOrders.insert(0, newOrder);

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': newOrder};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal menjadwalkan produksi.'};

    } on DioException catch (e) {
      // Offline fallback: queue the action locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('schedule_production', {
          'formula_id': formulaId,
          'target_quantity': targetQuantity,
          'batch_count': batchCount,
          'scheduled_start_date': scheduledStartDate,
          'scheduled_end_date': scheduledEndDate,
        });
        SyncService().updatePendingCount();
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'offline': true, 'message': 'Disimpan lokal, akan disinkronkan saat online.'};
      }
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Gagal menghubungi server.'
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  /**
   * Verify (Approve / Reject) a pending Material Request (Kepala Gudang action).
   */
  Future<Map<String, dynamic>> verifyMaterialRequest(
    int id, {
    required String status,
    String? rejectionReason,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/material-requests/$id/verify', data: {
        'status': status,
        'rejection_reason': rejectionReason,
      });

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final updatedMr = MaterialRequestModel.fromJson(response.data['data']);

        // Update in lists
        final idx = _materialRequests.indexWhere((m) => m.id == id);
        if (idx != -1) {
          _materialRequests[idx] = updatedMr;
        }
        if (_activeMaterialRequest?.id == id) {
          _activeMaterialRequest = updatedMr;
        }

        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': response.data['message'],
          'data': updatedMr
        };
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal memproses verifikasi.'};

    } on DioException catch (e) {
      // Offline fallback: queue the verification action locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('verify_material_request', {
          'material_request_id': id,
          'status': status,
          'rejection_reason': rejectionReason,
        });
        SyncService().updatePendingCount();
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'offline': true, 'message': 'Disimpan lokal, verifikasi akan disinkronkan saat online.'};
      }
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Gagal terhubung ke API.'
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }
}
