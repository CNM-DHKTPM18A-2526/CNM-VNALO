import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  // Dark theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DarkColors.scaffold,
    primaryColor: DarkColors.primary,

    colorScheme: const ColorScheme.dark(
      primary: DarkColors.primary,
      secondary: DarkColors.primaryLight,
      surface: DarkColors.surface,
      error: AppColors.error,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: DarkColors.appBarBg,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      toolbarHeight: 52,
      titleTextStyle: AppTypography.titleLarge.copyWith(color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DarkColors.surface,
      selectedItemColor: DarkColors.primary,
      unselectedItemColor: DarkColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DarkColors.surface,
      hintStyle: AppTypography.bodyMedium.copyWith(color: DarkColors.textHint),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DarkColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // Modal Themes
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DarkColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DarkColors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.titleLarge.copyWith(color: DarkColors.textPrimary),
      contentTextStyle: AppTypography.bodyLarge.copyWith(color: DarkColors.textSecondary),
    ),

    dividerColor: DarkColors.divider,
    splashColor: AppColors.itemPressBackground.withValues(alpha: 0.22),
    highlightColor: AppColors.itemPressBackground.withValues(alpha: 0.16),
    hoverColor: AppColors.itemPressBackground.withValues(alpha: 0.1),
    listTileTheme: const ListTileThemeData(
      dense: false,
      enableFeedback: true,
    ),
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
      toolbarHeight: 52,
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
    splashColor: AppColors.itemPressBackground.withValues(alpha: 0.7),
    highlightColor: AppColors.itemPressBackground,
    hoverColor: AppColors.itemPressBackground.withValues(alpha: 0.6),
    listTileTheme: const ListTileThemeData(
      dense: false,
      enableFeedback: true,
    ),
  );
}
