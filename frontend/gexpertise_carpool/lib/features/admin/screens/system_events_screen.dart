import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';
import '../models/monitoring_overview.dart';
import '../services/admin_monitoring_service.dart';

/// System Events Screen - Dedicated page for viewing all system events
class SystemEventsScreen extends StatefulWidget {
  const SystemEventsScreen({super.key});

  @override
  State<SystemEventsScreen> createState() => _SystemEventsScreenState();
}

class _SystemEventsScreenState extends State<SystemEventsScreen> {
  List<SystemEvent> _events = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final events = await AdminMonitoringService.fetchSystemEvents(
        limit: _limit,
        offset: 0,
      );
      setState(() {
        _events = events;
        _offset = events.length;
        _hasMore = events.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load events: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final events = await AdminMonitoringService.fetchSystemEvents(
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _events.addAll(events);
        _offset += events.length;
        _hasMore = events.length == _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _offset = 0;
      _hasMore = true;
    });
    await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: BrandColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'System Events',
          style: TextStyle(
            color: BrandColors.black,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BrandColors.black),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: BrandColors.primaryRed,
        backgroundColor: BrandColors.white,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(BrandColors.primaryRed),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadEvents,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, color: Colors.grey[300], size: 64),
            const SizedBox(height: 16),
            Text(
              'No system events found',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _events.length) {
          // Load more button
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        BrandColors.primaryRed,
                      ),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text(
                        'Load More',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
          );
        }

        final event = _events[index];
        final isLast = index == _events.length - 1;

        return _EventCard(event: event, isLast: isLast);
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.isLast});

  final SystemEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final icon = _getEventIcon(event.eventType);
    final color = _getSeverityColor(event.severity ?? 'info');
    final timeAgo = _timeAgo(event.timestamp);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.eventType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.black,
                      height: 1.4,
                    ),
                  ),
                  if (event.user != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.user!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.entityType != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getEntityIcon(event.entityType!),
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${event.entityType} ${event.rideId != null ? '#${event.rideId}' : ''}${event.reservationId != null ? '#${event.reservationId}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    final type = eventType.toUpperCase();
    if (type.contains('USER')) return Icons.person_outline;
    if (type.contains('RIDE')) return Icons.directions_car_outlined;
    if (type.contains('RESERVATION')) return Icons.bookmark_outline;
    if (type.contains('SYSTEM')) return Icons.settings_outlined;
    if (type.contains('LOGIN')) return Icons.login_outlined;
    if (type.contains('LOGOUT')) return Icons.logout_outlined;
    if (type.contains('BOARD')) return Icons.gps_fixed_outlined;
    if (type.contains('CANCEL')) return Icons.cancel_outlined;
    return Icons.info_outline;
  }

  IconData _getEntityIcon(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'ride':
        return Icons.directions_car_outlined;
      case 'reservation':
        return Icons.bookmark_outline;
      case 'user':
        return Icons.person_outline;
      case 'system':
        return Icons.computer_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Color _getSeverityColor(String? severity) {
    final s = (severity ?? 'info').toUpperCase();
    if (s == 'CRITICAL') return Colors.red;
    if (s == 'WARNING') return Colors.orange;
    return BrandColors.primaryRed;
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }
}
