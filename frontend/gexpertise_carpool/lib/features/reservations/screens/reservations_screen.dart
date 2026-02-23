import 'package:flutter/material.dart';
import '../../../core/theme/brand_text_styles.dart';

/// Reservations Screen - Displays user's ride reservations
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
      ),
      body: SafeArea(
        child: Center(
          child: Text(
            'Reservations Screen',
            style: BrandTextStyles.header2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}