import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/features/reservations/providers/reservation_provider.dart';
import 'package:gexpertise_carpool/core/theme/brand_colors.dart';
import 'package:gexpertise_carpool/core/services/route_service.dart';
import 'package:gexpertise_carpool/core/services/websocket_service.dart';

class TripCard extends StatefulWidget {
  final Ride activeRide;
  final int currentUserId;
  final bool isDriver;
  final VoidCallback onRideCompleted;
  final VoidCallback onTogglePlanMode;
  final int?
  reservationId; // Passenger's reservation ID for boarding confirmation
  final DateTime? boardingDeadline; // Boarding deadline for passenger

  const TripCard({
    required this.activeRide,
    required this.currentUserId,
    required this.isDriver,
    required this.onRideCompleted,
    required this.onTogglePlanMode,
    this.reservationId,
    this.boardingDeadline,
    Key? key,
  }) : super(key: key);

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard>
    with SingleTickerProviderStateMixin {
  late Ride currentRide;
  bool isLoading = false;
  bool _isExpanded = false;
  bool _hasConfirmedBoarding = false; // Track if passenger confirmed boarding
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  Timer? _boardingDeadlineTimer; // Auto-dismiss after boarding deadline

  // GPS location streaming
  StreamSubscription<Position>? _locationStreamSubscription;
  final WebSocketService _wsService = WebSocketService();

  // ETA calculation
  String? _etaText;
  LatLng? _driverPosition;
  final DebouncedRouteCalculator _etaCalculator = DebouncedRouteCalculator();

  /// Lifecycle statuses that default to expanded mode
  static const _lifecycleStatuses = {
    'driver_en_route',
    'arrived',
    'in_progress',
  };

  @override
  void initState() {
    super.initState();
    currentRide = widget.activeRide;
    _isExpanded = _shouldDefaultExpanded(currentRide);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Start GPS streaming if driver and ride is active
    if (widget.isDriver) {
      _startLocationStreamingIfNeeded();
    } else {
      // Passenger: listen for driver location updates via WebSocket
      _setupDriverLocationListener();
    }

    // Start boarding deadline timer for passengers
    _setupBoardingDeadlineTimer();
  }

  @override
  void dispose() {
    _boardingDeadlineTimer?.cancel();
    _stopLocationStreaming();
    if (!widget.isDriver) {
      _wsService.off('driver_location_updated');
    }
    _animController.dispose();
    super.dispose();
  }

  bool _shouldDefaultExpanded(Ride ride) {
    final status = ride.status?.toLowerCase() ?? '';
    // Only lifecycle statuses (driver_en_route, arrived, in_progress) expand by default
    // active/full/scheduled remain collapsed until user taps
    return _lifecycleStatuses.contains(status);
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void didUpdateWidget(TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRide.id != widget.activeRide.id ||
        oldWidget.activeRide.status != widget.activeRide.status) {
      setState(() => currentRide = widget.activeRide);
      // Auto-expand when ride transitions to an active state
      final shouldExpand = _shouldDefaultExpanded(widget.activeRide);
      if (shouldExpand && !_isExpanded) {
        _isExpanded = true;
        _animController.forward();
      }

      // Update GPS streaming based on new status
      if (widget.isDriver) {
        _startLocationStreamingIfNeeded();
      }
    }

    // Re-setup boarding deadline timer if deadline changed
    if (oldWidget.boardingDeadline != widget.boardingDeadline) {
      _setupBoardingDeadlineTimer();
    }
  }

  String _getStatusLabel(String status) {
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'scheduled':
        return 'Scheduled';
      case 'active':
        return 'Active';
      case 'full':
        return 'Full';
      case 'driver_en_route':
        return 'Driver En Route';
      case 'arrived':
        return 'Driver Arrived';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'missed':
        return 'Missed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'scheduled':
        return Colors.blue;
      case 'active':
        return Colors.teal;
      case 'full':
        return Colors.indigo;
      case 'driver_en_route':
        return Colors.orange;
      case 'arrived':
        return Colors.purple;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'missed':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'scheduled':
        return Icons.schedule;
      case 'active':
        return Icons.check_circle_outline;
      case 'full':
        return Icons.people;
      case 'driver_en_route':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'in_progress':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'missed':
        return Icons.event_busy;
      default:
        return Icons.info;
    }
  }

