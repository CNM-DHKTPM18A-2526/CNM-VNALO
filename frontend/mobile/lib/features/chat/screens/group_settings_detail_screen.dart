import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';

class GroupSettingsDetailScreen extends StatelessWidget {
  const GroupSettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(common.groupSettingsHeader)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(common.changeGroupNameAction),
            onTap: () {
              // TODO: Implement change group name
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(common.changeGroupPhotoAction),
            onTap: () {
              // TODO: Implement change group photo
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(common.joinModeLabel),
            onTap: () {
              // TODO: Implement join mode
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(common.memberLimitLabel),
            onTap: () {
              // TODO: Implement member limit
            },
          ),
        ],
      ),
    );
  }
}
