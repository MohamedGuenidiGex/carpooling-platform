class TrendPoint {
  final String date;
  final int count;

  TrendPoint({
    required this.date,
    required this.count,
  });

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

  SystemTrends({
    required this.ridesPerDay,
    required this.reservationsPerDay,
  });

  factory SystemTrends.fromJson(Map<String, dynamic> json) {
    final rides = (json['rides_per_day'] as List?) ?? const [];
    final reservations = (json['reservations_per_day'] as List?) ?? const [];

    return SystemTrends(
      ridesPerDay: rides
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
      reservationsPerDay: reservations
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
    );
  }
}
