import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/widgets/group_avatar.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/profile/providers/avatar_cache_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';

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

    final chat = context.watch<ChatProvider>();
    final otherMember = _getOtherMember(conversation, currentUserId);
    final otherUserId = otherMember?.userId;
    final isOnline = otherUserId != null ? chat.isUserOnline(otherUserId) : (otherMember?.user?.isOnline ?? false);
    final lastSeen = otherMember?.user?.lastSeen;
    String? statusText;
    if (conversation.type == ConversationType.DIRECT && !isOnline && lastSeen != null) {
      statusText = DateFormatter.relative(lastSeen);
    } else if (conversation.type == ConversationType.DIRECT && isOnline) {
      statusText = 'Đang hoạt động';
    }

    final regularTileColor = isDarkMode ? DarkColors.surface : Colors.white;
    final pinnedTileColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF0F2F5);
    final secondaryTextColor = isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final hintColor = isDarkMode ? DarkColors.textHint : LightColors.textHint;
    final dividerColor = isDarkMode ? DarkColors.divider : AppColors.itemDivider;
    final lastPreview = _buildLastMessagePreview(currentUserId, common);

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              final chatProvider = context.read<ChatProvider>();
              chatProvider.updateConversationSettings(
                conversationId: conversation.id,
                isPinned: !conversation.isPinned,
              );
            },
            backgroundColor: AppColors.pinIcon,
            icon: conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: conversation.isPinned ? common.unpinAction : common.pinAction,
          ),
          SlidableAction(
            onPressed: (context) {
              final chatProvider = context.read<ChatProvider>();
              chatProvider.updateConversationSettings(
                conversationId: conversation.id,
                isMuted: !conversation.isMuted,
              );
            },
            backgroundColor: hintColor,
            icon: conversation.isMuted ? Icons.notifications_active : Icons.notifications_off,
            label: conversation.isMuted ? common.unmuteAction : common.muteAction,
          ),
          SlidableAction(
            onPressed: (context) {
              _showDeleteConfirmation(context);
            },
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: (conversation.type == ConversationType.GROUP && (conversation.avatarUrl == null || conversation.avatarUrl!.isEmpty))
              ? GroupAvatar(
                  members: conversation.members
                      .where((m) => m.userId != currentUserId)
                      .take(3)
                      .map((m) => (imageUrl: m.user?.avatarUrl, name: m.user?.displayName ?? 'User'))
                      .toList(),
                  totalMemberCount: conversation.members.length,
                  size: 48,
                )
              : AvatarWidget(
                  imageUrl: displayAvatar,
                  name: displayName,
                  size: 48,
                  showOnline: conversation.type == ConversationType.DIRECT,
                  isOnline: isOnline,
                  lastSeen: lastSeen,
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
                Icon(Icons.push_pin, size: 14, color: secondaryTextColor),
              const SizedBox(width: 4),
              Text(
                DateFormatter.relative(conversation.lastMessage?.createdAt),
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
          subtitle: Row(
            // children: [
            //   if (statusText != null) ...[
            //     Text(
            //       statusText,
            //       style: TextStyle(
            //         fontSize: 12,
            //         color: isOnline
            //             ? AppColors.online
            //             : (isDarkMode ? DarkColors.textHint : LightColors.textHint),
            //       ),
            //     ),
            //     const SizedBox(width: 6),
            //     Text('·', style: TextStyle(color: isDarkMode ? DarkColors.textHint : LightColors.textHint)),
            //     const SizedBox(width: 6),
            //   ],
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
    );
  }

  String _avatarOwnerId(String currentUserId) {
    if (conversation.type != ConversationType.DIRECT) return '';
    if (conversation.members.isEmpty) return '';
    final other = conversation.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => conversation.members.isNotEmpty ? conversation.members.first : ConversationMember(conversationId: conversation.id, userId: 'none', joinedAt: DateTime.now()),
    );
    return other.userId;
  }

  ConversationMember? _getOtherMember(Conversation conv, String currentUserId) {
    if (conv.members.isEmpty) return null;
    return conv.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => conv.members.first,
    );
  }

  String? _buildLastMessagePreview(String currentUserId, CommonTexts common) {
    final message = conversation.lastMessage;
    if (message == null) return null;

    final isMine = message.senderId.isNotEmpty && message.senderId == currentUserId;
    final prefix = isMine ? 'Bạn: ' : '';

    if (message.isRecalled) {
      return '$prefix${common.msgRecalled}';
    }

    final rawContent = message.content ?? '';
    final log = CallLogMessage.tryParse(rawContent);
    if (log != null) {
      final isVoice = log.mediaType == CallMediaType.voice;
      final typeStr = isVoice ? 'thoại' : 'video';
      return '$prefix[Cuộc gọi $typeStr]';
    }

    final content = (message.content ?? '').trim();
    final mediaUrl = (message.mediaUrl ?? '').trim();
    final typePreview = switch (message.messageType) {
      MessageType.TEXT => _textPreview(content),
      MessageType.IMAGE => '[${common.photoAction}]',
      MessageType.VIDEO => '[${common.videoAction}]',
      MessageType.FILE => _filePreview(content, common),
      MessageType.AUDIO => '[${common.audioAction}]',
      MessageType.STICKER => '[Sticker]',
      MessageType.SYSTEM => (() {
        if (content.startsWith('{')) return ''; // Hide JSON signals from preview
        if (content.startsWith('CALL_LOG::')) {
          final log = CallLogMessage.tryParse(content);
          if (log != null) {
            final isVoice = log.mediaType == CallMediaType.voice;
            final typeStr = isVoice ? 'thoại' : 'video';
            return '[Cuộc gọi $typeStr]';
          }
        }
        return content.isNotEmpty ? content : '[Hệ thống]';
      })(),
      MessageType.REPLY => content.isNotEmpty ? '[Trả lời] $content' : '[Trả lời]',
      MessageType.FORWARD => content.isNotEmpty ? '[Chuyển tiếp] $content' : '[Chuyển tiếp]',
      MessageType.POLL => '[Bình chọn]',
    };

    if (typePreview == null && mediaUrl.isNotEmpty) {
      return '$prefix[Link] $mediaUrl';
    }

    final result = '$prefix${typePreview ?? ''}'.trim();
    
    // FINAL SAFEGUARD: Nếu vẫn còn lộ call_log thì ép về text sạch
    if (result.contains('CALL_LOG::')) {
      return '$prefix[Cuộc gọi]';
    }
    
    return result;
  }

  String _filePreview(String content, CommonTexts common) {
    if (content.isEmpty) return '[${common.documentLabel}]';
    return '[${common.documentLabel}] $content';
  }

  String? _textPreview(String content) {
    if (content.isEmpty) return null;
    final uri = Uri.tryParse(content);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return '[Link] $content';
    }
    return content;
  }

  void _showDeleteConfirmation(BuildContext context) {
    final common = CommonTexts.of(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(common.delete),
        content: Text('Bạn có chắc chắn muốn xóa hội thoại này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(common.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().deleteConversation(conversation.id);
              Navigator.pop(context);
            },
            child: Text(common.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
