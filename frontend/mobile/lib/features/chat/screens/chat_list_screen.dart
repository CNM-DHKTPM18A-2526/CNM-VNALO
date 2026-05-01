import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/models/quick_action_item.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/screens/ai_conversation_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/my_documents_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:vnalo_mobile/core/widgets/skeleton_loading.dart';
import 'package:vnalo_mobile/features/common/widgets/quick_actions_sheet.dart';
import 'package:vnalo_mobile/features/contacts/screens/add_friend_screen.dart';
import 'package:vnalo_mobile/features/profile/screens/account_security_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/create_group_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/join_group_screen.dart';
import 'package:vnalo_mobile/features/search/screens/unified_search_screen.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
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
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddFriendScreen()));
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
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => JoinGroupScreen()));
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
    final dividerColor =
        isDarkMode ? DarkColors.divider : AppColors.itemDivider;

    return Scaffold(
      backgroundColor:
          isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? appBarBg : Colors.transparent,
        elevation: 0,
        forceMaterialTransparency:
            !isDarkMode, // Only transparent in light mode to show gradient
        flexibleSpace:
            isDarkMode
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
                builder:
                    (_) =>
                        const UnifiedSearchScreen(searchTag: 'search_bar_chat'),
              ),
            );
          },
          child: Hero(
            tag: 'search_bar_chat',
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    common.search,
                    style: const TextStyle(
                      color: Colors.white,
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
            icon: Icon(
              Icons.qr_code_scanner,
              color: isDarkMode ? DarkColors.textPrimary : Colors.white,
            ),
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: Icon(
              Icons.add,
              color: isDarkMode ? DarkColors.textPrimary : Colors.white,
            ),
            onPressed: _openQuickActions,
          ),
        ],
      ),
      body: Consumer2<ChatProvider, AiAssistantProvider>(
        builder: (context, chatProvider, aiProvider, _) {
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty) {
            return ListView.separated(
              itemCount: 8,
              separatorBuilder: (_, __) => Container(
                color: isDarkMode ? DarkColors.surface : Colors.white,
                child: Row(
                  children: [
                    const SizedBox(width: 76),
                    Expanded(child: Container(height: 0.5, color: dividerColor)),
                  ],
                ),
              ),
              itemBuilder: (_, __) => const _SkeletonChatListItem(),
            );
          }

          final hasAiConversation = aiProvider.hasConversation;
          final fixedItemCount = hasAiConversation ? 2 : 1;

          return RefreshIndicator(
            onRefresh: () => chatProvider.loadInbox(),
            color: AppColors.primary,
            child: ColoredBox(
              color:
                  isDarkMode ? DarkColors.surface : AppColors.sectionBackground,
              child: ListView.separated(
                itemCount: chatProvider.conversations.length + fixedItemCount,
                separatorBuilder: (context, index) {
                  return Container(
                    color: isDarkMode ? DarkColors.surface : Colors.white,
                    child: Row(
                      children: [
                        const SizedBox(width: 76),
                        Expanded(
                          child: Container(height: 0.5, color: dividerColor),
                        ),
                      ],
                    ),
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
                          MessageType.FILE =>
                            '[${common.documentLabel}] ${lastCloud.content ?? ''}'
                                .trim(),
                          MessageType.AUDIO => '[${common.audioAction}]',
                          MessageType.STICKER => '[Sticker]',
                          _ => common.msgSent,
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                isDarkMode ? DarkColors.primary : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_upload_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
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
                                  color:
                                      isDarkMode
                                          ? DarkColors.textPrimary
                                          : LightColors.textPrimary,
                                ),
                              ),
                            ),
                            if (cloudTime != null)
                              Text(
                                cloudTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDarkMode
                                          ? DarkColors.textSecondary
                                          : Colors.grey,
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
                            color:
                                isDarkMode
                                    ? DarkColors.textSecondary
                                    : LightColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyDocumentsScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  if (hasAiConversation && index == 1) {
                    final lastAt = aiProvider.lastConversationAt;
                    final lastAtLabel =
                        lastAt != null ? DateFormatter.relative(lastAt) : null;

                    return ColoredBox(
                      color: isDarkMode ? DarkColors.surface : Colors.white,
                      child: ListTile(
                        key: const ValueKey('chat_list_ai_assistant_tile'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B6CF6), Color(0xFF0F8BFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Trợ lý AI VNALO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color:
                                      isDarkMode
                                          ? DarkColors.textPrimary
                                          : LightColors.textPrimary,
                                ),
                              ),
                            ),
                            if (lastAtLabel != null)
                              Text(
                                lastAtLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDarkMode
                                          ? DarkColors.textSecondary
                                          : Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          aiProvider.lastConversationPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode
                                    ? DarkColors.textSecondary
                                    : LightColors.textSecondary,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AiConversationScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  // 2. Conversations
                  final conversationStartIndex = fixedItemCount;
                  final conversation =
                      chatProvider.conversations[index -
                          conversationStartIndex];
                  return ChatListItem(
                    key: ValueKey(conversation.id),
                    conversation: conversation,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  ChatDetailScreen(conversation: conversation),
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

class _SkeletonChatListItem extends StatelessWidget {
  const _SkeletonChatListItem();

  @override
  Widget build(BuildContext context) {
    return ChatListSkeletonItem();
  }
}
