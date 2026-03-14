import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/monitoring_overview.dart';

/// Admin Monitoring Service
/// Handles API calls for admin real-time monitoring dashboard.
class AdminMonitoringService {
  /// Fetch complete monitoring overview from multiple endpoints
  static Future<MonitoringOverview> fetchMonitoringOverview() async {
    try {
      debugPrint(
        'AdminMonitoringService: Fetching monitoring data from new endpoints',
      );

      // Fetch system health
      final healthResponse = await ApiClient.get('/admin/system-health');
      debugPrint(
        'AdminMonitoringService: System health received: $healthResponse',
      );

      // Fetch dashboard metrics
      final metricsResponse = await ApiClient.get('/admin/dashboard-metrics');
      debugPrint(
        'AdminMonitoringService: Dashboard metrics received: $metricsResponse',
      );

      // Fetch recent events (limit 5 for dashboard preview)
      final eventsResponse = await ApiClient.get('/admin/events?limit=5');
      debugPrint(
        'AdminMonitoringService: Recent events received: $eventsResponse',
      );

      // Combine into overview format
      final combinedResponse = {
        'system_health': healthResponse,
        'live_metrics': metricsResponse,
        'recent_events': eventsResponse is List ? eventsResponse : [],
      };

      return MonitoringOverview.fromJson(combinedResponse);
    } catch (e) {
      debugPrint('AdminMonitoringService: Error fetching monitoring data: $e');
      rethrow;
    }
  }

  /// Fetch system health only
  static Future<SystemHealth> fetchSystemHealth() async {
    try {
      debugPrint('AdminMonitoringService: Fetching system health');
      final response = await ApiClient.get('/admin/system-health');
      return SystemHealth.fromJson(response);
    } catch (e) {
      debugPrint('AdminMonitoringService: Error fetching system health: $e');
      // Return degraded health on error
      return SystemHealth(
        api: 'down',
        database: 'down',
        websocket: 'unknown',
        osrm: 'unknown',
        gpsStream: 'unknown',
        checkedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Fetch dashboard metrics only
  static Future<LiveMetrics> fetchDashboardMetrics() async {
    try {
      debugPrint('AdminMonitoringService: Fetching dashboard metrics');
      final response = await ApiClient.get('/admin/dashboard-metrics');
      return LiveMetrics.fromJson(response);
    } catch (e) {
      debugPrint(
        'AdminMonitoringService: Error fetching dashboard metrics: $e',
      );
      rethrow;
    }
  }

  /// Fetch system events with pagination
  static Future<List<SystemEvent>> fetchSystemEvents({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint(
        'AdminMonitoringService: Fetching system events (limit: $limit, offset: $offset)',
      );
      final response = await ApiClient.get(
        '/admin/events?limit=$limit&offset=$offset',
      );

      if (response is List) {
        return response
            .whereType<Map<String, dynamic>>()
            .map(SystemEvent.fromJson)
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('AdminMonitoringService: Error fetching system events: $e');
      rethrow;
    }
  }

  /// Send heartbeat to update last_seen timestamp
  static Future<void> sendHeartbeat() async {
    try {
      debugPrint('AdminMonitoringService: Sending heartbeat');
      await ApiClient.post('/admin/monitoring/heartbeat', body: {});
      debugPrint('AdminMonitoringService: Heartbeat sent successfully');
    } catch (e) {
      debugPrint('AdminMonitoringService: Error sending heartbeat: $e');
      // Don't rethrow - heartbeat failures are non-critical
    }
  }
}
