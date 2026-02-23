import '../../rides/models/ride_model.dart';

/// Reservation Model
///
/// Represents a ride reservation/booking in the carpooling platform.
class Reservation {
  final int? id;
  final int? employeeId;
  final int? rideId;
  final int? seatsReserved;
  final String? status; // PENDING, CONFIRMED, CANCELLED, REJECTED
  final DateTime? createdAt;
  final String? passengerName; // From backend join with Employee table
  final String? passengerEmail; // From backend join with Employee table
  final Ride? ride; // Nested ride data from API

  Reservation({
    this.id,
    this.employeeId,
    this.rideId,
    this.seatsReserved,
    this.status,
    this.createdAt,
    this.passengerName,
    this.passengerEmail,
    this.ride,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] is int ? json['id'] as int : null,
      employeeId: json['employee_id'] is int
          ? json['employee_id'] as int
          : null,
      rideId: json['ride_id'] is int ? json['ride_id'] as int : null,
      seatsReserved: json['seats_reserved'] is int
          ? json['seats_reserved'] as int
          : null,
      status: json['status'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : null,
      passengerName: json['passenger_name'] as String?,
      passengerEmail: json['passenger_email'] as String?,
      ride: json['ride'] != null && json['ride'] is Map<String, dynamic>
          ? Ride.fromJson(json['ride'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'ride_id': rideId,
      'seats_reserved': seatsReserved,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      if (ride != null) 'ride': ride!.toJson(),
    };
  }

  /// Check if reservation is pending approval
  bool get isPending => status == 'PENDING';

  /// Check if reservation is confirmed
  bool get isConfirmed => status == 'CONFIRMED';

  /// Check if reservation is cancelled
  bool get isCancelled => status == 'CANCELLED';

  /// Check if reservation is rejected
  bool get isRejected => status == 'REJECTED';

  /// Get display-friendly status text
  String get displayStatus {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status ?? 'Unknown';
    }
  }
}
