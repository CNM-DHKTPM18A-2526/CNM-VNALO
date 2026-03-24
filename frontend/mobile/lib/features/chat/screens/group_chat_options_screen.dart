import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/chat/screens/group_settings_detail_screen.dart';

class GroupChatOptionsScreen extends StatelessWidget {
  const GroupChatOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tuy chon nhom')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cai dat nhom chi tiet'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GroupSettingsDetailScreen(),
                ),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.group_add_outlined),
            title: Text('Them thanh vien'),
          ),
          const ListTile(
            leading: Icon(Icons.exit_to_app_outlined),
            title: Text('Roi nhom'),
          ),
        ],
      ),
    );
  }
}
