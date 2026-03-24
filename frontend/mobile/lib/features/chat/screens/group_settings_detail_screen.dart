import 'package:flutter/material.dart';

class GroupSettingsDetailScreen extends StatelessWidget {
  const GroupSettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cai dat nhom')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Doi ten nhom'),
          ),
          ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Doi anh nhom'),
          ),
          ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Che do tham gia'),
          ),
          ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Gioi han thanh vien'),
          ),
        ],
      ),
    );
  }
}
