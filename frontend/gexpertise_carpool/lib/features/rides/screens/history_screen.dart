import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/rides/models/ride_model.dart';
import '../../../features/rides/providers/ride_provider.dart';
import '../../../features/rides/screens/ride_details_screen.dart';
import '../../../features/rides/widgets/ride_card.dart';
import '../../../features/rides/widgets/ride_ticket_sheet.dart';
import '../../../features/reservations/providers/reservation_provider.dart';

/// History Screen - My Rides & Bookings
///
/// Displays user's activity in two tabs:
/// - Offered Rides: Rides the user has created as a driver
/// - Booked Rides: Reservations the user has made as a passenger
///
/// Smart read-only logic:
/// - Past rides or rides with status Completed/Cancelled/Rejected are read-only
/// - Upcoming rides with Pending/Approved status show action buttons
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      context.read<RideProvider>().getMyOfferedRides(userId);
      context.read<ReservationProvider>().getMyReservations(userId);
    }
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      await Future.wait([
        context.read<RideProvider>().getMyOfferedRides(userId),
        context.read<ReservationProvider>().getMyReservations(userId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: BrandColors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'My Rides',
            style: TextStyle(
              color: BrandColors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: BrandColors.primaryRed,
            indicatorWeight: 3.0,
            labelColor: BrandColors.primaryRed,
            unselectedLabelColor: Colors.grey[500],
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Offered Rides'),
              Tab(text: 'Booked Rides'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _OfferedRidesTab(
              onRefresh: _refreshData,
              currentUserId: context.read<AuthProvider>().user?.id,
            ),
            _BookedRidesTab(
              onRefresh: _refreshData,
              currentUserId: context.read<AuthProvider>().user?.id,
            ),
          ],
        ),
      ),
    );
  }
}

/// Offered Rides Tab
///
/// Displays rides created by the current user.
class _OfferedRidesTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final int? currentUserId;

  const _OfferedRidesTab({required this.onRefresh, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<RideProvider, ReservationProvider>(
      builder: (context, rideProvider, reservationProvider, child) {
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
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  rideProvider.errorMessage!,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primaryRed,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (rideProvider.myOfferedRides.isEmpty) {
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
                  'No rides offered yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a ride to see it here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: BrandColors.primaryRed,
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: rideProvider.myOfferedRides.length,
            itemBuilder: (context, index) {
              final ride = rideProvider.myOfferedRides[index];
              final isScheduled =
                  ride.status?.toUpperCase() == 'ACTIVE' ||
                  ride.status?.toUpperCase() == 'FULL';

              return Column(
                children: [
                  RideCard(
                    ride: ride,
                    onTap: () {
                      // Navigate to RideDetailsScreen for drivers to see pending requests
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RideDetailsScreen(rideId: ride.id!),
                        ),
                      );
                    },
                  ),
                  if (isScheduled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _cancelRide(context, rideProvider, ride),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red[700],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel Ride'),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ride.status ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _cancelRide(BuildContext context, RideProvider rideProvider, Ride ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: Text(
          'Are you sure you want to cancel this ride to ${ride.destination}? '
          'All passengers will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Ride'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await rideProvider.cancelRide(ride.id!);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ride cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        rideProvider.errorMessage ?? 'Failed to cancel ride',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }
}

/// Booked Rides Tab
///
/// Displays reservations made by the current user.
class _BookedRidesTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final int? currentUserId;

  const _BookedRidesTab({required this.onRefresh, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReservationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingReservations) {
          return const Center(
            child: CircularProgressIndicator(color: BrandColors.primaryRed),
          );
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primaryRed,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.myReservations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookings yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Book a ride to see it here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: BrandColors.primaryRed,
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: provider.myReservations.length,
            itemBuilder: (context, index) {
              final reservation = provider.myReservations[index];
              final isReadOnly =
                  reservation.isCancelled || reservation.isRejected;
              final ride = reservation.ride;

              // If ride data is available, show the ride card
              if (ride != null) {
                return RideCard(
                  ride: ride,
                  onTap: () {
                    showRideTicketSheet(
                      context,
                      ride: ride,
                      isDriver: false,
                      isHistory: isReadOnly,
                      reservation: reservation,
                    );
                  },
                );
              }

              // Fallback: show reservation card without ride details
              return _buildReservationCard(context, reservation, isReadOnly);
            },
          ),
        );
      },
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    reservation,
    bool isReadOnly,
  ) {
    Color statusColor;
    switch (reservation.status.toUpperCase()) {
      case 'PENDING':
        statusColor = Colors.orange;
      case 'CONFIRMED':
        statusColor = Colors.green;
      case 'CANCELLED':
        statusColor = Colors.red;
      case 'REJECTED':
        statusColor = Colors.grey;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reservation.displayStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Ride #${reservation.rideId}',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.event_seat_outlined,
                color: BrandColors.primaryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${reservation.seatsReserved} seat${reservation.seatsReserved != 1 ? 's' : ''} requested',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isReadOnly)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _cancelReservation(context, reservation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(BuildContext context, reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation?'),
        content: const Text(
          'Are you sure you want to cancel your reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
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
      final success = await provider.cancelReservation(reservation.id!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Reservation cancelled'
                  : provider.errorMessage ?? 'Failed to cancel',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}
