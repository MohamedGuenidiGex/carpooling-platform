import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';

/// Reservation Provider
///
/// Manages reservation-related state including booking operations.
/// Uses ChangeNotifier to update UI when state changes.
class ReservationProvider extends ChangeNotifier {
  final ReservationRepository _reservationRepository;

  bool _isBooking = false;
  bool _isLoadingReservations = false;
  bool _isUpdatingReservation = false;
  String? _errorMessage;
  List<Reservation> _myReservations = [];

  ReservationProvider({ReservationRepository? reservationRepository})
    : _reservationRepository = reservationRepository ?? ReservationRepository();

  // Getters
  bool get isBooking => _isBooking;
  bool get isLoadingReservations => _isLoadingReservations;
  bool get isUpdatingReservation => _isUpdatingReservation;
  String? get errorMessage => _errorMessage;
  List<Reservation> get myReservations => _myReservations;

  /// Book a ride (request a seat)
  ///
  /// Creates a reservation request for the specified ride.
  /// Returns true on success, false on failure.
  /// Error message is available via [errorMessage] getter.
  Future<bool> bookRide(int rideId, {int seats = 1}) async {
    _setBooking(true);
    _clearError();

    try {
      await _reservationRepository.requestSeat(rideId, seats: seats);
      _setBooking(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setBooking(false);
      return false;
    } catch (e) {
      _setError('Failed to book ride: $e');
      _setBooking(false);
      return false;
    }
  }

  /// Get my reservations (bookings I made)
  ///
  /// Fetches all reservations for the current user.
  /// Results are available via [myReservations] getter.
  Future<bool> getMyReservations(
    int employeeId, {
    bool includeRide = false,
  }) async {
    _setLoadingReservations(true);
    _clearError();

    try {
      final reservations = await _reservationRepository.getMyReservations(
        employeeId,
        includeRide: includeRide,
      );
      _myReservations = reservations;
      _setLoadingReservations(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoadingReservations(false);
      return false;
    } catch (e) {
      _setError('Failed to fetch reservations: $e');
      _setLoadingReservations(false);
      return false;
    }
  }

  /// Get confirmed reservations with ride details for active ride detection
  ///
  /// Fetches confirmed reservations with full ride information.
  /// Returns list of reservations with ride details.
  Future<List<Reservation>> getMyConfirmedReservationsWithRides(
    int employeeId,
  ) async {
    try {
      return await _reservationRepository.getMyConfirmedReservationsWithRides(
        employeeId,
      );
    } on ApiException catch (e) {
      _setError(e.message);
      return [];
    } catch (e) {
      _setError('Failed to fetch confirmed reservations: $e');
      return [];
    }
  }

  /// Clear my reservations list
  void clearMyReservations() {
    _myReservations = [];
    notifyListeners();
  }

  /// Approve a reservation (driver only)
  ///
  /// Approves a pending reservation request.
  /// Returns true on success, false on failure.
  Future<bool> approveReservation(int reservationId) async {
    _setUpdatingReservation(true);
    _clearError();

    try {
      await _reservationRepository.approveReservation(reservationId);
      _setUpdatingReservation(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setUpdatingReservation(false);
      return false;
    } catch (e) {
      _setError('Failed to approve reservation: $e');
      _setUpdatingReservation(false);
      return false;
    }
  }

  /// Reject a reservation (driver only)
  ///
  /// Rejects a pending reservation request.
  /// Returns true on success, false on failure.
  Future<bool> rejectReservation(int reservationId) async {
    _setUpdatingReservation(true);
    _clearError();

    try {
      await _reservationRepository.rejectReservation(reservationId);
      _setUpdatingReservation(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setUpdatingReservation(false);
      return false;
    } catch (e) {
      _setError('Failed to reject reservation: $e');
      _setUpdatingReservation(false);
      return false;
    }
  }

  /// Cancel a reservation (passenger only)
  ///
  /// Cancels a pending or confirmed reservation.
  /// Returns true on success, false on failure.
  Future<bool> cancelReservation(int reservationId) async {
    _setUpdatingReservation(true);
    _clearError();

    try {
      await _reservationRepository.cancelReservation(reservationId);
      _setUpdatingReservation(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setUpdatingReservation(false);
      return false;
    } catch (e) {
      _setError('Failed to cancel reservation: $e');
      _setUpdatingReservation(false);
      return false;
    }
  }

  /// Clear any error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Private helper methods
  void _setBooking(bool value) {
    if (_isBooking == value) return;
    _isBooking = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setLoadingReservations(bool value) {
    if (_isLoadingReservations == value) return;
    _isLoadingReservations = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setUpdatingReservation(bool value) {
    if (_isUpdatingReservation == value) return;
    _isUpdatingReservation = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setError(String message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
