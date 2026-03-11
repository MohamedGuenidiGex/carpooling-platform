import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/osm_search_service.dart';
import '../../../core/services/location_search_service.dart';
import '../../../core/services/route_service.dart';
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
import '../widgets/driver_info_tooltip.dart';
import 'find_ride_screen.dart';
import 'create_ride_screen.dart';

/// Search mode enum for unified search experience
enum SearchMode { none, passenger, driver }

/// View mode enum for ride screen when active ride exists
enum ViewMode { currentRide, planNextRide }

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
  String? _userCountryCode; // 'tn' or 'fr', detected from GPS

  // Selected location state (for new permanent search flow)
  LatLng? _selectedLocation;
  String? _selectedLocationName;
  final TextEditingController _locationSearchController =
      TextEditingController();
  final FocusNode _locationSearchFocusNode = FocusNode();

  // Active ride detection state
  Ride? _activeRide;
  int?
  _activeReservationId; // Passenger's reservation ID for boarding confirmation
  DateTime? _activeBoardingDeadline; // Boarding deadline for active reservation
  bool _sheetVisible = false;
  int? _currentUserId;
  final WebSocketService _wsService = WebSocketService();
  Timer? _rideCheckTimer;

  // View mode state (only relevant when active ride exists)
  ViewMode _viewMode = ViewMode.currentRide;

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
    _locationSearchController.dispose();
    _locationSearchFocusNode.dispose();
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

  /// Toggle between Current Ride and Plan Next Ride modes
  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ViewMode.currentRide
          ? ViewMode.planNextRide
          : ViewMode.currentRide;
    });
  }

  /// Handle ride completion - dismiss sheet and refresh
  void _handleRideCompleted() {
    setState(() {
      _activeRide = null;
      _activeReservationId = null;
      _activeBoardingDeadline = null;
      _sheetVisible = false;
      _viewMode = ViewMode.currentRide; // Reset to default mode
    });
    _refreshActiveRide(); // Fetch latest state
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

    // Detect country from GPS coordinates
    _detectUserCountry(newPosition);
  }

  /// Detect user's country from GPS coordinates and cache it
  Future<void> _detectUserCountry(LatLng coordinates) async {
    try {
      final countryCode = await OsmSearchService.detectCountryCode(coordinates);
      if (mounted && countryCode != null) {
        setState(() {
          _userCountryCode = countryCode;
        });
        debugPrint('RidesScreen: Detected user country: $countryCode');
      }
    } catch (e) {
      debugPrint('RidesScreen: Failed to detect country: $e');
      // Keep default (null = will default to 'tn' in search)
    }
  }

  /// Center map on current location
  void _goToCurrentLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15.0);
    } else {
      _determinePosition();
    }
  }

  /// Handle map tap to select location
  void _onMapTapped(LatLng coordinates) {
    setState(() {
      _selectedLocation = coordinates;
    });

    // Animate map to the tapped point
    _mapController.move(coordinates, _mapController.camera.zoom);

    // Reverse geocode to get address
    try {
      OsmSearchService.getAddressFromCoordinates(coordinates).then((address) {
        if (mounted) {
          setState(() {
            _selectedLocationName = address;
            _locationSearchController.text = address;
          });
        }
      });
    } catch (e) {
      // Fallback to coordinates
      if (mounted) {
        setState(() {
          _selectedLocationName =
              '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  /// Get the effective start location (selected location or current position)
  LatLng? _getEffectiveStartLocation() {
    return _selectedLocation ?? _currentPosition;
  }

  /// Get the effective start address (selected location name or "Current Location")
  String _getEffectiveStartAddress() {
    return _selectedLocationName ?? 'Current Location';
  }

  /// Start searching as Passenger (Find a Ride)
  void _startPassengerSearch() {
    final startLocation = _getEffectiveStartLocation();
    final startAddress = _getEffectiveStartAddress();

    // If a location is selected (or current position available), navigate directly
    if (startLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FindRideScreen(
            startName: startAddress,
            startCoordinates: startLocation,
          ),
        ),
      );
      return;
    }

    // Otherwise, show a snackbar prompting user to select a location
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please search and select a location first'),
        backgroundColor: BrandColors.primaryRed,
      ),
    );
  }

  /// Start searching as Driver (Offer a Ride)
  void _startDriverSearch() {
    final startLocation = _getEffectiveStartLocation();
    final startAddress = _getEffectiveStartAddress();

    // If a location is selected (or current position available), navigate directly
    if (startLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRideScreen(
            startName: startAddress,
            startCoordinates: startLocation,
          ),
        ),
      );
      return;
    }

    // Otherwise, show a snackbar prompting user to select a location
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please search and select a location first'),
        backgroundColor: BrandColors.primaryRed,
      ),
    );
  }

  /// Handle location selection from search
  void _onLocationSelected(Map<String, dynamic> suggestion) {
    final bool isCurrentLocation = suggestion['is_current_location'] == true;

    // Handle "Use Current Location" - retrieve fresh GPS and reverse geocode
    if (isCurrentLocation) {
      _handleUseCurrentLocation();
      return;
    }

    // Regular location selection
    final String name = suggestion['display_name'] as String;
    final double lat = suggestion['lat'] as double;
    final double lon = suggestion['lon'] as double;
    final coordinates = LatLng(lat, lon);

    setState(() {
      _selectedLocation = coordinates;
      _selectedLocationName = name;
      _locationSearchController.text = name;
    });

    // Animate map to selected location
    _mapController.move(coordinates, 15.0);
  }

  /// Handle "Use Current Location" selection
  Future<void> _handleUseCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please enable location services.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get fresh GPS location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = position.latitude;
      final lon = position.longitude;
      final coordinates = LatLng(lat, lon);

      // Reverse geocode to get readable address
      final address = await OsmSearchService.getAddressFromCoordinates(
        coordinates,
      );

      // Remove loading indicator
      Navigator.of(context).pop();

      setState(() {
        _selectedLocation = coordinates;
        _selectedLocationName = address;
        _locationSearchController.text = address;
      });

      // Animate map to current location
      _mapController.move(coordinates, 15.0);
    } catch (e) {
      // Remove loading indicator if still showing
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get current location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveRide = _activeRide != null && _currentUserId != null;
    final bool showCurrentRideMode =
        hasActiveRide && _viewMode == ViewMode.currentRide;
    final bool showPlanNextRideMode =
        hasActiveRide && _viewMode == ViewMode.planNextRide;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const GExpertiseDrawer(),
      body: Stack(
        children: [
          // Layer 1: Map Background (base layer)
          _MapBackground(
            mapController: _mapController,
            currentPosition: _currentPosition,
            showCenterPin: false,
            activeRide: _activeRide,
            isDriver:
                _activeRide != null && _activeRide!.driverId == _currentUserId,
            wsService: _wsService,
            onTap: _onMapTapped,
            selectedLocation: _selectedLocation,
          ),

          // Layer 2: Bottom sheets (above map)
          // 2a: Bottom action panel (visible when NO active ride OR in Plan Next Ride mode)
          if (!hasActiveRide || showPlanNextRideMode)
            _BottomActionPanel(
              onFindRide: _startPassengerSearch,
              onOfferRide: _startDriverSearch,
              activeRide: showPlanNextRideMode ? _activeRide : null,
              isDriver:
                  showPlanNextRideMode &&
                  _activeRide!.driverId == _currentUserId,
              onToggleMode: hasActiveRide ? _toggleViewMode : null,
            ),

          // 2b: TripCard bottom sheet (visible in Current Ride mode)
          if (showCurrentRideMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                  onTogglePlanMode: _toggleViewMode,
                ),
              ),
            ),

          // Layer 3: Current Location Button (elevated above bottom panel)
          // Positioned just above bottom panel with minimal clearance
          _CurrentLocationButton(
            onPressed: _goToCurrentLocation,
            bottomOffset: hasActiveRide ? 350 : 200,
          ),

          // Layer 5: Search Bar (always visible at top)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _IntegratedSearchBar(
                controller: _locationSearchController,
                focusNode: _locationSearchFocusNode,
                currentPosition: _currentPosition,
                userCountryCode: _userCountryCode,
                onLocationSelected: _onLocationSelected,
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
/// Supports tap-to-select location when not in search mode.
class _MapBackground extends StatefulWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final bool showCenterPin;
  final Ride? activeRide;
  final bool isDriver;
  final WebSocketService wsService;
  final Function(LatLng)? onTap;
  final LatLng? selectedLocation;

  const _MapBackground({
    required this.mapController,
    this.currentPosition,
    this.showCenterPin = false,
    this.activeRide,
    this.isDriver = false,
    required this.wsService,
    this.onTap,
    this.selectedLocation,
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

  // Driver info panel state
  bool _showDriverInfo = false;

  // ETA calculation
  String? _currentETA;
  final DebouncedRouteCalculator _etaCalculator = DebouncedRouteCalculator();

  // Route visualization state
  List<LatLng> _routePoints = [];
  final DebouncedRouteCalculator _routeCalculator = DebouncedRouteCalculator();

  // Named callback reference so dispose only removes this widget's listener
  Function(dynamic)? _locationUpdateCallback;

  @override
  void initState() {
    super.initState();
    // Initialize driver position for passengers
    _initializeDriverPosition();
    // Defer listener setup until after first frame when WebSocket is connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupDriverLocationListener();
        // For drivers, calculate route immediately since own GPS is available
        if (widget.isDriver && widget.currentPosition != null) {
          _calculateRouteForActiveRide();
        }
      }
    });
  }

  /// Initialize driver position for passengers
  /// Driver position will be set by WebSocket updates only
  void _initializeDriverPosition() {
    // Only for passengers with active rides
    if (widget.isDriver || widget.activeRide == null) return;

    final status = widget.activeRide!.status?.toLowerCase() ?? '';
    final isActiveStatus =
        status == 'driver_en_route' || status == 'in_progress';

    if (!isActiveStatus) return;

    // Driver position will be set when first WebSocket update arrives
    // Do not use ride origin as fallback - it's the pickup location, not driver location
    debugPrint(
      'RidesScreen: Waiting for driver location updates via WebSocket for ride ${widget.activeRide!.id}',
    );
  }

  @override
  void dispose() {
    if (_locationUpdateCallback != null) {
      widget.wsService.off('driver_location_updated', _locationUpdateCallback!);
    }
    _animController?.dispose();
    super.dispose();
  }

  /// Calculate ETA based on current ride status
  Future<void> _updateETA() async {
    if (_currentDriverPosition == null || widget.activeRide == null) return;

    final status = widget.activeRide!.status?.toLowerCase() ?? '';
    LatLng? destination;

    // Determine destination based on ride status
    if (status == 'driver_en_route') {
      // ETA to pickup (origin)
      if (widget.activeRide!.originLat != null &&
          widget.activeRide!.originLng != null) {
        destination = LatLng(
          widget.activeRide!.originLat!,
          widget.activeRide!.originLng!,
        );
      }
    } else if (status == 'in_progress') {
      // ETA to destination
      if (widget.activeRide!.destinationLat != null &&
          widget.activeRide!.destinationLng != null) {
        destination = LatLng(
          widget.activeRide!.destinationLat!,
          widget.activeRide!.destinationLng!,
        );
      }
    } else {
      // No ETA for other statuses
      setState(() => _currentETA = null);
      return;
    }

    if (destination == null) return;

    // Use debounced calculator to prevent excessive API calls
    final result = await _etaCalculator.calculateIfNeeded(
      _currentDriverPosition!,
      destination,
    );

    if (result != null && mounted) {
      setState(() {
        _currentETA = result.formattedDuration;
      });
    }
  }

  /// Force ETA update (for initial load)
  Future<void> _forceETAUpdate() async {
    if (_currentDriverPosition == null || widget.activeRide == null) return;

    final status = widget.activeRide!.status?.toLowerCase() ?? '';
    LatLng? destination;

    if (status == 'driver_en_route') {
      if (widget.activeRide!.originLat != null &&
          widget.activeRide!.originLng != null) {
        destination = LatLng(
          widget.activeRide!.originLat!,
          widget.activeRide!.originLng!,
        );
      }
    } else if (status == 'in_progress') {
      if (widget.activeRide!.destinationLat != null &&
          widget.activeRide!.destinationLng != null) {
        destination = LatLng(
          widget.activeRide!.destinationLat!,
          widget.activeRide!.destinationLng!,
        );
      }
    }

    if (destination == null) return;

    final result = await _etaCalculator.forceCalculate(
      _currentDriverPosition!,
      destination,
    );

    if (result != null && mounted) {
      setState(() {
        _currentETA = result.formattedDuration;
      });
    }
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

      // Initialize position and route for new ride
      _initializeDriverPosition();
      _calculateRouteForActiveRide();
    }

    // Recalculate route if ride status changes
    final oldStatus = oldWidget.activeRide?.status?.toLowerCase() ?? '';
    final newStatus = widget.activeRide?.status?.toLowerCase() ?? '';
    if (oldStatus != newStatus) {
      _calculateRouteForActiveRide();
    }

    // For drivers: recalculate route when own GPS position changes
    if (widget.isDriver &&
        widget.currentPosition != oldWidget.currentPosition) {
      _calculateRouteForActiveRide();
    }

    // Clear driver position and route when ride completes
    if ((oldStatus == 'driver_en_route' || oldStatus == 'in_progress') &&
        (newStatus == 'completed' || newStatus == 'cancelled')) {
      setState(() {
        _currentDriverPosition = null;
        _targetDriverPosition = null;
        _routePoints = [];
      });
    }
  }

  void _setupDriverLocationListener() {
    debugPrint(
      'RidesScreen: Setting up driver location listener, isDriver=${widget.isDriver}',
    );
    debugPrint('RidesScreen: Active ride ID: ${widget.activeRide?.id}');
    debugPrint('RidesScreen: Active ride status: ${widget.activeRide?.status}');
    debugPrint(
      'RidesScreen: WebSocket connected: ${widget.wsService.isConnected}',
    );

    _locationUpdateCallback = (data) {
      debugPrint('RidesScreen: driver_location_updated event received');
      debugPrint('RidesScreen: Event data type: ${data.runtimeType}');
      debugPrint('RidesScreen: Event data: $data');

      if (!mounted) {
        debugPrint('RidesScreen: Widget not mounted, ignoring event');
        return;
      }

      if (widget.isDriver) {
        debugPrint('RidesScreen: User is driver, ignoring event');
        return;
      }

      if (widget.activeRide == null) {
        debugPrint('RidesScreen: No active ride, ignoring event');
        return;
      }

      try {
        final Map<String, dynamic> locationData = data as Map<String, dynamic>;
        final int rideId = locationData['ride_id'] as int;

        debugPrint(
          'RidesScreen: Event for ride $rideId, current ride ${widget.activeRide!.id}',
        );

        // Only process if it's for the current active ride
        if (rideId != widget.activeRide!.id) {
          debugPrint('RidesScreen: Event for different ride, ignoring');
          return;
        }

        // Only process during active ride statuses
        final status = widget.activeRide!.status?.toLowerCase() ?? '';
        debugPrint('RidesScreen: Current ride status: $status');

        if (status != 'driver_en_route' && status != 'in_progress') {
          debugPrint('RidesScreen: Ride not in active status, ignoring');
          return;
        }

        final double lat = (locationData['lat'] as num).toDouble();
        final double lng = (locationData['lng'] as num).toDouble();
        final LatLng newPosition = LatLng(lat, lng);

        debugPrint(
          'RidesScreen: ✅ Processing driver location for ride $rideId: ($lat, $lng)',
        );

        setState(() {
          _targetDriverPosition = newPosition;

          if (_currentDriverPosition == null) {
            // First update - set immediately
            debugPrint(
              'RidesScreen: First driver position received, setting immediately',
            );
            _currentDriverPosition = newPosition;
          } else {
            // Animate from current to target
            debugPrint('RidesScreen: Updating driver position with animation');
            _animateMarker();
          }
        });

        // Update route when driver position changes
        _calculateRouteForActiveRide().then((_) {
          // Frame camera after route is calculated on first update
          if (!_hasInitiallyFramed &&
              widget.activeRide != null &&
              _currentDriverPosition != null) {
            debugPrint('RidesScreen: Framing camera to show route');
            _fitCameraToRoute();
            _hasInitiallyFramed = true;
          }
        });

        // Update ETA with debouncing (5 second interval)
        _updateETA();
      } catch (e) {
        debugPrint('RidesScreen: Error processing driver location update: $e');
      }
    };
    widget.wsService.on('driver_location_updated', _locationUpdateCallback!);

    // Set up fallback timer to check if driver position is received
    if (!widget.isDriver && widget.activeRide != null) {
      final status = widget.activeRide!.status?.toLowerCase() ?? '';
      if (status == 'driver_en_route' || status == 'in_progress') {
        debugPrint(
          'RidesScreen: Setting up 5-second fallback timer for driver position',
        );
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _currentDriverPosition == null) {
            debugPrint(
              'RidesScreen: ⚠️ WARNING: No driver position received after 5 seconds!',
            );
            debugPrint(
              'RidesScreen: WebSocket connected: ${widget.wsService.isConnected}',
            );
            debugPrint('RidesScreen: Active ride: ${widget.activeRide?.id}');
            debugPrint(
              'RidesScreen: Ride status: ${widget.activeRide?.status}',
            );
          }
        });
      }
    }
  }

  void _animateMarker() {
    if (_currentDriverPosition == null || _targetDriverPosition == null) return;

    // Safely dispose previous animation controller
    try {
      _animController?.dispose();
    } catch (_) {
      // Controller may have been disposed already by didUpdateWidget
    }
    _animController = null;

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

  /// Calculate and display route for active ride based on status
  Future<void> _calculateRouteForActiveRide() async {
    if (widget.activeRide == null) {
      debugPrint('RidesScreen: No active ride, skipping route calculation');
      return;
    }

    final status = widget.activeRide!.status?.toLowerCase() ?? '';
    debugPrint(
      'RidesScreen: _calculateRouteForActiveRide called for ride ${widget.activeRide!.id}, '
      'status: $status, isDriver: ${widget.isDriver}',
    );

    // Only calculate route for active statuses
    if (status != 'driver_en_route' && status != 'in_progress') {
      debugPrint('RidesScreen: Status not active, clearing route');
      setState(() => _routePoints = []);
      return;
    }

    LatLng? from;
    LatLng? to;

    // Determine route origin: driver uses own GPS, passenger uses driver's WebSocket position
    final LatLng? routeOrigin = widget.isDriver
        ? widget.currentPosition
        : _currentDriverPosition;

    // Determine route endpoints based on status
    if (status == 'driver_en_route') {
      // Route from driver to pickup location
      from = routeOrigin;
      if (widget.activeRide!.originLat != null &&
          widget.activeRide!.originLng != null) {
        to = LatLng(
          widget.activeRide!.originLat!,
          widget.activeRide!.originLng!,
        );
      }
      debugPrint(
        'RidesScreen: Route endpoints (driver_en_route): '
        'FROM ${widget.isDriver ? "own GPS" : "driver WebSocket"}: $from, TO pickup: $to',
      );
    } else if (status == 'in_progress') {
      // Route from driver to destination
      from = routeOrigin;
      if (widget.activeRide!.destinationLat != null &&
          widget.activeRide!.destinationLng != null) {
        to = LatLng(
          widget.activeRide!.destinationLat!,
          widget.activeRide!.destinationLng!,
        );
      }
      debugPrint(
        'RidesScreen: Route endpoints (in_progress): '
        'FROM ${widget.isDriver ? "own GPS" : "driver WebSocket"}: $from, TO destination: $to',
      );
    }

    if (from == null || to == null) {
      debugPrint(
        'RidesScreen: ⚠️ Cannot calculate route - missing coordinates. '
        'Driver position (_currentDriverPosition): $from, Destination: $to',
      );
      debugPrint(
        'RidesScreen: Current ride origin: (${widget.activeRide!.originLat}, ${widget.activeRide!.originLng}), '
        'destination: (${widget.activeRide!.destinationLat}, ${widget.activeRide!.destinationLng})',
      );
      return;
    }

    debugPrint(
      'RidesScreen: ✅ Calculating route from ($from) to ($to) for ${widget.isDriver ? "DRIVER" : "PASSENGER"}',
    );

    // Use debounced calculator to prevent excessive API calls
    final result = await _routeCalculator.calculateIfNeeded(from, to);

    if (result != null && mounted) {
      setState(() {
        _routePoints = result.polylinePoints;
      });
      debugPrint(
        'RidesScreen: ✅ Route calculated successfully with ${result.polylinePoints.length} points, '
        'displaying on map for ${widget.isDriver ? "DRIVER" : "PASSENGER"}',
      );
    } else {
      debugPrint(
        'RidesScreen: ⚠️ Route calculation returned null (debounced or failed)',
      );
    }
  }

  /// Fit camera to show the full route with all relevant markers
  void _fitCameraToRoute() {
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

    // Add padding - increased for better visibility
    final double latPadding = (maxLat - minLat) * 0.3;
    final double lngPadding = (maxLng - minLng) * 0.3;

    final LatLng sw = LatLng(minLat - latPadding, minLng - lngPadding);
    final LatLng ne = LatLng(maxLat + latPadding, maxLng + lngPadding);

    // Fit bounds with extra padding for driver info panel
    widget.mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(sw, ne),
        padding: const EdgeInsets.only(
          left: 50,
          right: 50,
          top: 250, // Extra top padding to accommodate driver info panel
          bottom: 100,
        ),
      ),
    );
  }

  /// Ensure driver info panel is fully visible by adjusting map camera
  void _ensureDriverInfoVisible() {
    if (_currentDriverPosition == null) return;

    // Small delay to allow panel animation to start
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      final camera = widget.mapController.camera;
      final currentZoom = camera.zoom;

      // Project driver position to screen coordinates
      final driverScreenPoint = camera.latLngToScreenPoint(
        _currentDriverPosition!,
      );

      // Panel is ~160px tall + 48px gap above the car icon = ~210px total above driver point
      // Only pan if the panel top would be clipped by the top edge (with some buffer)
      const double panelHeightOnScreen = 220.0;
      const double topEdgeBuffer = 20.0;

      if (driverScreenPoint.y < panelHeightOnScreen + topEdgeBuffer) {
        // Driver marker is too close to top — pan down so panel is visible
        // Convert pixels to lat offset at current zoom
        final neededPixels =
            panelHeightOnScreen + topEdgeBuffer - driverScreenPoint.y;
        // 1 pixel ≈ 360 / (256 * 2^zoom) degrees latitude
        final degreesPerPixel = 360.0 / (256.0 * (1 << currentZoom.floor()));
        final latOffset = neededPixels * degreesPerPixel;

        final newCenter = LatLng(
          camera.center.latitude - latOffset,
          camera.center.longitude,
        );
        widget.mapController.move(newCenter, currentZoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use current position if available, otherwise fallback to Sfax coordinates
    final LatLng initialCenter =
        widget.currentPosition ?? const LatLng(34.7408, 10.7600);

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15.0,
            minZoom: 3,
            maxZoom: 18,
            onTap: (tapPosition, latLng) {
              if (widget.onTap != null) {
                widget.onTap!(latLng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gexpertise.carpool',
            ),
            // Route polyline for active rides (same styling as Offer Ride and Find Ride screens)
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: BrandColors.primaryRed.withOpacity(0.7),
                    strokeWidth: 3,
                  ),
                ],
              ),
            // Selected location marker (from map tap)
            if (widget.selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.selectedLocation!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: BrandColors.primaryRed.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: BrandColors.primaryRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
            // Driver location marker with tooltip (for passengers only)
            if (!widget.isDriver && _currentDriverPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentDriverPosition!,
                    width: 180,
                    height: 200,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showDriverInfo = !_showDriverInfo);
                        if (_showDriverInfo) {
                          _forceETAUpdate();
                          _ensureDriverInfoVisible();
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Car marker (always shown at bottom)
                          Positioned(
                            bottom: 0,
                            child: AnimatedScale(
                              scale: _showDriverInfo ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 40,
                                height: 40,
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
                          ),
                          // Tooltip (shown above marker when active)
                          if (_showDriverInfo)
                            Positioned(
                              bottom: 48,
                              child: AnimatedScale(
                                scale: _showDriverInfo ? 1.0 : 0.8,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: _showDriverInfo ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: DriverInfoTooltip(
                                    driverPosition: _currentDriverPosition!,
                                    driverName:
                                        widget.activeRide?.driverName ??
                                        'Unknown',
                                    driverInitial:
                                        (widget.activeRide?.driverName ??
                                                '?')[0]
                                            .toUpperCase(),
                                    carModel: widget.activeRide?.driverCarModel,
                                    carColor: widget.activeRide?.driverCarColor,
                                    eta: _currentETA,
                                    onClose: () =>
                                        setState(() => _showDriverInfo = false),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Integrated Search Bar with Menu
///
/// Maps-style floating search bar with integrated menu button, search field, and clear.
/// Single unified container - floating, rounded, subtle shadow.
class _IntegratedSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LatLng? currentPosition;
  final String? userCountryCode; // 'tn' or 'fr' for country-based search
  final Function(Map<String, dynamic>) onLocationSelected;

  const _IntegratedSearchBar({
    required this.controller,
    required this.focusNode,
    this.currentPosition,
    this.userCountryCode,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: TypeAheadField<Map<String, dynamic>>(
              controller: controller,
              focusNode: focusNode,
              suggestionsCallback: (pattern) async {
                try {
                  // Use unified LocationSearchService for consistent autocomplete
                  final results = await LocationSearchService.searchLocations(
                    query: pattern,
                    currentLocation: currentPosition,
                    userCountryCode: userCountryCode,
                    includeCurrentLocation: true,
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
                    hintText: 'Search places...',
                    hintStyle: TextStyle(fontSize: 15, color: Colors.grey[500]),
                    prefixIcon: Builder(
                      builder: (context) => InkWell(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.menu,
                            color: BrandColors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        if (value.text.isEmpty) {
                          return const SizedBox(width: 48);
                        }
                        return InkWell(
                          onTap: () => controller.clear(),
                          child: Container(
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                  dense: true,
                  leading: Icon(
                    isCurrentLocation ? Icons.my_location : Icons.location_on,
                    color: isCurrentLocation ? Colors.green : Colors.grey,
                    size: 20,
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
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: IntrinsicWidth(
                      stepWidth: constraints.maxWidth,
                      child: child,
                    ),
                  ),
                );
              },
              onSelected: (suggestion) {
                onLocationSelected(suggestion);
              },
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No locations found',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
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
            ),
          ),
        );
      },
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
/// Shows compact ride info when in Plan Next Ride mode.
class _BottomActionPanel extends StatelessWidget {
  final VoidCallback onFindRide;
  final VoidCallback onOfferRide;
  final Ride? activeRide;
  final bool isDriver;
  final VoidCallback? onToggleMode;

  const _BottomActionPanel({
    required this.onFindRide,
    required this.onOfferRide,
    this.activeRide,
    this.isDriver = false,
    this.onToggleMode,
  });

  String _shortAddress(String? address) {
    if (address == null || address.isEmpty) return '';
    final parts = address.split(',');
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveRide = activeRide != null;
    final status = hasActiveRide ? normalizeStatus(activeRide!.status) : '';
    final statusLabel = status == 'driver_en_route'
        ? 'Driver En Route'
        : status == 'in_progress'
        ? 'In Progress'
        : status == 'arrived'
        ? 'Arrived'
        : 'Active';

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
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                const SizedBox(height: 16),

                // Compact ride info card (only when in Plan Next Ride mode)
                if (hasActiveRide) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onToggleMode,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEEEEEE),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE6E6), // Soft red tint
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: Color(0xFFD6001C), // Brand red
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Current Ride ($statusLabel)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_shortAddress(activeRide!.origin)} → ${_shortAddress(activeRide!.destination)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      letterSpacing: 0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Find a Ride Button
                _ActionButton(
                  label: 'FIND A RIDE',
                  icon: Icons.search,
                  onPressed: onFindRide,
                ),
                const SizedBox(height: 16),

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
