import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_storage.dart';
import '../models/user_model.dart';

/// Authentication Provider for GExpertise Carpool
///
/// Manages authentication state using ChangeNotifier pattern.
/// Handles login/logout with backend API and secure token storage.
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isUpdatingProfile = false;
  String? _errorMessage;
  String? _token;
  User? _user;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isUpdatingProfile => _isUpdatingProfile;
  String? get errorMessage => _errorMessage;
  String? get token => _token;
  User? get user => _user;

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
          // Fetch user profile from /users/me endpoint
          await refreshUserProfile();
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
      _user = User.fromJson(response['employee'] as Map<String, dynamic>);

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

  /// Refresh user profile from backend
  ///
  /// Fetches latest user details from GET /users/me to update
  /// stats and vehicle info.
  Future<void> refreshUserProfile() async {
    if (_token == null) return;

    try {
      final response = await ApiClient.get('/users/me');
      _user = User.fromJson(response);
      notifyListeners();
    } on ApiException catch (e) {
      _setError('Failed to refresh profile: ${e.message}');
    } catch (e) {
      _setError('Failed to refresh profile: $e');
    }
  }

  /// Update user profile
  ///
  /// Sends a PATCH request to update phone and vehicle details.
  Future<bool> updateUserProfile({
    String? phone,
    String? carModel,
    String? plate,
    String? color,
  }) async {
    if (_token == null || _user == null) return false;

    _setUpdatingProfile(true);
    _clearError();

    try {
      final body = <String, dynamic>{};
      if (phone != null) body['phone_number'] = phone;
      if (carModel != null) body['car_model'] = carModel;
      if (plate != null) body['car_plate'] = plate;
      if (color != null) body['car_color'] = color;

      final response = await ApiClient.patch('/users/me', body: body);

      // Update local user with response
      _user = User.fromJson(response);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError('Failed to update profile: ${e.message}');
      return false;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setUpdatingProfile(false);
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

  void _setUpdatingProfile(bool updating) {
    _isUpdatingProfile = updating;
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
