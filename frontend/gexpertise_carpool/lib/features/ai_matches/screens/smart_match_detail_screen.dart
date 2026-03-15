import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../services/ai_matches_service.dart';
import '../widgets/smart_match_card.dart';

/// Screen to display AI match details from notification
///
/// Loads a single match by ID and allows passenger to:
/// - Request the match (indicate interest)
/// - Reject the match (decline)
///
/// Opened from notification tap with ai_match_id parameter.
class SmartMatchDetailScreen extends StatefulWidget {
  final int aiMatchId;

  const SmartMatchDetailScreen({
    super.key,
    required this.aiMatchId,
  });

  @override
  State<SmartMatchDetailScreen> createState() => _SmartMatchDetailScreenState();
}

class _SmartMatchDetailScreenState extends State<SmartMatchDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  Map<String, dynamic>? _matchData;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  /// Load match data from API
  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AIMatchesService.getMatchById(widget.aiMatchId);
      setState(() {
        _matchData = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load match details';
        _isLoading = false;
      });
    }
  }

  /// Handle request match action
  Future<void> _handleRequestMatch() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await AIMatchesService.requestMatch(widget.aiMatchId);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match requested! The driver will be notified.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Close screen
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request match: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to request match. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handle reject match action
  Future<void> _handleRejectMatch() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await AIMatchesService.rejectMatch(widget.aiMatchId);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match rejected.'),
          duration: Duration(seconds: 2),
        ),
      );

      // Close screen
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject match: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reject match. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show confirmation dialog before rejecting
  Future<void> _confirmReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Match'),
        content: const Text(
          'Are you sure you want to reject this match? '
          'You won\'t be able to request it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleRejectMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Match Details'),
      ),
      body: _buildBody(),
    );
  }

  /// Build body based on current state
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_matchData == null) {
      return _buildEmptyState();
    }

    return _buildSuccessState();
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading match details...'),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Failed to load match details',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMatchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No match found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This match may have been removed or is no longer available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Build success state with match details and action buttons
  Widget _buildSuccessState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Match details card
                SmartMatchCard(matchData: _matchData!),

                // Additional info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'What happens next?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoPoint(
                            '1. Request this match to show your interest',
                          ),
                          _buildInfoPoint(
                            '2. The driver will be notified of your request',
                          ),
                          _buildInfoPoint(
                            '3. If the driver accepts, a seat will be reserved for you',
                          ),
                          _buildInfoPoint(
                            '4. You\'ll receive a confirmation notification',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  /// Build info point
  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Ignore button
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _confirmReject,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: const Text('Ignore'),
              ),
            ),
            const SizedBox(width: 12),

            // Request button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleRequestMatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Request Seat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
