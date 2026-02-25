import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/ride_model.dart';
import '../repositories/ride_repository.dart';

/// Ride Provider
///
/// Manages ride-related state including loading states and errors.
/// Uses ChangeNotifier to update UI when state changes.
class RideProvider extends ChangeNotifier {
  final RideRepository _rideRepository;

  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  List<Ride> _rides = [];
  List<Ride> _searchResults = [];
  Ride? _currentRide;

  List<Ride> _myOfferedRides = [];

  RideProvider({RideRepository? rideRepository})
    : _rideRepository = rideRepository ?? RideRepository();

  // Getters
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  List<Ride> get rides => _rides;
  List<Ride> get searchResults => _searchResults;
  List<Ride> get myOfferedRides => _myOfferedRides;
  Ride? get currentRide => _currentRide;

  /// Create a new ride from form data
  ///
  /// Accepts a Map with ride data including GPS coordinates.
  /// Returns true on success, false on failure.
  Future<bool> createRide(Map<String, dynamic> rideData) async {
    _setLoading(true);
    _clearError();

    try {
      // Parse date and time from form data
      final dateStr = rideData['date'] as String;
      final timeStr = rideData['time'] as String;
      final date = DateTime.parse(dateStr);
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final departureTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      final ride = Ride(
        origin: rideData['origin'] as String,
        destination: rideData['destination'] as String,
        departureTime: departureTime,
        availableSeats: rideData['availableSeats'] as int,
        comments: rideData['comments'] as String?,
      );

      final createdRide = await _rideRepository.createRide(ride);
      _currentRide = createdRide;
      _myOfferedRides.add(createdRide);

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to create ride: $e');
      _setLoading(false);
      return false;
    }
  }

  ///
  /// Creates a Ride object and sends it to the backend.
  /// Returns true on success, false on failure.
  /// Error message is available via [errorMessage] getter.
  Future<bool> submitRide({
    required String origin,
    required String destination,
    required DateTime departureTime,
    required int availableSeats,
    String? comments,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final ride = Ride(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
        availableSeats: availableSeats,
        comments: comments,
      );

      final createdRide = await _rideRepository.createRide(ride);
      _currentRide = createdRide;

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to create ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Search for rides
  ///
  /// Fetches rides matching the search criteria.
  /// Results are available via [rides] getter.
  Future<bool> searchRides({
    String? origin,
    String? destination,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final rides = await _rideRepository.getRides(
        origin: origin,
        destination: destination,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      _rides = rides;
      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to search rides: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get my offered rides (rides I created as a driver)
  ///
  /// Fetches rides where the current user is the driver.
  /// Results are available via [myOfferedRides] getter.
  Future<bool> getMyOfferedRides(int driverId) async {
    _setLoading(true);
    _clearError();

    try {
      final rides = await _rideRepository.getMyOfferedRides(driverId);
      _myOfferedRides = rides;
      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to fetch my rides: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Clear my offered rides list
  void clearMyOfferedRides() {
    _myOfferedRides = [];
    notifyListeners();
  }

  /// Cancel a ride (driver only)
  ///
  /// PATCH /rides/<ride_id>/cancel
  /// Returns true on success, false on failure.
  Future<bool> cancelRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRide = await _rideRepository.cancelRide(rideId);

      // Update the ride in the myOfferedRides list
      final index = _myOfferedRides.indexWhere((ride) => ride.id == rideId);
      if (index != -1) {
        _myOfferedRides[index] = updatedRide;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to cancel ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Start ride - driver en route (driver only)
  ///
  /// PATCH /rides/<ride_id>/start
  /// Returns true on success, false on failure.
  Future<bool> startRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRide = await _rideRepository.startRide(rideId);

      // Update the ride in the myOfferedRides list
      final index = _myOfferedRides.indexWhere((ride) => ride.id == rideId);
      if (index != -1) {
        _myOfferedRides[index] = updatedRide;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to start ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Mark driver as arrived (driver only)
  ///
  /// PATCH /rides/<ride_id>/arrive
  /// Returns true on success, false on failure.
  Future<bool> arriveRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRide = await _rideRepository.arriveRide(rideId);

      // Update the ride in the myOfferedRides list
      final index = _myOfferedRides.indexWhere((ride) => ride.id == rideId);
      if (index != -1) {
        _myOfferedRides[index] = updatedRide;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to mark arrival: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Begin ride journey (driver only)
  ///
  /// PATCH /rides/<ride_id>/begin
  /// Returns true on success, false on failure.
  Future<bool> beginRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRide = await _rideRepository.beginRide(rideId);

      // Update the ride in the myOfferedRides list
      final index = _myOfferedRides.indexWhere((ride) => ride.id == rideId);
      if (index != -1) {
        _myOfferedRides[index] = updatedRide;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to begin ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Complete ride (driver only)
  ///
  /// PATCH /rides/<ride_id>/complete
  /// Returns true on success, false on failure.
  Future<bool> completeRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedRide = await _rideRepository.completeRide(rideId);

      // Update the ride in the myOfferedRides list
      final index = _myOfferedRides.indexWhere((ride) => ride.id == rideId);
      if (index != -1) {
        _myOfferedRides[index] = updatedRide;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to complete ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Delete ride (driver only, completed or cancelled rides only)
  ///
  /// DELETE /rides/<ride_id>
  /// Returns true on success, false on failure.
  Future<bool> deleteRide(int rideId) async {
    _setLoading(true);
    _clearError();

    try {
      await _rideRepository.deleteRide(rideId);

      // Remove the ride from the myOfferedRides list
      _myOfferedRides.removeWhere((ride) => ride.id == rideId);

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to delete ride: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get ride by ID
  ///
  /// Fetches a single ride details.
  /// Result is available via [currentRide] getter.
  Future<bool> getRideDetails(int id) async {
    _setLoading(true);
    _clearError();

    try {
      final ride = await _rideRepository.getRideById(id);
      _currentRide = ride;

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to fetch ride details: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Perform search for rides
  ///
  /// Fetches rides matching the search criteria.
  /// Results are available via [searchResults] getter.
  /// Optionally filters out rides created by the current user.
  Future<bool> performSearch({
    String? origin,
    String? destination,
    DateTime? date,
    int? excludeDriverId,
  }) async {
    _setSearching(true);
    _clearError();

    try {
      final rides = await _rideRepository.searchRides(
        origin: origin,
        destination: destination,
        date: date,
      );

      // Filter out own rides if excludeDriverId is provided
      _searchResults = excludeDriverId != null
          ? rides.where((ride) => ride.driverId != excludeDriverId).toList()
          : rides;

      _setSearching(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setSearching(false);
      return false;
    } catch (e) {
      _setError('Failed to search rides: $e');
      _setSearching(false);
      return false;
    }
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setSearching(bool value) {
    if (_isSearching == value) return;
    _isSearching = value;
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
