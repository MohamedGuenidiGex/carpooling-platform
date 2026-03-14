class TrendPoint {
  final String date;
  final int count;

  TrendPoint({required this.date, required this.count});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: (json['date'] ?? '').toString(),
      count: (json['count'] ?? 0) as int,
    );
  }
}

class SystemTrends {
  final List<TrendPoint> ridesPerDay;
  final List<TrendPoint> reservationsPerDay;
  final List<TrendPoint> userGrowthPerDay;

  SystemTrends({
    required this.ridesPerDay,
    required this.reservationsPerDay,
    this.userGrowthPerDay = const [],
  });

  factory SystemTrends.fromJson(Map<String, dynamic> json) {
    final rides = (json['rides_per_day'] as List?) ?? const [];
    final reservations = (json['reservations_per_day'] as List?) ?? const [];
    final userGrowth = (json['user_growth_per_day'] as List?) ?? const [];

    return SystemTrends(
      ridesPerDay: rides
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
      reservationsPerDay: reservations
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
      userGrowthPerDay: userGrowth
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
    );
  }

  /// Create SystemTrends from rides-over-time API response
  factory SystemTrends.fromRidesOverTime(List<dynamic> ridesData, int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));

    // Parse rides data from API
    final ridesMap = <String, int>{};
    for (final item in ridesData) {
      if (item is Map<String, dynamic>) {
        final date = item['date']?.toString() ?? '';
        final rides = item['rides'] as int? ?? 0;
        ridesMap[date] = rides;
      }
    }

    // Create trend points for the requested date range
    final ridesPerDay = <TrendPoint>[];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = ridesMap[dateStr] ?? 0;
      ridesPerDay.add(TrendPoint(date: dateStr, count: count));
    }

    return SystemTrends(ridesPerDay: ridesPerDay, reservationsPerDay: []);
  }

  /// Create SystemTrends from user-growth API response
  factory SystemTrends.fromUserGrowth(List<dynamic> userData, int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));

    // Parse user growth data from API
    final userMap = <String, int>{};
    for (final item in userData) {
      if (item is Map<String, dynamic>) {
        final date = item['date']?.toString() ?? '';
        final users = item['users'] as int? ?? 0;
        userMap[date] = users;
      }
    }

    // Create trend points for the requested date range
    final userGrowthPerDay = <TrendPoint>[];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = userMap[dateStr] ?? 0;
      userGrowthPerDay.add(TrendPoint(date: dateStr, count: count));
    }

    return SystemTrends(
      ridesPerDay: [],
      reservationsPerDay: [],
      userGrowthPerDay: userGrowthPerDay,
    );
  }
}
