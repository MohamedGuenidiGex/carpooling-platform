import 'package:flutter/material.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/gexpertise_drawer.dart';
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';

/// Rides Screen - Premium Dashboard for Carpooling
///
/// Clean, modern, "final boss" UI with seamless logo integration
/// and premium action buttons.
class RidesScreen extends StatelessWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BrandColors.black, size: 28),
      ),
      drawer: const GExpertiseDrawer(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // GExpertise Logo - Seamless, no container
                Image.asset(
                  'assets/images/logogexpertise.jpg',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 60),

                // Find a Ride Button - Premium
                _PremiumActionButton(
                  label: 'FIND A RIDE',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FindRideScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Offer a Ride Button - Premium
                _PremiumActionButton(
                  label: 'OFFER A RIDE',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OfferRideScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium Action Button Widget
///
/// Ultra-modern button with soft shadow, sleek radius, and bold typography.
class _PremiumActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PremiumActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              label,
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
