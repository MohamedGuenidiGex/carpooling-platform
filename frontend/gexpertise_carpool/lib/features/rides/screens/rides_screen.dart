import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/gexpertise_drawer.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../features/notifications/screens/notifications_screen.dart';
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';

/// Rides Screen - Map-First Home Dashboard
///
/// Uber/InDrive-style layout with map background, floating controls,
/// and a bottom action panel for Find/Offer ride buttons.
class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  Timer? _notificationTimer;
  int _lastKnownCount = 0;

  @override
  void initState() {
    super.initState();
    // Start notification polling
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const GExpertiseDrawer(),
      body: Stack(
        children: [
          // Layer 1: Map Background
          _MapBackground(),

          // Layer 2: Menu Button (Top Left)
          _MenuButton(),

          // Layer 3: Floating Action Panel (Bottom) - Positioned
          const _BottomActionPanel(),
        ],
      ),
    );
  }
}

/// Map Background Placeholder
///
/// Displays a placeholder map view until real map integration is added.
class _MapBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE8F4F8), // Light blue-grey top
            const Color(0xFFF5F5F5), // Light grey bottom
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Map View',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find and offer rides near you',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
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

/// Bottom Action Panel (Positioned)
///
/// White panel pinned to bottom using Positioned widget.
class _BottomActionPanel extends StatelessWidget {
  const _BottomActionPanel();

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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FindRideScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Offer a Ride Button
                _ActionButton(
                  label: 'OFFER A RIDE',
                  icon: Icons.add_circle_outline,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OfferRideScreen(),
                      ),
                    );
                  },
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
