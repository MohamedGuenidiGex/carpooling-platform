import 'package:flutter/foundation.dart';
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
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime departureTime;
  final int availableSeats;
  final String? status;
  final DateTime? createdAt;
  final String? comments;
  final bool isRegular;
  final List<Reservation>? reservations;
  final String? driverName;
  final String? driverEmail;
  final String? driverCarModel;
  final String? driverCarColor;

  Ride({
    this.id,
    this.driverId,
    required this.origin,
    required this.destination,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    required this.departureTime,
    required this.availableSeats,
    this.status,
    this.createdAt,
    this.comments,
    this.isRegular = false,
    this.reservations,
    this.driverName,
    this.driverEmail,
    this.driverCarModel,
    this.driverCarColor,
  });

  /// Create Ride from JSON response
  factory Ride.fromJson(Map<String, dynamic> json) {
    // Debug: Log raw JSON to see if coordinates are present
    debugPrint('Ride.fromJson: Parsing ride ID ${json['id']}');
    debugPrint('  origin_lat in JSON: ${json['origin_lat']}');
    debugPrint('  origin_lng in JSON: ${json['origin_lng']}');
    debugPrint('  destination_lat in JSON: ${json['destination_lat']}');
    debugPrint('  destination_lng in JSON: ${json['destination_lng']}');

    String? driverName;
    String? driverEmail;

    if (json['driver'] != null && json['driver'] is Map<String, dynamic>) {
      final driverData = json['driver'] as Map<String, dynamic>;
      driverName = driverData['name'] as String?;
      driverEmail = driverData['email'] as String?;
    }

    // Also check for driver_name at top level (from serialize_ride_with_reservations)
    if (driverName == null && json['driver_name'] != null) {
      driverName = json['driver_name'] as String?;
    }

    return Ride(
      id: json['id'] as int?,
      driverId: json['driver_id'] as int?,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      originLat: json['origin_lat'] != null
          ? (json['origin_lat'] as num).toDouble()
          : null,
      originLng: json['origin_lng'] != null
          ? (json['origin_lng'] as num).toDouble()
          : null,
      destinationLat: json['destination_lat'] != null
          ? (json['destination_lat'] as num).toDouble()
          : null,
      destinationLng: json['destination_lng'] != null
          ? (json['destination_lng'] as num).toDouble()
          : null,
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
      driverCarModel: json['driver_car_model'] as String?,
      driverCarColor: json['driver_car_color'] as String?,
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
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
    };
  }

  /// Create a copy of Ride with updated fields
  Ride copyWith({
    int? id,
    int? driverId,
    String? origin,
    String? destination,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    DateTime? departureTime,
    int? availableSeats,
    String? status,
    DateTime? createdAt,
    String? comments,
    bool? isRegular,
    List<Reservation>? reservations,
    String? driverName,
    String? driverEmail,
    String? driverCarModel,
    String? driverCarColor,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      departureTime: departureTime ?? this.departureTime,
      availableSeats: availableSeats ?? this.availableSeats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      comments: comments ?? this.comments,
      isRegular: isRegular ?? this.isRegular,
      reservations: reservations ?? this.reservations,
      driverName: driverName ?? this.driverName,
      driverEmail: driverEmail ?? this.driverEmail,
      driverCarModel: driverCarModel ?? this.driverCarModel,
      driverCarColor: driverCarColor ?? this.driverCarColor,
    );
  }

  @override
  String toString() {
    return 'Ride(id: $id, origin: $origin, destination: $destination, '
        'departure: $departureTime, seats: $availableSeats)';
  }
}
