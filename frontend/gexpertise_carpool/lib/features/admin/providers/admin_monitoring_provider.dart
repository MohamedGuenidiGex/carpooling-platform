import 'package:flutter/foundation.dart';
import 'package:gexpertise_carpool/core/network/api_client.dart';
import '../models/monitoring_overview.dart';
import '../services/admin_monitoring_service.dart';

/// Admin Monitoring Provider
/// Manages real-time monitoring dashboard state and fetches data from backend.
class AdminMonitoringProvider extends ChangeNotifier {
  MonitoringOverview? _overview;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  // Getters
  MonitoringOverview? get overview => _overview;
  SystemHealth? get systemHealth => _overview?.systemHealth;
  LiveMetrics? get liveMetrics => _overview?.liveMetrics;
  List<SystemEvent> get recentEvents => _overview?.recentEvents ?? [];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  /// Fetch monitoring overview from API
  Future<void> fetchMonitoringOverview() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _overview = await AdminMonitoringService.fetchMonitoringOverview();
      _lastUpdated = DateTime.now();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint(
        'AdminMonitoringProvider: ApiException - status: ${e.statusCode}, message: ${e.message}',
      );
      _errorMessage = e.statusCode == 0
          ? 'Failed to connect to server. Is backend running on ${ApiClient.baseUrl}?'
          : 'Failed to load monitoring data: ${e.message}';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminMonitoringProvider: Unexpected error: $e');
      _errorMessage = 'Failed to load monitoring data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send heartbeat to update last_seen
  Future<void> sendHeartbeat() async {
    await AdminMonitoringService.sendHeartbeat();
  }

  /// Refresh monitoring data
  Future<void> refresh() async {
    await fetchMonitoringOverview();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
