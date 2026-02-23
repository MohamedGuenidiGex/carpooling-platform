import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/brand_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BrandColors.black),
        title: Text(
          'About',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: BrandColors.black,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _buildAppIdentity(),
              const SizedBox(height: 20),
              _buildSectionHeader('Credits'),
              const SizedBox(height: 10),
              _buildDeveloperCard(context),
              const SizedBox(height: 20),
              _buildSectionHeader('Built With'),
              const SizedBox(height: 10),
              _buildTechStack(),
              const Spacer(),
              const SizedBox(height: 16),
              _buildFooter(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIdentity() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BrandColors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/logogexpertise.jpg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'GExpertise Carpool',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: BrandColors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version 1.0.0 – Alpha',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: BrandColors.mediumGray,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enterprise mobility solution for GExpertise employees.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: BrandColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BrandColors.mediumGray,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BrandColors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mohamed Guenidi',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: BrandColors.black,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Computer Science Student',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: BrandColors.mediumGray,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: BrandColors.primaryRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PFE 2026',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.primaryRed,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  'End-of-Study Project',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: BrandColors.darkGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildSocialButton(
                  icon: FontAwesomeIcons.linkedin,
                  label: 'LinkedIn',
                  color: const Color(0xFF0A66C2),
                  onTap: () => _launchUri(
                    context,
                    Uri.parse('https://www.linkedin.com/in/mohamed-guenidi/'),
                  ),
                ),
                const SizedBox(width: 10),
                _buildSocialButton(
                  icon: FontAwesomeIcons.github,
                  label: 'GitHub',
                  color: BrandColors.black,
                  onTap: () => _launchUri(
                    context,
                    Uri.parse('https://github.com/MohamedGuenidiGex'),
                  ),
                ),
                const SizedBox(width: 10),
                _buildSocialButton(
                  icon: FontAwesomeIcons.envelope,
                  label: 'Email',
                  color: BrandColors.primaryRed,
                  onTap: () => _launchUri(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: 'contact@gexpertise.fr',
                      queryParameters: {
                        'subject': 'GExpertise Carpool - Contact',
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: BrandColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.lightGray),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.darkGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechStack() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: BrandColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BrandColors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTechLogo(
              imagePath: 'assets/images/flutterLogo.png',
              label: 'Flutter',
            ),
            _buildTechLogo(
              imagePath: 'assets/images/python.png',
              label: 'Python',
            ),
            _buildTechLogo(
              imagePath: 'assets/images/postgres.png',
              label: 'PostgreSQL',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechLogo({required String imagePath, required String label}) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BrandColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.lightGray),
          ),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BrandColors.darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: BrandColors.lightGray)),
      ),
      child: Column(
        children: [
          Text(
            '© GExpertise 2026',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BrandColors.darkGray,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'All rights reserved',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: BrandColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}
