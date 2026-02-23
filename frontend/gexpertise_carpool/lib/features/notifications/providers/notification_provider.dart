import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_model.dart';

/// Notification Provider
///
/// Manages user notifications state and provides methods to
/// fetch, mark as read, and clear notifications.
class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Fetch notifications from backend
  Future<void> fetchNotifications() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final response = await ApiClient.get('/notifications');

      if (response is List) {
        _notifications = response
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      } else {
        _notifications = [];
      }

      _setLoading(false);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
    } catch (e) {
      _errorMessage = 'Failed to load notifications: $e';
      _setLoading(false);
    }
  }

  /// Mark a notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      await ApiClient.patch('/notifications/$notificationId/read', body: {});

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to mark as read: $e';
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    // Optimistically update local state so UI (drawer badge) updates immediately
    final previous = _notifications;
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notifyListeners();

    try {
      await ApiClient.post('/notifications/mark-all-read', body: {});
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _notifications = previous;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to mark all as read: $e';
      _notifications = previous;
      notifyListeners();
      return false;
    }
  }

  /// Clear all notifications locally
  void clearAll() {
    _notifications = [];
    notifyListeners();
  }

  /// Clear all notifications (backend + local)
  Future<bool> clearAllNotifications() async {
    final previous = _notifications;
    _notifications = [];
    notifyListeners();

    try {
      await ApiClient.delete('/notifications/clear-all');
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _notifications = previous;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to clear notifications: $e';
      _notifications = previous;
      notifyListeners();
      return false;
    }
  }

  /// Add a new notification (for testing or real-time updates)
  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
