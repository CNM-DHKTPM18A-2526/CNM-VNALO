import 'package:flutter/material.dart';

class DirectChatOptionsScreen extends StatelessWidget {
  const DirectChatOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tuy chon tro chuyen')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Xem trang ca nhan'),
          ),
          ListTile(
            leading: Icon(Icons.notifications_off_outlined),
            title: Text('Tat thong bao'),
          ),
          ListTile(
            leading: Icon(Icons.block_outlined),
            title: Text('Chan nguoi dung'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Xoa cuoc tro chuyen'),
          ),
        ],
      ),
    );
  }
}
