import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:vnalo_mobile/features/common/widgets/quick_actions_sheet.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().loadInbox();
    });
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  void _openQuickActions() {
    showQuickActionsSheet(
      context,
      items: [
        QuickActionItem(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Thêm bạn',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddFriendScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.group_add_outlined,
          title: 'Tạo nhóm',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Luồng tạo nhóm sẽ được nối ở bước message/group tiếp theo.')),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.folder_copy_outlined,
          title: 'My Documents',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.calendar_month_outlined,
          title: 'Lịch Zalo',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lịch Zalo sẽ được tích hợp ở bước lịch/message tiếp theo.')),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.video_call_outlined,
          title: 'Tạo cuộc gọi nhóm',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tạo cuộc gọi nhóm sẽ được triển khai ở module call.')),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.devices_outlined,
          title: 'Thiết bị đăng nhập',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode
        ? DarkColors.textHint
        : Colors.white.withValues(alpha: 0.8);
    final dividerColor = isDarkMode
      ? const Color(0xFF3A3F46)
      : const Color(0xFFE9EDF3);

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
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: searchHint),
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: Icon(Icons.add, color: searchHint),
            onPressed: _openQuickActions,
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.loadInbox(),
            color: AppColors.primary,
            child: ListView.builder(
              itemCount: chatProvider.conversations.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.folder, color: Colors.white, size: 32),
                              const Icon(Icons.cloud, color: Colors.blue, size: 16),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                                ),
                              )
                            ],
                          ),
                        ),
                        title: const Text(
                          'My Documents',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 80,
                        color: dividerColor,
                      ),
                    ],
                  );
                }

                final conversation = chatProvider.conversations[index - 1];
                return ChatListItem(
                  key: ValueKey(conversation.id),
                  conversation: conversation,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          conversation: conversation,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
