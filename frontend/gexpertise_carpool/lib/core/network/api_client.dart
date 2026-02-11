import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

/// ApiClient - Reusable HTTP client for backend API
///
/// Provides generic GET and POST methods with automatic JSON handling
/// and Authorization header attachment.
class ApiClient {
  // Android emulator maps 10.0.2.2 to host machine localhost
  static const String baseUrl = 'http://10.0.2.2:5000';

  /// Perform a GET request
  ///
  /// Returns parsed JSON or throws an exception on error.
  static Future<dynamic> get(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _buildHeaders();

      final response = await http.get(uri, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Perform a POST request
  ///
  /// [body] will be JSON encoded automatically.
  /// Returns parsed JSON or throws an exception on error.
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _buildHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Temporary connectivity test method
  ///
  /// Tests connection to /rides/ endpoint and logs result.
  /// Used to verify emulator  backend communication.
  static Future<void> testConnectivity() async {
    try {
      debugPrint('Testing connectivity to /rides/');
      final response = await get('/rides/');
      debugPrint('Connectivity test SUCCESS: $response');
    } on ApiException catch (e) {
      debugPrint(
        'Connectivity test FAILED: ${e.message} (status: ${e.statusCode})',
      );
    } catch (e) {
      debugPrint('Connectivity test ERROR: $e');
    }
  }

  /// Build request headers with optional Authorization
  static Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await AuthStorage.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Handle HTTP response
  ///
  /// Returns parsed JSON for successful responses.
  /// Throws exception for error responses.
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _parseErrorMessage(response.body),
      );
    }
  }

  /// Parse error message from response body
  static String _parseErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data['message'] ?? data['error'] ?? 'Unknown error';
      }
      return body;
    } catch (_) {
      return body.isNotEmpty ? body : 'Request failed';
    }
  }

  /// Handle network/connection errors
  static Exception _handleError(dynamic error) {
    if (error is ApiException) return error;
    return ApiException(statusCode: 0, message: 'Network error: ');
  }
}

/// Custom API exception for error handling
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(): ';
}
