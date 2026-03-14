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
        'AdminAnalyticsService: Calling /admin/analytics/rides-over-time',
      );
      final response = await ApiClient.get('/admin/analytics/rides-over-time');
      debugPrint('AdminAnalyticsService: Trends response received: $response');

      if (response is List) {
        return SystemTrends.fromRidesOverTime(response, days);
      }

      throw Exception('Invalid response format from trends API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching trends: $e');
      rethrow;
    }
  }

  static Future<StatusDistribution> fetchStatusDistribution() async {
    try {
      debugPrint('AdminAnalyticsService: Calling /admin/analytics/ride-status');
      final response = await ApiClient.get('/admin/analytics/ride-status');
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

  /// Fetch top routes
  static Future<List<Map<String, dynamic>>> fetchTopRoutes({
    String? country,
  }) async {
    try {
      final url = country != null
          ? '/admin/analytics/top-routes?country=$country'
          : '/admin/analytics/top-routes';
      debugPrint('AdminAnalyticsService: Calling $url');
      final response = await ApiClient.get(url);
      debugPrint('AdminAnalyticsService: Top routes response: $response');

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }

      throw Exception('Invalid response format from top routes API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching top routes: $e');
      rethrow;
    }
  }

  /// Fetch reservation funnel
  static Future<Map<String, dynamic>> fetchReservationFunnel() async {
    try {
      debugPrint(
        'AdminAnalyticsService: Calling /admin/analytics/reservation-funnel',
      );
      final response = await ApiClient.get(
        '/admin/analytics/reservation-funnel',
      );
      debugPrint(
        'AdminAnalyticsService: Reservation funnel response: $response',
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid response format from reservation funnel API');
    } catch (e) {
      debugPrint(
        'AdminAnalyticsService: Error fetching reservation funnel: $e',
      );
      rethrow;
    }
  }

  /// Fetch user growth data
  static Future<List<Map<String, dynamic>>> fetchUserGrowth() async {
    try {
      debugPrint('AdminAnalyticsService: Calling /admin/analytics/user-growth');
      final response = await ApiClient.get('/admin/analytics/user-growth');
      debugPrint('AdminAnalyticsService: User growth response: $response');

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }

      throw Exception('Invalid response format from user growth API');
    } catch (e) {
      debugPrint('AdminAnalyticsService: Error fetching user growth: $e');
      rethrow;
    }
  }
}
