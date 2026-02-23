import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../models/reservation_model.dart';
import '../providers/reservation_provider.dart';

/// Premium Reservation Card Widget
///
/// Displays reservation information with a sleek status pill showing:
/// - Pending -> Soft Orange background, Dark Orange text
/// - Approved/Confirmed -> Soft Green background, Dark Green text
/// - Rejected/Cancelled -> Soft Red background, Dark Red text
///
/// When [readOnly] is true, action buttons are hidden (for history view).
class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onCancelled;
  final bool readOnly;

  const ReservationCard({
    super.key,
    required this.reservation,
    this.onCancelled,
    this.readOnly = false,
  });

  /// Get status colors based on reservation status
  ({Color background, Color text}) _getStatusColors() {
    switch (reservation.status?.toUpperCase()) {
      case 'PENDING':
        return (background: Colors.orange[50]!, text: Colors.orange[800]!);
      case 'CONFIRMED':
        return (background: Colors.green[50]!, text: Colors.green[700]!);
      case 'CANCELLED':
      case 'REJECTED':
        return (background: Colors.red[50]!, text: Colors.red[700]!);
      default:
        return (background: Colors.grey[100]!, text: Colors.grey[700]!);
    }
  }

  /// Get status icon based on reservation status
  IconData _getStatusIcon() {
    switch (reservation.status?.toUpperCase()) {
      case 'PENDING':
        return Icons.pending_outlined;
      case 'CONFIRMED':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'REJECTED':
        return Icons.block_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = _getStatusColors();

    return Container(
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
            // Header with Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Reservation ID
                Text(
                  'Booking #${reservation.id}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(),
                        size: 14,
                        color: statusColors.text,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        reservation.displayStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Ride Info
            _buildInfoRow(
              icon: Icons.local_taxi_outlined,
              label: 'Ride #${reservation.rideId}',
            ),
            const SizedBox(height: 12),
            // Seats Reserved
            _buildInfoRow(
              icon: Icons.event_seat_outlined,
              label:
                  '${reservation.seatsReserved} seat${reservation.seatsReserved != 1 ? 's' : ''} reserved',
            ),
            const SizedBox(height: 12),
            // Booking Date
            if (reservation.createdAt != null)
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Booked on ${_formatDate(reservation.createdAt!)}',
              ),
            const SizedBox(height: 16),
            // Action buttons based on status (hidden in read-only mode)
            if (!readOnly && (reservation.isPending || reservation.isConfirmed))
              _buildCancelButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CancelConfirmationSheet(
        reservation: reservation,
        onCancelled: onCancelled,
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _showCancelConfirmation(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[600],
          side: BorderSide(color: Colors.red[300]!),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Cancel Request',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// Cancel Confirmation Bottom Sheet
///
/// Premium confirmation dialog for canceling a reservation.
class _CancelConfirmationSheet extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onCancelled;

  const _CancelConfirmationSheet({required this.reservation, this.onCancelled});

  Future<void> _handleCancel(BuildContext context) async {
    final success = await context.read<ReservationProvider>().cancelReservation(
      reservation.id!,
    );

    if (context.mounted) {
      Navigator.pop(context); // Close bottom sheet

      if (success) {
        onCancelled?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reservation cancelled successfully',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final errorMessage =
            context.read<ReservationProvider>().errorMessage ??
            'Failed to cancel reservation';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: BrandColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Warning icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: Colors.red[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Cancel Reservation?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Are you sure you want to cancel this reservation for Ride #${reservation.rideId}?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Buttons
              Consumer<ReservationProvider>(
                builder: (context, provider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cancel reservation button
                      ElevatedButton(
                        onPressed: provider.isUpdatingReservation
                            ? null
                            : () => _handleCancel(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: provider.isUpdatingReservation
                            ? const SizedBox(
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Yes, Cancel Reservation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      // Keep reservation button
                      TextButton(
                        onPressed: provider.isUpdatingReservation
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'No, Keep Reservation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
