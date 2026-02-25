import '../../../core/network/api_client.dart';
import '../models/ride_model.dart';

/// Ride Repository
///
/// Handles all ride-related API operations including creating,
/// fetching, and managing rides through the Flask backend.
class RideRepository {
  /// Create a new ride
  ///
  /// POST /rides/
  /// Returns the created Ride on success, throws exception on error
  Future<Ride> createRide(Ride ride) async {
    try {
      final response = await ApiClient.post('/rides/', body: ride.toJson());
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to create ride: $e');
    }
  }

  /// Get all rides with optional filtering
  ///
  /// GET /rides/?origin=&destination=&date_from=&date_to=
  Future<List<Ride>> getRides({
    String? origin,
    String? destination,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      // Build query string manually since ApiClient doesn't support query params
      final queryParams = <String, String>{};
      if (origin != null && origin.isNotEmpty) {
        queryParams['origin'] = origin;
      }
      if (destination != null && destination.isNotEmpty) {
        queryParams['destination'] = destination;
      }
      if (dateFrom != null) {
        queryParams['date_from'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) {
        queryParams['date_to'] = dateTo.toIso8601String();
      }

      String endpoint = '/rides/';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');
        endpoint = '/rides/?$queryString';
      }

      final response = await ApiClient.get(endpoint);

      // Handle paginated response
      final items = response['items'] as List<dynamic>?;
      if (items == null) {
        return [];
      }

      return items
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to fetch rides: $e');
    }
  }

  /// Search rides with filters (alias for getRides for semantic clarity)
  ///
  /// GET /rides/?origin=&destination=&date_from=&date_to=
  Future<List<Ride>> searchRides({
    String? origin,
    String? destination,
    DateTime? date,
  }) async {
    // For date search, use the date as both from and to (single day search)
    return getRides(
      origin: origin,
      destination: destination,
      dateFrom: date,
      dateTo: date,
    );
  }

  /// Get rides offered by a specific driver
  ///
  /// GET /rides/?driver_id={driverId}
  Future<List<Ride>> getMyOfferedRides(int driverId) async {
    try {
      final endpoint = '/rides/?driver_id=$driverId';
      final response = await ApiClient.get(endpoint);

      // Handle paginated response
      final items = response['items'] as List<dynamic>?;
      if (items == null) {
        return [];
      }

      return items
          .map((json) => Ride.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to fetch my rides: $e');
    }
  }

  /// Get a single ride by ID
  ///
  /// GET /rides/{id}
  Future<Ride> getRideById(int id) async {
    try {
      final response = await ApiClient.get('/rides/$id');
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to fetch ride: $e');
    }
  }

  /// Cancel a ride (driver only)
  ///
  /// PATCH /rides/{id}/cancel
  Future<Ride> cancelRide(int id) async {
    try {
      final response = await ApiClient.patch('/rides/$id/cancel', body: {});
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to cancel ride: $e');
    }
  }

  /// Start ride - driver en route (driver only)
  ///
  /// PATCH /rides/{id}/start
  Future<Ride> startRide(int id) async {
    try {
      final response = await ApiClient.patch('/rides/$id/start', body: {});
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to start ride: $e');
    }
  }

  /// Mark driver as arrived (driver only)
  ///
  /// PATCH /rides/{id}/arrive
  Future<Ride> arriveRide(int id) async {
    try {
      final response = await ApiClient.patch('/rides/$id/arrive', body: {});
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to mark arrival: $e');
    }
  }

  /// Begin ride journey (driver only)
  ///
  /// PATCH /rides/{id}/begin
  Future<Ride> beginRide(int id) async {
    try {
      final response = await ApiClient.patch('/rides/$id/begin', body: {});
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to begin ride: $e');
    }
  }

  /// Complete ride (driver only)
  ///
  /// PATCH /rides/{id}/complete
  Future<Ride> completeRide(int id) async {
    try {
      final response = await ApiClient.patch('/rides/$id/complete', body: {});
      return Ride.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to complete ride: $e');
    }
  }

  /// Delete ride (driver only, completed or cancelled rides only)
  ///
  /// DELETE /rides/{id}
  Future<void> deleteRide(int id) async {
    try {
      await ApiClient.delete('/rides/$id');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw RideRepositoryException('Failed to delete ride: $e');
    }
  }
}

/// Custom exception for RideRepository errors
class RideRepositoryException implements Exception {
  final String message;

  RideRepositoryException(this.message);

  @override
  String toString() => message;
}
