import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/localization/profile_texts.dart';
import 'package:vnalo_mobile/features/profile/screens/profile_more_settings_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/personal_info_screen.dart';

/// Full profile detail screen — shows cover photo, avatar, name, bio, info tiles,
/// and action buttons. Similar to Vnalo's personal profile page.
class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({super.key});

  // ——— Avatar Bottom Sheet ———
  void _showAvatarOptions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = ProfileTexts.of(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : LightColors.surface,
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
                  color: isDark ? DarkColors.divider : LightColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                t.language == AppLanguage.vi ? 'Ảnh đại diện' : 'Profile picture',
                style: TextStyle(
                  fontSize: 17, 
                  fontWeight: FontWeight.w600, 
                  color: isDark ? DarkColors.primary : AppColors.primary
                )
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.account_circle_outlined, size: 28, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary),
              title: Text(
                t.language == AppLanguage.vi ? 'Xem ảnh đại diện' : 'View profile picture',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _viewImage(context, auth.user?.avatarUrl, t.language == AppLanguage.vi ? 'Ảnh đại diện' : 'Profile picture');
              },
            ),
            ListTile(
              leading: Icon(Icons.add_photo_alternate_outlined, size: 28, color: isDark ? DarkColors.textPrimary : Colors.black87),
              title: Text(
                t.language == AppLanguage.vi ? 'Chọn ảnh từ máy' : 'Choose from gallery',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : Colors.black87)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpdateAvatar(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.filter_frames_outlined, size: 28, color: isDark ? DarkColors.textPrimary : Colors.black87),
              title: Text(
                t.language == AppLanguage.vi ? 'Chọn khung ảnh đại diện' : 'Choose avatar frame',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : Colors.black87)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, t.language == AppLanguage.vi ? 'Chọn khung ảnh' : 'Choose frame');
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined, size: 28, color: isDark ? DarkColors.textPrimary : Colors.black87),
              title: Text(
                t.language == AppLanguage.vi ? 'Trang trí vnStyle' : 'vnStyle Decoration',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : Colors.black87)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'vnStyle');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ——— Cover Photo Bottom Sheet ———
  void _showCoverOptions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = ProfileTexts.of(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : LightColors.surface,
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
                  color: isDark ? DarkColors.divider : LightColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                t.language == AppLanguage.vi ? 'Ảnh bìa' : 'Cover photo',
                style: TextStyle(
                  fontSize: 17, 
                  fontWeight: FontWeight.w600, 
                  color: isDark ? DarkColors.textPrimary : AppColors.primary
                )
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.panorama_outlined, size: 28, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary),
              title: Text(
                t.language == AppLanguage.vi ? 'Xem ảnh bìa' : 'View cover photo',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)
              ),
              onTap: () {
                Navigator.pop(ctx);
                _viewImage(context, auth.user?.coverUrl, t.language == AppLanguage.vi ? 'Ảnh bìa' : 'Cover photo');
              },
            ),
            ListTile(
              leading: Icon(Icons.add_photo_alternate_outlined, size: 28, color: isDark ? DarkColors.textPrimary : Colors.black87),
              title: Text(
                t.language == AppLanguage.vi ? 'Chọn ảnh bìa từ máy' : 'Choose cover from gallery',
                style: TextStyle(fontSize: 15, color: isDark ? DarkColors.textPrimary : Colors.black87)
              ),
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

  // ——— View image fullscreen ———
  void _viewImage(BuildContext context, String? imageUrl, String title) {
    if (imageUrl == null || imageUrl.isEmpty) {
      final t = ProfileTexts.of(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.language == AppLanguage.vi ? 'Chưa có ảnh' : 'No image available'), 
          backgroundColor: Colors.orange
        ),
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

  // ——— Pick & update avatar ———
  Future<void> _pickAndUpdateAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final t = ProfileTexts.of(context, listen: false);
    final auth = context.read<AuthProvider>();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (picked == null) return;

    final success = await auth.updateAvatar(File(picked.path));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? t.updateSuccess : auth.error ?? t.updateFailed),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // ——— Pick & update cover ———
  Future<void> _pickAndUpdateCover(BuildContext context) async {
    final picker = ImagePicker();
    final t = ProfileTexts.of(context, listen: false);
    final auth = context.read<AuthProvider>();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85,
    );
    if (picked == null) return;

    final success = await auth.updateCover(File(picked.path));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? t.updateSuccess : auth.error ?? t.updateFailed),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    final common = CommonTexts.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — ${common.comingSoon}'), backgroundColor: Colors.orange),
    );
  }

  void _showTimelineVisibilitySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = ProfileTexts.of(context, listen: false);
    String selected = 'all';
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? DarkColors.surface : Colors.white,
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
                activeColor: isDark ? DarkColors.primary : AppColors.primary,
                onChanged: (v) => setSheetState(() => selected = v ?? selected),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(fontSize: 13, color: isDark ? DarkColors.textSecondary : LightColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (showChevron) Icon(Icons.chevron_right, color: isDark ? DarkColors.textHint : LightColors.textHint),
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
                        Expanded(
                          child: Center(
                            child: Text(
                              t.language == AppLanguage.vi ? 'Cho phép bạn bè xem nhật ký' : 'Allow friends to view timeline',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    option(value: 'all', label: t.language == AppLanguage.vi ? 'Toàn bộ bài đăng' : 'All posts'),
                    option(value: '7d', label: t.language == AppLanguage.vi ? 'Trong 7 ngày gần nhất' : 'Last 7 days'),
                    option(value: '1m', label: t.language == AppLanguage.vi ? 'Trong 1 tháng gần nhất' : 'Last month'),
                    option(value: '6m', label: t.language == AppLanguage.vi ? 'Trong 6 tháng gần nhất' : 'Last 6 months'),
                    option(
                      value: 'custom',
                      label: t.language == AppLanguage.vi ? 'Tùy chỉnh' : 'Custom',
                      subtitle: t.language == AppLanguage.vi ? 'Bấm chọn khoảng thời gian' : 'Select date range',
                      showChevron: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? DarkColors.primary : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(t.saveAction, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final t = ProfileTexts.of(context);
    final displayName = user?.displayName ?? t.notUpdated;
    final token = auth.accessToken;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkColors.scaffold : LightColors.scaffold,
      body: CustomScrollView(
        slivers: [
          // ——— Cover + Avatar Header ———
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
                            placeholder: (_, __) => _buildCoverPlaceholder(),
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
                      color: isDark ? DarkColors.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      user?.statusMessage ?? (t.language == AppLanguage.vi ? 'Trạng thái\nhiện tại' : 'Current\nstatus'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? DarkColors.textPrimary : LightColors.textPrimary
                      ),
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

          // ——— Name + Bio Section ———
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
                    onTap: () => _showComingSoon(context, t.language == AppLanguage.vi ? 'Cập nhật giới thiệu' : 'Update bio'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: isDark ? DarkColors.primary : AppColors.primary),
                        const SizedBox(width: 4),
                        Text(user?.bio ?? (t.language == AppLanguage.vi ? 'Cập nhật giới thiệu bản thân' : 'Update your bio'),
                          style: TextStyle(fontSize: 14, color: isDark ? DarkColors.primary : AppColors.primary)),
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
                        _actionChip(context, icon: Icons.auto_awesome, label: t.language == AppLanguage.vi ? 'Cài vnStyle' : 'Set vnStyle',
                          color: const Color(0xFFFFA726), onTap: () => _showComingSoon(context, 'vnStyle')),
                        const SizedBox(width: 10),
                        _actionChip(context, icon: Icons.photo_library, label: t.language == AppLanguage.vi ? 'Ảnh của tôi' : 'My photos',
                          color: isDark ? DarkColors.primary : AppColors.primary, onTap: () => _showComingSoon(context, 'Photos')),
                        const SizedBox(width: 10),
                        _actionChip(context, icon: Icons.inventory_2_outlined, label: t.language == AppLanguage.vi ? 'Kho khoảnh khắc' : 'Moments',
                          color: isDark ? DarkColors.primary : AppColors.primary, onTap: () => _showComingSoon(context, 'Moments')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ——— Personal Info Navigation ———
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : LightColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.person_outline, color: isDark ? DarkColors.textHint : LightColors.textHint),
                title: Text(t.personalInfo,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)),
                trailing: Icon(Icons.chevron_right, color: isDark ? DarkColors.divider : LightColors.divider),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                  );
                },
              ),
            ),
          ),

          // ——— Timeline Section ———
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : LightColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 64, color: (isDark ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.3)),
                      Positioned(left: -10, top: 5,
                        child: Icon(Icons.favorite, size: 24, color: Colors.red.withValues(alpha: 0.6))),
                      Positioned(right: -10, top: 0,
                        child: Icon(Icons.chat_bubble, size: 24, color: (isDark ? DarkColors.primary : AppColors.primary).withValues(alpha: 0.6))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.language == AppLanguage.vi ? 'Hôm nay $displayName có gì vui?' : 'What\'s new with $displayName today?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: isDark ? DarkColors.textPrimary : LightColors.textPrimary)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.language == AppLanguage.vi 
                      ? 'Đây là Nhật ký của bạn - Hãy làm đầy Nhật ký với những dấu ấn cuộc đời và kỷ niệm'
                      : 'This is your Timeline - Fill it with your life marks and memories',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13,
                      color: isDark ? DarkColors.textSecondary : LightColors.textSecondary)
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () => _showComingSoon(context, t.language == AppLanguage.vi ? 'Đăng lên Nhật ký' : 'Post to timeline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? DarkColors.primary : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: Text(
                        t.language == AppLanguage.vi ? 'Đăng lên Nhật ký' : 'Post to timeline', 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
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

  Widget _actionChip(BuildContext context, {
    required IconData icon, required String label,
    required Color color, required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? DarkColors.surface : Colors.white,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ——— Fullscreen Image Viewer ———
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
                Text(
                  ProfileTexts.of(context).language == AppLanguage.vi ? 'Không thể tải ảnh' : 'Failed to load image',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
