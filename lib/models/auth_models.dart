/// DTOs that mirror the backend Pydantic schemas field-for-field.
/// No extra fields — only what the API returns.

class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String phone;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
      };
}

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class TokenResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
}

class UserResponse {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final bool isActive;
  final DateTime createdAt;

  const UserResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
