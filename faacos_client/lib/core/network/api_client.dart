import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final Dio dio = Dio();

  // Production base URL (change this to your public API address when deploying)
  static const String _productionUrl = 'https://api.hpp-faacos.com/api';

  // Base URL points to the Laragon local web server API or production API.
  static String get baseUrl {
    if (kReleaseMode) {
      return _productionUrl;
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2/hpp-faacos/public/api';
    }
    return 'http://127.0.0.1/hpp-faacos/public/api';
  }

  ApiClient() {
    dio.options.baseUrl = baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    // Automatically inject Bearer Sanctum Tokens from SharedPreferences into headers.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Global error handler or debugging hook can be attached here
          return handler.next(e);
        },
      ),
    );
  }
}
