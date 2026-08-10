import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized API client. Single Dio instance shared across all services.
/// JWT token is injected via interceptor — no per-call boilerplate.
class ApiClient {
  static const String _tokenKey = 'jwt_access_token';

  // Dynamic API base URL: Reads --dart-define=API_BASE_URL=... or defaults to Android emulator URL
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient._internal(this.dio, this._storage);

  static ApiClient? _instance;

  // FIX: call sites use ApiClient.instance, but only a private static field
  // and a factory constructor existed — no public accessor. This was a compile error.
  static ApiClient get instance => ApiClient();

  factory ApiClient() {
    if (_instance != null) return _instance!;

    final storage = const FlutterSecureStorage();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // JWT interceptor: reads token from secure storage, attaches to every request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // FIX: this was an empty passthrough - an expired/invalid token
          // left the user stuck on a broken home screen forever. Clear the
          // stored token on 401 so AuthGate falls back to the login screen.
          if (error.response?.statusCode == 401) {
            await storage.delete(key: _tokenKey);
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    _instance = ApiClient._internal(dio, storage);
    return _instance!;
  }

  /// Save JWT after login
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clear JWT on logout
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check if a token exists (for auth gate)
  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }
}
