import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/dashboard_analytics.dart';
import '../models/recent_activity.dart';
import '../models/status_distribution.dart';
import '../models/system_trends.dart';

/// Admin Analytics Service
/// Handles API calls for admin dashboard analytics.
class AdminAnalyticsService {
  /// Fetch dashboard summary analytics
  static Future<DashboardAnalytics> fetchDashboardAnalytics() async {
    try {
      debugPrint('AdminAnalyticsService: Calling /admin/analytics/dashboard');
      final response = await ApiClient.get('/admin/analytics/dashboard');
      debugPrint('AdminAnalyticsService: Response received: $response');

      if (response is Map<String, dynamic>) {
        return DashboardAnalytics.fromJson(response);
      }

      throw Exception('Invalid response format from analytics API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching analytics: $e');
      rethrow;
    }
  }

  static Future<SystemTrends> fetchSystemTrends({int days = 7}) async {
    try {
      debugPrint(
        'AdminAnalyticsService: Calling /admin/analytics/trends?days=$days',
      );
      final response = await ApiClient.get(
        '/admin/analytics/trends?days=$days',
      );
      debugPrint('AdminAnalyticsService: Trends response received: $response');

      if (response is Map<String, dynamic>) {
        return SystemTrends.fromJson(response);
      }

      throw Exception('Invalid response format from trends API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching trends: $e');
      rethrow;
    }
  }

  static Future<StatusDistribution> fetchStatusDistribution() async {
    try {
      debugPrint(
        'AdminAnalyticsService: Calling /admin/analytics/status-distribution',
      );
      final response = await ApiClient.get(
        '/admin/analytics/status-distribution',
      );
      debugPrint(
        'AdminAnalyticsService: Status distribution response: $response',
      );

      if (response is Map<String, dynamic>) {
        return StatusDistribution.fromJson(response);
      }

      throw Exception('Invalid response format from status distribution API');
    } catch (e) {
      debugPrint(
        'AdminAnalyticsService: Error fetching status distribution: $e',
      );
      rethrow;
    }
  }

  static Future<RecentActivity> fetchRecentActivity({int limit = 10}) async {
    try {
      debugPrint(
        'AdminAnalyticsService: Calling /admin/analytics/recent-activity?limit=$limit',
      );
      final response = await ApiClient.get(
        '/admin/analytics/recent-activity?limit=$limit',
      );
      debugPrint('AdminAnalyticsService: Recent activity response: $response');

      if (response is Map<String, dynamic>) {
        return RecentActivity.fromJson(response);
      }

      throw Exception('Invalid response format from recent activity API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching recent activity: $e');
      rethrow;
    }
  }
}
