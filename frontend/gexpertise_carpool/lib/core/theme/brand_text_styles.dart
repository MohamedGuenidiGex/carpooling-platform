import 'package:flutter/material.dart';
import 'brand_colors.dart';

/// GExpertise Brand Typography System
/// Enterprise typography using system default fonts (Roboto/San Francisco)
class BrandTextStyles {
  static const TextStyle header1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: BrandColors.black,
  );

  static const TextStyle header2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: BrandColors.darkGray,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: BrandColors.darkGray,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: BrandColors.white,
  );
}