  Future<void> _handlePrimaryAction(RideProvider rideProvider) async {
    final status = currentRide.status?.toLowerCase() ?? 'scheduled';

    if (widget.isDriver) {
      switch (status) {
        case 'scheduled':
        case 'active':
        case 'full':
          await _startRide(rideProvider);
          break;
        case 'driver_en_route':
          await _arriveRide(rideProvider);
          break;
        case 'arrived':
          await _beginRide(rideProvider);
          break;
        case 'in_progress':
          await _completeRide(rideProvider);
          break;
      }
    }
  }

  Future<void> _startRide(RideProvider rideProvider) async {
    setState(() => isLoading = true);
    final success = await rideProvider.startRide(currentRide.id!);
    setState(() => isLoading = false);

    if (mounted) {
      if (success) {
        setState(
          () => currentRide = currentRide.copyWith(status: 'driver_en_route'),
        );
        // Start GPS location streaming immediately
        _startLocationStreamingIfNeeded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride started - en route!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rideProvider.errorMessage ?? 'Failed to start ride'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _arriveRide(RideProvider rideProvider) async {
    // Soft GPS validation before marking arrival
    final shouldProceed = await _validateArrivalLocation();
    if (!shouldProceed) {
      return; // User cancelled
    }

    setState(() => isLoading = true);
    final success = await rideProvider.arriveRide(currentRide.id!);
    setState(() => isLoading = false);

    if (mounted) {
      if (success) {
        setState(() => currentRide = currentRide.copyWith(status: 'arrived'));
        // Stop GPS streaming while waiting at pickup
        _stopLocationStreaming();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as arrived!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rideProvider.errorMessage ?? 'Failed to mark arrival',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Soft location validation for arrival
  /// Returns true if should proceed, false if cancelled
  Future<bool> _validateArrivalLocation() async {
    debugPrint('TripCard: === ARRIVAL VALIDATION STARTED ===');
    debugPrint('TripCard: Ride ID: ${currentRide.id}');
    debugPrint('TripCard: Origin: ${currentRide.origin}');
    debugPrint('TripCard: Origin Lat: ${currentRide.originLat}');
    debugPrint('TripCard: Origin Lng: ${currentRide.originLng}');
    debugPrint('TripCard: Destination: ${currentRide.destination}');
    debugPrint('TripCard: Destination Lat: ${currentRide.destinationLat}');
    debugPrint('TripCard: Destination Lng: ${currentRide.destinationLng}');
    debugPrint('TripCard: Full ride object: $currentRide');

    // Check if pickup coordinates are available
    if (currentRide.originLat == null || currentRide.originLng == null) {
      debugPrint(
        'TripCard: ⚠️ No pickup coordinates available, skipping validation',
      );
      debugPrint(
        'TripCard: This ride was created without GPS coordinates. '
        'Location validation only works for rides created with GPS data.',
      );

      // Show info dialog to driver
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Validation Unavailable'),
            content: const Text(
              'This ride was created without GPS coordinates. '
              'Location validation cannot be performed.\n\n'
              'New rides created from the map will include GPS data for arrival validation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      return true; // Proceed without validation
    }

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied - show dialog and allow continue
          if (!mounted) return false;
          return await _showPermissionDeniedDialog();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return false;
        return await _showPermissionDeniedDialog();
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
        'TripCard: Driver GPS: ${position.latitude}, ${position.longitude}',
      );
      debugPrint(
        'TripCard: Pickup GPS: ${currentRide.originLat}, ${currentRide.originLng}',
      );

      // Calculate distance in meters
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentRide.originLat!,
        currentRide.originLng!,
      );

      debugPrint(
        'TripCard: Distance to pickup: ${distance.toStringAsFixed(0)} meters',
      );

      // Soft validation: warn if > 200m
      if (distance > 200) {
        debugPrint(
          'TripCard: ⚠️ Driver is FAR from pickup, showing warning dialog',
        );
        if (!mounted) return false;
        final result = await _showDistanceWarningDialog(distance);
        debugPrint('TripCard: Warning dialog result: $result');
        return result;
      }

      debugPrint('TripCard: ✅ Driver is within 200m, proceeding');
      return true; // Within range, proceed
    } catch (e) {
      debugPrint('TripCard: ❌ Location validation error: $e');
      // On error, allow user to proceed
      return true;
    }
  }

  /// Show dialog when location permission is denied
  Future<bool> _showPermissionDeniedDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is needed to validate your arrival at the pickup point. '
          'You can continue without validation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show warning dialog when driver is far from pickup
  Future<bool> _showDistanceWarningDialog(double distance) async {
    final distanceText = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : '${distance.toStringAsFixed(0)} meters';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You are not near pickup location'),
        content: Text(
          'You are approximately $distanceText away from the pickup point. '
          'Are you sure you want to mark as arrived?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _beginRide(RideProvider rideProvider) async {
    setState(() => isLoading = true);
    final success = await rideProvider.beginRide(currentRide.id!);
    setState(() => isLoading = false);

    if (mounted) {
      if (success) {
        setState(
          () => currentRide = currentRide.copyWith(status: 'in_progress'),
        );
        // Resume GPS location streaming for the journey
        _startLocationStreamingIfNeeded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride journey begun!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rideProvider.errorMessage ?? 'Failed to begin ride'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRide(RideProvider rideProvider) async {
    setState(() => isLoading = true);
    // Stop GPS streaming before completing
    _stopLocationStreaming();
    final success = await rideProvider.completeRide(currentRide.id!);
    setState(() => isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRideCompleted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rideProvider.errorMessage ?? 'Failed to complete ride',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPrimaryButtonLabel() {
    final status = currentRide.status?.toLowerCase() ?? 'scheduled';

    if (widget.isDriver) {
      switch (status) {
        case 'scheduled':
        case 'active':
        case 'full':
          return 'Start Ride';
        case 'driver_en_route':
          return 'Mark Arrived';
        case 'arrived':
          return 'Begin Ride';
        case 'in_progress':
          return 'Complete Ride';
        default:
          return 'Update Status';
      }
    } else {
      switch (status) {
        case 'scheduled':
        case 'active':
        case 'full':
          return 'Waiting for driver';
        case 'driver_en_route':
          return 'Driver en route';
        case 'arrived':
          return 'Driver arrived';
        case 'in_progress':
          return 'Ride in progress';
        default:
          return 'Ride status';
      }
    }
  }

  IconData _getPrimaryButtonIcon() {
    final status = currentRide.status?.toLowerCase() ?? 'scheduled';

    if (widget.isDriver) {
      switch (status) {
        case 'scheduled':
        case 'active':
        case 'full':
          return Icons.directions_car_outlined;
        case 'driver_en_route':
          return Icons.location_on_outlined;
        case 'arrived':
          return Icons.play_arrow_rounded;
        case 'in_progress':
          return Icons.check_circle_outline;
        default:
          return Icons.update;
      }
    } else {
      return Icons.info_outline;
    }
  }

  bool _isDriverAction() {
    final status = currentRide.status?.toLowerCase() ?? 'scheduled';
    // Hide lifecycle buttons for terminal states (completed, cancelled, missed)
    return widget.isDriver &&
        status != 'completed' &&
        status != 'cancelled' &&
        status != 'missed';
  }

  /// Check if driver should see navigation button
  /// Only show during active ride states: driver_en_route or in_progress
  bool _shouldShowNavigationButton() {
    if (!widget.isDriver) return false;

    final status = currentRide.status?.toLowerCase() ?? 'scheduled';
    return status == 'driver_en_route' || status == 'in_progress';
  }

  /// Open Google Maps navigation
  /// - If driver_en_route: navigate to pickup location
  /// - If in_progress: navigate to destination
  /// - Origin: driver's current GPS location
  Future<void> _openGoogleMapsNavigation() async {
    final ride = currentRide;
    final status = ride.status?.toLowerCase() ?? '';

    // Determine destination based on ride state
    double? destLat;
    double? destLng;

    if (status == 'driver_en_route') {
      // Navigate to pickup location
      if (ride.originLat == null || ride.originLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup location coordinates not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      destLat = ride.originLat;
      destLng = ride.originLng;
    } else if (status == 'in_progress') {
      // Navigate to final destination
      if (ride.destinationLat == null || ride.destinationLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination coordinates not available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      destLat = ride.destinationLat;
      destLng = ride.destinationLng;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation not available for current ride state'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build Google Maps URL with only destination (next ride objective)
    // Google Maps will automatically use the phone's GPS location as origin
    // Format: https://www.google.com/maps/dir/?api=1&destination=lat,lng&travelmode=driving
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to generic maps URL
        final fallbackUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$destLat,$destLng',
        );
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not open Google Maps');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open navigation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Schedule auto-dismiss of TripCard when boarding deadline expires (passenger only)
  void _setupBoardingDeadlineTimer() {
    // Only for passengers with a boarding deadline who haven't confirmed
    if (widget.isDriver ||
        widget.boardingDeadline == null ||
        _hasConfirmedBoarding) {
      return;
    }

    final now = DateTime.now().toUtc();
    final deadline = widget.boardingDeadline!.toUtc();
    final remaining = deadline.difference(now);

    if (remaining.isNegative) {
      // Deadline already passed — trigger refresh immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRideCompleted();
      });
      return;
    }

    // Schedule dismissal when deadline expires
    _boardingDeadlineTimer?.cancel();
    _boardingDeadlineTimer = Timer(remaining, () {
      if (mounted && !_hasConfirmedBoarding) {
        // Deadline just expired — trigger card removal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Boarding deadline expired. Your reservation has been marked as missed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        widget.onRideCompleted();
      }
    });
  }

  /// Check if passenger needs to confirm boarding
  /// Shows during 'arrived' OR 'in_progress' (within 5-min boarding deadline)
  bool _isPassengerBoardingAction() {
    if (widget.isDriver ||
        widget.reservationId == null ||
        _hasConfirmedBoarding) {
      return false;
    }

    final status = currentRide.status?.toLowerCase() ?? 'scheduled';

    // Show during 'arrived' status (no deadline yet)
    if (status == 'arrived') {
      return true;
    }

    // Show during 'in_progress' if within boarding deadline (5 minutes)
    if (status == 'in_progress' && widget.boardingDeadline != null) {
      final now = DateTime.now().toUtc();
      final deadline = widget.boardingDeadline!.toUtc();
      return now.isBefore(deadline);
    }

    return false;
  }

  /// Confirm passenger boarding
  Future<void> _confirmBoarding() async {
    if (widget.reservationId == null) return;

    setState(() => isLoading = true);
    final provider = context.read<ReservationProvider>();
    final success = await provider.confirmBoarding(widget.reservationId!);
    setState(() => isLoading = false);

    if (mounted) {
      if (success) {
        setState(() => _hasConfirmedBoarding = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Boarding confirmed! You\'re on the ride.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Failed to confirm boarding',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Shorten long addresses to first meaningful part
  String _shortAddress(String addr) {
    final parts = addr.split(',');
    return parts.first.trim();
  }

  /// Start GPS location streaming if ride is in active status
  Future<void> _startLocationStreamingIfNeeded() async {
    final status = currentRide.status?.toLowerCase() ?? '';
    final isActiveStatus =
        status == 'driver_en_route' || status == 'in_progress';

    if (!isActiveStatus) {
      _stopLocationStreaming();
      return;
    }

    // Already streaming
    if (_locationStreamSubscription != null) {
      return;
    }

    // Request location permission
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationPermissionDialog();
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog();
        }
        return;
      }

      // Start location stream
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _locationStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _sendLocationUpdate(position);
            },
            onError: (error) {
              debugPrint('TripCard: Location stream error: $error');
            },
          );

      debugPrint(
        'TripCard: Started driver location streaming for ride ${currentRide.id}',
      );
    } catch (e) {
      debugPrint('TripCard: Failed to start location streaming: $e');
    }
  }

  /// Stop GPS location streaming
  void _stopLocationStreaming() {
    if (_locationStreamSubscription != null) {
      _locationStreamSubscription!.cancel();
      _locationStreamSubscription = null;
      debugPrint('TripCard: Stopped driver location streaming');
    }
  }

  /// Send location update to backend via WebSocket
  void _sendLocationUpdate(Position position) {
    if (currentRide.id == null) return;
    if (!_wsService.isConnected) return;

    final status = currentRide.status?.toLowerCase() ?? '';
    final isActiveStatus =
        status == 'driver_en_route' || status == 'in_progress';

    if (!isActiveStatus) {
      _stopLocationStreaming();
      return;
    }

    // Update driver position for ETA calculation
    _driverPosition = LatLng(position.latitude, position.longitude);
    _calculateETA();

    _wsService.sendDriverLocationUpdate(
      rideId: currentRide.id!,
      lat: position.latitude,
      lng: position.longitude,
      timestamp: DateTime.now().toIso8601String(),
    );

    debugPrint(
      'TripCard: Sent driver location update: '
      '(${position.latitude}, ${position.longitude})',
    );
  }

  /// Setup WebSocket listener for driver location updates (passenger only)
  void _setupDriverLocationListener() {
    if (currentRide.id == null) return;

    _wsService.on('driver_location_updated', (data) {
      if (!mounted) return;
      if (data is! Map) return;

      final rideId = data['ride_id'];
      if (rideId != currentRide.id) return;

      final lat = data['lat'];
      final lng = data['lng'];
      if (lat == null || lng == null) return;

      _driverPosition = LatLng(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );

      _calculateETA();
    });
  }

  /// Calculate ETA based on current driver position and ride status
  Future<void> _calculateETA() async {
    if (_driverPosition == null) return;

    final status = currentRide.status?.toLowerCase() ?? '';
    LatLng? destination;

    if (status == 'driver_en_route') {
      // ETA to pickup (origin)
      if (currentRide.originLat != null && currentRide.originLng != null) {
        destination = LatLng(currentRide.originLat!, currentRide.originLng!);
      }
    } else if (status == 'in_progress') {
      // ETA to destination
      if (currentRide.destinationLat != null &&
          currentRide.destinationLng != null) {
        destination = LatLng(
          currentRide.destinationLat!,
          currentRide.destinationLng!,
        );
      }
    } else {
      // No ETA for other statuses
      if (_etaText != null && mounted) {
        setState(() => _etaText = null);
      }
      return;
    }

    if (destination == null) {
      if (mounted) setState(() => _etaText = 'Unavailable');
      return;
    }

    // Use debounced calculator to prevent excessive API calls
    final result = await _etaCalculator.calculateIfNeeded(
      _driverPosition!,
      destination,
    );

    if (result != null && mounted) {
      setState(() => _etaText = result.formattedDuration);
    } else if (_etaText == null && mounted) {
      // First attempt returned null (debounce), force calculate
      final forced = await _etaCalculator.forceCalculate(
        _driverPosition!,
        destination,
      );
      if (mounted) {
        setState(() => _etaText = forced?.formattedDuration ?? 'Unavailable');
      }
    }
  }

  /// Show dialog when location permission is denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is required to share your real-time location '
          'with passengers during the ride. Please enable location access in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _getStatusLabel(currentRide.status ?? 'scheduled');
    final statusColor = _getStatusColor(currentRide.status ?? 'scheduled');
    final statusIcon = _getStatusIcon(currentRide.status ?? 'scheduled');
    final formattedTime = DateFormat(
      'MMM d, h:mm a',
    ).format(currentRide.departureTime);

    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        return GestureDetector(
          onTap: _toggleExpanded,
          onVerticalDragEnd: (details) {
            // Swipe up → expand, swipe down → collapse
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -200 && !_isExpanded) {
                _toggleExpanded();
              } else if (details.primaryVelocity! > 200 && _isExpanded) {
                _toggleExpanded();
              }
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Collapsed content (always visible) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Compact route
                        Expanded(
                          child: Text(
                            '${_shortAddress(currentRide.origin)} → ${_shortAddress(currentRide.destination)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Departure time
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Expand/collapse chevron
                        AnimatedBuilder(
                          animation: _expandAnimation,
                          builder: (context, child) => Transform.rotate(
                            angle: _expandAnimation.value * 3.14159,
                            child: child,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Expanded content (animated) ──
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: -1.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Route section with Plan Next button centered on right
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Route info column
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: BrandColors.primaryRed,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: BrandColors.primaryRed
                                                .withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _shortAddress(currentRide.origin),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Container(
                                      width: 2,
                                      height: 20,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _shortAddress(currentRide.destination),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Plan Next button (aligned to right edge)
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onTogglePlanMode,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: BrandColors.primaryRed
                                                .withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              size: 16,
                                              color: BrandColors.primaryRed,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Plan Next',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: BrandColors.primaryRed,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ETA Display for both drivers and passengers during active ride phases
                          _buildETASection(),

                          const SizedBox(height: 16),
                          // Primary Action Button (Driver actions)
                          if (_isDriverAction())
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: !isLoading
                                    ? () => _handlePrimaryAction(rideProvider)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.primaryRed,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[200],
                                  disabledForegroundColor: Colors.grey[500],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getPrimaryButtonIcon(),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getPrimaryButtonLabel(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                          // Google Maps Navigation Button (Driver only, during active ride)
                          if (_shouldShowNavigationButton()) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openGoogleMapsNavigation,
                                icon: const Icon(Icons.navigation, size: 16),
                                label: const Text(
                                  'Navigate with Google Maps',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BrandColors.primaryRed,
                                  side: const BorderSide(
                                    color: BrandColors.primaryRed,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Passenger Boarding Confirmation Button
                          if (_isPassengerBoardingAction())
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: !isLoading && !_hasConfirmedBoarding
                                    ? () => _confirmBoarding()
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasConfirmedBoarding
                                      ? Colors.green[700]
                                      : Colors.green[600],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _hasConfirmedBoarding
                                      ? Colors.green[700]
                                      : Colors.grey[200],
                                  disabledForegroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _hasConfirmedBoarding
                                                ? Icons.check_circle
                                                : Icons.check_circle_outline,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _hasConfirmedBoarding
                                                ? 'Boarding Confirmed ✓'
                                                : 'Confirm Boarding',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom padding when collapsed
                  AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, _) =>
                        SizedBox(height: 12 * (1 - _expandAnimation.value)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build ETA section for both drivers and passengers during active ride phases
  Widget _buildETASection() {
    final status = currentRide.status?.toLowerCase() ?? '';

    String etaLabel;

    switch (status) {
      case 'driver_en_route':
        etaLabel = 'ETA to pickup';
        break;
      case 'arrived':
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.purple[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Driver arrived at pickup location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple[700],
                  ),
                ),
              ),
            ],
          ),
        );
      case 'in_progress':
        etaLabel = 'ETA to destination';
        break;
      default:
        return const SizedBox.shrink();
    }

    // Use real ETA text from calculation, with fallback
    final displayEta = _etaText ?? 'Calculating...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.primaryRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: BrandColors.primaryRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$etaLabel: $displayEta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BrandColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
