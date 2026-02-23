class SystemHealth {
  final String status;
  final String message;
  final String lastUpdated;

  SystemHealth({
    required this.status,
    required this.message,
    required this.lastUpdated,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      status: (json['status'] ?? 'unknown').toString(),
      message: (json['message'] ?? '').toString(),
      lastUpdated: (json['last_updated'] ?? '').toString(),
    );
  }

  bool get isOperational => status == 'operational';
  bool get isDegraded => status == 'degraded';
}

class LiveMetrics {
  final int activeRidesNow;
  final int onlineUsers;
  final int pendingRequests;
  final int activeSessions;

  LiveMetrics({
    required this.activeRidesNow,
    required this.onlineUsers,
    required this.pendingRequests,
    required this.activeSessions,
  });

  factory LiveMetrics.fromJson(Map<String, dynamic> json) {
    return LiveMetrics(
      activeRidesNow: (json['active_rides_now'] ?? 0) as int,
      onlineUsers: (json['online_users'] ?? 0) as int,
      pendingRequests: (json['pending_requests'] ?? 0) as int,
      activeSessions: (json['active_sessions'] ?? 0) as int,
    );
  }
}

class SystemEvent {
  final int id;
  final String eventType;
  final String message;
  final String severity;
  final String? employee;
  final int? employeeId;
  final int? rideId;
  final int? reservationId;
  final String createdAt;

  SystemEvent({
    required this.id,
    required this.eventType,
    required this.message,
    required this.severity,
    this.employee,
    this.employeeId,
    this.rideId,
    this.reservationId,
    required this.createdAt,
  });

  factory SystemEvent.fromJson(Map<String, dynamic> json) {
    return SystemEvent(
      id: (json['id'] ?? 0) as int,
      eventType: (json['event_type'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      severity: (json['severity'] ?? 'info').toString(),
      employee: json['employee']?.toString(),
      employeeId: json['employee_id'] as int?,
      rideId: json['ride_id'] as int?,
      reservationId: json['reservation_id'] as int?,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isInfo => severity == 'info';
}

class MonitoringOverview {
  final SystemHealth systemHealth;
  final LiveMetrics liveMetrics;
  final List<SystemEvent> recentEvents;

  MonitoringOverview({
    required this.systemHealth,
    required this.liveMetrics,
    required this.recentEvents,
  });

  factory MonitoringOverview.fromJson(Map<String, dynamic> json) {
    final healthJson = json['system_health'] as Map<String, dynamic>? ?? {};
    final metricsJson = json['live_metrics'] as Map<String, dynamic>? ?? {};
    final eventsJson = json['recent_events'] as List? ?? [];

    return MonitoringOverview(
      systemHealth: SystemHealth.fromJson(healthJson),
      liveMetrics: LiveMetrics.fromJson(metricsJson),
      recentEvents: eventsJson
          .whereType<Map<String, dynamic>>()
          .map(SystemEvent.fromJson)
          .toList(),
    );
  }
}
