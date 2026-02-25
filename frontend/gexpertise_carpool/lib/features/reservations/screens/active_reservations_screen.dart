import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../rides/models/ride_model.dart';
import '../../rides/providers/ride_provider.dart';
import '../../rides/screens/ride_details_screen.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../reservations/widgets/reservation_card.dart';

/// Active Reservations Screen
///
/// Shows actionable items:
/// - To Approve: Rides offered by current user with pending reservations (Driver view)
/// - Upcoming: User's pending/approved reservations (Passenger view)
class ActiveReservationsScreen extends StatefulWidget {
  const ActiveReservationsScreen({super.key});

  @override
  State<ActiveReservationsScreen> createState() =>
      _ActiveReservationsScreenState();
}

class _ActiveReservationsScreenState extends State<ActiveReservationsScreen>
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
      // Load data for both tabs
      context.read<RideProvider>().getMyOfferedRides(userId);
      context.read<ReservationProvider>().getMyReservations(
        userId,
        includeRide: true,
      );
    }
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;

    if (userId != null) {
      await Future.wait([
        context.read<RideProvider>().getMyOfferedRides(userId),
        context.read<ReservationProvider>().getMyReservations(
          userId,
          includeRide: true,
        ),
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
          title: const Text(
            'Reservations',
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
              Tab(text: 'To Approve'),
              Tab(text: 'Upcoming'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ToApproveTab(onRefresh: _refreshData),
            _UpcomingTab(onRefresh: _refreshData),
          ],
        ),
      ),
    );
  }
}

/// To Approve Tab (Driver View)
///
/// Shows rides offered by current user that have pending reservations.
class _ToApproveTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _ToApproveTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer2<RideProvider, ReservationProvider>(
      builder: (context, rideProvider, reservationProvider, child) {
        if (rideProvider.isLoading ||
            reservationProvider.isLoadingReservations) {
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

        // Get rides with pending reservations
        final ridesWithPending = _getRidesWithPendingReservations(
          rideProvider.myOfferedRides,
          reservationProvider.myReservations,
        );

        if (ridesWithPending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have no rides with pending reservations',
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
            itemCount: ridesWithPending.length,
            itemBuilder: (context, index) {
              final ride = ridesWithPending[index];
              final pendingCount = _getPendingCount(
                ride,
                reservationProvider.myReservations,
              );
              return _PendingRideCard(
                ride: ride,
                pendingCount: pendingCount,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RideDetailsScreen(rideId: ride.id!),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Ride> _getRidesWithPendingReservations(
    List<Ride> offeredRides,
    List<Reservation> reservations,
  ) {
    return offeredRides.where((ride) {
      return reservations.any((r) => r.rideId == ride.id && r.isPending);
    }).toList();
  }

  int _getPendingCount(Ride ride, List<Reservation> reservations) {
    return reservations.where((r) => r.rideId == ride.id && r.isPending).length;
  }
}

/// Pending Ride Card
///
/// Shows ride details with pending request badge.
class _PendingRideCard extends StatelessWidget {
  final Ride ride;
  final int pendingCount;
  final VoidCallback onTap;

  const _PendingRideCard({
    required this.ride,
    required this.pendingCount,
    required this.onTap,
  });

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
        child: Column(
          children: [
            // Pending Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_actions,
                    size: 18,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pendingCount Pending Request${pendingCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange[700],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.orange[700],
                  ),
                ],
              ),
            ),
            // Ride Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: BrandColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ride.origin,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ride.destination,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Info row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(ride.departureTime),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time_outlined,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(ride.departureTime),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.event_seat_outlined,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${ride.availableSeats} seats',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// Upcoming Tab (Passenger View)
///
/// Shows user's pending/approved reservations.
class _UpcomingTab extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _UpcomingTab({required this.onRefresh});

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

        // Filter for active reservations (pending or confirmed)
        final activeReservations = provider.myReservations
            .where((r) => r.isPending || r.isConfirmed)
            .toList();

        if (activeReservations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No upcoming rides',
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
            itemCount: activeReservations.length,
            itemBuilder: (context, index) {
              final reservation = activeReservations[index];
              return ReservationCard(
                reservation: reservation,
                onCancelled: onRefresh,
              );
            },
          ),
        );
      },
    );
  }
}

/// Consumer2 helper widget
class Consumer2<A extends ChangeNotifier, B extends ChangeNotifier>
    extends StatelessWidget {
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const Consumer2({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Consumer<A>(
      builder: (context, a, child) {
        return Consumer<B>(
          builder: (context, b, _) {
            return builder(context, a, b, child);
          },
        );
      },
    );
  }
}
