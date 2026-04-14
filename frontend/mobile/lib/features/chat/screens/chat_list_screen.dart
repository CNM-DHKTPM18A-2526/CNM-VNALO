import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:vnalo_mobile/features/common/widgets/quick_actions_sheet.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/create_group_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/join_group_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';

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
      final chatProvider = context.read<ChatProvider>();
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        chatProvider.setCurrentUserId(userId);
      }
      chatProvider.loadInbox();
    });
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  void _openQuickActions() {
    final common = CommonTexts.of(context, listen: false);
    showQuickActionsSheet(
      context,
      items: [
        QuickActionItem(
          icon: Icons.person_add_alt_1_outlined,
          title: common.addFriendAction,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddFriendScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.group_add_outlined,
          title: common.createGroupAction,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.link,
          title: common.joinGroupAction,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => JoinGroupScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.folder_copy_outlined,
          title: common.myDocumentsSubtitle,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyDocumentsScreen()),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.calendar_month_outlined,
          title: common.vnaloCalendar,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(common.calendarFlowPlaceholder)),
            );
          },
        ),
        QuickActionItem(
          icon: Icons.devices_outlined,
          title: common.loggedInDevices,
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
    final common = CommonTexts.of(context);
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final searchHint = isDarkMode
        ? DarkColors.textSecondary
        : Colors.white.withValues(alpha: 0.8);
    final dividerColor = isDarkMode
      ? DarkColors.divider
      : const Color(0xFFE9EDF3);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency: !isDarkMode, // Only transparent in light mode to show gradient
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
                    common.search,
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
            icon: Icon(Icons.qr_code_scanner, color: isDarkMode ? DarkColors.textPrimary : Colors.white),
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: Icon(Icons.add, color: isDarkMode ? DarkColors.textPrimary : Colors.white),
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
            child: ColoredBox(
              color: isDarkMode ? DarkColors.surface : AppColors.sectionBackground,
              child: ListView.separated(
                itemCount: chatProvider.conversations.length + 1,
                separatorBuilder: (context, index) {
                  if (index == 0) return const SizedBox.shrink(); // No separator after header
                  return Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 80,
                    color: dividerColor,
                  );
                },
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // 1. My Documents (First Item)
                    final lastCloud = chatProvider.lastCloudMessage;
                    String cloudSubtitle = common.myDocumentsSubtitle;
                    String? cloudTime;
                    
                    if (lastCloud != null) {
                      cloudTime = DateFormatter.relative(lastCloud.createdAt);
                      final prefix = 'Bạn: ';
                      
                      if (lastCloud.messageType == MessageType.TEXT) {
                        cloudSubtitle = '$prefix${lastCloud.content ?? ''}';
                      } else {
                        final label = switch (lastCloud.messageType) {
                          MessageType.IMAGE => '[${common.photoAction}]',
                          MessageType.VIDEO => '[${common.videoAction}]',
                          MessageType.FILE => '[${common.documentLabel}] ${lastCloud.content ?? ''}'.trim(),
                          MessageType.AUDIO => '[${common.audioAction}]',
                          MessageType.STICKER => '[Sticker]',
                          _ => common.msgSent
                        };
                        cloudSubtitle = '$prefix$label';
                      }
                    }

                    return ColoredBox(
                      color: isDarkMode ? DarkColors.surface : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      leading: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDarkMode ? DarkColors.primary : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              common.myDocumentsHeader,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                              ),
                            ),
                          ),
                          if (cloudTime != null)
                            Text(
                              cloudTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? DarkColors.textSecondary : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        cloudSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? DarkColors.textSecondary : Colors.grey,
                        ),
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

                  // 2. Conversations
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
            ),
          );
        },
      ),
    );
  }
}
