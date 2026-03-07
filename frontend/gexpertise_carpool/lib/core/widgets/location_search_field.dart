import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_search_service.dart';
import '../theme/brand_colors.dart';

/// Unified Location Search Field Widget
///
/// Provides consistent autocomplete search behavior across all screens.
/// Used by Home screen, Offer Ride screen, and Find Ride screen.
class LocationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final Color? prefixIconColor;
  final LatLng? currentLocation;
  final String? userCountryCode;
  final bool includeCurrentLocation;
  final Function(Map<String, dynamic>) onLocationSelected;
  final VoidCallback? onClear;
  final bool enabled;

  const LocationSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.prefixIconColor,
    this.currentLocation,
    this.userCountryCode,
    this.includeCurrentLocation = true,
    required this.onLocationSelected,
    this.onClear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      controller: controller,
      focusNode: focusNode,
      suggestionsCallback: (pattern) async {
        // Use unified search service with partial text matching
        return await LocationSearchService.searchLocations(
          query: pattern,
          currentLocation: currentLocation,
          userCountryCode: userCountryCode,
          includeCurrentLocation: includeCurrentLocation,
        );
      },
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: Icon(
              prefixIcon,
              color: prefixIconColor ?? Colors.grey[500],
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      if (onClear != null) onClear!();
                    },
                  )
                : null,
            filled: true,
            fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
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
      onSelected: (suggestion) {
        if (LocationSearchService.isValidLocation(suggestion)) {
          onLocationSelected(suggestion);
        }
      },
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No locations found',
          style: TextStyle(color: Colors.grey, fontSize: 14),
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
          'Search error. Please try again.',
          style: TextStyle(color: Colors.red[700], fontSize: 14),
        ),
      ),
    );
  }
}
