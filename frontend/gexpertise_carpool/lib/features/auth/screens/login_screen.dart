import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/brand_text_styles.dart';
import '../../../core/widgets/navigation_shell.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with AutomaticKeepAliveClientMixin<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _validationMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('*** LoginScreen: initState called ***');
  }

  @override
  void dispose() {
    debugPrint('*** LoginScreen: dispose called ***');
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

    _login(email, password);
  }

  Future<void> _login(String email, String password) async {
    final provider = context.read<AuthProvider>();

    // Clear any previous error first
    setState(() {
      _validationMessage = null;
    });

    try {
      await provider.login(email, password);
      // Login successful - navigate based on role
      if (mounted) {
        final user = provider.user;
        if (user != null && user.role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NavigationShell()),
          );
        }
      }
    } on Exception catch (e) {
      debugPrint('*** LoginScreen: Exception caught: $e ***');
      if (!mounted) {
        debugPrint('*** LoginScreen: not mounted, returning ***');
        return;
      }
      final msg = e.toString().replaceAll('Exception: ', '');
      debugPrint('*** LoginScreen: Setting _validationMessage to: $msg ***');
      setState(() {
        _validationMessage = msg.isNotEmpty
            ? msg
            : 'Login failed. Please try again.';
      });
      debugPrint('*** LoginScreen: setState completed ***');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    debugPrint(
      '*** LoginScreen: build called, _validationMessage=$_validationMessage ***',
    );
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
