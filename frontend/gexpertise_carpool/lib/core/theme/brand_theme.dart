import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'brand_text_styles.dart';

/// GExpertise Brand Theme
/// Enterprise Material 3 theme with exact design tokens
class BrandTheme {
  /// Reusable primary button style
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: BrandColors.primaryRed,
    foregroundColor: BrandColors.white,
    textStyle: BrandTextStyles.button,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  /// Reusable input decoration theme
  static final InputDecorationTheme inputTheme = InputDecorationTheme(
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandColors.primaryRed),
    ),
  );

  /// Primary brand theme for the application
  static ThemeData get brandTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: BrandColors.primaryRed,
      scaffoldBackgroundColor: BrandColors.background,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButton,
      ),
      inputDecorationTheme: inputTheme,
      textTheme: const TextTheme(
        headlineLarge: BrandTextStyles.header1,
        headlineMedium: BrandTextStyles.header2,
        bodyLarge: BrandTextStyles.body,
        labelLarge: BrandTextStyles.button,
      ),
    );
  }
}