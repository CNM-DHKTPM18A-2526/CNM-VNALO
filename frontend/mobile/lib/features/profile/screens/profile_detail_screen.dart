import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_more_settings_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/personal_info_screen.dart';

/// Full profile detail screen — shows cover photo, avatar, name, bio, info tiles,
/// and action buttons. Similar to Zalo's personal profile page.
class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  // ─── Avatar Bottom Sheet ───
  void _showAvatarOptions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Ảnh đại diện',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, size: 28, color: Colors.black87),
              title: const Text('Xem ảnh đại diện', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _viewImage(context, auth.user?.avatarUrl, 'Ảnh đại diện');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.black87),
              title: const Text('Chọn ảnh trên máy', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpdateAvatar(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_frames_outlined, size: 28, color: Colors.black87),
              title: const Text('Chọn khung ảnh đại diện', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'Chọn khung ảnh đại diện');
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined, size: 28, color: Colors.black87),
              title: const Text('Chọn trang trí ảnh đại diện zStyle', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'Trang trí zStyle');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Cover Photo Bottom Sheet ───
  void _showCoverOptions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Ảnh bìa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.panorama_outlined, size: 28, color: Colors.black87),
              title: const Text('Xem ảnh bìa', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _viewImage(context, auth.user?.coverUrl, 'Ảnh bìa');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.black87),
              title: const Text('Chọn ảnh bìa từ máy', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpdateCover(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── View image fullscreen ───
  void _viewImage(BuildContext context, String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ảnh'), backgroundColor: Colors.orange),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageView(
          imageUrl: imageUrl,
          title: title,
          authToken: auth.accessToken,
        ),
      ),
    );
  }

  // ─── Pick & update avatar ───
  Future<void> _pickAndUpdateAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (picked == null) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.updateAvatar(File(picked.path));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Cập nhật ảnh đại diện thành công!' : auth.error ?? 'Cập nhật thất bại'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // ─── Pick & update cover ───
  Future<void> _pickAndUpdateCover(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85,
    );
    if (picked == null) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.updateCover(File(picked.path));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Cập nhật ảnh bìa thành công!' : auth.error ?? 'Cập nhật thất bại'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — tính năng đang phát triển'), backgroundColor: Colors.orange),
    );
  }

  void _showTimelineVisibilitySheet(BuildContext context) {
    String selected = 'all';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget option({
              required String value,
              required String label,
              String? subtitle,
              bool showChevron = false,
            }) {
              return RadioListTile<String>(
                value: value,
                groupValue: selected,
                activeColor: AppColors.primary,
                onChanged: (v) => setSheetState(() => selected = v ?? selected),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 13, color: LightColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (showChevron) const Icon(Icons.chevron_right, color: LightColors.textHint),
                  ],
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Cho phép bạn bè xem nhật ký',
                              style: TextStyle(fontSize: 24 / 1.2, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: AppColors.sectionDivider),
                    option(value: 'all', label: 'Toàn bộ bài đăng'),
                    option(value: '7d', label: 'Trong 7 ngày gần nhất'),
                    option(value: '1m', label: 'Trong 1 tháng gần nhất'),
                    option(value: '6m', label: 'Trong 6 tháng gần nhất'),
                    option(
                      value: 'custom',
                      label: 'Tùy chỉnh',
                      subtitle: 'Bấm chọn khoảng thời gian',
                      showChevron: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('LƯU'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final displayName = user?.displayName ?? 'Người dùng';
    final token = auth.accessToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkColors.scaffold : LightColors.scaffold,
      body: CustomScrollView(
        slivers: [
          // ─── Cover + Avatar Header ───
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover photo
                GestureDetector(
                  onTap: () => _showCoverOptions(context),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.primaryLight.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: user?.coverUrl != null && user!.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.coverUrl!,
                            fit: BoxFit.cover,
                            httpHeaders: token != null
                                ? {'Authorization': 'Bearer $token'}
                                : const {},
                            errorWidget: (_, __, ___) => _buildCoverPlaceholder(),
                          )
                        : _buildCoverPlaceholder(),
                  ),
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 8,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Menu button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 20),
                        ),
                        onPressed: () => _showTimelineVisibilitySheet(context),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileMoreSettingsScreen(displayName: displayName),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Status bubble
                Positioned(
                  bottom: 60,
                  right: MediaQuery.of(context).size.width * 0.5 - 90,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      user?.statusMessage ?? 'Trạng thái\nhiện tại',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),

                // Avatar (overlapping cover)
                Positioned(
                  bottom: -40,
                  left: 0, right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _showAvatarOptions(context),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: AvatarWidget(imageUrl: user?.avatarUrl, name: displayName, size: 100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Name + Bio Section ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  Text(displayName,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                      color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showComingSoon(context, 'Cập nhật giới thiệu'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(user?.bio ?? 'Cập nhật giới thiệu bản thân',
                          style: const TextStyle(fontSize: 14, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _actionChip(icon: Icons.auto_awesome, label: 'Cài zStyle',
                          color: const Color(0xFFFFA726), onTap: () => _showComingSoon(context, 'Cài zStyle')),
                        const SizedBox(width: 10),
                        _actionChip(icon: Icons.photo_library, label: 'Ảnh của tôi',
                          color: AppColors.primary, onTap: () => _showComingSoon(context, 'Ảnh của tôi')),
                        const SizedBox(width: 10),
                        _actionChip(icon: Icons.inventory_2_outlined, label: 'Kho khoảnh khắc',
                          color: AppColors.primary, onTap: () => _showComingSoon(context, 'Kho khoảnh khắc')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ─── Personal Info Navigation ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : LightColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFF9CA3AF)),
                title: const Text('Thông tin cá nhân',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                  );
                },
              ),
            ),
          ),

          // ─── Timeline Section ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : LightColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                      Positioned(left: -10, top: 5,
                        child: Icon(Icons.favorite, size: 24, color: Colors.red.withValues(alpha: 0.6))),
                      Positioned(right: -10, top: 0,
                        child: Icon(Icons.chat_bubble, size: 24, color: AppColors.primary.withValues(alpha: 0.6))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Hôm nay $displayName có gì vui?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Đây là Nhật ký của bạn - Hãy làm đầy Nhật ký với những dấu ấn cuộc đời và kỷ niệm',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13,
                      color: isDark ? DarkColors.textSecondary : LightColors.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 190,
                    child: ElevatedButton(
                      onPressed: () => _showComingSoon(context, 'Đăng lên Nhật ký'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Đăng lên Nhật ký'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.7),
            AppColors.primaryLight.withValues(alpha: 0.5),
            const Color(0xFF7C4DFF).withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon, required String label,
    required Color color, required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: LightColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ─── Fullscreen Image Viewer ───
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? authToken;

  const _FullScreenImageView({
    required this.imageUrl,
    required this.title,
    this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            httpHeaders: authToken != null
                ? {'Authorization': 'Bearer $authToken'}
                : const {},
            placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, __, error) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text('Không thể tải ảnh',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
