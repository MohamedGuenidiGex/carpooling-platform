import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../models/ride_model.dart';

/// Ride Ticket Sheet - "Wallet" Style Detail View
///
/// Shows ride details with context-aware actions:
/// - Passenger view: Cancel reservation button
/// - Driver view: Approve/Reject passenger requests
/// - History view: No actions (read-only)
class RideTicketSheet extends StatelessWidget {
  final Ride ride;
  final Reservation? reservation;
  final bool isDriver;
  final bool isHistory;

  const RideTicketSheet({
    super.key,
    required this.ride,
    this.reservation,
    required this.isDriver,
    this.isHistory = false,
  });

  bool get _isUpcoming => ride.departureTime.isAfter(DateTime.now());

  // Consolidate data: Use ride.reservations
  List<Reservation> get activeReservations => ride.reservations ?? [];

  bool get _canCancelReservation {
    if (reservation == null) return false;
    if (!_isUpcoming) return false;
    final status = (reservation?.status ?? '').toUpperCase();
    return status == 'PENDING' || status == 'CONFIRMED';
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

              // Header - Ride Summary
              _buildHeader(),
              const SizedBox(height: 24),

              // Route Info
              _buildRouteSection(),
              const SizedBox(height: 24),

              // Status Section
              _buildStatusSection(),
              const SizedBox(height: 24),

              // Actions Section
              if (!isHistory) _buildActionsSection(context),
              if (isHistory) _buildHistoryMessage(),

              const SizedBox(height: 16),

              // Close button
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Map placeholder
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Route Preview',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isDriver ? 'Your Ride Offer' : 'Your Reservation',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: BrandColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ride #${ride.id}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRouteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildRouteRow(Icons.location_on, ride.origin, isOrigin: true),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 12),
              Container(width: 2, height: 30, color: BrandColors.primaryRed),
              const SizedBox(width: 34),
              Icon(
                Icons.arrow_downward,
                size: 16,
                color: BrandColors.primaryRed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRouteRow(Icons.location_on, ride.destination, isOrigin: false),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoRow(
                Icons.calendar_today_outlined,
                '${ride.departureTime.day.toString().padLeft(2, '0')}/${ride.departureTime.month.toString().padLeft(2, '0')}/${ride.departureTime.year}',
              ),
              _buildInfoRow(
                Icons.access_time_outlined,
                '${ride.departureTime.hour.toString().padLeft(2, '0')}:${ride.departureTime.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String text, {required bool isOrigin}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isOrigin ? BrandColors.primaryRed : BrandColors.darkRed,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BrandColors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildStatusSection() {
    final status = (ride.status ?? 'ACTIVE').toUpperCase();
    final reservationStatus = reservation?.status?.toUpperCase();

    Color statusColor;
    String statusText;

    if (isDriver) {
      switch (status) {
        case 'ACTIVE':
          statusColor = Colors.green;
          statusText = 'Active - Accepting Requests';
        case 'FULL':
          statusColor = Colors.orange;
          statusText = 'Full - No Seats Available';
        case 'COMPLETED':
          statusColor = Colors.blue;
          statusText = 'Completed';
        case 'CANCELLED':
          statusColor = Colors.red;
          statusText = 'Cancelled';
        default:
          statusColor = Colors.grey;
          statusText = status;
      }
    } else {
      switch (reservationStatus) {
        case 'PENDING':
          statusColor = Colors.orange;
          statusText = 'Pending - Waiting for Approval';
        case 'CONFIRMED':
          statusColor = Colors.green;
          statusText = 'Confirmed - Seat Reserved';
        case 'CANCELLED':
          statusColor = Colors.red;
          statusText = 'Cancelled';
        case 'REJECTED':
          statusColor = Colors.grey;
          statusText = 'Rejected';
        default:
          statusColor = Colors.grey;
          statusText = reservationStatus ?? status;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    if (isDriver) {
      return _buildDriverActions(context);
    } else {
      return _buildPassengerActions(context);
    }
  }

  Widget _buildDriverActions(BuildContext context) {
    final pendingReservations = activeReservations
        .where((r) => (r.status ?? '').toUpperCase() == 'PENDING')
        .toList();

    if (pendingReservations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No pending requests',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passenger Requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BrandColors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...pendingReservations.map(
          (res) => _buildPassengerRequestItem(context, res),
        ),
      ],
    );
  }

  Widget _buildPassengerRequestItem(BuildContext context, Reservation res) {
    final seatsReserved = res.seatsReserved ?? 1;
    final reservationId = res.id;
    final passengerName = res.passengerName ?? 'Unknown Passenger';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: BrandColors.primaryRed.withOpacity(0.1),
            child: const Icon(
              Icons.person_outline,
              color: BrandColors.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.black,
                  ),
                ),
                Text(
                  '$seatsReserved seat${seatsReserved != 1 ? 's' : ''} requested',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Approve button
          IconButton(
            onPressed: reservationId != null
                ? () => _approveReservation(context, reservationId)
                : null,
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Approve',
          ),
          // Reject button
          IconButton(
            onPressed: reservationId != null
                ? () => _rejectReservation(context, reservationId)
                : null,
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerActions(BuildContext context) {
    if (!_canCancelReservation) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _cancelReservation(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text(
          'Cancel Reservation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildHistoryMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: const Row(
        children: [
          Icon(Icons.history, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This ride is in the past. No actions available.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(BuildContext context) async {
    if (reservation == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation?'),
        content: const Text(
          'Are you sure you want to cancel your reservation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Reservation'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<ReservationProvider>();
      final success = await provider.cancelReservation(reservation!.id!);

      if (context.mounted) {
        Navigator.pop(context); // Close ticket sheet

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Reservation cancelled successfully'
                  : provider.errorMessage ?? 'Failed to cancel reservation',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveReservation(
    BuildContext context,
    int reservationId,
  ) async {
    final provider = context.read<ReservationProvider>();
    final success = await provider.approveReservation(reservationId);

    if (context.mounted) {
      Navigator.pop(context); // Close ticket sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Reservation approved'
                : provider.errorMessage ?? 'Failed to approve',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectReservation(
    BuildContext context,
    int reservationId,
  ) async {
    final provider = context.read<ReservationProvider>();
    final success = await provider.rejectReservation(reservationId);

    if (context.mounted) {
      Navigator.pop(context); // Close ticket sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Reservation rejected'
                : provider.errorMessage ?? 'Failed to reject',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

/// Show Ride Ticket as bottom sheet
void showRideTicketSheet(
  BuildContext context, {
  required Ride ride,
  Reservation? reservation,
  required bool isDriver,
  bool isHistory = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => RideTicketSheet(
      ride: ride,
      reservation: reservation,
      isDriver: isDriver,
      isHistory: isHistory,
    ),
  );
}
