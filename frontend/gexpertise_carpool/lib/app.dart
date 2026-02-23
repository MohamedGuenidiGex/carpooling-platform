import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/brand_theme.dart';
import 'core/widgets/navigation_shell.dart';
import 'features/admin/providers/admin_analytics_provider.dart';
import 'features/admin/providers/admin_monitoring_provider.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/reservations/providers/reservation_provider.dart';
import 'features/rides/providers/ride_provider.dart';

/// GExpertise Carpool Application
///
/// Main app entry point with enterprise theme, authentication state management,
/// and conditional routing between login and main navigation.
class GExpertiseCarpoolApp extends StatelessWidget {
  const GExpertiseCarpoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AdminAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => AdminMonitoringProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'GExpertise Carpool',
        debugShowCheckedModeBanner: false,
        theme: BrandTheme.brandTheme,
        home: const AuthRouter(),
      ),
    );
  }
}

/// Auth Router Widget
///
/// Listens to authentication state and routes between LoginScreen
/// and NavigationShell based on isAuthenticated status.
class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthRouterBody();
  }
}

class _AuthRouterBody extends StatefulWidget {
  const _AuthRouterBody();

  @override
  State<_AuthRouterBody> createState() => _AuthRouterBodyState();
}

class _AuthRouterBodyState extends State<_AuthRouterBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, bool>(
      selector: (_, provider) => provider.isAuthenticated,
      builder: (context, isAuthenticated, child) {
        debugPrint(
          'AuthRouter: Building with isAuthenticated=$isAuthenticated',
        );
        // Show loading overlay only during initial app startup
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isLoading && authProvider.user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (isAuthenticated) {
          debugPrint('AuthRouter: User is authenticated, showing main screen');
          if (authProvider.user?.role == 'admin') {
            return const AdminDashboardScreen();
          }

          return const NavigationShell();
        }

        debugPrint(
          'AuthRouter: User is not authenticated, showing LoginScreen',
        );
        return const LoginScreen();
      },
    );
  }
}
