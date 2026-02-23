import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../models/ride_model.dart';
import '../providers/ride_provider.dart';

/// Ride Details Screen
///
/// Premium screen showing full ride details and passenger requests.
/// For drivers: shows approve/reject buttons for pending reservations.
class RideDetailsScreen extends StatefulWidget {
  final int rideId;

  const RideDetailsScreen({super.key, required this.rideId});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRideDetails();
    });
  }

  Future<void> _loadRideDetails() async {
    await context.read<RideProvider>().getRideDetails(widget.rideId);
  }

  Future<void> _refreshData() async {
    await _loadRideDetails();
    final ride = context.read<RideProvider>().currentRide;
    if (ride != null) {
      // Refresh reservations for this ride
      final currentUserId = context.read<AuthProvider>().user?.id;
      if (currentUserId != null) {
        await context.read<ReservationProvider>().getMyReservations(
          currentUserId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ride Details',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: BrandColors.primaryRed,
        child: Consumer<RideProvider>(
          builder: (context, rideProvider, child) {
            if (rideProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: BrandColors.primaryRed),
              );
            }

            if (rideProvider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rideProvider.errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.primaryRed,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final ride = rideProvider.currentRide;
            if (ride == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_taxi_outlined,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ride not found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return _buildContent(context, ride);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Ride ride) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isDriver = currentUserId != null && ride.driverId == currentUserId;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ride Details Card
          _buildRideDetailsCard(ride),

          // Book Ride Button (only for non-drivers)
          if (!isDriver) ...[
            const SizedBox(height: 24),
            _buildBookRideButton(context, ride),
          ],

          // Passenger Requests Section (only for driver)
          if (isDriver) ...[
            const SizedBox(height: 24),
            _buildPassengerRequestsSection(ride),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRideDetailsCard(Ride ride) {
    return Container(
      margin: const EdgeInsets.all(24),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: BrandColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    color: BrandColors.primaryRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride #${ride.id}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ride.origin} → ${ride.destination}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: BrandColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Details Grid
            _buildDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: _formatDate(ride.departureTime),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.access_time_outlined,
              label: 'Time',
              value: _formatTime(ride.departureTime),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.person_outline,
              label: 'Available Seats',
              value: '${ride.availableSeats} seats',
              valueColor: ride.availableSeats > 0
                  ? Colors.green[700]
                  : Colors.red[700],
            ),
            if (ride.comments != null && ride.comments!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: ride.comments!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[500]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? BrandColors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookRideButton(BuildContext context, Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Consumer<ReservationProvider>(
        builder: (context, provider, child) {
          final isBooking = provider.isBooking;

          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ride.availableSeats > 0 && !isBooking
                  ? () => _handleBookRide(context, ride)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isBooking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.event_seat),
              label: Text(
                ride.availableSeats > 0 ? 'Request Seat' : 'No Seats Available',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleBookRide(BuildContext context, Ride ride) async {
    final success = await context.read<ReservationProvider>().bookRide(
      ride.id!,
    );

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Seat requested! Waiting for driver approval.'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        // Refresh ride details to show updated state
        _loadRideDetails();
      }
    } else {
      if (context.mounted) {
        final error =
            context.read<ReservationProvider>().errorMessage ??
            'Failed to request seat';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: BrandColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildPassengerRequestsSection(Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passenger Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: BrandColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final rideReservations = ride.reservations ?? <Reservation>[];

              if (rideReservations.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[500]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No passenger requests yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rideReservations.length,
                itemBuilder: (context, index) {
                  final reservation = rideReservations[index];
                  return _PassengerRequestCard(
                    reservation: reservation,
                    onActionCompleted: _refreshData,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Passenger Request Card
///
/// Shows a passenger's reservation request with approve/reject actions.
class _PassengerRequestCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onActionCompleted;

  const _PassengerRequestCard({
    required this.reservation,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = reservation.isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.passengerName ?? 'Unknown Passenger',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reservation.seatsReserved} seat${reservation.seatsReserved != 1 ? 's' : ''} · ${reservation.displayStatus}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Action Buttons (only for pending)
          if (isPending) ...[
            _buildActionButtons(context),
          ] else ...[
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                reservation.displayStatus,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reject button
        _buildActionButton(
          context: context,
          icon: Icons.close,
          color: Colors.red,
          onTap: () => _handleReject(context),
        ),
        const SizedBox(width: 8),
        // Approve button
        _buildActionButton(
          context: context,
          icon: Icons.check,
          color: Colors.green,
          onTap: () => _handleApprove(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Consumer<ReservationProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isUpdatingReservation;

        return Material(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    final success = await context
        .read<ReservationProvider>()
        .approveReservation(reservation.id!);

    if (success) {
      onActionCompleted?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reservation approved'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      if (context.mounted) {
        final error =
            context.read<ReservationProvider>().errorMessage ??
            'Failed to approve';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: BrandColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    final success = await context.read<ReservationProvider>().rejectReservation(
      reservation.id!,
    );

    if (success) {
      onActionCompleted?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reservation rejected'),
            backgroundColor: Colors.orange[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      if (context.mounted) {
        final error =
            context.read<ReservationProvider>().errorMessage ??
            'Failed to reject';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: BrandColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Color _getStatusColor() {
    switch (reservation.status?.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.green;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
}
