import 'package:flutter/material.dart';

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();
  // Primary
  static const Color primary = Color(0xFF0068FF);
  static const Color primaryLight = Color(0xFF00A2ED);
  static const Color primaryDark = Color(0xFF0050CC);

  // ─── Semantic ───
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color online = Color(0xFF22C55E);
  static const Color unreadBadge = Color(0xFFEF4444);
  static const Color pinIcon = Color(0xFFF59E0B);

  // Shared UI tokens (aligned with main settings screens)
  static const LinearGradient appBarGradient = LinearGradient(
    // Search/app bars: softer left blue, stronger right blue.
    colors: [Color(0xFF2A8DF8), Color(0xFF008CFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const Color sectionBackground = Color(0xFFF4F5F7);
  static const Color sectionDivider = Color(0xFFE5E7EB);
  static const Color itemDivider = Color(0xFFE9EDF3);
  static const Color iconSubtle = Color(0xFF5D6470);
  static const Color itemPressBackground = Color(0xFFEFF2F6);
}

// Dark and Light color palettes
class DarkColors {
  DarkColors._();
  static const Color scaffold = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF242424);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textHint = Color(0xFF808080);
  static const Color divider = Color(0xFF333333);
  static const Color chatBubbleSent = Color(0xFF0068FF);
  static const Color chatBubbleReceived = Color(0xFF3A3A3A);
  static const Color appBarBg = Color(0xFF1A1A1A);
}

class LightColors {
  LightColors._();
  static const Color scaffold = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF0F0F0);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color chatBubbleSent = Color(0xFF0068FF);
  static const Color chatBubbleReceived = Color(0xFFE8E8E8);
  static const Color appBarBg = Color(0xFF0068FF);
}
