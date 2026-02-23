import 'package:flutter/material.dart';

/// Notification Model
///
/// Represents a single notification for the user.
class NotificationModel {
  final int id;
  final String message;
  final DateTime createdAt;
  final String
  type; // 'request', 'approval', 'rejection', 'cancellation', 'info'
  final bool isRead;
  final int? rideId;
  final int? employeeId;

  NotificationModel({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.rideId,
    this.employeeId,
  });

  /// Create from JSON response from backend
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      type: json['type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      rideId: json['ride_id'] as int?,
      employeeId: json['employee_id'] as int?,
    );
  }

  NotificationModel copyWith({
    int? id,
    String? message,
    DateTime? createdAt,
    String? type,
    bool? isRead,
    int? rideId,
    int? employeeId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      rideId: rideId ?? this.rideId,
      employeeId: employeeId ?? this.employeeId,
    );
  }

  /// Get notification type for icon/color
  NotificationType get notificationType {
    switch (type.toLowerCase()) {
      case 'approval':
        return NotificationType.rideApproved;
      case 'rejection':
        return NotificationType.rideCancelled;
      case 'request':
        return NotificationType.rideRequested;
      case 'cancellation':
        return NotificationType.rideCancelled;
      default:
        return NotificationType.general;
    }
  }
}

enum NotificationType {
  rideApproved,
  rideCancelled,
  rideRequested,
  rideCompleted,
  newRideAvailable,
  general,
}

extension NotificationTypeExtension on NotificationType {
  IconData get icon {
    switch (this) {
      case NotificationType.rideApproved:
        return Icons.check_circle;
      case NotificationType.rideCancelled:
        return Icons.cancel;
      case NotificationType.rideRequested:
        return Icons.person_add;
      case NotificationType.rideCompleted:
        return Icons.done_all;
      case NotificationType.newRideAvailable:
        return Icons.local_taxi;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.rideApproved:
        return Colors.green;
      case NotificationType.rideCancelled:
        return Colors.red;
      case NotificationType.rideRequested:
        return Colors.blue;
      case NotificationType.rideCompleted:
        return Colors.purple;
      case NotificationType.newRideAvailable:
        return const Color(0xFFE31B23); // Brand red
      case NotificationType.general:
        return Colors.grey;
    }
  }
}
