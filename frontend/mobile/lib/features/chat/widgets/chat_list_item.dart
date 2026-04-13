import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool isVirtualCloud;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isVirtualCloud = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final displayName = conversation.getDisplayName(currentUserId);
    final displayAvatar = conversation.getDisplayAvatarUrl(currentUserId);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final regularTileColor =
        isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
    final pinnedTileColor =
        isDarkMode ? const Color(0xFF2D3440) : const Color(0xFFEFF2F7);
    final secondaryTextColor =
        isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final hintColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;
    final dividerColor = isDarkMode
      ? const Color(0xFF3A3F46)
      : const Color(0xFFE9EDF3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {},
                backgroundColor: AppColors.pinIcon,
                icon: Icons.push_pin,
                label: 'Ghim',
              ),
              SlidableAction(
                onPressed: (_) {},
                backgroundColor: hintColor,
                icon: Icons.notifications_off,
                label: 'Tat',
              ),
              SlidableAction(
                onPressed: (_) {},
                backgroundColor: AppColors.error,
                icon: Icons.delete,
                label: 'Xoa',
              ),
            ],
          ),
          child: ColoredBox(
            color: conversation.isPinned ? pinnedTileColor : regularTileColor,
            child: ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: isVirtualCloud
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.folder, color: Colors.white, size: 28),
                          const Icon(Icons.cloud, color: Colors.blue, size: 14),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 10),
                            ),
                          )
                        ],
                      ),
                    )
                  : AvatarWidget(
                      imageUrl: displayAvatar,
                      name: displayName,
                      size: 48,
                      showOnline: conversation.type == ConversationType.DIRECT,
                    ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (conversation.isPinned)
                    Icon(Icons.push_pin, size: 14, color: AppColors.pinIcon),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.relative(conversation.lastMessage?.createdAt),
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.lastMessage?.content ??
                          (isVirtualCloud
                              ? 'Lưu trữ các tin nhắn quan trọng'
                              : (conversation.type == ConversationType.DIRECT
                                  ? 'Gửi lời chào $displayName'
                                  : '')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: conversation.lastMessage == null
                            ? AppColors.primary
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                  if (conversation.isMuted)
                    Icon(Icons.notifications_off, size: 14, color: hintColor),
                  if (conversation.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.unreadBadge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        conversation.unreadCount > 99
                            ? '99+'
                            : '${conversation.unreadCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 80,
          endIndent: 0,
          color: dividerColor,
        ),
      ],
    );
  }
}
