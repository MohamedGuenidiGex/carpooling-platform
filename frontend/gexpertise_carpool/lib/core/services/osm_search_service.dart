import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OpenStreetMap Nominatim Search Service
///
/// Provides geocoding and place search functionality using the
/// Nominatim API (OpenStreetMap's free search service).
class OsmSearchService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'com.gexpertise.carpooling';

  /// Detect country code from GPS coordinates
  ///
  /// Returns 'tn' for Tunisia, 'fr' for France, or null if detection fails.
  /// Uses reverse geocoding to extract country_code from address.
  static Future<String?> detectCountryCode(LatLng coordinates) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr,en'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        final address = result['address'] as Map<String, dynamic>?;

        if (address != null && address['country_code'] != null) {
          final countryCode = (address['country_code'] as String).toLowerCase();
          // Only support Tunisia and France
          if (countryCode == 'tn' || countryCode == 'fr') {
            return countryCode;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Search for places by query string
  ///
  /// Returns a list of places with display_name, lat, and lon.
  /// Prioritizes user's detected country (tn or fr) but allows global search.
  /// If currentLocation is provided and query is empty/short, prepends "Current Location" option.
  static Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    LatLng? currentLocation,
    String? userCountryCode, // 'tn' or 'fr', defaults to 'tn'
  }) async {
    final List<Map<String, dynamic>> results = [];

    // Add "Use Current Location" option if available and query is short/empty
    if (currentLocation != null && query.trim().length < 3) {
      results.add({
        'display_name': 'Use Current Location',
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

    // Use detected country code or default to Tunisia
    final countryCode = (userCountryCode ?? 'tn').toLowerCase();
    final validCountryCode = (countryCode == 'tn' || countryCode == 'fr')
        ? countryCode
        : 'tn';

    // Build base query parameters
    final baseParams = {
      'q': encodedQuery,
      'format': 'json',
      'limit': '10',
      'addressdetails': '1',
    };

    // Add location bias if current location is available
    Map<String, String>? viewboxParams;
    if (currentLocation != null) {
      final lat = currentLocation.latitude;
      final lon = currentLocation.longitude;
      final offset = 1.0; // ~100km radius for better coverage
      final viewbox =
          '${lon - offset},${lat + offset},${lon + offset},${lat - offset}';
      viewboxParams = {
        'viewbox': viewbox,
        'bounded': '0', // Don't restrict to viewbox, just prioritize
      };
    }

    try {
      // STRATEGY 1: Try with country filter first (prioritizes local results)
      var queryParams = {
        ...baseParams,
        'countrycodes': validCountryCode,
        if (viewboxParams != null) ...viewboxParams,
      };

      var urlBuilder = Uri.parse(
        '$_baseUrl/search',
      ).replace(queryParameters: queryParams);

      var response = await http.get(
        urlBuilder,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr,en'},
      );

      List<dynamic> apiResults = [];

      if (response.statusCode == 200) {
        apiResults = json.decode(response.body);
      }

      // STRATEGY 2: If no results with country filter, try global search
      if (apiResults.isEmpty) {
        queryParams = {
          ...baseParams,
          if (viewboxParams != null) ...viewboxParams,
        };

        urlBuilder = Uri.parse(
          '$_baseUrl/search',
        ).replace(queryParameters: queryParams);

        response = await http.get(
          urlBuilder,
          headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr,en'},
        );

        if (response.statusCode == 200) {
          apiResults = json.decode(response.body);
        }
      }

      // Parse and return results
      if (apiResults.isNotEmpty) {
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
      }

      return results;
    } catch (e) {
      throw Exception('Network error during place search: $e');
    }
  }

  /// Reverse geocode - get place name from coordinates
  ///
  /// Returns a formatted address string for the given coordinates.
  static Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse('$_baseUrl/reverse?lat=$lat&lon=$lon&format=json');

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr,en'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        return result['display_name'] as String?;
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
        '$_baseUrl/reverse?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'fr,en'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        final address = result['address'] as Map<String, dynamic>?;

        if (address != null) {
          // Build a clean address from components
          final parts = <String>[];

          // Road/street name
          if (address['road'] != null) {
            parts.add(address['road'] as String);
          } else if (address['street'] != null) {
            parts.add(address['street'] as String);
          }

          // Suburb/neighborhood
          if (address['suburb'] != null) {
            parts.add(address['suburb'] as String);
          } else if (address['neighbourhood'] != null) {
            parts.add(address['neighbourhood'] as String);
          }

          // City/town
          if (address['city'] != null) {
            parts.add(address['city'] as String);
          } else if (address['town'] != null) {
            parts.add(address['town'] as String);
          } else if (address['village'] != null) {
            parts.add(address['village'] as String);
          }

          // State/country
          if (address['state'] != null) {
            parts.add(address['state'] as String);
          }
          if (address['country'] != null) {
            parts.add(address['country'] as String);
          }

          if (parts.isNotEmpty) {
            // Join first 2-3 parts for a clean address
            final cleanParts = parts.take(3).toList();
            return cleanParts.join(', ');
          }
        }

        // Fallback to display_name if address parsing fails
        final displayName = result['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Truncate if too long
          final parts = displayName.split(', ');
          if (parts.length > 3) {
            return parts.take(3).join(', ');
          }
          return displayName;
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
