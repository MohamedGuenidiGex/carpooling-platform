import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OpenStreetMap Nominatim Search Service
///
/// Provides geocoding and place search functionality using the
/// backend proxy API (which calls Nominatim).
/// This avoids CORS issues when running on Flutter Web.
class OsmSearchService {
  // Backend proxy URL - platform-aware
  static String get _backendUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }

  static const String _userAgent = 'com.gexpertise.carpooling';

  /// Search for places by query string
  ///
  /// Returns a list of places with display_name, lat, and lon.
  /// Restricted to Tunisia (countrycodes=tn) for better local results.
  /// If currentLocation is provided and query is empty/short, prepends "Current Location" option.
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    LatLng? currentLocation,
  }) async {
    final List<Map<String, dynamic>> results = [];

    // Add "Current Location" option if available and query is short/empty
    if (currentLocation != null && query.trim().length < 3) {
      results.add({
        'display_name': 'Current Location',
        'lat': currentLocation.latitude,
        'lon': currentLocation.longitude,
        'is_current_location': true,
      });
    }

    // If query is empty, return only current location (if available)
    if (query.trim().isEmpty) {
      return results;
    }

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      '$_backendUrl/geocoding/search?q=$encodedQuery&limit=5',
    );

    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> apiResults = data['results'] ?? [];
        results.addAll(
          apiResults.map((item) {
            return {
              'display_name':
                  (item['display_name'] as String?) ?? 'Unknown location',
              'lat': double.tryParse(item['lat'].toString()) ?? 0.0,
              'lon': double.tryParse(item['lon'].toString()) ?? 0.0,
              'place_id': item['place_id'],
              'osm_type': item['osm_type'],
              'is_current_location': false,
            };
          }).toList(),
        );
        return results;
      } else {
        throw Exception('Failed to search places: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error during place search: $e');
    }
  }

  /// Reverse geocode - get place name from coordinates
  ///
  /// Returns a formatted address string for the given coordinates.
  static Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse('$_backendUrl/geocoding/reverse?lat=$lat&lon=$lon');

    try {
      final response = await http.get(url, headers: {'User-Agent': _userAgent});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        return result['address'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get clean address from coordinates
  ///
  /// Returns a shortened, user-friendly address (e.g., "Technopark Sfax, Tunisia")
  /// instead of the full display_name. Never returns "Current Location".
  static Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final url = Uri.parse(
        '$_backendUrl/geocoding/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}',
      );

      final response = await http.get(url, headers: {'User-Agent': _userAgent});

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        final address = result['address'] as String?;

        if (address != null && address.isNotEmpty) {
          return address;
        }
      }

      // Ultimate fallback - return coordinates as string
      return '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
    } catch (e) {
      // On error, return coordinates
      return '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
    }
  }
}
