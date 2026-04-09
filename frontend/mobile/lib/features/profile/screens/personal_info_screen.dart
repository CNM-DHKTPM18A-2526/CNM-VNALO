import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/edit_personal_info_screen.dart';

/// "Thông tin cá nhân" screen — displays user's personal info in Zalo style.
/// Shows avatar, name, birthday, gender with a blue gradient app bar.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  String _formatGender(String? gender) {
    switch (gender?.toUpperCase()) {
      case 'MALE':
        return 'Nam';
      case 'FEMALE':
        return 'Nữ';
      case 'UNKNOWN':
      case 'OTHER':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  String _formatDob(DateTime? dob) {
    if (dob == null) return 'Chưa cập nhật';
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider?>();
    final user = auth?.user;
    final displayName = user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg,
        foregroundColor: Colors.white,
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: AvatarWidget(
                    imageUrl: user?.avatarUrl,
                    name: displayName,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 18),
                _buildInfoRow(
                  icon: Icons.account_circle_outlined,
                  label: 'Tên Zalo',
                  value: displayName,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.sectionDivider),

                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ngày sinh',
                  value: _formatDob(user?.dob),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.sectionDivider),

                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Giới tính',
                  value: _formatGender(user?.gender),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditPersonalInfoScreen()),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Chỉnh sửa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LightColors.textPrimary,
                        backgroundColor: AppColors.itemPressBackground,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
