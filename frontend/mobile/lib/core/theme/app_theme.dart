import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  // Dark theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true, // Enable Material 3 design
    brightness: Brightness.dark, // Set the brightness to dark
    scaffoldBackgroundColor: DarkColors.scaffold,
    primaryColor: AppColors.primary,

    // Define the color scheme for the dark theme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: DarkColors.surface,
      error: AppColors.error,
    ),

    // Define the app bar theme for the dark theme
    appBarTheme: AppBarTheme(
      backgroundColor: DarkColors.scaffold,
      elevation: 0,
      titleTextStyle: AppTypography.titleLarge,
      iconTheme: const IconThemeData(color: DarkColors.textPrimary),
    ),

    // Define the bottom navigation bar theme for the dark theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DarkColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: DarkColors.textHint,
      type: BottomNavigationBarType.fixed,
    ),

    // Define the input decoration theme for the dark theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DarkColors.surface,
      hintStyle: AppTypography.bodyMedium.copyWith(color: DarkColors.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Define the elevated button theme for the dark theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Define the text theme for the dark theme
    dividerColor: DarkColors.divider,
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightColors.scaffold,
    primaryColor: AppColors.primary,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: LightColors.surface,
      error: AppColors.error,
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: LightColors.appBarBg,
      titleTextStyle: AppTypography.titleLarge.copyWith(color: Colors.white),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: LightColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: LightColors.textHint,
      type: BottomNavigationBarType.fixed,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LightColors.surfaceLight,
      hintStyle: AppTypography.bodyMedium.copyWith(color: LightColors.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    dividerColor: LightColors.divider,
  );
}
