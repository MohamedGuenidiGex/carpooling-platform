import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/brand_colors.dart';
import '../../auth/providers/auth_provider.dart';

/// Profile Screen - Enterprise Identity & Carpool Essentials
///
/// Corporate ID card mixed with vehicle settings. Read-only identity from
/// Microsoft Auth, editable carpool essentials (phone, vehicle).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _carModelController;
  late final TextEditingController _plateNumberController;
  late final TextEditingController _carColorController;

  bool _hasVehicle = false;
  bool _hasChanges = false;
  bool _isInitialized = false;

  // Store original values for change detection
  String _originalPhone = '';
  String _originalCarModel = '';
  String _originalPlateNumber = '';
  String _originalCarColor = '';
  bool _originalHasVehicle = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers empty - will be populated from user data
    _phoneController = TextEditingController();
    _carModelController = TextEditingController();
    _plateNumberController = TextEditingController();
    _carColorController = TextEditingController();
    _addListeners();

    // Refresh profile when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshUserProfile();
    });
  }

  void _saveOriginalValues() {
    _originalPhone = _phoneController.text;
    _originalCarModel = _carModelController.text;
    _originalPlateNumber = _plateNumberController.text;
    _originalCarColor = _carColorController.text;
    _originalHasVehicle = _hasVehicle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update form values from user data whenever it changes
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
      _carModelController.text = user.carModel ?? '';
      _plateNumberController.text = user.carPlate ?? '';
      _carColorController.text = user.carColor ?? '';
      _hasVehicle = user.hasVehicle;

      // Save original values once for change detection
      if (!_isInitialized) {
        _saveOriginalValues();
        _isInitialized = true;
      }
    }
  }

  void _addListeners() {
    _phoneController.addListener(_checkChanges);
    _carModelController.addListener(_checkChanges);
    _plateNumberController.addListener(_checkChanges);
    _carColorController.addListener(_checkChanges);
  }

  void _checkChanges() {
    final hasChanges =
        _phoneController.text != _originalPhone ||
        _carModelController.text != _originalCarModel ||
        _plateNumberController.text != _originalPlateNumber ||
        _carColorController.text != _originalCarColor ||
        _hasVehicle != _originalHasVehicle;

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  void _addVehicle() {
    setState(() {
      _hasVehicle = true;
      _carModelController.text = '';
      _plateNumberController.text = '';
      _carColorController.text = '';
    });
    _checkChanges();
  }

  void _removeVehicle() {
    setState(() => _hasVehicle = false);
    _checkChanges();
  }

  Future<void> _saveChanges() async {
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.updateUserProfile(
      phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      carModel: _hasVehicle
          ? (_carModelController.text.isNotEmpty
                ? _carModelController.text
                : null)
          : '', // Send empty string to clear vehicle
      plate: _hasVehicle
          ? (_plateNumberController.text.isNotEmpty
                ? _plateNumberController.text
                : null)
          : '', // Send empty string to clear vehicle
      color: _hasVehicle
          ? (_carColorController.text.isNotEmpty
                ? _carColorController.text
                : null)
          : '', // Send empty string to clear vehicle
    );

    if (success) {
      // Update controllers with the saved values from server
      final updatedUser = authProvider.user;
      if (updatedUser != null) {
        _phoneController.text = updatedUser.phoneNumber ?? '';
        _carModelController.text = updatedUser.carModel ?? '';
        _plateNumberController.text = updatedUser.carPlate ?? '';
        _carColorController.text = updatedUser.carColor ?? '';
        _hasVehicle = updatedUser.hasVehicle;
      }
      _saveOriginalValues();
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMessage ?? 'Failed to save changes',
            ),
            backgroundColor: BrandColors.primaryRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _carModelController.dispose();
    _plateNumberController.dispose();
    _carColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final userName = user?.displayName ?? 'Employee Name';
    final userEmail = user?.email ?? 'employee@company.com';

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
          'Profile',
          style: TextStyle(
            color: BrandColors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildEnterpriseIdentity(userName, userEmail),
              const SizedBox(height: 24),
              _buildStatsRow(
                ridesCount: user?.ridesOfferedCount ?? 0,
                bookingsCount: user?.bookingsCount ?? 0,
              ),
              const SizedBox(height: 32),
              _buildCarpoolEssentialsForm(),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 40),
              _buildLogoutButton(context),
              const SizedBox(height: 16),
              _buildFooterLinks(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnterpriseIdentity(String name, String email) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: BrandColors.primaryRed.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: BrandColors.primaryRed.withOpacity(0.2),
              width: 3,
            ),
          ),
          child: const Icon(
            Icons.person,
            size: 60,
            color: BrandColors.primaryRed,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: BrandColors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                'Microsoft Entra ID',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow({required int ridesCount, required int bookingsCount}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: 'Rides', value: ridesCount.toString()),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          _StatItem(label: 'Bookings', value: bookingsCount.toString()),
        ],
      ),
    );
  }

  Widget _buildCarpoolEssentialsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Carpool Essentials',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BrandColors.black,
          ),
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          hint: 'Enter your phone number',
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Vehicle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BrandColors.black,
              ),
            ),
            if (_hasVehicle)
              TextButton.icon(
                onPressed: _removeVehicle,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red[400],
                ),
                label: Text(
                  'Remove',
                  style: TextStyle(fontSize: 13, color: Colors.red[400]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_hasVehicle) ...[
          _buildInputField(
            controller: _carModelController,
            label: 'Car Model',
            icon: Icons.directions_car_outlined,
            hint: 'e.g., Golf 7, Civic, Model 3',
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _plateNumberController,
            label: 'Plate Number',
            icon: Icons.confirmation_number_outlined,
            hint: 'e.g., 123 TU 4567',
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _carColorController,
            label: 'Color',
            icon: Icons.palette_outlined,
            hint: 'e.g., Silver, Black, Blue',
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addVehicle,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Vehicle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.primaryRed,
                side: const BorderSide(color: BrandColors.primaryRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: BrandColors.primaryRed,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isUpdating = authProvider.isUpdatingProfile;

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_hasChanges && !isUpdating) ? _saveChanges : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.primaryRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: BrandColors.primaryRed.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: BrandColors.primaryRed,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () async {
            await context.read<AuthProvider>().logout(context);
          },
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: BrandColors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Log Out',
                  style: TextStyle(
                    color: BrandColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {},
          child: Text(
            'Support',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
        Text('•', style: TextStyle(color: Colors.grey[400])),
        TextButton(
          onPressed: () {},
          child: Text(
            'About',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
        Text('•', style: TextStyle(color: Colors.grey[400])),
        TextButton(
          onPressed: () {},
          child: Text(
            'Privacy',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: BrandColors.primaryRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
