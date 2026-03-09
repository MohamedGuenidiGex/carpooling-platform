import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gexpertise_carpool/features/auth/providers/auth_provider.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/widgets/trip_card.dart';
import 'package:gexpertise_carpool/features/reservations/providers/reservation_provider.dart';
import 'package:gexpertise_carpool/core/services/websocket_service.dart';
import 'package:gexpertise_carpool/core/utils/status_helpers.dart';
import '../theme/brand_text_styles.dart';

/// Home Screen for GExpertise Carpool MVP
/// Displays contextual Trip Card if user has active ride, otherwise shows normal dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Ride? activeRide;
  bool isLoading = true;
  int? currentUserId;
  final WebSocketService _wsService = WebSocketService();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _wsService.removeAllListeners('ride_status_updated');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshActiveRide();
    }
  }

  void _initializeScreen() async {
    final authProvider = context.read<AuthProvider>();
    currentUserId = authProvider.user?.id;

    if (currentUserId != null) {
      // Connect WebSocket
      final token = authProvider.token;
      if (token != null) {
        _wsService.connect(token);
        _setupWebSocketListener();
      }

      await _refreshActiveRide();

      // Start periodic polling as fallback (every 10 seconds)
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _refreshActiveRide();
      });
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _setupWebSocketListener() {
    _wsService.onRideStatusUpdate((data) {
      debugPrint('HomeScreen: Received ride_status_updated: $data');
      if (!mounted) return;
      _refreshActiveRide();
    });
  }

  Future<void> _refreshActiveRide() async {
    if (!mounted || currentUserId == null) return;

    final rideProvider = context.read<RideProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    try {
      final List<Ride> candidateRides = [];

      // 1. Driver rides — any ride not COMPLETED/CANCELLED
      await rideProvider.getMyOfferedRides(currentUserId!);
      final driverRides = rideProvider.myOfferedRides
          .where((ride) => isRideStatusActive(ride.status))
          .toList();
      debugPrint('HomeScreen: Driver rides found: ${driverRides.length}');
      candidateRides.addAll(driverRides);

      // 2. Passenger rides — CONFIRMED reservation on active ride
      final confirmedReservations = await reservationProvider
          .getMyConfirmedReservationsWithRides(currentUserId!);
      debugPrint(
        'HomeScreen: Confirmed reservations found: ${confirmedReservations.length}',
      );

      for (final reservation in confirmedReservations) {
        final ride = reservation.ride;
        if (ride != null && isRideStatusActive(ride.status)) {
          candidateRides.add(ride);
        }
      }

      // 3. Pick nearest by departure time
      candidateRides.sort((a, b) => a.departureTime.compareTo(b.departureTime));

      if (!mounted) return;

      if (candidateRides.isNotEmpty) {
        final selected = candidateRides.first;
        debugPrint(
          'HomeScreen: Active ride selected: ID=${selected.id}, status=${selected.status}',
        );
        _wsService.joinRide(selected.id!);
        setState(() => activeRide = selected);
      } else {
        debugPrint('HomeScreen: No active rides found');
        if (activeRide != null) {
          setState(() => activeRide = null);
        }
      }
    } catch (e) {
      debugPrint('HomeScreen: Error fetching active ride: $e');
    }
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
          onTogglePlanMode: () {}, // Not used in legacy home screen
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
