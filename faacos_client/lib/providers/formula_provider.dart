import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/formula_model.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/sync_service.dart';

class FormulaProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<FormulaModel> _formulas = [];
  FormulaModel? _activeFormula;
  bool _isLoading = false;

  List<FormulaModel> get formulas => _formulas;
  FormulaModel? get activeFormula => _activeFormula;
  bool get isLoading => _isLoading;

  /**
   * Fetch all formulas from the API.
   */
  Future<void> fetchFormulas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/formulas');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List;
        _formulas = list.map((f) => FormulaModel.fromJson(f)).toList();
      }
    } catch (e) {
      // Catch exceptions silently or attach loggers
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Fetch the details of a specific formula.
   */
  Future<void> fetchFormulaDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/formulas/$id');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        _activeFormula = FormulaModel.fromJson(response.data['data']);
      }
    } catch (e) {
      // Catch exceptions silently
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Save a newly created formula (Simulasi Costing HPP).
   */
  Future<Map<String, dynamic>> saveFormula({
    required String name,
    required double batchSize,
    required List<Map<String, dynamic>> ingredients,
    required List<Map<String, dynamic>> costs,
    required double profitMarginPercent,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/formulas', data: {
        'name': name,
        'batch_size': batchSize,
        'ingredients': ingredients,
        'costs': costs,
        'profit_margin_percent': profitMarginPercent,
      });

      if ((response.statusCode == 201 || response.statusCode == 210) && response.data['status'] == 'success') {
        final newFormula = FormulaModel.fromJson(response.data['data']);
        _formulas.insert(0, newFormula);
        
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'data': newFormula};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal menyimpan formula.'};

    } on DioException catch (e) {
      // Offline fallback: queue the action locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('create_formula', {
          'name': name,
          'batch_size': batchSize,
          'ingredients': ingredients,
          'costs': costs,
          'profit_margin_percent': profitMarginPercent,
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
        'message': e.response?.data['message'] ?? 'Gagal terhubung ke API.'
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  /**
   * Pre-check stock levels in warehouse for a target batch quantity.
   */
  Future<Map<String, dynamic>> preCheckStock(int id, {double? targetQuantity}) async {
    try {
      final Map<String, dynamic> params = {};
      if (targetQuantity != null) {
        params['target_quantity'] = targetQuantity;
      }

      final response = await _apiClient.dio.get(
        '/formulas/$id/pre-check-stock',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return {
          'success': true,
          'sufficient': response.data['sufficient'],
          'shortages': response.data['shortages']
        };
      }
    } catch (e) {
      // Silently fall through to error return
    }
    return {'success': false, 'message': 'Gagal melakukan pre-check stok gudang.'};
  }

  /**
   * Approve / ACC a formula (R&D action).
   */
  Future<Map<String, dynamic>> approveFormula(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/formulas/$id/approve');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final updatedFormula = FormulaModel.fromJson(response.data['data']);
        
        // Synchronize in local lists
        final idx = _formulas.indexWhere((f) => f.id == id);
        if (idx != -1) {
          _formulas[idx] = updatedFormula;
        }
        if (_activeFormula?.id == id) {
          _activeFormula = updatedFormula;
        }

        _isLoading = false;
        notifyListeners();
        return {
          'status': 'success',
          'message': response.data['message'],
          'data': updatedFormula
        };
      }
      
      _isLoading = false;
      notifyListeners();
      return {'status': 'error', 'message': 'Gagal memproses approval.'};

    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();

      if (e.response?.statusCode == 422 && e.response?.data['status'] == 'insufficient_stock') {
        return {
          'status': 'insufficient_stock',
          'message': e.response?.data['message'],
          'shortages': e.response?.data['shortages']
        };
      }

      // Offline fallback: queue the approval action locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('approve_formula', {
          'formula_id': id,
        });
        SyncService().updatePendingCount();
        return {
          'status': 'success',
          'offline': true,
          'message': 'Disimpan lokal, approval akan disinkronkan saat online.'
        };
      }

      return {
        'status': 'error',
        'message': e.response?.data['message'] ?? 'Gagal terhubung ke API.'
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'status': 'error', 'message': 'Terjadi kesalahan sistem.'};
    }
  }
}
