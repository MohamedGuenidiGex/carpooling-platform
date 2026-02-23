class RecentActivityItem {
  final String user;
  final String route;
  final String time;
  final String status;

  RecentActivityItem({
    required this.user,
    required this.route,
    required this.time,
    required this.status,
  });

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    return RecentActivityItem(
      user: (json['user'] ?? 'Unknown').toString(),
      route: (json['route'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class RecentActivity {
  final List<RecentActivityItem> items;

  RecentActivity({required this.items});

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];

    return RecentActivity(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(RecentActivityItem.fromJson)
          .toList(),
    );
  }
}
