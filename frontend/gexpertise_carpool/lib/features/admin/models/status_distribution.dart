class StatusDistribution {
  final int active;
  final int completed;
  final int cancelled;

  StatusDistribution({
    required this.active,
    required this.completed,
    required this.cancelled,
  });

  factory StatusDistribution.fromJson(Map<String, dynamic> json) {
    return StatusDistribution(
      active: (json['active'] ?? 0) as int,
      completed: (json['completed'] ?? 0) as int,
      cancelled: (json['cancelled'] ?? 0) as int,
    );
  }
}
