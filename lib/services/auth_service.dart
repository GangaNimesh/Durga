import '../models/auth_models.dart';
import 'api_client.dart';

/// Auth-specific API calls. Thin wrapper over ApiClient — no business logic.
class AuthService {
  final ApiClient _client = ApiClient();

  Future<UserResponse> register(RegisterRequest request) async {
    final response = await _client.dio.post(
      '/auth/register',
      data: request.toJson(),
    );
    return UserResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenResponse> login(LoginRequest request) async {
    final response = await _client.dio.post(
      '/auth/login',
      data: request.toJson(),
    );
    final tokenResponse =
        TokenResponse.fromJson(response.data as Map<String, dynamic>);

    // Persist the JWT in secure storage
    await _client.saveToken(tokenResponse.accessToken);

    return tokenResponse;
  }

  Future<UserResponse> getMe() async {
    final response = await _client.dio.get('/auth/me');
    return UserResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.clearToken();
  }
}
