import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM Route Service
///
/// Provides route calculation using the OSRM public demo server.
/// Handles ETA calculation and route polyline generation.
class RouteService {
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Calculate route between two points using OSRM
  ///
  /// Returns route information including:
  /// - duration: Travel time in seconds
  /// - distance: Distance in meters
  /// - polylinePoints: List of LatLng points for drawing the route
  static Future<RouteResult?> calculateRoute(LatLng from, LatLng to) async {
    try {
      // Build OSRM URL: {lon},{lat};{lon},{lat}
      final url = Uri.parse(
        '$_osrmBaseUrl/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson',
      );

      print(
        'RouteService: Calculating route from (${from.latitude}, ${from.longitude}) to (${to.latitude}, ${to.longitude})',
      );
      print('RouteService: OSRM URL: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(
              seconds: 30,
            ), // Increased timeout for international routes
            onTimeout: () =>
                throw Exception('Route calculation timeout after 30 seconds'),
          );

      print('RouteService: Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('RouteService: OSRM API error: ${response.statusCode}');
        throw Exception('OSRM API error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('RouteService: Response code: ${data['code']}');

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        print(
          'RouteService: No valid route found. Code: ${data['code']}, Routes: ${data['routes']}',
        );
        return null;
      }

      final route = data['routes'][0];
      final duration = (route['duration'] as num).toInt(); // seconds
      final distance = (route['distance'] as num).toInt(); // meters

      print(
        'RouteService: Route found - Duration: ${duration}s, Distance: ${distance}m',
      );

      // Parse geometry points
      final geometry = route['geometry'];
      final List<LatLng> polylinePoints = [];

      if (geometry != null && geometry['coordinates'] != null) {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        for (final coord in coordinates) {
          final lon = (coord[0] as num).toDouble();
          final lat = (coord[1] as num).toDouble();
          polylinePoints.add(LatLng(lat, lon));
        }
      }

      print('RouteService: Parsed ${polylinePoints.length} polyline points');

      return RouteResult(
        durationSeconds: duration,
        distanceMeters: distance,
        polylinePoints: polylinePoints,
      );
    } catch (e) {
      print('RouteService: Route calculation failed: $e');
      return null;
    }
  }

  /// Format duration in seconds to human-readable string
  ///
  /// Examples:
  /// - 180 -> "3 min"
  /// - 3600 -> "1 hr"
  /// - 5400 -> "1 hr 30 min"
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '< 1 min';
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours == 0) {
      return '$minutes min';
    } else if (minutes == 0) {
      return '$hours hr';
    } else {
      return '$hours hr ${minutes}min';
    }
  }

  /// Calculate ETA timestamp based on current time and duration
  static DateTime calculateETA(int durationSeconds) {
    return DateTime.now().add(Duration(seconds: durationSeconds));
  }
}

/// Route calculation result
class RouteResult {
  final int durationSeconds;
  final int distanceMeters;
  final List<LatLng> polylinePoints;

  RouteResult({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.polylinePoints,
  });

  String get formattedDuration => RouteService.formatDuration(durationSeconds);

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}

/// Debounced route calculator for ETA updates
///
/// Prevents excessive API calls by only calculating every 5 seconds minimum
class DebouncedRouteCalculator {
  DateTime? _lastCalculation;
  final Duration _debounceInterval;

  DebouncedRouteCalculator({Duration? debounceInterval})
    : _debounceInterval = debounceInterval ?? const Duration(seconds: 5);

  /// Check if enough time has passed since last calculation
  bool shouldCalculate() {
    if (_lastCalculation == null) return true;
    return DateTime.now().difference(_lastCalculation!) >= _debounceInterval;
  }

  /// Mark calculation as completed
  void markCalculated() {
    _lastCalculation = DateTime.now();
  }

  /// Calculate route with debouncing
  ///
  /// Returns null if debounce period hasn't elapsed
  Future<RouteResult?> calculateIfNeeded(LatLng from, LatLng to) async {
    if (!shouldCalculate()) return null;

    final result = await RouteService.calculateRoute(from, to);
    if (result != null) {
      markCalculated();
    }
    return result;
  }

  /// Force calculation regardless of debounce (for initial loads)
  Future<RouteResult?> forceCalculate(LatLng from, LatLng to) async {
    final result = await RouteService.calculateRoute(from, to);
    if (result != null) {
      markCalculated();
    }
    return result;
  }

  /// Reset debounce timer
  void reset() {
    _lastCalculation = null;
  }
}
