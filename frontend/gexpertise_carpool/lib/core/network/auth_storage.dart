import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AuthStorage - Secure JWT token storage using FlutterSecureStorage
///
/// Provides persistent, encrypted storage for authentication tokens.
/// Uses platform-specific secure storage (Keychain on iOS/macOS, Keystore on Android).
class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  /// Get the stored JWT token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Store a JWT token securely
  static Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Clear the stored token
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check if a token exists
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null;
  }
}
