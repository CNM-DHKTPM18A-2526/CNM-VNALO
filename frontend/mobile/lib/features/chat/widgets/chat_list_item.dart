import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/widgets/group_avatar.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/profile/providers/avatar_cache_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final displayName = conversation.getDisplayName(currentUserId);
    final displayAvatar = conversation.getDisplayAvatarUrl(currentUserId);
    final avatarOwnerId = _avatarOwnerId(currentUserId);
    final avatarVersion = context.watch<AvatarCacheProvider>().versionForUser(avatarOwnerId);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    final regularTileColor = isDarkMode ? DarkColors.surface : const Color(0xFFFFFFFF);
    final pinnedTileColor = isDarkMode ? const Color(0xFF1E2633) : const Color(0xFFEFF2F7);
    final secondaryTextColor = isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final hintColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;
    final dividerColor = isDarkMode ? DarkColors.divider : const Color(0xFFE9EDF3);
    final lastPreview = _buildLastMessagePreview(currentUserId);

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
                label: common.pinAction,
              ),
              SlidableAction(
                onPressed: (_) {},
                backgroundColor: hintColor,
                icon: Icons.notifications_off,
                label: common.muteAction,
              ),
              SlidableAction(
                onPressed: (_) {},
                backgroundColor: AppColors.error,
                icon: Icons.delete,
                label: common.delete,
              ),
            ],
          ),
          child: ColoredBox(
            color: conversation.isPinned ? pinnedTileColor : regularTileColor,
            child: ListTile(
              onTap: onTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: (conversation.type == ConversationType.GROUP && (conversation.avatarUrl == null || conversation.avatarUrl!.isEmpty))
                  ? GroupAvatar(
                      members: conversation.members
                          .where((m) => m.userId != currentUserId)
                          .take(4)
                          .map((m) => (imageUrl: m.user?.avatarUrl, name: m.user?.displayName ?? 'User'))
                          .toList(),
                      size: 48,
                    )
                  : AvatarWidget(
                      imageUrl: displayAvatar,
                      name: displayName,
                      size: 48,
                      showOnline: conversation.type == ConversationType.DIRECT,
                      cacheVersion: avatarVersion,
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
                      lastPreview ??
                          (conversation.type == ConversationType.DIRECT
                              ? common.sayHelloTo(displayName)
                              : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: conversation.lastMessage == null
                            ? (isDarkMode ? DarkColors.primary : AppColors.primary)
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                  if (conversation.isMuted)
                    Icon(Icons.notifications_off, size: 14, color: hintColor),
                  if (conversation.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.unreadBadge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
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

  String _avatarOwnerId(String currentUserId) {
    if (conversation.type != ConversationType.DIRECT) return '';
    if (conversation.members.isEmpty) return '';
    final other = conversation.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => conversation.members.first,
    );
    return other.userId;
  }

  String? _buildLastMessagePreview(String currentUserId) {
    final message = conversation.lastMessage;
    if (message == null) return null;

    final isMine = message.senderId.isNotEmpty && message.senderId == currentUserId;
    final prefix = isMine ? 'Bạn: ' : '';

    if (message.status == MessageStatus.RECALLED) {
      return '${prefix}Tin nhắn đã thu hồi';
    }

    final content = (message.content ?? '').trim();
    final mediaUrl = (message.mediaUrl ?? '').trim();
    final typePreview = switch (message.messageType) {
      MessageType.TEXT => _textPreview(content),
      MessageType.IMAGE => '[Hình ảnh]',
      MessageType.VIDEO => '[Video]',
      MessageType.FILE => _filePreview(content),
      MessageType.AUDIO => '[Âm thanh]',
      MessageType.STICKER => '[Sticker]',
      MessageType.SYSTEM => content.isNotEmpty ? content : '[Hệ thống]',
      MessageType.REPLY => content.isNotEmpty ? '[Trả lời] $content' : '[Trả lời]',
      MessageType.FORWARD => content.isNotEmpty ? '[Chuyển tiếp] $content' : '[Chuyển tiếp]',
    };

    if (typePreview == null && mediaUrl.isNotEmpty) {
      return '$prefix[Link] $mediaUrl';
    }

    return '$prefix${typePreview ?? ''}'.trim();
  }

  String _filePreview(String content) {
    if (content.isEmpty) return '[File]';
    return '[File] $content';
  }

  String? _textPreview(String content) {
    if (content.isEmpty) return null;
    final uri = Uri.tryParse(content);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return '[Link] $content';
    }
    return content;
  }
}
