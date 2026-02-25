import 'package:gexpertise_carpool/features/reservations/models/reservation_model.dart';

/// Ride Model
///
/// Represents a carpool ride with all necessary details for
/// serialization to/from the Flask backend.
class Ride {
  final int? id;
  final int? driverId;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final int availableSeats;
  final String? status;
  final DateTime? createdAt;
  final String? comments;
  final bool isRegular;
  final List<Reservation>? reservations;
  final String? driverName;
  final String? driverEmail;

  Ride({
    this.id,
    this.driverId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.availableSeats,
    this.status,
    this.createdAt,
    this.comments,
    this.isRegular = false,
    this.reservations,
    this.driverName,
    this.driverEmail,
  });

  /// Create Ride from JSON response
  factory Ride.fromJson(Map<String, dynamic> json) {
    // Extract driver info from nested driver object if present
    String? driverName;
    String? driverEmail;

    if (json['driver'] != null && json['driver'] is Map<String, dynamic>) {
      final driverData = json['driver'] as Map<String, dynamic>;
      driverName = driverData['name'] as String?;
      driverEmail = driverData['email'] as String?;
    }

    return Ride(
      id: json['id'] as int?,
      driverId: json['driver_id'] as int?,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureTime: DateTime.parse(json['departure_time'] as String),
      availableSeats: json['available_seats'] as int,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      comments: json['comments'] as String?,
      reservations: (json['reservations'] as List<dynamic>?)
          ?.where((e) => e != null)
          .map((e) => Reservation.fromJson(e as Map<String, dynamic>))
          .toList(),
      driverName: driverName,
      driverEmail: driverEmail,
    );
  }

  /// Convert Ride to JSON for POST request
  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'destination': destination,
      'departure_time': departureTime.toIso8601String(),
      'available_seats': availableSeats,
      if (driverId != null) 'driver_id': driverId,
      if (comments != null && comments!.isNotEmpty) 'comments': comments,
    };
  }

  /// Create a copy of Ride with updated fields
  Ride copyWith({
    int? id,
    int? driverId,
    String? origin,
    String? destination,
    DateTime? departureTime,
    int? availableSeats,
    String? status,
    DateTime? createdAt,
    String? comments,
    bool? isRegular,
    List<Reservation>? reservations,
    String? driverName,
    String? driverEmail,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureTime: departureTime ?? this.departureTime,
      availableSeats: availableSeats ?? this.availableSeats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
      isRegular: isRegular ?? this.isRegular,
      reservations: reservations ?? this.reservations,
      driverName: driverName ?? this.driverName,
      driverEmail: driverEmail ?? this.driverEmail,
    );
  }

  @override
  String toString() {
    return 'Ride(id: $id, origin: $origin, destination: $destination, '
        'departure: $departureTime, seats: $availableSeats)';
  }
}
