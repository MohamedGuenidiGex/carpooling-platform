import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/osm_search_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/status_helpers.dart';
import '../../../core/widgets/gexpertise_drawer.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../features/notifications/screens/notifications_screen.dart';
import '../../../features/reservations/providers/reservation_provider.dart';
import '../models/ride_model.dart';
import '../providers/ride_provider.dart';
import '../widgets/trip_card.dart';
import 'find_ride_screen.dart';
import 'create_ride_screen.dart';

/// Search mode enum for unified search experience
enum SearchMode { none, passenger, driver }

/// Rides Screen - Map-First Home Dashboard with Unified Search
///
/// Uber/InDrive-style layout with map background, floating controls,
/// and a unified search-first experience for both Find and Offer rides.
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> with WidgetsBindingObserver {
  Timer? _notificationTimer;
  int _lastKnownCount = 0;
  final MapController _mapController = MapController();
  LatLng? _currentPosition;

  // Unified search state
  bool _isSearching = false;
  SearchMode _searchMode = SearchMode.none;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Active ride detection state
  Ride? _activeRide;
  int?
  _activeReservationId; // Passenger's reservation ID for boarding confirmation
  DateTime? _activeBoardingDeadline; // Boarding deadline for active reservation
  bool _sheetVisible = false;
  int? _currentUserId;
  final WebSocketService _wsService = WebSocketService();
  Timer? _rideCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer provider access to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNotificationPolling();
      _initActiveRideDetection();
    });
    _determinePosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _rideCheckTimer?.cancel();
    _wsService.removeAllListeners('ride_status_updated');
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshActiveRide();
    }
  }

  /// Initialize active ride detection: WebSocket + initial fetch + polling fallback
  void _initActiveRideDetection() {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.user?.id;

    if (_currentUserId == null) return;

    // Connect WebSocket and listen for ride status changes
    final token = authProvider.token;
    if (token != null) {
      _wsService.connect(token);
      _wsService.onRideStatusUpdate((data) {
        debugPrint('RidesScreen: Received ride_status_updated: $data');
        if (mounted) _refreshActiveRide();
      });
    }

    // Initial fetch
    _refreshActiveRide();

    // Polling fallback every 10 seconds
    _rideCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshActiveRide(),
    );
  }

  /// Lifecycle statuses that always qualify for display (expanded by default)
  static const _activeStatuses = {'driver_en_route', 'arrived', 'in_progress'};

  /// Terminal statuses that should never show the sheet
  static const _terminalStatuses = {'completed', 'cancelled', 'missed'};

  /// Check if a ride qualifies for the trip bottom sheet
  bool _isEligibleForSheet(Ride ride) {
    final status = ride.status?.toLowerCase() ?? '';
    final now = DateTime.now();

    // Never show completed or cancelled rides
    if (_terminalStatuses.contains(status)) return false;

    // Always show lifecycle rides (driver_en_route, arrived, in_progress)
    if (_activeStatuses.contains(status)) return true;

    // Show active/full rides (driver has accepted passengers)
    if (status == 'active' || status == 'full') return true;

    // Show scheduled rides only within 10 minutes of departure
    if (status == 'scheduled') {
      final minutesUntil = ride.departureTime.difference(now).inMinutes;
      return minutesUntil <= 10 && ride.departureTime.isAfter(now);
    }

    return false;
  }

  /// Priority sort: active states first, then scheduled, then by departure
  int _ridePriority(Ride a, Ride b) {
    final aStatus = a.status?.toLowerCase() ?? '';
    final bStatus = b.status?.toLowerCase() ?? '';
    final aActive = _activeStatuses.contains(aStatus);
    final bActive = _activeStatuses.contains(bStatus);

    // Active statuses take priority over scheduled
    if (aActive && !bActive) return -1;
    if (!aActive && bActive) return 1;

    // Within same tier, nearest departure first
    return a.departureTime.compareTo(b.departureTime);
  }

  /// Fetch and determine the active ride for the current user
  Future<void> _refreshActiveRide() async {
    if (!mounted || _currentUserId == null) return;

    final rideProvider = context.read<RideProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    try {
      final List<Ride> candidateRides = [];

      // 1. Driver rides — any ride not COMPLETED/CANCELLED
      await rideProvider.getMyOfferedRides(_currentUserId!);
      final driverRides = rideProvider.myOfferedRides
          .where((ride) => isRideStatusActive(ride.status))
          .toList();
      debugPrint('RidesScreen: Driver rides found: ${driverRides.length}');
      candidateRides.addAll(driverRides);

      // 2. Passenger rides — CONFIRMED reservation on active ride
      final confirmedReservations = await reservationProvider
          .getMyConfirmedReservationsWithRides(_currentUserId!);
      debugPrint(
        'RidesScreen: Confirmed reservations found: ${confirmedReservations.length}',
      );

      // Map ride IDs to reservation IDs and boarding deadlines for boarding confirmation
      final Map<int, int> rideToReservation = {};
      final Map<int, DateTime?> rideToBoardingDeadline = {};
      for (final reservation in confirmedReservations) {
        final ride = reservation.ride;
        if (ride != null && isRideStatusActive(ride.status)) {
          candidateRides.add(ride);
          if (ride.id != null && reservation.id != null) {
            rideToReservation[ride.id!] = reservation.id!;
            rideToBoardingDeadline[ride.id!] = reservation.boardingDeadline;
          }
        }
      }

      // 3. Filter by strict visibility rules
      final eligible = candidateRides.where(_isEligibleForSheet).toList();
      debugPrint(
        'RidesScreen: ${candidateRides.length} total candidates, ${eligible.length} eligible for sheet',
      );

      // 4. Sort by priority (active states first, then nearest departure)
      eligible.sort(_ridePriority);

      if (!mounted) return;

      if (eligible.isNotEmpty) {
        final selected = eligible.first;
        debugPrint(
          'RidesScreen: Active ride selected: ID=${selected.id}, status=${selected.status}',
        );
        _wsService.joinRide(selected.id!);
        final wasNull = _activeRide == null;
        setState(() {
          _activeRide = selected;
          _activeReservationId = selected.id != null
              ? rideToReservation[selected.id!]
              : null;
          _activeBoardingDeadline = selected.id != null
              ? rideToBoardingDeadline[selected.id!]
              : null;
        });
        // Trigger slide-up after frame if this is a new appearance
        if (wasNull) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _sheetVisible = true);
          });
        }
      } else {
        debugPrint('RidesScreen: No eligible rides for sheet');
        if (_activeRide != null) {
          setState(() {
            _activeRide = null;
            _sheetVisible = false;
          });
        }
      }
    } catch (e) {
      debugPrint('RidesScreen: Error fetching active ride: $e');
    }
  }

  void _handleRideCompleted() {
    if (mounted) {
      setState(() {
        _activeRide = null;
        _sheetVisible = false;
      });
    }
  }

  void _startNotificationPolling() {
    // Initial fetch
    _fetchNotifications();

    // Poll every 30 seconds
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchNotifications(),
    );
  }

  Future<void> _fetchNotifications() async {
    final provider = context.read<NotificationProvider>();
    await provider.fetchNotifications();

    final newCount = provider.unreadCount;

    // Check if there are new notifications
    if (newCount > _lastKnownCount && mounted) {
      _showNewNotificationSnackBar();
    }

    _lastKnownCount = newCount;
  }

  void _showNewNotificationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New Notification Received'),
        backgroundColor: BrandColors.primaryRed,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Determine the current position
  ///
  /// Checks permissions and gets the current position, then centers the map.
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied
      return;
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition();

    _onPositionDetermined(position);
  }

  void _onPositionDetermined(Position position) {
    if (!mounted) return;
    final newPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = newPosition;
    });
    // Immediately center map on user's position
    _mapController.move(newPosition, 15.0);
  }

  /// Center map on current location
  void _goToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15.0);
    } else {
      _determinePosition();
    }
  }

  /// Start searching as Passenger (Find a Ride)
  void _startPassengerSearch() {
    setState(() {
      _isSearching = true;
      _searchMode = SearchMode.passenger;
    });
    // Auto-open keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  /// Start searching as Driver (Offer a Ride)
  void _startDriverSearch() {
    setState(() {
      _isSearching = true;
      _searchMode = SearchMode.driver;
    });
    // Auto-open keyboard
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });
  }

  /// Cancel search and return to button mode
  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchMode = SearchMode.none;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  /// Handle location selection based on mode
  void _onLocationSelected(Map<String, dynamic> suggestion) {
    final String name = suggestion['display_name'] as String;
    final double lat = suggestion['lat'] as double;
    final double lon = suggestion['lon'] as double;

    // Navigate based on mode
    if (_searchMode == SearchMode.driver) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRideScreen(
            startName: name,
            startCoordinates: LatLng(lat, lon),
          ),
        ),
      ).then((_) => _cancelSearch());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FindRideScreen(
            startName: name,
            startCoordinates: LatLng(lat, lon),
          ),
        ),
      ).then((_) => _cancelSearch());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveRide = _activeRide != null && _currentUserId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _isSearching ? null : const GExpertiseDrawer(),
      body: Stack(
        children: [
          // Layer 1: Map Background (always visible)
          _MapBackground(
            mapController: _mapController,
            currentPosition: _currentPosition,
            showCenterPin: _isSearching,
            activeRide: _activeRide,
            isDriver:
                _activeRide != null && _activeRide!.driverId == _currentUserId,
            wsService: _wsService,
          ),

          // Layer 2: Menu Button (Top Left) - hidden in search mode
          if (!_isSearching) _MenuButton(),

          // Layer 3: Search Bar (Top) - only in search mode
          if (_isSearching)
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              currentPosition: _currentPosition,
              onLocationSelected: _onLocationSelected,
            ),

          // Layer 4: Current Location Button (Bottom Right, above panels)
          _CurrentLocationButton(
            onPressed: _goToCurrentLocation,
            bottomOffset: hasActiveRide ? 280 : 200,
          ),

          // Layer 5: Bottom action panel (always visible unless searching)
          if (!_isSearching)
            _BottomActionPanel(
              onFindRide: _startPassengerSearch,
              onOfferRide: _startDriverSearch,
            )
          else
            _CancelPanel(onCancel: _cancelSearch),

          // Layer 6: TripCard bottom sheet (above action panel when active)
          if (hasActiveRide)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160, // Above the action panel
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                offset: _sheetVisible ? Offset.zero : const Offset(0, 1),
                child: TripCard(
                  activeRide: _activeRide!,
                  currentUserId: _currentUserId!,
                  isDriver: _activeRide!.driverId == _currentUserId,
                  onRideCompleted: _handleRideCompleted,
                  reservationId: _activeReservationId,
                  boardingDeadline: _activeBoardingDeadline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Map Background with OpenStreetMap
///
/// Displays an interactive map using flutter_map with OpenStreetMap tiles.
/// For passengers, shows animated driver location marker during active rides.
class _MapBackground extends StatefulWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final bool showCenterPin;
  final Ride? activeRide;
  final bool isDriver;
  final WebSocketService wsService;

  const _MapBackground({
    required this.mapController,
    this.currentPosition,
    this.showCenterPin = false,
    this.activeRide,
    this.isDriver = false,
    required this.wsService,
  });

  @override
  State<_MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<_MapBackground>
    with SingleTickerProviderStateMixin {
  LatLng? _currentDriverPosition;
  LatLng? _targetDriverPosition;
  AnimationController? _animController;
  Animation<double>? _animation;
  bool _hasInitiallyFramed = false;

  @override
  void initState() {
    super.initState();
    // Defer listener setup until after first frame when WebSocket is connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupDriverLocationListener();
      }
    });
  }

  @override
  void dispose() {
    widget.wsService.off('driver_location_updated');
    _animController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset state when ride changes or completes
    if (oldWidget.activeRide?.id != widget.activeRide?.id) {
      _currentDriverPosition = null;
      _targetDriverPosition = null;
      _hasInitiallyFramed = false;
      _animController?.dispose();
      _animController = null;
    }

    // Clear driver marker when ride completes
    final oldStatus = oldWidget.activeRide?.status?.toLowerCase() ?? '';
    final newStatus = widget.activeRide?.status?.toLowerCase() ?? '';
    if ((oldStatus == 'driver_en_route' || oldStatus == 'in_progress') &&
        (newStatus == 'completed' || newStatus == 'cancelled')) {
      setState(() {
        _currentDriverPosition = null;
        _targetDriverPosition = null;
      });
    }
  }

  void _setupDriverLocationListener() {
    debugPrint(
      'RidesScreen: Setting up driver location listener, isDriver=${widget.isDriver}',
    );
    widget.wsService.on('driver_location_updated', (data) {
      debugPrint('RidesScreen: driver_location_updated event received: $data');
      if (!mounted) return;
      if (widget.isDriver) return; // Only passengers track driver
      if (widget.activeRide == null) return;

      final Map<String, dynamic> locationData = data as Map<String, dynamic>;
      final int rideId = locationData['ride_id'] as int;

      // Only process if it's for the current active ride
      if (rideId != widget.activeRide!.id) return;

      // Only process during active ride statuses
      final status = widget.activeRide!.status?.toLowerCase() ?? '';
      if (status != 'driver_en_route' && status != 'in_progress') return;

      final double lat = (locationData['lat'] as num).toDouble();
      final double lng = (locationData['lng'] as num).toDouble();
      final LatLng newPosition = LatLng(lat, lng);

      debugPrint(
        'RidesScreen: Processing driver location for ride $rideId: ($lat, $lng)',
      );

      setState(() {
        _targetDriverPosition = newPosition;

        if (_currentDriverPosition == null) {
          // First update - set immediately
          _currentDriverPosition = newPosition;

          // Frame camera to include driver, pickup, and destination
          if (!_hasInitiallyFramed && widget.activeRide != null) {
            _frameInitialView();
            _hasInitiallyFramed = true;
          }
        } else {
          // Animate from current to target
          _animateMarker();
        }
      });
    });
  }

  void _animateMarker() {
    if (_currentDriverPosition == null || _targetDriverPosition == null) return;

    _animController?.dispose();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOut),
    );

    final LatLng startPos = _currentDriverPosition!;
    final LatLng endPos = _targetDriverPosition!;

    _animController!.addListener(() {
      if (!mounted) return;

      final double t = _animation!.value;
      final double lat =
          startPos.latitude + (endPos.latitude - startPos.latitude) * t;
      final double lng =
          startPos.longitude + (endPos.longitude - startPos.longitude) * t;

      setState(() {
        _currentDriverPosition = LatLng(lat, lng);
      });
    });

    _animController!.forward();
  }

  void _frameInitialView() {
    if (widget.activeRide == null) return;

    final List<LatLng> points = [];

    // Add driver position
    if (_currentDriverPosition != null) {
      points.add(_currentDriverPosition!);
    }

    // Add pickup location if available
    if (widget.activeRide!.originLat != null &&
        widget.activeRide!.originLng != null) {
      points.add(
        LatLng(widget.activeRide!.originLat!, widget.activeRide!.originLng!),
      );
    }

    // Add destination if available
    if (widget.activeRide!.destinationLat != null &&
        widget.activeRide!.destinationLng != null) {
      points.add(
        LatLng(
          widget.activeRide!.destinationLat!,
          widget.activeRide!.destinationLng!,
        ),
      );
    }

    if (points.isEmpty) return;

    // Calculate bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding
    final double latPadding = (maxLat - minLat) * 0.2;
    final double lngPadding = (maxLng - minLng) * 0.2;

    final LatLng sw = LatLng(minLat - latPadding, minLng - lngPadding);
    final LatLng ne = LatLng(maxLat + latPadding, maxLng + lngPadding);

    // Fit bounds
    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw, ne),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use current position if available, otherwise fallback to Sfax coordinates
    final LatLng initialCenter =
        widget.currentPosition ?? const LatLng(34.7408, 10.7600);

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 15.0,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gexpertise.carpool',
        ),
        // Center pin marker when in search mode
        if (widget.showCenterPin)
          MarkerLayer(
            markers: [
              Marker(
                point: initialCenter,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        // Current location marker
        if (widget.currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.currentPosition!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        // Driver location marker (for passengers only)
        if (!widget.isDriver && _currentDriverPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentDriverPosition!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: BrandColors.primaryRed,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Menu Button (Top Left)
///
/// Hamburger menu button that opens the drawer.
class _MenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8),
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(Icons.menu, color: BrandColors.black, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Current Location Button (Bottom Right)
///
/// Floating action button to re-center the map on user's location.
class _CurrentLocationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double bottomOffset;

  const _CurrentLocationButton({
    required this.onPressed,
    this.bottomOffset = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: SafeArea(
        top: false,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.white,
          foregroundColor: BrandColors.primaryRed,
          elevation: 4,
          mini: true,
          shape: const CircleBorder(),
          child: const Icon(Icons.my_location, size: 24),
        ),
      ),
    );
  }
}

/// Bottom Action Panel (Positioned)
///
/// White panel pinned to bottom using Positioned widget.
class _BottomActionPanel extends StatelessWidget {
  final VoidCallback onFindRide;
  final VoidCallback onOfferRide;

  const _BottomActionPanel({
    required this.onFindRide,
    required this.onOfferRide,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),

                // Find a Ride Button
                _ActionButton(
                  label: 'FIND A RIDE',
                  icon: Icons.search,
                  onPressed: onFindRide,
                ),
                const SizedBox(height: 12),

                // Offer a Ride Button
                _ActionButton(
                  label: 'OFFER A RIDE',
                  icon: Icons.add_circle_outline,
                  onPressed: onOfferRide,
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search Bar Widget (Picker Mode)
///
/// TypeAheadField for searching places via OSM Nominatim.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LatLng? currentPosition;
  final Function(Map<String, dynamic>) onLocationSelected;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    this.currentPosition,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TypeAheadField<Map<String, dynamic>>(
            controller: controller,
            focusNode: focusNode,
            suggestionsCallback: (pattern) async {
              if (pattern.length < 2) {
                return <Map<String, dynamic>>[];
              }
              try {
                final results = await OsmSearchService.searchPlaces(
                  pattern,
                  currentLocation: currentPosition,
                );
                return results;
              } catch (e) {
                debugPrint('Search error: $e');
                return <Map<String, dynamic>>[];
              }
            },
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => controller.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: BrandColors.primaryRed,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              );
            },
            itemBuilder: (context, suggestion) {
              final isCurrentLocation =
                  suggestion['is_current_location'] == true;
              final displayName =
                  suggestion['display_name'] as String? ??
                  suggestion['name'] as String? ??
                  'Unknown location';
              return ListTile(
                leading: Icon(
                  isCurrentLocation ? Icons.my_location : Icons.location_on,
                  color: isCurrentLocation ? Colors.green : Colors.grey,
                ),
                title: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
            decorationBuilder: (context, child) {
              return Material(
                type: MaterialType.card,
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: child,
              );
            },
            onSelected: (suggestion) {
              onLocationSelected(suggestion);
            },
            emptyBuilder: (context) => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No locations found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            loadingBuilder: (context) => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorBuilder: (context, error) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancel Panel (Picker Mode)
///
/// Simple cancel button for the streamlined location picker.
class _CancelPanel extends StatelessWidget {
  final VoidCallback onCancel;

  const _CancelPanel({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),

                // Instructions
                const Text(
                  'Search and select your starting location',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Action Button Widget
///
/// Premium styled button for the floating panel.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isOutlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.primaryRed,
                side: const BorderSide(color: BrandColors.primaryRed, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22, color: Colors.white),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }
}
