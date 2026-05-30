import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/ingredient_model.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/sync_service.dart';

class InventoryLogModel {
  final int id;
  final int ingredientId;
  final IngredientModel? ingredient;
  final String type;
  final double quantity;
  final String unit;
  final double balanceAfter;
  final String? referenceType;
  final int? referenceId;
  final String? notes;
  final String? userName;
  final DateTime createdAt;

  InventoryLogModel({
    required this.id,
    required this.ingredientId,
    this.ingredient,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.notes,
    this.userName,
    required this.createdAt,
  });

  factory InventoryLogModel.fromJson(Map<String, dynamic> json) {
    return InventoryLogModel(
      id: json['id'],
      ingredientId: json['ingredient_id'],
      ingredient: json['ingredient'] != null ? IngredientModel.fromJson(json['ingredient']) : null,
      type: json['type'],
      quantity: double.parse(json['quantity'].toString()),
      unit: json['unit'],
      balanceAfter: double.parse(json['balance_after'].toString()),
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      notes: json['notes'],
      userName: json['user'] != null ? json['user']['name'] : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class InventoryProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<IngredientModel> _ingredients = [];
  List<InventoryLogModel> _logs = [];
  bool _isLoading = false;

  List<IngredientModel> get ingredients => _ingredients;
  List<InventoryLogModel> get logs => _logs;
  bool get isLoading => _isLoading;

  /**
   * Fetch master warehouse stock levels from API.
   */
  Future<void> fetchIngredients() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/inventory');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List;
        _ingredients = list.map((i) => IngredientModel.fromJson(i)).toList();
      }
    } catch (e) {
      // Catch exceptions silently
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Fetch full warehouse stock movement logs history.
   */
  Future<void> fetchLogs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/inventory/logs');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final list = response.data['data'] as List;
        _logs = list.map((l) => InventoryLogModel.fromJson(l)).toList();
      }
    } catch (e) {
      // Catch exceptions silently
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Adjust warehouse stock level manually (Stock In, Stock Out, or Opname).
   */
  Future<Map<String, dynamic>> adjustStock({
    required int ingredientId,
    required String type, // in, out, adjustment
    required double quantity,
    required String unit,
    String? notes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/inventory/adjust', data: {
        'ingredient_id': ingredientId,
        'type': type,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
      });

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final updatedIngredient = IngredientModel.fromJson(response.data['data']['ingredient']);
        final newLog = InventoryLogModel.fromJson(response.data['data']['log']);

        // Update active local state caches
        final idx = _ingredients.indexWhere((i) => i.id == ingredientId);
        if (idx != -1) {
          _ingredients[idx] = updatedIngredient;
        }
        _logs.insert(0, newLog);

        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': response.data['message']};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal memproses penyesuaian stok.'};

    } on DioException catch (e) {
      // Offline fallback: queue the stock adjustment locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('adjust_stock', {
          'ingredient_id': ingredientId,
          'type': type,
          'quantity': quantity,
          'unit': unit,
          'notes': notes,
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
   * Add a new raw material / packaging (and merge stock if it already exists).
   */
  Future<Map<String, dynamic>> addIngredient({
    required String code,
    required String name,
    required String type, // raw_material, packaging
    required String unit,
    required double pricePerUnit,
    required double currentStock,
    double? minimumStock,
    String? expiredAt,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/inventory', data: {
        'code': code,
        'name': name,
        'type': type,
        'unit': unit,
        'price_per_unit': pricePerUnit,
        'current_stock': currentStock,
        'minimum_stock': minimumStock ?? 0.0,
        'expired_at': expiredAt,
      });

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        // Fully refresh active list and logs from DB
        await fetchIngredients();
        await fetchLogs();
        return {
          'success': true,
          'message': response.data['message'],
          'merged': response.data['data']['merged'] ?? false,
        };
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal mendaftarkan bahan baku.'};

    } on DioException catch (e) {
      // Offline fallback: queue adding ingredient locally
      if (!ConnectivityService().currentStatus || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        await OfflineQueueService().addToQueue('add_ingredient', {
          'code': code,
          'name': name,
          'type': type,
          'unit': unit,
          'price_per_unit': pricePerUnit,
          'current_stock': currentStock,
          'minimum_stock': minimumStock ?? 0.0,
          'expired_at': expiredAt,
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
}
