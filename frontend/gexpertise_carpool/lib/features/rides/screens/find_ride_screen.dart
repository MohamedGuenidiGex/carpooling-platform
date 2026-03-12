import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/location_search_service.dart';
import '../../../core/services/osm_search_service.dart';
import '../../../core/services/route_service.dart';
import '../../../core/theme/brand_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/ride_card.dart';
import 'ride_details_screen.dart';

/// Find a Ride Screen - Premium Search Experience
///
/// Clean, modern UI for passengers to search for available rides.
/// Features a search form with origin, destination, and date filters,
/// plus a results list with premium ride cards.
class FindRideScreen extends StatefulWidget {
  final String? startName;
  final LatLng? startCoordinates;

  const FindRideScreen({super.key, this.startName, this.startCoordinates});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dateController = TextEditingController();
  final MapController _mapController = MapController();

  DateTime? _selectedDate;
  LatLng? _originCoordinates; // Store origin coordinates for route calculation
  LatLng? _destinationCoordinates;
  bool _isResolvingOrigin = false;
  bool _hasPerformedSearch = false;
  List<LatLng> _routePoints = [];
  String?
  _userCountryCode; // Detected from GPS for country-based search filtering

  @override
  void initState() {
    super.initState();
    // Clear search results immediately to prevent showing old results
    context.read<RideProvider>().clearSearch();

    // Set start location if provided - address is already resolved from reverse geocoding
    if (widget.startName != null) {
      _originController.text = widget.startName!;
      _originCoordinates = widget.startCoordinates; // Store initial coordinates
    }

    // Detect user's country from start coordinates for search filtering
    if (widget.startCoordinates != null) {
      _detectUserCountry(widget.startCoordinates!);
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Detect user's country from GPS coordinates for search filtering
  Future<void> _detectUserCountry(LatLng coordinates) async {
    try {
      final countryCode = await OsmSearchService.detectCountryCode(coordinates);
      if (mounted && countryCode != null) {
        setState(() {
          _userCountryCode = countryCode;
        });
        debugPrint('FindRideScreen: Detected user country: $countryCode');
      }
    } catch (e) {
      debugPrint('FindRideScreen: Failed to detect country: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: BrandColors.primaryRed,
              onPrimary: BrandColors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _performSearch() async {
    // Validate that at least one field is filled
    if (_originController.text.trim().isEmpty &&
        _destinationController.text.trim().isEmpty &&
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in at least one search field'),
          backgroundColor: BrandColors.primaryRed,
        ),
      );
      return;
    }

    final currentUserId = context.read<AuthProvider>().user?.id;

    // Print coordinates for debugging
    debugPrint('Search with coordinates:');
    debugPrint(
      '  Origin: ${_originCoordinates?.latitude}, ${_originCoordinates?.longitude}',
    );
    debugPrint(
      '  Destination: ${_destinationCoordinates?.latitude}, ${_destinationCoordinates?.longitude}',
    );

    // Mark that a search has been performed
    setState(() {
      _hasPerformedSearch = true;
    });

    await context.read<RideProvider>().performSearch(
      origin: _originController.text.trim().isNotEmpty
          ? _originController.text.trim()
          : null,
      destination: _destinationController.text.trim().isNotEmpty
          ? _destinationController.text.trim()
          : null,
      date: _selectedDate,
      excludeDriverId: currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find a Ride',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map Preview (shows origin and destination)
                if (_originCoordinates != null ||
                    _destinationCoordinates != null)
                  _buildMapPreview(),
                // Search Form
                _buildSearchForm(),
                // Results List (constrained height)
                _buildResultsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Origin Field with TypeAhead (now editable)
          _buildOriginField(),
          const SizedBox(height: 16),
          // Destination Field with TypeAhead
          _buildDestinationField(),
          const SizedBox(height: 16),
          // Date Picker
          _buildDatePickerField(),
          const SizedBox(height: 24),
          // Search Button
          _buildSearchButton(),
        ],
      ),
    );
  }

  /// Origin Field with TypeAhead for editable search
  Widget _buildOriginField() {
    return TypeAheadField<Map<String, dynamic>>(
      controller: _originController,
      suggestionsCallback: (pattern) async {
        // Use unified LocationSearchService for consistent autocomplete
        return await LocationSearchService.searchLocations(
          query: pattern,
          currentLocation: widget.startCoordinates,
          userCountryCode: _userCountryCode,
          includeCurrentLocation: true,
        );
      },
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: 'From',
            hintText: 'Enter origin city',
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: Colors.grey[500],
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _originCoordinates = null;
                        _routePoints = [];
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: BrandColors.primaryRed,
                width: 2,
              ),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
            ),
          ),
        );
      },
      itemBuilder: (context, suggestion) {
        final isCurrentLocation = LocationSearchService.isCurrentLocationOption(
          suggestion,
        );
        final displayName = LocationSearchService.getDisplayName(suggestion);
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
      onSelected: (suggestion) async {
        final isCurrentLocation = LocationSearchService.isCurrentLocationOption(
          suggestion,
        );
        final lat = suggestion['lat'] as double;
        final lon = suggestion['lon'] as double;
        final coordinates = LatLng(lat, lon);

        setState(() {
          _originCoordinates = coordinates;
        });

        // If current location, perform reverse geocoding to get real place name
        if (isCurrentLocation) {
          final address = await LocationSearchService.getAddressFromCoordinates(
            coordinates,
          );
          setState(() {
            _originController.text = address;
          });
        } else {
          setState(() {
            _originController.text = LocationSearchService.getDisplayName(
              suggestion,
            );
          });
        }

        print('FindRideScreen: Origin selected - lat: $lat, lon: $lon');
        print('FindRideScreen: Origin LatLng object: $_originCoordinates');

        // Recalculate route if destination is already set
        if (_destinationCoordinates != null) {
          _calculateRoute();
        }
      },
    );
  }

  /// Destination Field with TypeAhead for smart search
  Widget _buildDestinationField() {
    return TypeAheadField<Map<String, dynamic>>(
      controller: _destinationController,
      suggestionsCallback: (pattern) async {
        // Use unified LocationSearchService for consistent autocomplete
        return await LocationSearchService.searchLocations(
          query: pattern,
          currentLocation: widget.startCoordinates,
          userCountryCode: _userCountryCode,
          includeCurrentLocation: true,
        );
      },
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: 'Going to',
            hintText: 'Enter destination city',
            prefixIcon: Icon(
              Icons.flag_outlined,
              color: Colors.grey[500],
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _destinationCoordinates = null;
                        _routePoints = [];
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: BrandColors.primaryRed,
                width: 2,
              ),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
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
      onSelected: (suggestion) async {
        final isCurrentLocation = LocationSearchService.isCurrentLocationOption(
          suggestion,
        );
        final lat = suggestion['lat'] as double;
        final lon = suggestion['lon'] as double;
        final coordinates = LatLng(lat, lon);

        setState(() {
          _destinationCoordinates = coordinates;
        });

        // If current location, perform reverse geocoding to get real place name
        if (isCurrentLocation) {
          final address = await LocationSearchService.getAddressFromCoordinates(
            coordinates,
          );
          setState(() {
            _destinationController.text = address;
          });
        } else {
          setState(() {
            _destinationController.text = suggestion['display_name'] as String;
          });
        }

        print('FindRideScreen: Destination selected - lat: $lat, lon: $lon');
        print(
          'FindRideScreen: Destination LatLng object: $_destinationCoordinates',
        );

        // Move map to show the destination
        _mapController.move(coordinates, 13.0);

        // Calculate route when both points are available
        _calculateRoute();
      },
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          controller: _dateController,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: 'Date (optional)',
            hintText: 'Select date',
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              color: Colors.grey[500],
              size: 20,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: BrandColors.primaryRed,
                width: 2,
              ),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
            ),
            suffixIcon: _selectedDate != null
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                        _dateController.clear();
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    final isSearching = context.watch<RideProvider>().isSearching;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primaryRed.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: isSearching ? Colors.grey[400] : BrandColors.primaryRed,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isSearching ? null : _performSearch,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: isSearching
                ? const SizedBox(
                    height: 20,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: BrandColors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : const Text(
                    'Search Rides',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BrandColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Mini Map Preview with Start and Destination Markers and Route
  Widget _buildMapPreview() {
    final markers = <Marker>[];

    // Green marker for start (origin)
    if (_originCoordinates != null) {
      markers.add(
        Marker(
          point: _originCoordinates!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
    }

    // Red marker for destination
    if (_destinationCoordinates != null) {
      markers.add(
        Marker(
          point: _destinationCoordinates!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    // Determine map center
    LatLng mapCenter;
    if (_originCoordinates != null && _destinationCoordinates != null) {
      // Center between origin and destination
      mapCenter = LatLng(
        (_originCoordinates!.latitude + _destinationCoordinates!.latitude) / 2,
        (_originCoordinates!.longitude + _destinationCoordinates!.longitude) /
            2,
      );
    } else if (_originCoordinates != null) {
      mapCenter = _originCoordinates!;
    } else if (_destinationCoordinates != null) {
      mapCenter = _destinationCoordinates!;
    } else {
      mapCenter = const LatLng(36.8065, 10.1815); // Default: Tunis
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: mapCenter, initialZoom: 13.0),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gexpertise.carpooling',
            ),
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
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  /// Fit camera to show both origin and destination
  void _fitCameraToBounds() {
    if (_originCoordinates != null && _destinationCoordinates != null) {
      final bounds = LatLngBounds(
        _originCoordinates!,
        _destinationCoordinates!,
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  /// Calculate and display route between origin and destination
  Future<void> _calculateRoute() async {
    print('FindRideScreen: _calculateRoute called');
    print('FindRideScreen: Origin coordinates: $_originCoordinates');
    print('FindRideScreen: Destination coordinates: $_destinationCoordinates');

    if (_originCoordinates != null && _destinationCoordinates != null) {
      print(
        'FindRideScreen: Both coordinates available, calling RouteService.calculateRoute',
      );
      print(
        'FindRideScreen: Origin - lat: ${_originCoordinates!.latitude}, lon: ${_originCoordinates!.longitude}',
      );
      print(
        'FindRideScreen: Destination - lat: ${_destinationCoordinates!.latitude}, lon: ${_destinationCoordinates!.longitude}',
      );

      final result = await RouteService.calculateRoute(
        _originCoordinates!,
        _destinationCoordinates!,
      );

      print(
        'FindRideScreen: RouteService returned: ${result != null ? "success" : "null"}',
      );

      if (result != null && mounted) {
        setState(() {
          _routePoints = result.polylinePoints;
        });
        print(
          'FindRideScreen: Route points set: ${_routePoints.length} points',
        );
        _fitCameraToBounds();
      } else {
        print('FindRideScreen: Route calculation failed or returned null');
      }
    } else {
      print('FindRideScreen: Missing coordinates - cannot calculate route');
    }
  }

  Widget _buildResultsList() {
    return Consumer<RideProvider>(
      builder: (context, provider, child) {
        if (provider.isSearching) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              color: BrandColors.primaryRed,
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.primaryRed,
                    foregroundColor: BrandColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        if (provider.searchResults.isEmpty) {
          // Only show "No rides found" if a search was actually performed
          if (!_hasPerformedSearch) {
            return const SizedBox.shrink(); // Return empty widget before first search
          }
          return Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 20),
                Text(
                  'No rides found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your search criteria',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          itemCount: provider.searchResults.length,
          itemBuilder: (context, index) {
            final ride = provider.searchResults[index];
            return RideCard(
              ride: ride,
              onTap: () {
                // Navigate to ride details for booking
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RideDetailsScreen(rideId: ride.id!),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
