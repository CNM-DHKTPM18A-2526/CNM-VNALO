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
    (flag: 'VN', name: 'Việt Nam', code: '+84'),
    (flag: 'US', name: 'United States', code: '+1'),
    (flag: 'SG', name: 'Singapore', code: '+65'),
    (flag: 'TH', name: 'Thailand', code: '+66'),
    (flag: 'ID', name: 'Indonesia', code: '+62'),
    (flag: 'JP', name: 'Japan', code: '+81'),
    (flag: 'KR', name: 'Korea', code: '+82'),
  ];

  void _showCountryCodePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _countryCodes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = _countryCodes[index];
              final isSelected = item.code == selectedCountryCode;
              return ListTile(
                onTap: () {
                  onCountryCodeChanged?.call(item.code);
                  Navigator.pop(sheetContext);
                },
                leading: Text(item.flag),
                title: Text(item.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.code),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ],
                ),
              );
            },
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
        prefixIconConstraints: const BoxConstraints(minWidth: 102),
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
