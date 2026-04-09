import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  String _gender = 'MALE';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider?>()?.user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    final dob = user?.dob;
    _dobController = TextEditingController(
      text: dob == null ? '' : '${dob.day}/${dob.month}/${dob.year}',
    );
    _gender = user?.gender ?? 'MALE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final pageBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.sectionDivider;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Chỉnh sửa thông tin'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            color: sectionBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 28, child: Icon(Icons.person)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Tên hiển thị',
                            labelStyle: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                        ),
                      ),
                      Icon(Icons.edit_outlined, color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary),
                    ],
                  ),
                  Divider(height: 20, color: dividerColor),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dobController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ngày sinh',
                            hintStyle: TextStyle(color: isDarkMode ? DarkColors.textHint : LightColors.textHint),
                          ),
                          style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                        ),
                      ),
                      Icon(Icons.edit_outlined, color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary),
                    ],
                  ),
                  Divider(height: 20, color: dividerColor),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'MALE',
                          groupValue: _gender,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nam', style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)),
                          onChanged: (v) => setState(() => _gender = v ?? 'MALE'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'FEMALE',
                          groupValue: _gender,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nữ', style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary)),
                          onChanged: (v) => setState(() => _gender = v ?? 'FEMALE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu (fallback UI).')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('LƯU'),
            ),
          ),
        ],
      ),
    );
  }
}
