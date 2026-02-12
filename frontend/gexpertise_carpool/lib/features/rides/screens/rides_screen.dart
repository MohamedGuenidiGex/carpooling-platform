import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/osm_search_service.dart';
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
  final MapController _mapController = MapController();
  LatLng? _currentPosition;

  // Location picker state
  bool _isPickingLocation = false;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _pickedLocation;
  String? _pickedLocationName;

  @override
  void initState() {
    super.initState();
    // Start notification polling
    _startNotificationPolling();
    // Get current location
    _determinePosition();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
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

    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Move map to current position
      _mapController.move(_currentPosition!, 15.0);
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

  /// Enter location picker mode
  void _enterPickerMode() {
    setState(() {
      _isPickingLocation = true;
    });
  }

  /// Exit location picker mode
  void _exitPickerMode() {
    setState(() {
      _isPickingLocation = false;
      _searchController.clear();
      _pickedLocation = null;
      _pickedLocationName = null;
    });
  }

  /// Confirm selected location and navigate to FindRideScreen
  void _confirmLocation() {
    final center = _mapController.camera.center;
    setState(() {
      _pickedLocation = center;
    });

    // Get location name via reverse geocoding
    OsmSearchService.reverseGeocode(center.latitude, center.longitude).then((
      name,
    ) {
      setState(() {
        _pickedLocationName = name ?? 'Selected Location';
      });
    });

    // Navigate to FindRideScreen with the selected location
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FindRideScreen(
          initialPickupLocation: center,
          initialPickupName: _pickedLocationName,
        ),
      ),
    ).then((_) {
      // Reset picker mode when returning
      _exitPickerMode();
    });
  }

  /// Move map to searched location
  void _moveToSearchedLocation(double lat, double lon, String name) {
    _mapController.move(LatLng(lat, lon), 15.0);
    setState(() {
      _pickedLocation = LatLng(lat, lon);
      _pickedLocationName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _isPickingLocation ? null : const GExpertiseDrawer(),
      body: Stack(
        children: [
          // Layer 1: Map Background
          _MapBackground(
            mapController: _mapController,
            currentPosition: _currentPosition,
            showCenterPin: _isPickingLocation,
          ),

          // Layer 2: Menu Button (Top Left) - hidden in picker mode
          if (!_isPickingLocation) _MenuButton(),

          // Layer 3: Search Bar (Top) - only in picker mode
          if (_isPickingLocation)
            _SearchBar(
              controller: _searchController,
              onSuggestionSelected: (suggestion) {
                _moveToSearchedLocation(
                  suggestion['lat'] as double,
                  suggestion['lon'] as double,
                  suggestion['display_name'] as String,
                );
              },
            ),

          // Layer 4: Current Location Button (Bottom Right, above panel)
          _CurrentLocationButton(onPressed: _goToCurrentLocation),

          // Layer 5: Floating Action Panel or Confirm Panel (Bottom)
          if (_isPickingLocation)
            _ConfirmLocationPanel(
              onConfirm: _confirmLocation,
              onCancel: _exitPickerMode,
            )
          else
            _BottomActionPanel(onFindRide: _enterPickerMode),
        ],
      ),
    );
  }
}

/// Map Background with OpenStreetMap
///
/// Displays an interactive map using flutter_map with OpenStreetMap tiles.
class _MapBackground extends StatelessWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final bool showCenterPin;

  const _MapBackground({
    required this.mapController,
    this.currentPosition,
    this.showCenterPin = false,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: LatLng(36.8065, 10.1815), // Tunis, Tunisia
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gexpertise.carpooling',
        ),
        // Current location marker
        if (currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPosition!,
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
      ],
    );
  }
}

/// Center Pin Marker (Visible in Picker Mode)
///
/// Displays a red pin in the center of the map.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_pin, color: BrandColors.primaryRed, size: 50),
          // Shadow under the pin
          Container(
            width: 20,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
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

/// Current Location Button (Bottom Right)
///
/// Floating action button to re-center the map on user's location.
class _CurrentLocationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CurrentLocationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 200, // Above the bottom action panel
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

  const _BottomActionPanel({required this.onFindRide});

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

/// Search Bar Widget (Picker Mode)
///
/// TypeAheadField for searching places via OSM Nominatim.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>) onSuggestionSelected;

  const _SearchBar({
    required this.controller,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
            suggestionsCallback: (pattern) async {
              if (pattern.length < 2) return [];
              return await OsmSearchService.searchPlaces(pattern);
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
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              );
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                leading: const Icon(Icons.location_on, color: Colors.grey),
                title: Text(
                  suggestion['display_name'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
            onSelected: (suggestion) {
              onSuggestionSelected(suggestion);
            },
          ),
        ),
      ),
    );
  }
}

/// Confirm Location Panel (Picker Mode)
///
/// Bottom panel with Confirm and Cancel buttons.
class _ConfirmLocationPanel extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmLocationPanel({
    required this.onConfirm,
    required this.onCancel,
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
              color: Colors.black.withOpacity(0.15),
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
                  'Adjust the pin to set your pickup location',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'CONFIRM LOCATION',
                      style: TextStyle(
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
                ),
                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
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
