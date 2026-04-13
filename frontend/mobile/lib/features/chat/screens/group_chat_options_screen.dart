import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/chat/screens/group_settings_detail_screen.dart';

class GroupChatOptionsScreen extends StatelessWidget {
  const GroupChatOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(common.groupOptionsHeader)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(common.detailedGroupSettings),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GroupSettingsDetailScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: Text(common.addMemberAction),
            onTap: () {
              // TODO: Implement add member
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app_outlined),
            title: Text(common.leaveGroupAction),
            onTap: () {
              // TODO: Implement leave group
            },
          ),
        ],
      ),
    );
  }
}
