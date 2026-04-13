import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';

class DirectChatOptionsScreen extends StatelessWidget {
  const DirectChatOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(common.chatOptionsHeader)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(common.viewProfileAction),
            onTap: () {
              // TODO: Implement view profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(common.muteNotificationsAction),
            onTap: () {
              // TODO: Implement mute notifications
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(common.blockUserAction),
            onTap: () {
              // TODO: Implement block user
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(common.deleteChatAction),
            onTap: () {
              // TODO: Implement delete conversation
            },
          ),
        ],
      ),
    );
  }
}
