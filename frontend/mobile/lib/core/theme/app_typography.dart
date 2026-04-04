import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTypography defines all text styles used in the app.
/// Colors are NOT hardcoded here — styles should be applied with
/// Theme.of(context).textTheme or overridden per-widget.
/// This class only defines sizes, weights, and font family.
class AppTypography {
  AppTypography._();

  static TextStyle get _baseStyle => GoogleFonts.inter();

  // Headers
  static TextStyle displayLarge = _baseStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static TextStyle displayMedium = _baseStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle titleLarge = _baseStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle titleMedium = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Body
  static TextStyle bodyLarge = _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodyMedium = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodySmall = _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // Labels
  static TextStyle labelLarge = _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static TextStyle labelSmall = _baseStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}
