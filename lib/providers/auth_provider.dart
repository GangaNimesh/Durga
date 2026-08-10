import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

/// Auth state managed via ChangeNotifier (uses the existing `provider` package).
/// No new state-management library introduced.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserResponse? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  UserResponse? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  /// Check if a saved token exists and try to load the user profile.
  Future<void> tryAutoLogin() async {
    final hasToken = await ApiClient().hasToken();
    if (!hasToken) return;

    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.getMe();
      _isAuthenticated = true;
      _error = null;
    } on DioException catch (e) {
      // Token expired or invalid — clear it
      await _authService.logout();
      _isAuthenticated = false;
      _user = null;
      _error = _extractError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Register the user
      await _authService.register(
        RegisterRequest(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
        ),
      );

      // 2. Auto-login after registration
      await _authService.login(
        LoginRequest(email: email, password: password),
      );

      // 3. Fetch user profile
      _user = await _authService.getMe();
      _isAuthenticated = true;
      _error = null;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.login(
        LoginRequest(email: email, password: password),
      );
      _user = await _authService.getMe();
      _isAuthenticated = true;
      _error = null;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Extract a human-readable error message from a DioException.
  String _extractError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final detail = (e.response!.data as Map<String, dynamic>)['detail'];
      if (detail is String) return detail;
    }
    if (e.response != null) {
      return 'Server error (${e.response!.statusCode})';
    }
    return 'Network error — is the server running?';
  }
}
