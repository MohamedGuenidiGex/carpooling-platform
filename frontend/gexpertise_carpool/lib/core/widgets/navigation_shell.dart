import 'package:flutter/material.dart';
import '../../features/rides/screens/rides_screen.dart';

/// Navigation Shell for GExpertise Carpool App
///
/// Provides the main app shell without bottom navigation.
/// Uses a single root screen (RidesScreen) as the home dashboard.
class NavigationShell extends StatelessWidget {
  const NavigationShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RidesScreen();
  }
}
