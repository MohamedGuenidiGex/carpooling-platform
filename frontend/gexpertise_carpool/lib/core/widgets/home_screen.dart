import 'package:flutter/material.dart';
import '../theme/brand_text_styles.dart';

/// Home Screen for GExpertise Carpool MVP
/// Displays the main landing page with placeholder content
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GExpertise Carpool'),
      ),
      body: Center(
        child: Text(
          'GExpertise Carpool MVP',
          style: BrandTextStyles.header1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}