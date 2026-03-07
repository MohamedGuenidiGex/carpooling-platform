import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'osm_search_service.dart';

/// Unified Location Search Service
///
/// Provides consistent location search and autocomplete functionality
/// across all screens in the application (Home, Offer Ride, Find Ride).
///
/// Key features:
/// - Partial text matching for autocomplete
/// - Consistent suggestion behavior
/// - Current location support
/// - Country-based filtering
class LocationSearchService {
  /// Search for locations with autocomplete support
  ///
  /// Returns suggestions based on partial input (minimum 1 character).
  /// Provides consistent results across all screens.
  ///
  /// Parameters:
  /// - [query]: Search text (partial matching supported)
  /// - [currentLocation]: User's current GPS position for proximity bias
  /// - [userCountryCode]: Country code ('tn' or 'fr') for filtering results
  /// - [includeCurrentLocation]: Whether to show "Use Current Location" option
  static Future<List<Map<String, dynamic>>> searchLocations({
    required String query,
    LatLng? currentLocation,
    String? userCountryCode,
    bool includeCurrentLocation = true,
  }) async {
    try {
      // Trim query
      final trimmedQuery = query.trim();

      // For very short queries (0-1 chars), only show current location if available
      if (trimmedQuery.isEmpty || trimmedQuery.length == 1) {
        if (includeCurrentLocation && currentLocation != null) {
          return [
            {
              'display_name': 'Use Current Location',
              'lat': currentLocation.latitude,
              'lon': currentLocation.longitude,
              'is_current_location': true,
            }
          ];
        }
        return [];
      }

      // For queries with 2+ characters, perform full search
      final results = await OsmSearchService.searchPlaces(
        trimmedQuery,
        currentLocation: includeCurrentLocation ? currentLocation : null,
        userCountryCode: userCountryCode,
      );

      debugPrint(
        'LocationSearchService: Query "$trimmedQuery" returned ${results.length} results',
      );

      return results;
    } catch (e) {
      debugPrint('LocationSearchService: Search error: $e');
      return [];
    }
  }

  /// Get address from coordinates (reverse geocoding)
  ///
  /// Returns a clean, user-friendly address string.
  static Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      return await OsmSearchService.getAddressFromCoordinates(coordinates);
    } catch (e) {
      debugPrint('LocationSearchService: Reverse geocoding error: $e');
      return '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
    }
  }

  /// Detect country code from GPS coordinates
  ///
  /// Returns 'tn' for Tunisia, 'fr' for France, or null if detection fails.
  static Future<String?> detectCountryCode(LatLng coordinates) async {
    try {
      return await OsmSearchService.detectCountryCode(coordinates);
    } catch (e) {
      debugPrint('LocationSearchService: Country detection error: $e');
      return null;
    }
  }

  /// Validate if a location result is valid
  ///
  /// Checks that required fields are present and coordinates are valid.
  static bool isValidLocation(Map<String, dynamic> location) {
    if (location['is_current_location'] == true) {
      return location['lat'] != null && location['lon'] != null;
    }

    return location['display_name'] != null &&
        location['lat'] != null &&
        location['lon'] != null &&
        location['lat'] is double &&
        location['lon'] is double;
  }

  /// Extract coordinates from location result
  ///
  /// Returns LatLng or null if invalid.
  static LatLng? getCoordinates(Map<String, dynamic> location) {
    try {
      final lat = location['lat'];
      final lon = location['lon'];

      if (lat == null || lon == null) return null;

      final latDouble = lat is double ? lat : double.tryParse(lat.toString());
      final lonDouble = lon is double ? lon : double.tryParse(lon.toString());

      if (latDouble == null || lonDouble == null) return null;

      return LatLng(latDouble, lonDouble);
    } catch (e) {
      debugPrint('LocationSearchService: Coordinate extraction error: $e');
      return null;
    }
  }

  /// Extract display name from location result
  ///
  /// Returns a user-friendly name for the location.
  static String getDisplayName(Map<String, dynamic> location) {
    if (location['is_current_location'] == true) {
      return 'Use Current Location';
    }

    return location['display_name'] as String? ??
        location['name'] as String? ??
        'Unknown location';
  }

  /// Check if location is "Use Current Location" option
  static bool isCurrentLocationOption(Map<String, dynamic> location) {
    return location['is_current_location'] == true;
  }
}
