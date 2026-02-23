import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

/// Admin Provider - Manages admin-specific operations
///
/// Handles user management features including fetching all users
/// and toggling user status (active/frozen).
class AdminProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> get users => _users;

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Fetch all users from the admin API
  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.get('/admin/users');

      if (response is List) {
        _users = List<Map<String, dynamic>>.from(response);
      } else {
        _users = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle user status between active and frozen
  Future<bool> toggleUserStatus(int userId, String newStatus) async {
    try {
      await ApiClient.put(
        '/admin/users/$userId/status',
        body: {'status': newStatus},
      );

      // Update local user list with new status
      final userIndex = _users.indexWhere((u) => u['id'] == userId);
      if (userIndex != -1) {
        _users[userIndex] = {..._users[userIndex], 'status': newStatus};
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update user status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get filtered users based on search query
  List<Map<String, dynamic>> getFilteredUsers(String query) {
    if (query.isEmpty) return _users;

    final lowerQuery = query.toLowerCase();
    return _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  /// Clear any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch dashboard statistics from the admin API
  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.get('/admin/stats');

      if (response is Map<String, dynamic>) {
        _stats = response;
      } else {
        _stats = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load dashboard stats: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}
