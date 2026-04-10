import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:open_file/open_file.dart';
import 'package:vnalo_mobile/features/chat/widgets/full_screen_image_viewer.dart';
import 'package:vnalo_mobile/features/chat/widgets/audio_player_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final List<ConversationMember>? readByMembers;
  final VoidCallback? onRetry;
  final bool showTime;
  final bool showStatus;
  final String? milestoneText;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.readByMembers,
    this.onRetry,
    this.showTime = true,
    this.showStatus = false,
    this.milestoneText,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (milestoneText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              milestoneText!,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: _buildBubbleContent(context, isDarkMode),
                  ),
                ],
              ),
              if (isMine || showTime || (readByMembers != null && readByMembers!.isNotEmpty)) ...[
                const SizedBox(height: 4),
                _buildStatusLabel(isDarkMode),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(BuildContext context, bool isDarkMode) {
    if (message.messageType == MessageType.STICKER) {
      return _buildSticker();
    }

    final bubbleColor = isMine
        ? (isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent)
        : (isDarkMode ? DarkColors.chatBubbleReceived : LightColors.chatBubbleReceived);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: message.messageType == MessageType.IMAGE
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        boxShadow: [
          if (!isDarkMode && !isMine)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _renderTypeSpecificContent(context, isDarkMode),
          if (showTime && message.messageType != MessageType.IMAGE)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormatter.time(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderTypeSpecificContent(BuildContext context, bool isDarkMode) {
    switch (message.messageType) {
      case MessageType.IMAGE:
        return _buildImage(context);
      case MessageType.FILE:
        return _buildFileCard(context, isDarkMode);
      case MessageType.AUDIO:
        return _buildAudioPlayer(context);
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isMine
                ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                : (isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
            height: 1.3,
          ),
        );
    }
  }

  Widget _buildImage(BuildContext context) {
    final url = message.mediaUrl ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        final isLocal = url.startsWith('/') || url.contains('Users') || url.contains('storage');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: url,
              isLocal: isLocal,
            ),
          ),
        );
      },
      child: url.startsWith('/') || url.contains('Users') || url.contains('storage') // Basic check for local path
          ? Image.file(File(url), fit: BoxFit.cover)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
    );
  }

  Widget _buildSticker() {
    final url = message.mediaUrl ?? '';
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.grey),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, bool isDarkMode) {
    return InkWell(
      onTap: () {
        if (message.mediaUrl != null) {
          OpenFile.open(message.mediaUrl);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.blue, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content ?? 'Tài liệu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  message.mediaSizeBytes != null
                      ? '${(message.mediaSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB'
                      : 'File',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(BuildContext context) {
    return AudioPlayerWidget(
      audioUrl: message.mediaUrl ?? '',
      isMine: isMine,
    );
  }

  Widget _buildStatusLabel(bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMine && showStatus && message.status == MessageStatus.DELIVERED) ...[
          const Icon(Icons.done_all, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Đã nhận',
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),
        ] else if (message.status != MessageStatus.SENDING && message.status != MessageStatus.FAILED)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.status == MessageStatus.SENT ? Icons.done : Icons.done_all,
                  size: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  _getStatusText(message.status),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else if (message.status == MessageStatus.SENDING)
          Text(
            'Đang gửi...',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
            ),
          )
        else if (message.status == MessageStatus.FAILED)
          const Text(
            'Lỗi gửi',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
        if (readByMembers != null && readByMembers!.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildReadAvatars(),
        ],
      ],
    );
  }

  Widget _buildReadAvatars() {
    if (readByMembers == null || readByMembers!.isEmpty) return const SizedBox.shrink();

    final displayed = readByMembers!.take(4).toList();
    final remainingCount = readByMembers!.length - displayed.length;

    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...displayed.map((m) => Padding(
                padding: const EdgeInsets.only(left: 2),
                child: ClipOval(
                  child: Image.network(
                    m.user?.avatarUrl ?? 'https://ui-avatars.com/api/?name=${m.user?.displayName ?? 'U'}',
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 14,
                      height: 14,
                      color: Colors.grey,
                      child: const Icon(Icons.person, size: 10, color: Colors.white),
                    ),
                  ),
                ),
              )),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText(MessageStatus status) {
    switch (status) {
      case MessageStatus.SENT:
        return 'Đã gửi';
      case MessageStatus.DELIVERED:
        return 'Đã nhận';
      case MessageStatus.READ:
        return 'Đã xem';
      default:
        return '';
    }
  }
}
