import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode ? DarkColors.textHint : Colors.white.withOpacity(0.8);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
        title: Row(
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
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(radius: 20),
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
          const Divider(thickness: 8),
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
