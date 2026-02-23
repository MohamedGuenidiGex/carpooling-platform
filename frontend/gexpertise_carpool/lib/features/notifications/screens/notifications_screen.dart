import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../features/rides/screens/history_screen.dart';
import '../../../features/rides/screens/ride_details_screen.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

/// Notifications Screen - Displays user notifications
///
/// Dynamic screen using NotificationProvider. Shows empty state when
/// no notifications are available.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationProvider()..fetchNotifications(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Mark all as read button
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: const Text('Mark all read'),
              );
            },
          ),
          // Clear all notifications
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (!provider.hasNotifications) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  final ok = await provider.clearAllNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Notifications cleared'
                              : (provider.errorMessage ??
                                    'Failed to clear notifications'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Clear'),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: BrandColors.primaryRed),
              );
            }

            if (provider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            if (!provider.hasNotifications) {
              return const _EmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _NotificationCard(notification: notification);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Empty State Widget
///
/// Displays when no notifications are available.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No new notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification Card Widget
///
/// Displays a single notification with icon, message, and time.
/// Unread notifications have a light red background.
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final type = notification.notificationType;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Unread notifications have light red background
          color: notification.isRead ? Colors.white : Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? Colors.grey[200]! : Colors.red[100]!,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(type.icon, color: type.color, size: 24),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label as title
                  Text(
                    _getTypeLabel(notification.type),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: BrandColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'request':
        return 'New Request';
      case 'approval':
        return 'Request Approved';
      case 'rejection':
        return 'Request Rejected';
      case 'cancellation':
        return 'Ride Cancelled';
      default:
        return 'Notification';
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    // Mark as read
    await context.read<NotificationProvider>().markAsRead(notification.id);

    // Navigate based on notification type
    if (notification.rideId != null) {
      if (notification.type == 'request') {
        // Driver received a request - go to RideDetails to approve/reject
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RideDetailsScreen(rideId: notification.rideId!),
          ),
        );
      } else if (notification.type == 'approval') {
        // Passenger's request was approved - go to Booked Rides
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HistoryScreen()),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${diff.inDays} days ago';
  }
}
