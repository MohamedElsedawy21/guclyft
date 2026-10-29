import 'dart:convert';
import 'api_service.dart';

class AuthResult {
  final String token;
  final String role;
  final String id;
  final String name;
  final bool? isPriority;

  AuthResult({required this.token, required this.role, required this.id, required this.name, this.isPriority});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'],
      role: json['role'],
      id: json['id'].toString(),
      name: json['name'],
      isPriority: json['is_priority'],
    );
  }
}

class AuthService {
  static Future<AuthResult> login(String username, String password) async {
    final res = await ApiService.post("/login", {
      "username": username,
      "password": password,
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final result = AuthResult.fromJson(data);
      await ApiService.saveToken(result.token);
      return result;
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Login failed");
    }
  }

  static Future<void> signup({
    required String id,
    required String firstname,
    required String lastname,
    required String email,
    String? faculty,
    required String username,
    required String password,
  }) async {
    final res = await ApiService.post("/signup", {
      "id": id,
      "firstname": firstname,
      "lastname": lastname,
      "email": email,
      "faculty": faculty,
      "username": username,
      "password": password,
    });

    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Signup failed");
    }
  }
    static Future<void> forgotPassword(String email) async {
    final res = await ApiService.post("/forgot-password", {"email": email});
    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to send reset code");
    }
  }

  static Future<String> verifyResetCode(String email, String code) async {
    final res = await ApiService.post("/verify-reset-code", {"email": email, "code": code});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['reset_token'];
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Invalid or expired code");
    }
  }

  static Future<void> resetPassword(String resetToken, String newPassword) async {
    final res = await ApiService.post("/reset-password", {
      "reset_token": resetToken,
      "new_password": newPassword,
    });
    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to reset password");
    }
  }
}
