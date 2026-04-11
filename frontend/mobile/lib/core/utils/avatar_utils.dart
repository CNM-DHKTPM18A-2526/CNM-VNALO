import 'dart:ui';

/// Utility for generating Google/Vnalo-style initials avatars.
class AvatarUtils {
  AvatarUtils._();

  /// Palette of background colors for initials avatars.
  static const List<Color> _palette = [
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFFFF9800), // orange
    Color(0xFF9C27B0), // purple
    Color(0xFFE91E63), // pink
    Color(0xFF009688), // teal
    Color(0xFFFF5722), // deep orange
    Color(0xFF3F51B5), // indigo
  ];

  /// Extract up to 2 initials from a display name.
  ///
  /// Examples:
  /// - "Đạt Lê"  → "DL"
  /// - "Nguyễn Văn A" → "NA" (first + last word)
  /// - "Minh" → "M"
  static String getInitials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    // First char of first word + first char of last word
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// Pick a deterministic color from the palette based on the name hash.
  static Color getColor(String name) {
    final hash = name.trim().codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _palette[hash % _palette.length];
  }
}
