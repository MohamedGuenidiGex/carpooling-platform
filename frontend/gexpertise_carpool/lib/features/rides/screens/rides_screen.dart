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

class _RidesScreenState extends State<RidesScreen> {
  Timer? _notificationTimer;
  int _lastKnownCount = 0;
  final MapController _mapController = MapController();
  LatLng? _currentPosition;

  // Unified search state
  bool _isSearching = false;
  SearchMode _searchMode = SearchMode.none;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
    _determinePosition();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

    _onPositionDetermined(position);
  }

  void _onPositionDetermined(Position position) {
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
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _isSearching ? null : const GExpertiseDrawer(),
      body: Stack(
        children: [
          // Layer 1: Map Background
          _MapBackground(
            mapController: _mapController,
            currentPosition: _currentPosition,
            showCenterPin: _isSearching,
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

          // Layer 4: Current Location Button (Bottom Right, above panel)
          _CurrentLocationButton(onPressed: _goToCurrentLocation),

          // Layer 5: Floating Action Panel or Cancel Button (Bottom)
          if (_isSearching)
            _CancelPanel(onCancel: _cancelSearch)
          else
            _BottomActionPanel(
              onFindRide: _startPassengerSearch,
              onOfferRide: _startDriverSearch,
            ),
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
    // Use current position if available, otherwise fallback to Sfax coordinates
    final LatLng initialCenter =
        currentPosition ?? const LatLng(34.7408, 10.7600);

    return FlutterMap(
      mapController: mapController,
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
        if (showCenterPin)
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
                  border: InputBorder.none,
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
