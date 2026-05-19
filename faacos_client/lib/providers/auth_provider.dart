import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;

  /**
   * Check if a token already exists locally on launch, and verify its validity with the API.
   */
  Future<void> checkLoginSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');

      if (savedToken != null) {
        _token = savedToken;
        // Verify session against /api/user endpoint
        final response = await _apiClient.dio.get('/user');
        
        if (response.statusCode == 200 && response.data['status'] == 'success') {
          _user = UserModel.fromJson(response.data['data']);
          _isAuthenticated = true;
        } else {
          await logout();
        }
      }
    } catch (e) {
      // Local token expired or API offline
      _token = null;
      _user = null;
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /**
   * Log in user and persist token inside local storage.
   */
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        _token = data['access_token'];
        _user = UserModel.fromJson(data['user']);
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);

        _isLoading = false;
        notifyListeners();
        return {'success': true};
      }
      
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan login.'};

    } on DioException catch (e) {
      debugPrint('AUTH_DEBUG [DioException]: $e');
      if (e.response != null) {
        debugPrint('AUTH_DEBUG [Response Data]: ${e.response?.data}');
      }
      _isLoading = false;
      notifyListeners();
      
      String errorMsg = 'Gagal terhubung ke server.';
      if (e.response != null && e.response?.data != null) {
        errorMsg = e.response?.data['message'] ?? 'Kombinasi email & password salah.';
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      debugPrint('AUTH_DEBUG [Exception]: $e');
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  /**
   * Log out active user and clear session caches.
   */
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null) {
        await _apiClient.dio.post('/logout');
      }
    } catch (e) {
      // Ignore network errors on logout to allow clean local wiping
    } finally {
      _token = null;
      _user = null;
      _isAuthenticated = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

      _isLoading = false;
      notifyListeners();
    }
  }
}
