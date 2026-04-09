import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withValues(alpha: 0.8);
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'Người dùng';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
            );
          },
          child: Row(
          children: [
            Icon(Icons.search, size: 24, color: searchHint),
            const SizedBox(width: 8),
            Text(
              'Tìm kiếm',
              style: TextStyle(color: searchHint, fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: auth.user?.avatarUrl,
                  name: displayName,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text('Bạn đang nghĩ gì?'),
                  ),
                ),
              ],
            ),
          ),
          Divider(thickness: 8, color: Theme.of(context).dividerColor,),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Chưa có bài viết nào',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
