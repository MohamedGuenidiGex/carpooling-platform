import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

class _TripCardState extends State<TripCard> {
  late Ride currentRide;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentRide = widget.activeRide;
  }

  @override
  void didUpdateWidget(TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRide.id != widget.activeRide.id ||
        oldWidget.activeRide.status != widget.activeRide.status) {
      setState(() => currentRide = widget.activeRide);
    }
  }

  String _getStatusLabel(String status) {
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'scheduled':
        return 'Scheduled';
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

  @override
  Widget build(BuildContext context) {
    final statusLabel = _getStatusLabel(currentRide.status ?? 'scheduled');
    final statusColor = _getStatusColor(currentRide.status ?? 'scheduled');
    final statusIcon = _getStatusIcon(currentRide.status ?? 'scheduled');
    final formattedTime = DateFormat(
      'MMM d, h:mm a',
    ).format(currentRide.departureTime);

    // Shorten long addresses to first meaningful part
    String shortAddress(String addr) {
      final parts = addr.split(',');
      return parts.first.trim();
    }

    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Status chip + departure time
                      Row(
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
                          const Spacer(),
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
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Route summary: Origin → Destination
                      Row(
                        children: [
                          // Origin dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: BrandColors.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: BrandColors.primaryRed.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shortAddress(currentRide.origin),
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
                      // Connecting line
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
                          // Destination dot
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
                              shortAddress(currentRide.destination),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
              ],
            ),
          ),
        );
      },
    );
  }
}
