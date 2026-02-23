/// Dashboard Analytics Model
/// Represents analytics data for the admin dashboard.
class DashboardAnalytics {
  final int usersTotal;
  final int usersToday;
  final int activeRides;
  final int ridesTotal;
  final int reservationsTotal;
  final String systemStatus;

  DashboardAnalytics({
    required this.usersTotal,
    required this.usersToday,
    required this.activeRides,
    required this.ridesTotal,
    required this.reservationsTotal,
    required this.systemStatus,
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) {
    return DashboardAnalytics(
      usersTotal: json['users_total'] ?? 0,
      usersToday: json['users_today'] ?? 0,
      activeRides: json['active_rides'] ?? 0,
      ridesTotal: json['rides_total'] ?? 0,
      reservationsTotal: json['reservations_total'] ?? 0,
      systemStatus: json['system_status'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users_total': usersTotal,
      'users_today': usersToday,
      'active_rides': activeRides,
      'rides_total': ridesTotal,
      'reservations_total': reservationsTotal,
      'system_status': systemStatus,
    };
  }
}
