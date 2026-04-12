import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
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
    final sectionBg = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final user = context.watch<AuthProvider?>()?.user;
    final displayName = user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa thông tin',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: true,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: ListView(
        children: [
          Container(
            color: sectionBg,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top section: Avatar Left, Inputs Right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AvatarWidget(
                          imageUrl: user?.avatarUrl,
                          name: displayName,
                          size: 80,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDarkMode ? DarkColors.surfaceLight : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildSimpleEditField(
                            controller: _nameController,
                            isDarkMode: isDarkMode,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _buildSimpleDateField(
                            controller: _dobController,
                            isDarkMode: isDarkMode,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 16),
                // Gender Selection Row
                Row(
                  children: [
                    const SizedBox(width: 4),
                    _buildRadioOption('Nam', 'MALE'),
                    const SizedBox(width: 32),
                    _buildRadioOption('Nữ', 'FEMALE'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.appBarGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật thông tin thành công!')),
                    );
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: const Center(
                    child: Text(
                      'LƯU',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleEditField({
    required TextEditingController controller,
    required bool isDarkMode,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              filled: false,
            ),
            style: TextStyle(fontSize: 16, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
          ),
        ),
        const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
      ],
    );
  }

  Widget _buildSimpleDateField({
    required TextEditingController controller,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            controller.text = "${picked.day}/${picked.month}/${picked.year}";
          });
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                controller.text.isEmpty ? 'Chọn ngày sinh' : controller.text,
                style: TextStyle(fontSize: 16, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
              ),
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
