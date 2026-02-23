import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/monitoring_overview.dart';

/// Admin Monitoring Service
/// Handles API calls for admin real-time monitoring dashboard.
class AdminMonitoringService {
  /// Fetch monitoring overview from API
  static Future<MonitoringOverview> fetchMonitoringOverview() async {
    try {
      debugPrint('AdminMonitoringService: Calling /admin/monitoring/overview');
      final response = await ApiClient.get('/admin/monitoring/overview');
      debugPrint('AdminMonitoringService: Response received: $response');

      if (response is Map<String, dynamic>) {
        return MonitoringOverview.fromJson(response);
      }

      throw Exception('Invalid response format from monitoring API');
    } catch (e) {
      debugPrint('AdminMonitoringService: Error fetching monitoring data: $e');
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
