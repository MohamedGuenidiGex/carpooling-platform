import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';
import '../models/ride_model.dart';

/// Clean Ride Card Widget - "Ticket" Style
///
/// Displays ride information in a clean card with:
/// - Route (Origin -> Destination)
/// - Date and Time
/// - Status pill (visual only)
///
/// All actions moved to RideTicketSheet via onTap.
class RideCard extends StatelessWidget {
  final Ride ride;
  final VoidCallback? onTap;

  const RideCard({super.key, required this.ride, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                          ride.origin,
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
                          ride.destination,
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
                    label: _formatDate(ride.departureTime),
                  ),
                  const SizedBox(width: 24),
                  _buildInfoItem(
                    icon: Icons.access_time_outlined,
                    label: _formatTime(ride.departureTime),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    final status = ride.status?.toUpperCase() ?? 'ACTIVE';
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
