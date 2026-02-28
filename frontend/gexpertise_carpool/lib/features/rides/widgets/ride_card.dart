import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';
import '../models/ride_model.dart';

/// Clean Ride Card Widget - "Ticket" Style
///
/// Displays ride information in a clean card with:
/// - Route (Origin -> Destination)
/// - Date and Time
/// - Status pill (visual only)
/// - Live countdown for scheduled rides
///
/// All actions moved to RideTicketSheet via onTap.
class RideCard extends StatefulWidget {
  final Ride ride;
  final VoidCallback? onTap;

  const RideCard({super.key, required this.ride, this.onTap});

  @override
  State<RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<RideCard> {
  Timer? _countdownTimer;
  String? _countdownText;

  @override
  void initState() {
    super.initState();
    _startCountdownIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id ||
        oldWidget.ride.status != widget.ride.status) {
      _countdownTimer?.cancel();
      _startCountdownIfNeeded();
    }
  }

  void _startCountdownIfNeeded() {
    final status = widget.ride.status?.toLowerCase() ?? '';
    if (status == 'scheduled' &&
        widget.ride.departureTime.isAfter(DateTime.now())) {
      _updateCountdown();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateCountdown();
      });
    }
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final difference = widget.ride.departureTime.difference(now);

    if (difference.isNegative) {
      setState(() => _countdownText = null);
      _countdownTimer?.cancel();
      return;
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    String text;
    if (hours > 0) {
      text = 'Starts in ${hours}h ${minutes}m';
    } else if (minutes > 0) {
      text = 'Starts in ${minutes}m ${seconds}s';
    } else if (seconds > 0) {
      text = 'Starts in ${seconds}s';
    } else {
      text = 'Starting now';
    }

    setState(() => _countdownText = text);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status pill at top
              _buildStatusPill(),
              const SizedBox(height: 16),
              // Route indicator with origin and destination
              Row(
                children: [
                  // Vertical route line with dots
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: BrandColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(width: 2, height: 40, color: Colors.grey[300]),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: BrandColors.darkRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Origin and destination
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ride.origin,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          widget.ride.destination,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Divider
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 16),
              // Info row: Date, Time
              Row(
                children: [
                  _buildInfoItem(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(widget.ride.departureTime),
                  ),
                  const SizedBox(width: 24),
                  _buildInfoItem(
                    icon: Icons.access_time_outlined,
                    label: _formatTime(widget.ride.departureTime),
                  ),
                ],
              ),
              // Countdown timer for scheduled rides
              if (_countdownText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _countdownText!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    final status = widget.ride.status?.toUpperCase() ?? 'ACTIVE';
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'PENDING':
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        label = 'Pending';
      case 'CONFIRMED':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        label = 'Confirmed';
      case 'COMPLETED':
        bgColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        label = 'Completed';
      case 'CANCELLED':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        label = 'Cancelled';
      case 'FULL':
        bgColor = Colors.purple[50]!;
        textColor = Colors.purple[700]!;
        label = 'Full';
      default:
        bgColor = Colors.grey[50]!;
        textColor = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
