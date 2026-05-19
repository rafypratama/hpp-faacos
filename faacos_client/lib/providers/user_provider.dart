import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  List<UserModel> _users = [];
  bool _isLoading = false;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;

  /**
   * Fetch all users from the backend API.
   */
  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/users');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> rawData = response.data['data'];
        _users = rawData.map((json) => UserModel.fromJson(json)).toList();
      }
    } on DioException catch (e) {
      debugPrint('USER_PROVIDER_DEBUG [DioException]: $e');
    } catch (e) {
      debugPrint('USER_PROVIDER_DEBUG [Exception]: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Create a new employee account.
   */
  Future<Map<String, dynamic>> addUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/users', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final newUser = UserModel.fromJson(response.data['data']);
        _users.insert(0, newUser); // Add to the top of list
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': 'Pengguna baru berhasil didaftarkan.'};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal mendaftarkan pengguna.'};

    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      String errorMsg = 'Gagal mendaftarkan pengguna.';
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data['errors'] != null) {
          final Map<String, dynamic> errors = data['errors'];
          errorMsg = errors.values.map((e) => (e as List).first).join('\n');
        } else {
          errorMsg = data['message'] ?? errorMsg;
        }
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  /**
   * Update an existing employee account.
   */
  Future<Map<String, dynamic>> updateUser({
    required int id,
    required String name,
    required String email,
    String? password,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> payload = {
        'name': name,
        'email': email,
        'role': role,
      };

      if (password != null && password.trim().isNotEmpty) {
        payload['password'] = password;
      }

      final response = await _apiClient.dio.put('/users/$id', data: payload);

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final updatedUser = UserModel.fromJson(response.data['data']);
        final index = _users.indexWhere((u) => u.id == id);
        if (index != -1) {
          _users[index] = updatedUser;
        }
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': 'Data pengguna berhasil diperbarui.'};
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal memperbarui pengguna.'};

    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      String errorMsg = 'Gagal memperbarui pengguna.';
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data['errors'] != null) {
          final Map<String, dynamic> errors = data['errors'];
          errorMsg = errors.values.map((e) => (e as List).first).join('\n');
        } else {
          errorMsg = data['message'] ?? errorMsg;
        }
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  /**
   * Delete an existing employee account.
   */
  Future<Map<String, dynamic>> deleteUser(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.delete('/users/$id');

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        _users.removeWhere((u) => u.id == id);
        _isLoading = false;
        notifyListeners();
        return {'success': true, 'message': 'Akun pengguna berhasil dihapus.'};
      }

      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Gagal menghapus pengguna.'};

    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      String errorMsg = 'Gagal menghapus pengguna.';
      if (e.response != null && e.response?.data != null) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }
}
