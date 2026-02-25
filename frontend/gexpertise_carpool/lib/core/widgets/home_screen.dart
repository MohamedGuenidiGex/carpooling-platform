import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gexpertise_carpool/features/auth/providers/auth_provider.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/widgets/trip_card.dart';
import 'package:gexpertise_carpool/features/dashboard/screens/dashboard_screen.dart';
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

    currentUserId = authProvider.user?.id;

    if (currentUserId != null) {
      await _fetchActiveRide(rideProvider);
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchActiveRide(RideProvider rideProvider) async {
    try {
      if (currentUserId == null) return;

      // Fetch all rides for current user as driver
      await rideProvider.getMyOfferedRides(currentUserId!);

      // Filter for active rides
      final allRides = rideProvider.myOfferedRides;

      final activeRides = allRides
          .where((ride) => _isRideActive(ride.status ?? ''))
          .toList();

      // Sort by departure time and get nearest upcoming ride
      activeRides.sort((a, b) => a.departureTime.compareTo(b.departureTime));

      if (activeRides.isNotEmpty) {
        if (mounted) {
          setState(() => activeRide = activeRides.first);
        }
      }
    } catch (e) {
      debugPrint('Error fetching active ride: $e');
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
