import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/edit_personal_info_screen.dart';

/// "Thông tin cá nhân" screen — displays user's personal info in Vnalo style.
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

    final sectionBg = isDarkMode ? DarkColors.surface : LightColors.surface;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header: Cover + Avatar + Name
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover Photo
                Container(
                  height: 220,
                  width: double.infinity,
                  child: user?.coverUrl != null && user!.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: user.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: auth?.accessToken != null ? {'Authorization': 'Bearer ${auth!.accessToken}'} : const {},
                          errorWidget: (_, __, ___) => _buildDefaultCover(),
                        )
                      : _buildDefaultCover(),
                ),
                // Gradient Overlay for visibility
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                // Back Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Avatar + Name Overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                        ),
                        child: AvatarWidget(
                          imageUrl: user?.avatarUrl,
                          name: displayName,
                          size: 72,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Content Section
            Container(
              color: sectionBg,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    label: 'Giới tính',
                    value: _formatGender(user?.gender),
                    showDivider: true,
                  ),
                  _buildInfoRow(
                    context,
                    label: 'Ngày sinh',
                    value: _formatDob(user?.dob),
                    showDivider: true,
                  ),
                  _buildInfoRow(
                    context,
                    label: 'Điện thoại',
                    value: user?.phone ?? 'Chưa cập nhật',
                    showDivider: false,
                    subtext: 'Số điện thoại chỉ hiển thị với người có lưu số bạn trong danh bạ máy',
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EditPersonalInfoScreen()),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? DarkColors.surfaceLight : const Color(0xFFE5E7EB).withValues(alpha: 0.6),
                          foregroundColor: isDarkMode ? DarkColors.textPrimary : Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool showDivider,
    String? subtext,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? DarkColors.textSecondary : Colors.black54,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                      ),
                    ),
                    if (subtext != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtext,
                        style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: dividerColor),
      ],
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&q=80&w=1000'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
