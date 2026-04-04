import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/validators.dart';

class PhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final String selectedCountryCode;
  final ValueChanged<String>? onCountryCodeChanged;

  const PhoneInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Số điện thoại',
    this.selectedCountryCode = '+84',
    this.onCountryCodeChanged,
  });

  static const List<({String flag, String name, String code})> _countryCodes = [
    (flag: '🇻🇳', name: 'Việt Nam', code: '+84'),
    (flag: '🇺🇸', name: 'United States', code: '+1'),
    (flag: '🇸🇬', name: 'Singapore', code: '+65'),
    (flag: '🇹🇭', name: 'Thailand', code: '+66'),
    (flag: '🇮🇩', name: 'Indonesia', code: '+62'),
    (flag: '🇯🇵', name: 'Japan', code: '+81'),
    (flag: '🇰🇷', name: 'Korea', code: '+82'),
    (flag: '🇬🇧', name: 'United Kingdom', code: '+44'),
    (flag: '🇦🇺', name: 'Australia', code: '+61'),
    (flag: '🇨🇳', name: 'China', code: '+86'),
  ];

  /// Returns the flag emoji for the currently selected country code.
  String get _selectedFlag {
    final match = _countryCodes.where((c) => c.code == selectedCountryCode);
    return match.isNotEmpty ? match.first.flag : '🌐';
  }

  void _showCountryCodePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Chọn mã vùng',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF141414),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                    child: Column(
                      children: _countryCodes.map((item) {
                        final isSelected = item.code == selectedCountryCode;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Text(
                            item.flag,
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.code,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check,
                                    color: AppColors.primary, size: 24),
                              ],
                            ],
                          ),
                          onTap: () {
                            onCountryCodeChanged?.call(item.code);
                            Navigator.pop(sheetContext);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      validator: Validators.phone,
      onChanged: onChanged,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: const Color(0xFFF9FAFB),
        prefixIconConstraints: const BoxConstraints(minWidth: 110),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Color(0xFFD8DCE2), width: 1),
            ),
          ),
          child: InkWell(
            onTap: () => _showCountryCodePicker(context),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedFlag,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 6),
                Text(
                  selectedCountryCode,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
