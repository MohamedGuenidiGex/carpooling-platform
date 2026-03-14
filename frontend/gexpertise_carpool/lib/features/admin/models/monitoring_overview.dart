import 'package:flutter/material.dart';

class SystemHealth {
  final String api;
  final String database;
  final String websocket;
  final String osrm;
  final String gpsStream;
  final String checkedAt;

  SystemHealth({
    required this.api,
    required this.database,
    required this.websocket,
    required this.osrm,
    required this.gpsStream,
    required this.checkedAt,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      api: (json['api'] ?? 'unknown').toString(),
      database: (json['database'] ?? 'unknown').toString(),
      websocket: (json['websocket'] ?? 'unknown').toString(),
      osrm: (json['osrm'] ?? 'unknown').toString(),
      gpsStream: (json['gps_stream'] ?? 'unknown').toString(),
      checkedAt: (json['checked_at'] ?? '').toString(),
    );
  }

  /// Legacy constructor for backwards compatibility
  factory SystemHealth.legacy({
    required String status,
    required String message,
    required String lastUpdated,
  }) {
    return SystemHealth(
      api: status == 'operational' ? 'online' : 'down',
      database: status == 'operational' ? 'healthy' : 'down',
      websocket: 'connected',
      osrm: 'responding',
      gpsStream: 'active',
      checkedAt: lastUpdated,
    );
  }

  /// Overall system status based on all components
  String get status {
    final components = [api, database, websocket, osrm, gpsStream];
    final downCount = components.where((c) => c == 'down').length;
    // 'idle' is a healthy state (no drivers to track), only 'inactive'/'unknown' are degraded
    final degradedCount = components
        .where((c) => ['inactive', 'unknown'].contains(c))
        .length;

    if (downCount > 0) return 'degraded';
    if (degradedCount > 0) return 'degraded';
    return 'operational';
  }

  /// Display message based on overall status
  String get message {
    if (status == 'operational') return 'All systems operational';
    return 'Some systems degraded';
  }

  /// Last updated timestamp (alias for checkedAt)
  String get lastUpdated => checkedAt;

  /// Check if all components are healthy
  bool get isOperational => status == 'operational';

  /// Check if any component is degraded
  bool get isDegraded => status == 'degraded';

  /// Get component status color
  static Color getStatusColor(String status) {
    switch (status) {
      case 'online':
      case 'healthy':
      case 'connected':
      case 'responding':
      case 'active':
      case 'idle':
        return Colors.green;
      case 'inactive':
      case 'unknown':
        return Colors.orange;
      case 'down':
      default:
        return Colors.red;
    }
  }

  /// Get component status label
  static String getStatusLabel(String component, String status) {
    final labels = {
      'api': 'API Server',
      'database': 'Database',
      'websocket': 'WebSocket',
      'osrm': 'OSRM Routing',
      'gps_stream': 'GPS Stream',
    };
    return labels[component] ?? component;
  }
}

class LiveMetrics {
  final int activeRides;
  final int onlineUsers;
  final int pendingRequests;
  final int activeSessions;

  LiveMetrics({
    required this.activeRides,
    required this.onlineUsers,
    required this.pendingRequests,
    required this.activeSessions,
  });

  factory LiveMetrics.fromJson(Map<String, dynamic> json) {
    return LiveMetrics(
      activeRides:
          (json['active_rides'] ?? json['active_rides_now'] ?? 0) as int,
      onlineUsers: (json['online_users'] ?? 0) as int,
      pendingRequests: (json['pending_requests'] ?? 0) as int,
      activeSessions: (json['active_sessions'] ?? 0) as int,
    );
  }

  /// Legacy getter for backwards compatibility
  int get activeRidesNow => activeRides;
}

class SystemEvent {
  final String eventType;
  final String description;
  final String timestamp;
  final String? entityType;
  final String? user;
  final int? userId;
  final int? rideId;
  final int? reservationId;
  final String? severity;
  final Map<String, dynamic>? metadata;

  SystemEvent({
    required this.eventType,
    required this.description,
    required this.timestamp,
    this.entityType,
    this.user,
    this.userId,
    this.rideId,
    this.reservationId,
    this.severity,
    this.metadata,
  });

  factory SystemEvent.fromJson(Map<String, dynamic> json) {
    return SystemEvent(
      eventType: (json['type'] ?? json['event_type'] ?? '').toString(),
      description: (json['description'] ?? json['message'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? json['created_at'] ?? '').toString(),
      entityType: json['entity_type']?.toString(),
      user: json['user']?.toString(),
      userId: json['user_id'] as int?,
      rideId: json['ride_id'] as int?,
      reservationId: json['reservation_id'] as int?,
      severity: json['severity']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Legacy getters for backwards compatibility
  String get message => description;
  String get createdAt => timestamp;
  String get severityValue => severity ?? 'info';
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
    // Handle new format with individual endpoints
    final healthJson = json['system_health'] as Map<String, dynamic>?;
    final metricsJson = json['live_metrics'] as Map<String, dynamic>?;
    final eventsJson = json['recent_events'] as List? ?? [];

    SystemHealth health;
    if (healthJson != null && healthJson.containsKey('api')) {
      // New format with component statuses
      health = SystemHealth.fromJson(healthJson);
    } else if (healthJson != null) {
      // Legacy format
      health = SystemHealth.legacy(
        status: healthJson['status']?.toString() ?? 'unknown',
        message: healthJson['message']?.toString() ?? '',
        lastUpdated: healthJson['last_updated']?.toString() ?? '',
      );
    } else {
      // Default
      health = SystemHealth(
        api: 'unknown',
        database: 'unknown',
        websocket: 'unknown',
        osrm: 'unknown',
        gpsStream: 'unknown',
        checkedAt: '',
      );
    }

    LiveMetrics metrics;
    if (metricsJson != null) {
      metrics = LiveMetrics.fromJson(metricsJson);
    } else {
      metrics = LiveMetrics(
        activeRides: 0,
        onlineUsers: 0,
        pendingRequests: 0,
        activeSessions: 0,
      );
    }

    return MonitoringOverview(
      systemHealth: health,
      liveMetrics: metrics,
      recentEvents: eventsJson
          .whereType<Map<String, dynamic>>()
          .map(SystemEvent.fromJson)
          .toList(),
    );
  }
}
