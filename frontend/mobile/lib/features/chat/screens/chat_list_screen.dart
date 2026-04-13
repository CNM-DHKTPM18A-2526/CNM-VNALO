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
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';

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
          title: 'Lịch Vnalo',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lịch Vnalo sẽ được tích hợp ở bước lịch/message tiếp theo.')),
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
            Navigator.of(context, rootNavigator: true).push(
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
      ? DarkColors.divider
      : const Color(0xFFE9EDF3);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: true,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
              ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UnifiedSearchScreen(searchTag: 'search_bar_chat'),
              ),
            );
          },
          child: Hero(
            tag: 'search_bar_chat',
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: isDarkMode ? searchHint : Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Tìm kiếm',
                    style: TextStyle(
                      color: searchHint,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
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

          final conversations = chatProvider.conversations;

          return RefreshIndicator(
            onRefresh: () => chatProvider.loadInbox(),
            color: AppColors.primary,
            child: ListView.builder(
              itemCount: conversations.length + 1, // 1 for Cloud + conversations
              itemBuilder: (context, index) {
                if (index == 0) {
                  // My Documents / Cloud item
                  return Container(
                    color: isDarkMode ? DarkColors.surface : Colors.white,
                    child: ChatListItem(
                      isVirtualCloud: true,
                      conversation: Conversation(
                        id: 'my_documents',
                        type: ConversationType.DIRECT,
                        title: 'My Documents',
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
                        );
                      },
                    ),
                  );
                }

                // Regular conversations
                final conversation = conversations[index - 1];
                return Container(
                  color: isDarkMode ? DarkColors.surface : Colors.white,
                  child: ChatListItem(
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
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
