import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/osm_search_service.dart';
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
  LatLng? _destinationCoordinates;
  bool _isResolvingOrigin = false;

  @override
  void initState() {
    super.initState();
    // Set start location if provided
    if (widget.startName != null) {
      _originController.text = widget.startName!;

      // If it's "Current Location", resolve it to a real address
      if (widget.startName == 'Current Location' &&
          widget.startCoordinates != null) {
        _resolveCurrentLocation();
      }
    }
    // Clear previous search results when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().clearSearch();
    });
  }

  /// Resolve "Current Location" to a real address using reverse geocoding
  Future<void> _resolveCurrentLocation() async {
    if (widget.startCoordinates == null) return;

    setState(() {
      _isResolvingOrigin = true;
    });

    try {
      final address = await OsmSearchService.getAddressFromCoordinates(
        widget.startCoordinates!,
      );

      if (mounted) {
        setState(() {
          _originController.text = address;
          _isResolvingOrigin = false;
        });
      }
    } catch (e) {
      // Keep "Current Location" if resolution fails
      if (mounted) {
        setState(() {
          _isResolvingOrigin = false;
        });
      }
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
      '  Origin: ${widget.startCoordinates?.latitude}, ${widget.startCoordinates?.longitude}',
    );
    debugPrint(
      '  Destination: ${_destinationCoordinates?.latitude}, ${_destinationCoordinates?.longitude}',
    );

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
        child: Column(
          children: [
            // Map Preview (shows origin and destination)
            if (widget.startCoordinates != null ||
                _destinationCoordinates != null)
              _buildMapPreview(),
            // Search Form (fixed at top)
            _buildSearchForm(),
            // Results List (scrollable)
            Expanded(child: _buildResultsList()),
          ],
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
          // Origin Field
          _buildInputField(
            controller: _originController,
            label: 'Leaving from',
            hint: 'Enter origin city',
            icon: Icons.location_on_outlined,
          ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: BrandColors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
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
          borderSide: const BorderSide(color: BrandColors.primaryRed, width: 2),
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
  }

  /// Destination Field with TypeAhead for smart search
  Widget _buildDestinationField() {
    return TypeAheadField<Map<String, dynamic>>(
      controller: _destinationController,
      suggestionsCallback: (pattern) async {
        if (pattern.length < 2) return [];
        return await OsmSearchService.searchPlaces(pattern);
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
      onSelected: (suggestion) {
        setState(() {
          _destinationController.text = suggestion['display_name'] as String;
          _destinationCoordinates = LatLng(
            suggestion['lat'] as double,
            suggestion['lon'] as double,
          );
          // Move map to show the destination
          _mapController.move(_destinationCoordinates!, 13.0);
        });
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

  /// Mini Map Preview with Start and Destination Markers
  Widget _buildMapPreview() {
    final markers = <Marker>[];

    // Green marker for start (origin)
    if (widget.startCoordinates != null) {
      markers.add(
        Marker(
          point: widget.startCoordinates!,
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
    if (widget.startCoordinates != null && _destinationCoordinates != null) {
      // Center between origin and destination
      mapCenter = LatLng(
        (widget.startCoordinates!.latitude +
                _destinationCoordinates!.latitude) /
            2,
        (widget.startCoordinates!.longitude +
                _destinationCoordinates!.longitude) /
            2,
      );
    } else if (widget.startCoordinates != null) {
      mapCenter = widget.startCoordinates!;
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
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Consumer<RideProvider>(
      builder: (context, provider, child) {
        if (provider.isSearching) {
          return const Center(
            child: CircularProgressIndicator(color: BrandColors.primaryRed),
          );
        }

        if (provider.errorMessage != null) {
          return Center(
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
          return Center(
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
