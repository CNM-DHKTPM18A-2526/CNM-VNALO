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
    return TextField(
      maxLength: length,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: 'Nhập mã OTP',
        counterText: '',
        filled: true,
        fillColor: LightColors.surfaceLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: LightColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary),
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
