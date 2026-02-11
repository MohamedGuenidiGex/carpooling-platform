import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_storage.dart';

/// Authentication Provider for GExpertise Carpool
///
/// Manages authentication state using ChangeNotifier pattern.
/// Handles login/logout with backend API and secure token storage.
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _token;
  Map<String, dynamic>? _user;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  /// Initialize auth state on app startup
  ///
  /// Checks for existing token in secure storage and validates it.
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      final hasToken = await AuthStorage.hasToken();
      if (hasToken) {
        final token = await AuthStorage.getToken();
        if (token != null) {
          _token = token;
          _isAuthenticated = true;
          // TODO: Fetch user profile from /auth/me endpoint
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Failed to restore session: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Login with email and password
  ///
  /// Posts credentials to /auth/login endpoint.
  /// On success: stores token, updates state, clears error.
  /// On failure: sets errorMessage, keeps user logged out.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await ApiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      // Extract token from response
      final token = response['access_token'] as String?;
      if (token == null) {
        _setError('Invalid response: missing token');
        return false;
      }

      // Store token securely
      await AuthStorage.setToken(token);

      // Update provider state
      _token = token;
      _isAuthenticated = true;
      _user = response['employee'] as Map<String, dynamic>?;

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _setError('Invalid email or password');
      } else if (e.statusCode == 0) {
        _setError('Network error. Please check your connection.');
      } else {
        _setError('Login failed: ${e.message}');
      }
      return false;
    } catch (e) {
      _setError('Unexpected error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout the current user
  ///
  /// Clears token from secure storage and resets all auth state.
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Clear token from secure storage
      await AuthStorage.clearToken();

      // Reset all state
      _token = null;
      _isAuthenticated = false;
      _user = null;
      _clearError();

      notifyListeners();
    } catch (e) {
      _setError('Logout failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Clear any error message
  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Private helper methods

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
