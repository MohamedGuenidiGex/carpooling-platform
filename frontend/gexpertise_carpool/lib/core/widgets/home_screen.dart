import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gexpertise_carpool/features/auth/providers/auth_provider.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/widgets/trip_card.dart';
import 'package:gexpertise_carpool/features/reservations/providers/reservation_provider.dart';
import '../theme/brand_text_styles.dart';

/// Home Screen for GExpertise Carpool MVP
/// Displays contextual Trip Card if user has active ride, otherwise shows normal dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Ride? activeRide;
  bool isLoading = true;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    currentUserId = authProvider.user?.id;

    if (currentUserId != null) {
      await _fetchActiveRide(rideProvider, reservationProvider);
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchActiveRide(
    RideProvider rideProvider,
    ReservationProvider reservationProvider,
  ) async {
    try {
      if (currentUserId == null) {
        debugPrint(
          'HomeScreen: currentUserId is null, skipping active ride fetch',
        );
        return;
      }

      debugPrint('HomeScreen: Fetching active rides for user $currentUserId');
      final List<Ride> candidateRides = [];

      // STEP 1: Fetch rides where user is driver
      await rideProvider.getMyOfferedRides(currentUserId!);
      final offeredRides = rideProvider.myOfferedRides
          .where((ride) => _isRideActive(ride.status ?? ''))
          .toList();
      debugPrint(
        'HomeScreen: Found ${offeredRides.length} active offered rides',
      );
      candidateRides.addAll(offeredRides);

      // STEP 2: Fetch rides where user is passenger with confirmed reservation
      final confirmedReservations = await reservationProvider
          .getMyConfirmedReservationsWithRides(currentUserId!);
      debugPrint(
        'HomeScreen: Found ${confirmedReservations.length} confirmed reservations',
      );

      for (final reservation in confirmedReservations) {
        if (reservation.ride != null) {
          debugPrint(
            'HomeScreen: Reservation ${reservation.id} has ride ${reservation.ride!.id} with status ${reservation.ride!.status}',
          );
          if (_isRideActive(reservation.ride!.status ?? '')) {
            candidateRides.add(reservation.ride!);
            debugPrint(
              'HomeScreen: Added ride ${reservation.ride!.id} from reservation',
            );
          }
        }
      }

      // STEP 3: Filter for active rides and sort by nearest upcoming
      candidateRides.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      debugPrint(
        'HomeScreen: Total ${candidateRides.length} active rides found',
      );

      if (candidateRides.isNotEmpty) {
        debugPrint(
          'HomeScreen: Setting active ride to ${candidateRides.first.id}',
        );
        if (mounted) {
          setState(() => activeRide = candidateRides.first);
        }
      } else {
        debugPrint('HomeScreen: No active rides found');
      }
    } catch (e) {
      debugPrint('HomeScreen: Error fetching active ride: $e');
    }
  }

  bool _isRideActive(String status) {
    final lowerStatus = status.toLowerCase();
    return lowerStatus == 'scheduled' ||
        lowerStatus == 'active' ||
        lowerStatus == 'full' ||
        lowerStatus == 'driver_en_route' ||
        lowerStatus == 'arrived' ||
        lowerStatus == 'in_progress';
  }

  void _handleRideCompleted() {
    if (mounted) {
      setState(() => activeRide = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('GExpertise Carpool')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If user has active ride, show TripCard
    if (activeRide != null && currentUserId != null) {
      return Scaffold(
        body: TripCard(
          activeRide: activeRide!,
          currentUserId: currentUserId!,
          isDriver: activeRide!.driverId == currentUserId,
          onRideCompleted: _handleRideCompleted,
        ),
      );
    }

    // Otherwise show normal dashboard
    return Scaffold(
      appBar: AppBar(title: const Text('GExpertise Carpool')),
      body: Center(
        child: Text(
          'GExpertise Carpool MVP',
          style: BrandTextStyles.header1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
