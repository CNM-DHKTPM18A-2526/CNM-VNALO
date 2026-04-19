import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class OtpInput extends StatelessWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      maxLength: length,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 24,
        letterSpacing: 8,
        fontWeight: FontWeight.w700,
        color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        hintText: '●●●●●●',
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white24 : Colors.black12,
          letterSpacing: 8,
        ),
        counterText: '',
        filled: true,
        fillColor: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? DarkColors.divider : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? DarkColors.primary : AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      onChanged: (value) {
        onChanged?.call(value);
        if (value.length == length) {
          onCompleted(value);
        }
      },
    );
  }
}
