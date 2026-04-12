import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final List<ConversationMember>? readByMembers;
  final VoidCallback? onRetry;
  final bool showTime;
  final bool showStatus;
  final String? milestoneText;
  final List<Message>? groupedMessages;
  final Function(String)? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.readByMembers,
    this.onRetry,
    this.showTime = true,
    this.showStatus = false,
    this.milestoneText,
    this.groupedMessages,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (milestoneText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  milestoneText!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
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
                    child: _buildBubbleWrapper(context, isDarkMode),
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
    if (groupedMessages != null && groupedMessages!.isNotEmpty) {
      return _buildImageGrid(context, isDarkMode);
    }

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
          if (message.replyToMessageId != null) _buildReplyQuote(context, isDarkMode),
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

  Widget _buildBubbleWrapper(BuildContext context, bool isDarkMode) {
    final chatProvider = context.read<ChatProvider>();
    final isHighlighted = context.watch<ChatProvider>().highlightedMessageId == message.id;

    return GestureDetector(
      onLongPress: () => _showActionMenu(context, chatProvider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isHighlighted
              ? Border.all(color: AppColors.primary, width: 3)
              : null,
        ),
        child: _buildBubbleContent(context, isDarkMode),
      ),
    );
  }

  void _showActionMenu(BuildContext context, ChatProvider chatProvider) {
    // Find bubble position
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    FocusedMessageDialog.show(
      context,
      message: message,
      isMine: isMine,
      position: position,
      size: size,
      child: _buildBubbleContent(context, isDarkMode), // Re-render bubble content for the dialog
      onAction: (action) {
        if (action == 'reply') {
          chatProvider.setReplyTo(message);
        } else if (action == 'copy') {
           if (message.messageType == MessageType.TEXT) {
             Clipboard.setData(ClipboardData(text: message.content ?? ''));
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Đã sao chép tin nhắn')),
             );
           }
        }
      },
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

  Widget _buildImageGrid(BuildContext context, bool isDarkMode) {
    final images = groupedMessages!;
    int crossAxisCount = 3;
    if (images.length == 2 || images.length == 4) crossAxisCount = 2;
    if (images.length == 1) crossAxisCount = 1;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final url = images[index].mediaUrl ?? '';
          if (url.isEmpty) return const SizedBox.shrink();
          final isLocal = url.startsWith('/') || url.contains('Users') || url.contains('storage');
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(imageUrl: url, isLocal: isLocal),
                ),
              );
            },
            child: isLocal
                ? Image.file(File(url), fit: BoxFit.cover)
                : Image.network(
                    url,
                    headers: const {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    },
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : Container(color: Colors.grey.shade200),
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                  ),
          );
        },
      ),
    );
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
          : Image.network(
              url,
              headers: const {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              },
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
              ),
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
    if (!showStatus && !showTime && readByMembers?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    
    final bool isImage = message.messageType == MessageType.IMAGE || (groupedMessages != null && groupedMessages!.isNotEmpty);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTime && isImage) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormatter.time(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (showStatus) ...[
          if (message.status == MessageStatus.SENDING)
             Text('Đang gửi...', style: TextStyle(fontSize: 10, color: Colors.grey))
          else if (message.status == MessageStatus.FAILED)
             const Text('Lỗi gửi', style: TextStyle(fontSize: 10, color: Colors.red))
          else
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
                    message.status == MessageStatus.DELIVERED || message.status == MessageStatus.READ
                        ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.status == MessageStatus.READ ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(message.status),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.status == MessageStatus.READ ? Colors.blue : (isDarkMode ? Colors.white70 : Colors.black54),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
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

  Widget _buildReplyQuote(BuildContext context, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        if (message.replyToMessageId != null) {
          onReplyTap?.call(message.replyToMessageId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isDarkMode ? Colors.blue[300]! : const Color(0xFF0068FF), 
              width: 2.5
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.replyToSenderName ?? 'Người dùng',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isDarkMode ? Colors.blue[300] : const Color(0xFF0068FF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.replyToContent ?? '[Phương tiện]',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
