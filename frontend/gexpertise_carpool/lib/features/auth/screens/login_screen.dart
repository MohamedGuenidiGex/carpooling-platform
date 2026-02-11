import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/brand_text_styles.dart';
import '../providers/auth_provider.dart';

/// Login Screen for GExpertise Carpool - Premium Final Boss UI
///
/// Ultra-modern authentication UI with seamless logo, refined inputs,
/// and premium button styling matching the dashboard aesthetic.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _validationMessage;
  String? _connectionStatus;
  bool _isTestingConnection = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Placeholder validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _validationMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _validationMessage = null;
    });

    // Call provider login (placeholder)
    context.read<AuthProvider>().login(email, password);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final result = await ApiClient.get('/rides/');
      setState(() {
        _connectionStatus =
            'Connection OK: ${result.toString().substring(0, result.toString().length > 50 ? 50 : result.toString().length)}...';
      });
    } on ApiException catch (e) {
      setState(() {
        _connectionStatus =
            'Connection failed: ${e.message} (Status: ${e.statusCode})';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection error: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo - Seamless on white background
                Image.asset(
                  'assets/images/logogexpertise.jpg',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),

                // Sleek subtitle
                Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field - Premium outlined style
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // Password Field - Premium outlined style
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: 32),

                // Validation Message
                if (_validationMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _validationMessage!,
                      style: BrandTextStyles.body.copyWith(
                        color: BrandColors.primaryRed,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Premium Login Button
                _buildPremiumLoginButton(),

                const SizedBox(height: 24),

                // Connection Test Section - PRESERVED EXACTLY AS IS
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Backend Connection Test',
                  style: BrandTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(
                    _isTestingConnection ? 'Testing...' : 'Test Connection',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.darkGray,
                    foregroundColor: BrandColors.white,
                  ),
                ),
                if (_connectionStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _connectionStatus!,
                      style: BrandTextStyles.body.copyWith(
                        color: _connectionStatus!.startsWith('Connection OK')
                            ? BrandColors.success
                            : BrandColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
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
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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

  /// Build premium login button matching dashboard aesthetic
  Widget _buildPremiumLoginButton() {
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
          onTap: _onLoginPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Login',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
