import '../../../core/network/api_client.dart';

/// Service for AI ride matching operations
///
/// Provides methods to interact with AI match endpoints:
/// - Get match details by ID
/// - Request a match (passenger indicates interest)
/// - Reject a match (passenger declines)
class AIMatchesService {
  /// Get a specific AI match by ID
  ///
  /// Used when opening match details from a notification.
  /// Returns match data including pickup location, detour time, and score.
  ///
  /// Throws [ApiException] if request fails.
  static Future<Map<String, dynamic>> getMatchById(int matchId) async {
    final response = await ApiClient.get('/ai/matches/$matchId');
    return response as Map<String, dynamic>;
  }

  /// Request an AI match (passenger indicates interest)
  ///
  /// Updates match status from 'suggested' to 'requested'.
  /// Triggers driver notification.
  ///
  /// Throws [ApiException] if request fails.
  static Future<Map<String, dynamic>> requestMatch(int matchId) async {
    final response = await ApiClient.post('/ai/matches/$matchId/request');
    return response as Map<String, dynamic>;
  }

  /// Reject an AI match (passenger declines)
  ///
  /// Updates match status to 'rejected'.
  /// No driver notification is sent.
  ///
  /// Throws [ApiException] if request fails.
  static Future<Map<String, dynamic>> rejectMatch(int matchId) async {
    final response = await ApiClient.post('/ai/matches/$matchId/reject');
    return response as Map<String, dynamic>;
  }

  /// Get all suggested AI matches for the current user
  ///
  /// Returns list of matches ordered by match score (highest first).
  ///
  /// Throws [ApiException] if request fails.
  static Future<List<Map<String, dynamic>>> getAllMatches() async {
    final response = await ApiClient.get('/ai/matches');
    return List<Map<String, dynamic>>.from(response as List);
  }
}
