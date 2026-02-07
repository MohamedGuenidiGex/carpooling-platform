import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/brand_text_styles.dart';
import '../../../core/theme/brand_theme.dart';
import '../providers/auth_provider.dart';

/// Login Screen for GExpertise Carpool
///
/// Provides email/password authentication UI with brand styling.
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Company Title
                Text(
                  'GExpertise Carpool',
                  style: BrandTextStyles.header1.copyWith(
                    color: BrandColors.primaryRed,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: BrandTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                ),
                const SizedBox(height: 24),

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

                // Login Button
                ElevatedButton(
                  onPressed: _onLoginPressed,
                  style: BrandTheme.primaryButton,
                  child: const Text('Login'),
                ),

                const SizedBox(height: 24),

                // Connection Test Section
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
}
