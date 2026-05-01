import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class GroupSettingsDetailScreen extends StatelessWidget {
  const GroupSettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        title: Text(
          common.groupSettingsHeader,
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
      ),
      body: Container(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        child: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: isDarkMode ? DarkColors.primary : AppColors.primary),
              title: Text(common.changeGroupNameAction),
              trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400),
              onTap: () {
                // TODO: Implement change group name
              },
            ),
            Divider(height: 1, thickness: 0.5, indent: 56, color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
            ListTile(
              leading: Icon(Icons.image_outlined, color: isDarkMode ? DarkColors.primary : AppColors.primary),
              title: Text(common.changeGroupPhotoAction),
              trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400),
              onTap: () {
                // TODO: Implement change group photo
              },
            ),
            Divider(height: 1, thickness: 0.5, indent: 56, color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
            ListTile(
              leading: Icon(Icons.lock_outline, color: isDarkMode ? DarkColors.primary : AppColors.primary),
              title: Text(common.joinModeLabel),
              trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400),
              onTap: () {
                // TODO: Implement join mode
              },
            ),
            Divider(height: 1, thickness: 0.5, indent: 56, color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
            ListTile(
              leading: Icon(Icons.people_outline, color: isDarkMode ? DarkColors.primary : AppColors.primary),
              title: Text(common.memberLimitLabel),
              trailing: Icon(Icons.chevron_right, size: 20, color: isDarkMode ? DarkColors.textHint : Colors.grey.shade400),
              onTap: () {
                // TODO: Implement member limit
              },
            ),
          ],
        ),
      ),
    );
  }
}
