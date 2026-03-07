import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/brand_colors.dart';

/// Driver info tooltip anchored to car marker
///
/// Displays driver information in a compact tooltip-style panel
/// positioned above the car marker with a pointer triangle.
class DriverInfoTooltip extends StatelessWidget {
  final LatLng driverPosition;
  final String driverName;
  final String driverInitial;
  final String? carModel;
  final String? carColor;
  final String? eta;
  final VoidCallback onClose;

  const DriverInfoTooltip({
    super.key,
    required this.driverPosition,
    required this.driverName,
    required this.driverInitial,
    this.carModel,
    this.carColor,
    this.eta,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tooltip content with pointer triangle
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main tooltip card
            Container(
              constraints: const BoxConstraints(maxWidth: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Driver avatar/initial
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: BrandColors.primaryRed,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              driverInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Driver name
                        Expanded(
                          child: Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Close button
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Car info
                        if (carModel != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  carModel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (carColor != null) const SizedBox(height: 2),
                        ],

                        // Car color
                        if (carColor != null) ...[
                          Text(
                            carColor!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ETA
                        if (eta != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: BrandColors.primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 11,
                                  color: BrandColors.primaryRed,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'ETA $eta',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BrandColors.primaryRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pointer triangle
            CustomPaint(size: const Size(16, 8), painter: _TrianglePainter()),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for the pointer triangle
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2 - 8, 0) // Top left
      ..lineTo(size.width / 2, size.height) // Bottom point
      ..lineTo(size.width / 2 + 8, 0) // Top right
      ..close();

    // Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.15), 2, false);

    // Triangle
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
