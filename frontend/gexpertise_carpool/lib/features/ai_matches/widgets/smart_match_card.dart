import 'package:flutter/material.dart';

/// Widget to display AI match details in a card layout
///
/// Shows pickup location, detour time, and match score
/// in a clean, Material Design card.
class SmartMatchCard extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const SmartMatchCard({
    super.key,
    required this.matchData,
  });

  @override
  Widget build(BuildContext context) {
    final pickupLocation = matchData['pickup_location'] as Map<String, dynamic>?;
    final pickupName = pickupLocation?['name'] ?? 'Unknown location';
    final detourMinutes = (matchData['detour_minutes'] as num?)?.toDouble() ?? 0.0;
    final matchScore = (matchData['match_score'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Smart Ride Match',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pickup location
            _buildInfoRow(
              context,
              icon: Icons.location_on,
              label: 'Pickup location',
              value: pickupName,
            ),
            const SizedBox(height: 16),

            // Detour time
            _buildInfoRow(
              context,
              icon: Icons.access_time,
              label: 'Detour',
              value: _formatDetour(detourMinutes),
              valueColor: _getDetourColor(detourMinutes),
            ),
            const SizedBox(height: 16),

            // Match score
            _buildInfoRow(
              context,
              icon: Icons.star,
              label: 'Match score',
              value: '${(matchScore * 100).toInt()}%',
              valueColor: _getScoreColor(matchScore),
            ),
            const SizedBox(height: 8),

            // Match score indicator
            _buildScoreIndicator(context, matchScore),
          ],
        ),
      ),
    );
  }

  /// Build an info row with icon, label, and value
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build match score visual indicator
  Widget _buildScoreIndicator(BuildContext context, double score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getScoreColor(score),
            ),
          ),
        ),
      ],
    );
  }

  /// Format detour time
  String _formatDetour(double minutes) {
    if (minutes < 1) {
      return 'Less than 1 minute';
    } else if (minutes < 60) {
      return '+${minutes.toInt()} minute${minutes > 1 ? 's' : ''}';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).toInt();
      if (mins == 0) {
        return '+$hours hour${hours > 1 ? 's' : ''}';
      }
      return '+$hours hr $mins min';
    }
  }

  /// Get color for detour time based on duration
  Color _getDetourColor(double minutes) {
    if (minutes <= 5) {
      return Colors.green;
    } else if (minutes <= 10) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Get color for match score
  Color _getScoreColor(double score) {
    if (score >= 0.8) {
      return Colors.green;
    } else if (score >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
