import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/reservation_model.dart';

/// Reservation Repository
///
/// Handles all reservation-related API operations including requesting seats,
/// canceling reservations, and managing booking state.
class ReservationRepository {
  /// Request a seat on a ride
  ///
  /// POST /reservations/
  /// Creates a PENDING reservation. Driver must approve.
  /// Throws exception on error (e.g., "Ride is full", "Already booked")
  Future<void> requestSeat(int rideId, {int seats = 1}) async {
    try {
      await ApiClient.post(
        '/reservations/',
        body: {'ride_id': rideId, 'seats_reserved': seats},
      );
    } on ApiException {
      // Pass through API errors with clean messages
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException('Failed to request seat: $e');
    }
  }

  /// Get reservations for a specific employee
  ///
  /// GET /reservations/?employee_id={employeeId}
  Future<List<Reservation>> getMyReservations(
    int employeeId, {
    bool includeRide = false,
  }) async {
    try {
      final endpoint =
          '/reservations/?employee_id=$employeeId&include_ride=${includeRide.toString()}';
      debugPrint('ReservationRepository: Fetching from $endpoint');
      final response = await ApiClient.get(endpoint);

      final reservations = response as List<dynamic>?;
      if (reservations == null) {
        debugPrint('ReservationRepository: Response is null');
        return [];
      }

      debugPrint(
        'ReservationRepository: Got ${reservations.length} reservations',
      );
      if (reservations.isNotEmpty && includeRide) {
        debugPrint(
          'ReservationRepository: First reservation JSON: ${reservations.first}',
        );
      }

      return reservations
          .map((json) => Reservation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException('Failed to fetch reservations: $e');
    }
  }

  /// Get confirmed reservations with ride details for active ride detection
  ///
  /// GET /reservations/?employee_id={employeeId}&include_ride=true
  Future<List<Reservation>> getMyConfirmedReservationsWithRides(
    int employeeId,
  ) async {
    try {
      final endpoint =
          '/reservations/?employee_id=$employeeId&include_ride=true';
      final response = await ApiClient.get(endpoint);

      final reservations = response as List<dynamic>?;
      if (reservations == null) {
        return [];
      }

      return reservations
          .map((json) => Reservation.fromJson(json as Map<String, dynamic>))
          .where(
            (reservation) => reservation.status?.toLowerCase() == 'confirmed',
          )
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException(
        'Failed to fetch confirmed reservations: $e',
      );
    }
  }

  /// Approve a reservation (driver only)
  ///
  /// PATCH /reservations/{id}/approve
  Future<void> approveReservation(int reservationId) async {
    try {
      await ApiClient.patch('/reservations/$reservationId/approve');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException('Failed to approve reservation: $e');
    }
  }

  /// Reject a reservation (driver only)
  ///
  /// PATCH /reservations/{id}/reject
  Future<void> rejectReservation(int reservationId) async {
    try {
      await ApiClient.patch('/reservations/$reservationId/reject');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException('Failed to reject reservation: $e');
    }
  }

  /// Cancel a reservation
  ///
  /// POST /reservations/{id}/cancel
  Future<void> cancelReservation(int reservationId) async {
    try {
      await ApiClient.post('/reservations/$reservationId/cancel');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ReservationRepositoryException('Failed to cancel reservation: $e');
    }
  }
}

/// Custom exception for ReservationRepository errors
class ReservationRepositoryException implements Exception {
  final String message;

  ReservationRepositoryException(this.message);

  @override
  String toString() => message;
}
