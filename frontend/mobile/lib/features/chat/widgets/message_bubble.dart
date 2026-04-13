import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/focused_message_dialog.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_file/open_file.dart';
import 'package:vnalo_mobile/features/chat/widgets/full_screen_image_viewer.dart';
import 'package:vnalo_mobile/features/chat/widgets/audio_player_widget.dart';
import 'package:flutter/services.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool showSender;
  final bool showAvatar;
  final bool showTime;
  final bool showStatus;
  final String? milestoneText;
  final List<Message>? groupedMessages;
  final List<ConversationMember>? readByMembers;
  final ValueChanged<String>? onReplyTap;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSender = false,
    this.showAvatar = false,
    this.showTime = true,
    this.showStatus = false,
    this.milestoneText,
    this.groupedMessages,
    this.readByMembers,
    this.onReplyTap,
    this.onRetry,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final common = CommonTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (milestoneText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    milestoneText!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? DarkColors.textHint : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (!isMine && showSender)
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 4),
              child: Text(
                message.senderName ?? common.unknownUser,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? DarkColors.textHint : Colors.grey[600],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) _buildAvatar(),
              _buildContent(context, common),
            ],
          ),
          if (showTime && message.createdAt != null)
            Padding(
              padding: EdgeInsets.only(
                left: isMine ? 0 : 42,
                top: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormatter.formatChatDate(message.createdAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? DarkColors.textHint : Colors.grey[500],
                    ),
                  ),
                  if (isMine && message.status == MessageStatus.FAILED && onRetry != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onRetry,
                      child: const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (!showAvatar) return const SizedBox(width: 38);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: message.senderAvatarUrl != null && message.senderAvatarUrl!.isNotEmpty
            ? CachedNetworkImageProvider(message.senderAvatarUrl!)
            : null,
        child: message.senderAvatarUrl == null || message.senderAvatarUrl!.isEmpty
            ? const Icon(Icons.person, size: 20)
            : null,
      ),
    );
  }

  Widget _buildContent(BuildContext context, CommonTexts common) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Flexible(
      child: GestureDetector(
        onLongPress: () {
          if (onLongPress != null) {
            onLongPress!();
          } else {
            _showContextMenu(context);
          }
        },
        child: Container(
          padding: _getPadding(),
          decoration: BoxDecoration(
            color: _getBubbleColor(isDarkMode),
            borderRadius: _getBorderRadius(),
          ),
          child: _buildMessageBody(context, common),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final common = CommonTexts.of(context, listen: false);
    
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset position = renderBox.localToGlobal(Offset.zero);
    Size size = renderBox.size;

    FocusedMessageDialog.show(
      context,
      message: message,
      isMine: isMine,
      position: position,
      size: size,
      onAction: (action) {
        if (action == 'copy') {
           if (message.messageType == MessageType.TEXT) {
             Clipboard.setData(ClipboardData(text: message.content ?? ''));
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(common.msgCopied)),
             );
           }
        } else if (action == 'reply') {
           context.read<ChatProvider>().setReplyTo(message);
        } else if (action == 'delete') {
           context.read<ChatProvider>().deleteMessage(message.id);
        }
      },
      child: this,
    );
  }

  EdgeInsets _getPadding() {
    if (message.messageType == MessageType.IMAGE || message.messageType == MessageType.VIDEO) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  Color _getBubbleColor(bool isDarkMode) {
    if (message.messageType == MessageType.IMAGE || message.messageType == MessageType.VIDEO) {
      return Colors.transparent;
    }
    if (isMine) {
      return isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent;
    }
    return isDarkMode ? DarkColors.chatBubbleReceived : LightColors.chatBubbleReceived;
  }

  BorderRadius _getBorderRadius() {
    if (isMine) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
  }

  Widget _buildMessageBody(BuildContext context, CommonTexts common) {
    switch (message.messageType) {
      case MessageType.IMAGE:
        return _buildImageMessage(context);
      case MessageType.VIDEO:
        return _buildVideoMessage(context);
      case MessageType.FILE:
        return _buildFileMessage(context, common);
      case MessageType.AUDIO:
        return _buildAudioMessage(context);
      case MessageType.STICKER:
        return _buildStickerMessage(context);
      case MessageType.TEXT:
      default:
        return _buildTextMessage(context);
    }
  }

  Widget _buildTextMessage(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Text(
      message.content ?? '',
      style: TextStyle(
        fontSize: 16,
        color: isMine 
            ? (isDarkMode ? Colors.white : Colors.black87)
            : (isDarkMode ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: message.mediaUrl ?? message.content ?? '',
              isLocal: message.mediaUrl?.startsWith('http') == false,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.content ?? '',
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          fit: BoxFit.cover,
          maxWidthDiskCache: 1000,
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white),
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context, CommonTexts common) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.insert_drive_file,
          color: isMine ? Colors.white : (isDarkMode ? DarkColors.primary : AppColors.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content ?? common.documentLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isMine ? Colors.white : (isDarkMode ? Colors.white : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.mediaSizeBytes != null)
                Text(
                  '${(message.mediaSizeBytes! / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMessage(BuildContext context) {
    return AudioPlayerWidget(
      audioUrl: message.mediaUrl ?? message.content ?? '',
      isMine: isMine,
    );
  }

  Widget _buildStickerMessage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: message.content ?? '',
      width: 120,
      height: 120,
      placeholder: (context, url) => const SizedBox(width: 120, height: 120),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}
