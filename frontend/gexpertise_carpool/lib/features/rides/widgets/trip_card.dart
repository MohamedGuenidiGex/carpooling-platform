import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gexpertise_carpool/features/rides/models/ride_model.dart';
import 'package:gexpertise_carpool/features/rides/providers/ride_provider.dart';
import 'package:gexpertise_carpool/core/theme/brand_colors.dart';
import 'package:gexpertise_carpool/core/services/websocket_service.dart';

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
    _setupStatusPolling();
  }

  void _setupStatusPolling() {
    // Poll for status updates every 5 seconds
    // This will be replaced with WebSocket listener when WebSocketService is available
    Future.doWhile(() async {
      if (!mounted) return false;

      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        final rideProvider = context.read<RideProvider>();
        try {
          final updatedRide = await rideProvider.getRideDetails(
            currentRide.id!,
          );
          if (updatedRide) {
            final newRide = rideProvider.currentRide;
            if (newRide != null) {
              setState(() => currentRide = newRide);

              // If ride is completed or cancelled, notify parent
              final status = newRide.status?.toLowerCase() ?? '';
              if (status == 'completed' || status == 'cancelled') {
                widget.onRideCompleted();
                return false; // Stop polling
              }
            }
          }
        } catch (e) {
          debugPrint('Error polling ride status: $e');
        }
      }

      return mounted;
    });
  }

  @override
  void didUpdateWidget(TripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRide.id != widget.activeRide.id) {
      currentRide = widget.activeRide;
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

    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.primaryRed.withOpacity(0.95),
                BrandColors.primaryRed.withOpacity(0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            border: Border.all(color: statusColor, width: 1.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 8),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Route Information
                        Text(
                          'Your Trip',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Origin
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentRide.origin,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Divider with arrow
                        Center(
                          child: Container(
                            width: 2,
                            height: 24,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        Center(
                          child: Icon(
                            Icons.arrow_downward,
                            color: Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 2,
                            height: 24,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Destination
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentRide.destination,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Date & Time
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.white.withOpacity(0.8),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Primary Action Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isDriverAction() && !isLoading
                          ? () => _handlePrimaryAction(rideProvider)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: BrandColors.primaryRed,
                        disabledBackgroundColor: Colors.white.withOpacity(0.5),
                        disabledForegroundColor: Colors.white.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                  BrandColors.primaryRed,
                                ),
                              ),
                            )
                          : Text(
                              _getPrimaryButtonLabel(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
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
