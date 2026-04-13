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
        fontSize: 18,
        letterSpacing: 4,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        hintText: 'Nháº­p mÃ£ OTP',
        counterText: '',
        filled: true,
        fillColor: isDarkMode ? DarkColors.surface : LightColors.surfaceLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : LightColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDarkMode ? DarkColors.primary : AppColors.primary, width: 2),
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
