import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/services/osm_search_service.dart';
import '../../../core/theme/brand_colors.dart';
import '../providers/ride_provider.dart';

/// Create Ride Screen - Smart Ride Creation with Map Preview
///
/// Enhanced ride creation form with pre-filled start location,
/// smart destination search, and mini map showing route preview.
class CreateRideScreen extends StatefulWidget {
  final String? startName;
  final LatLng? startCoordinates;

  const CreateRideScreen({super.key, this.startName, this.startCoordinates});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _commentsController = TextEditingController();
  final MapController _mapController = MapController();

  int _passengerCount = 1;
  bool _isRegular = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _originCoordinates;
  LatLng? _destinationCoordinates;

  String? _resolvedOriginAddress;
  bool _isResolvingOrigin = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill start location if provided
    if (widget.startName != null) {
      _originController.text = widget.startName!;
      _originCoordinates = widget.startCoordinates;

      // If it's "Current Location", resolve it to a real address
      if (widget.startName == 'Current Location' &&
          widget.startCoordinates != null) {
        _resolveCurrentLocation();
      } else {
        _resolvedOriginAddress = widget.startName;
      }
    }
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
          _resolvedOriginAddress = address;
          _originController.text = address;
          _isResolvingOrigin = false;
        });
      }
    } catch (e) {
      // Keep "Current Location" if resolution fails
      if (mounted) {
        setState(() {
          _isResolvingOrigin = false;
          _resolvedOriginAddress = widget.startName;
        });
      }
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _commentsController.dispose();
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
        _selectedTime = picked;
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _publishRide() async {
    // Validate form
    if (_originController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create ride data with GPS coordinates if available
    final rideData = {
      'origin': _originController.text.trim(),
      'destination': _destinationController.text.trim(),
      'origin_lat': _originCoordinates?.latitude,
      'origin_lng': _originCoordinates?.longitude,
      'destination_lat': _destinationCoordinates?.latitude,
      'destination_lng': _destinationCoordinates?.longitude,
      'date': _selectedDate!.toIso8601String(),
      'time':
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'availableSeats': _passengerCount,
      'isRegular': _isRegular,
      'comments': _commentsController.text.trim().isNotEmpty
          ? _commentsController.text.trim()
          : null,
    };

    debugPrint('Publishing ride with data: $rideData');
    debugPrint(
      'Coordinates - Origin: (${_originCoordinates?.latitude}, ${_originCoordinates?.longitude}), Destination: (${_destinationCoordinates?.latitude}, ${_destinationCoordinates?.longitude})',
    );

    try {
      await context.read<RideProvider>().createRide(rideData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BrandColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offer a Ride',
          style: TextStyle(
            color: BrandColors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini Map Preview
              if (widget.startCoordinates != null) _buildMapPreview(),

              const SizedBox(height: 20),

              // Origin Field (Pre-filled)
              _buildOriginField(),
              const SizedBox(height: 16),

              // Destination Field with TypeAhead
              _buildDestinationField(),
              const SizedBox(height: 16),

              // Date and Time Row
              Row(
                children: [
                  Expanded(child: _buildDatePickerField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimePickerField()),
                ],
              ),
              const SizedBox(height: 20),

              // Passenger Count
              _buildPassengerCounter(),
              const SizedBox(height: 20),

              // Ride Type Toggle
              _buildRideTypeToggle(),
              const SizedBox(height: 20),

              // Comments
              _buildCommentsField(),
              const SizedBox(height: 30),

              // Publish Button
              _buildPublishButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Mini Map Preview with Start and Destination Markers
  Widget _buildMapPreview() {
    final markers = <Marker>[];

    // Blue marker for origin
    if (_originCoordinates != null) {
      markers.add(
        Marker(
          point: _originCoordinates!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
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

    return Container(
      height: 140,
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
          options: MapOptions(
            initialCenter:
                widget.startCoordinates ?? const LatLng(36.8065, 10.1815),
            initialZoom: 13.0,
          ),
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

  /// Origin Field with TypeAhead for search
  Widget _buildOriginField() {
    return TypeAheadField<Map<String, dynamic>>(
      controller: _originController,
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
            labelText: 'From',
            hintText: 'Search origin location',
            prefixIcon: const Icon(
              Icons.my_location,
              color: Colors.green,
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        _originCoordinates = null;
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
        final isCurrentLocation = suggestion['is_current_location'] == true;
        return ListTile(
          leading: Icon(
            isCurrentLocation ? Icons.my_location : Icons.location_on,
            color: isCurrentLocation ? Colors.green : Colors.grey,
          ),
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
          _originController.text = suggestion['display_name'] as String;
          _originCoordinates = LatLng(
            suggestion['lat'] as double,
            suggestion['lon'] as double,
          );
        });
      },
    );
  }

  /// Destination Field with TypeAhead
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
            labelText: 'To',
            hintText: 'Enter destination',
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
        final isCurrentLocation = suggestion['is_current_location'] == true;
        return ListTile(
          leading: Icon(
            isCurrentLocation ? Icons.my_location : Icons.location_on,
            color: isCurrentLocation ? Colors.green : Colors.grey,
          ),
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
            labelText: 'Date',
            hintText: 'Select date',
            prefixIcon: Icon(
              Icons.calendar_today,
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
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerField() {
    return GestureDetector(
      onTap: _pickTime,
      child: AbsorbPointer(
        child: TextField(
          controller: _timeController,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: 'Time',
            hintText: 'Select time',
            prefixIcon: Icon(
              Icons.access_time,
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
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Seats',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _passengerCount > 1
                  ? () => setState(() => _passengerCount--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: BrandColors.primaryRed,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                '$_passengerCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _passengerCount < 8
                  ? () => setState(() => _passengerCount++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: BrandColors.primaryRed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRideTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isRegular = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_isRegular
                        ? BrandColors.primaryRed
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isRegular
                          ? BrandColors.primaryRed
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    'One-time',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !_isRegular ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isRegular = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isRegular
                        ? BrandColors.primaryRed
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isRegular
                          ? BrandColors.primaryRed
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    'Regular',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isRegular ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
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

  Widget _buildCommentsField() {
    return TextField(
      controller: _commentsController,
      maxLines: 3,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: BrandColors.black,
      ),
      decoration: InputDecoration(
        labelText: 'Comments (Optional)',
        hintText: 'Add any additional information...',
        alignLabelWithHint: true,
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

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _publishRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'PUBLISH RIDE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
