import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gexpertise_carpool/core/network/api_client.dart';
import '../models/dashboard_analytics.dart';
import '../models/recent_activity.dart';
import '../models/status_distribution.dart';
import '../models/system_trends.dart';
import '../services/admin_analytics_service.dart';

/// Admin Analytics Provider
/// Manages dashboard analytics state and fetches data from backend.
class AdminAnalyticsProvider extends ChangeNotifier {
  DashboardAnalytics? _analytics;
  SystemTrends? _trends;
  StatusDistribution? _statusDistribution;
  RecentActivity? _recentActivity;
  int _trendsDays = 7;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  DashboardAnalytics? get analytics => _analytics;
  SystemTrends? get trends => _trends;
  StatusDistribution? get statusDistribution => _statusDistribution;
  RecentActivity? get recentActivity => _recentActivity;
  int get trendsDays => _trendsDays;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch dashboard analytics from API
  Future<void> fetchDashboardAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _analytics = await AdminAnalyticsService.fetchDashboardAnalytics();
      _trends = await AdminAnalyticsService.fetchSystemTrends(
        days: _trendsDays,
      );
      _statusDistribution =
          await AdminAnalyticsService.fetchStatusDistribution();
      _recentActivity = await AdminAnalyticsService.fetchRecentActivity(
        limit: 10,
      );
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint(
        'AdminAnalyticsProvider: ApiException - status: ${e.statusCode}, message: ${e.message}',
      );
      _errorMessage = e.statusCode == 0
          ? 'Failed to connect to server. Is backend running on ${ApiClient.baseUrl}?'
          : 'Failed to load analytics: ${e.message}';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminAnalyticsProvider: Unexpected error: $e');
      _errorMessage = 'Failed to load analytics: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentActivity({int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recentActivity = await AdminAnalyticsService.fetchRecentActivity(
        limit: limit,
      );
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint(
        'AdminAnalyticsProvider: ApiException (recent activity) - status: ${e.statusCode}, message: ${e.message}',
      );
      _errorMessage = e.statusCode == 0
          ? 'Failed to connect to server. Is backend running on ${ApiClient.baseUrl}?'
          : 'Failed to load recent activity: ${e.message}';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint(
        'AdminAnalyticsProvider: Unexpected recent activity error: $e',
      );
      _errorMessage = 'Failed to load recent activity: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh analytics data
  Future<void> refresh() async {
    await fetchDashboardAnalytics();
  }

  Future<void> fetchTrends({int days = 7}) async {
    _isLoading = true;
    _errorMessage = null;
    _trendsDays = days;
    notifyListeners();

    try {
      _trends = await AdminAnalyticsService.fetchSystemTrends(days: days);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint(
        'AdminAnalyticsProvider: ApiException (trends) - status: ${e.statusCode}, message: ${e.message}',
      );
      _errorMessage = e.statusCode == 0
          ? 'Failed to connect to server. Is backend running on ${ApiClient.baseUrl}?'
          : 'Failed to load trends: ${e.message}';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminAnalyticsProvider: Unexpected trends error: $e');
      _errorMessage = 'Failed to load trends: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
