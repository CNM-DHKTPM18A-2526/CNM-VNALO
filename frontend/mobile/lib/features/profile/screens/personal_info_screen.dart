import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

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
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final displayName = user?.displayName ?? 'Người dùng';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: Column(
        children: [
          // ─── White card with avatar + info rows ───
          Container(
            margin: const EdgeInsets.only(top: 0),
            color: Colors.white,
            child: Column(
              children: [
                // Avatar centered
                const SizedBox(height: 28),
                Center(
                  child: AvatarWidget(
                    imageUrl: user?.avatarUrl,
                    name: displayName,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 28),

                // Info rows
                _buildInfoRow(
                  icon: Icons.account_circle_outlined,
                  label: 'Tên VNALO',
                  value: displayName,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),

                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ngày sinh',
                  value: _formatDob(user?.dob),
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),

                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Giới tính',
                  value: _formatGender(user?.gender),
                ),
                const SizedBox(height: 8),

                // ─── Edit button ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: navigate to edit profile screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chức năng chỉnh sửa đang phát triển'),
                            backgroundColor: Colors.orange,
                          ),
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
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
