import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';

/// Offer a Ride Screen - Premium Ride Creation Form
///
/// Clean, modern UI for drivers to publish new rides with
/// all necessary details: origin, destination, date, time,
/// seats, ride type, and optional comments.
class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _commentsController = TextEditingController();

  int _passengerCount = 1;
  bool _isRegular = false; // false = One-time, true = Regular
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _commentsController.dispose();
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

  void _publishRide() {
    // Validate form
    if (_originController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: BrandColors.primaryRed,
        ),
      );
      return;
    }

    // Print data to console (backend integration next)
    final rideData = {
      'origin': _originController.text.trim(),
      'destination': _destinationController.text.trim(),
      'date': _selectedDate?.toIso8601String(),
      'time': '${_selectedTime?.hour}:${_selectedTime?.minute}',
      'passengers': _passengerCount,
      'rideType': _isRegular ? 'Regular' : 'One-time',
      'comments': _commentsController.text.trim(),
    };

    debugPrint('Publishing Ride: $rideData');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride published successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
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
          'Offer a Ride',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Origin Field
              _buildInputField(
                controller: _originController,
                label: 'Leaving from',
                hint: 'Enter departure location',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 20),

              // Destination Field
              _buildInputField(
                controller: _destinationController,
                label: 'Going to',
                hint: 'Enter destination',
                icon: Icons.flag_outlined,
              ),
              const SizedBox(height: 20),

              // Date & Time Row
              Row(
                children: [
                  // Date Picker
                  Expanded(
                    child: _buildPickerField(
                      controller: _dateController,
                      label: 'Date',
                      hint: 'Select date',
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Time Picker
                  Expanded(
                    child: _buildPickerField(
                      controller: _timeController,
                      label: 'Time',
                      hint: 'Select time',
                      icon: Icons.access_time_outlined,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Passengers Counter
              _buildPassengerCounter(),
              const SizedBox(height: 24),

              // Ride Type Toggle
              _buildRideTypeToggle(),
              const SizedBox(height: 24),

              // Comments Field
              _buildInputField(
                controller: _commentsController,
                label: 'Comments / Notes',
                hint: 'Meeting point, preferences, etc.',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 40),

              // Publish Button
              _buildPublishButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build premium outlined input field
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: BrandColors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BrandColors.primaryRed, width: 2),
        ),
        labelStyle: TextStyle(
          fontSize: 14,
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

  /// Build date/time picker field (read-only)
  Widget _buildPickerField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: BrandColors.black,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: BrandColors.primaryRed, width: 2),
            ),
            labelStyle: TextStyle(
              fontSize: 14,
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

  /// Build sleek passenger counter
  Widget _buildPassengerCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey[500], size: 24),
              const SizedBox(width: 12),
              Text(
                'Available Seats',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Decrease button
              _buildCounterButton(
                icon: Icons.remove,
                onPressed: _passengerCount > 1
                    ? () => setState(() => _passengerCount--)
                    : null,
              ),
              const SizedBox(width: 16),
              // Count display
              Text(
                '$_passengerCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.black,
                ),
              ),
              const SizedBox(width: 16),
              // Increase button
              _buildCounterButton(
                icon: Icons.add,
                onPressed: _passengerCount < 4
                    ? () => setState(() => _passengerCount++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build counter button
  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onPressed != null ? BrandColors.primaryRed : Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: BrandColors.white),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  /// Build ride type toggle (One-time vs Regular)
  Widget _buildRideTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // One-time option
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegular = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isRegular ? BrandColors.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'One-time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: !_isRegular ? BrandColors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          // Regular option
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegular = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isRegular ? BrandColors.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Regular',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isRegular ? BrandColors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build premium publish button
  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primaryRed.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: BrandColors.primaryRed,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _publishRide,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Text(
              'Publish Ride',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
