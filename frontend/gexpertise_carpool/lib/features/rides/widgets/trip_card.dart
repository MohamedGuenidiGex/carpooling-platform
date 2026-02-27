import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/core/theme/brand_colors.dart';

class TripCard extends StatefulWidget {
  final Ride activeRide;
  final int currentUserId;
  final bool isDriver;
  final VoidCallback onRideCompleted;

  const TripCard({
    required this.activeRide,
    required this.currentUserId,
    required this.isDriver,
    required this.onRideCompleted,
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
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

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
  }

  @override
  void dispose() {
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

  bool _isDriverAction() {
    final status = currentRide.status?.toLowerCase() ?? 'scheduled';
    return widget.isDriver && status != 'completed' && status != 'cancelled';
  }

  // Shorten long addresses to first meaningful part
  String _shortAddress(String addr) {
    final parts = addr.split(',');
    return parts.first.trim();
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

                          // Full route: Origin → Destination
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: BrandColors.primaryRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: BrandColors.primaryRed.withOpacity(
                                      0.3,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _shortAddress(currentRide.origin),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                    color: Colors.green.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _shortAddress(currentRide.destination),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Primary Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isDriverAction() && !isLoading
                                  ? () => _handlePrimaryAction(rideProvider)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BrandColors.primaryRed,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[200],
                                disabledForegroundColor: Colors.grey[500],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      _getPrimaryButtonLabel(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
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
}
