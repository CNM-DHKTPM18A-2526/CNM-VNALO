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
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:open_file/open_file.dart';
import 'package:vnalo_mobile/features/chat/widgets/full_screen_image_viewer.dart';
import 'package:vnalo_mobile/features/chat/widgets/audio_player_widget.dart';
import 'package:flutter/services.dart';
import 'package:vnalo_mobile/features/chat/providers/forward_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/forward_screen.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final List<ConversationMember>? readByMembers;
  final VoidCallback? onRetry;
  final bool showTime;
  final bool showStatus;
  final String? milestoneText;
  final List<Message>? groupedMessages;
  final String? senderAvatarUrl;
  final String? senderDisplayName;
  final Function(Message)? onReplyAction;
  final Function(Message)? onDeleteAction;
  final Function(Message)? onForwardAction;
  final Function(String)? onReplyTap;
  final bool showAvatar;

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
    this.senderAvatarUrl,
    this.senderDisplayName,
    this.onReplyAction,
    this.onDeleteAction,
    this.onForwardAction,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context, listen: false);

    return Column(
      children: [
        if (milestoneText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
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
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMine)
                    SizedBox(
                      width: 30,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child:
                            showAvatar
                                ? AvatarWidget(
                                  imageUrl: senderAvatarUrl,
                                  name:
                                      senderDisplayName ??
                                      message.senderName ??
                                      'User',
                                  size: 24,
                                )
                                : const SizedBox(width: 24, height: 24),
                      ),
                    ),
                  if (!isMine) const SizedBox(width: 6),
                  Flexible(child: _buildBubbleWrapper(context, isDarkMode)),
                ],
              ),
              if (isMine ||
                  showTime ||
                  (readByMembers != null && readByMembers!.isNotEmpty)) ...[
                const SizedBox(height: 4),
                _buildStatusLabel(context, isDarkMode, common),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContent(BuildContext context, bool isDarkMode) {
    final common = CommonTexts.of(context, listen: false);
    final callLog = CallLogMessage.tryParse(message.content);
    if (callLog != null) {
      return _buildCallLogCard(context, isDarkMode, callLog, common);
    }

    if (message.isRecalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : Colors.transparent,
          border: Border.all(color: isDarkMode ? DarkColors.divider : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 16, color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              common.msgRecalled,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (groupedMessages != null && groupedMessages!.isNotEmpty) {
      return _buildImageGrid(context, isDarkMode);
    }

    if (message.messageType == MessageType.STICKER) {
      return _buildSticker(context);
    }

    final isMediaOnly = message.messageType == MessageType.IMAGE || message.messageType == MessageType.VIDEO;
    
    final bubbleColor = isMediaOnly
        ? Colors.transparent
        : (isMine
            ? (isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent)
            : (isDarkMode ? DarkColors.chatBubbleReceived : LightColors.chatBubbleReceived));

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: isMediaOnly
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
        border: isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)
            : null,
        boxShadow: [
          if (!isDarkMode && !isMine && !isMediaOnly)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
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
          if (showTime && !isMediaOnly)
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
    final isHighlighted =
        context.watch<ChatProvider>().highlightedMessageId == message.id;

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
          border:
              isHighlighted
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
    final common = CommonTexts.of(context, listen: false);

    // Skip action menu for recalled messages.
    if (message.isRecalled) return;

    final isCloud = message.conversationId == 'MY_DOCUMENTS' || message.conversationId == 'my_documents_conversation';

    FocusedMessageDialog.show(
      context,
      message: message,
      isMine: isMine,
      isCloud: isCloud,
      position: position,
      size: size,
      child: _buildBubbleContent(context, isDarkMode),
      onAction: (action) async {
        if (action == 'ask_ai') {
          final aiProvider = context.read<AiAssistantProvider>();
          aiProvider.analyzeMessageContext(message);
        } else if (action == 'reply') {
          if (onReplyAction != null) {
            onReplyAction!(message);
          } else {
            chatProvider.setReplyTo(message);
          }
        } else if (action == 'copy') {
          if (message.messageType == MessageType.TEXT) {
             Clipboard.setData(ClipboardData(text: message.content ?? ''));
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(common.msgCopiedToast)),
               );
             }
           }
        } else if (action == 'recall') {
          if (context.mounted) {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.recallMessageTitle),
                content: Text(common.recallMessagePrompt),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: Text(common.recallMessageTitle),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              chatProvider.recallMessage(message.id, message.conversationId);
            }
          }
        } else if (action == 'delete') {
          if (onDeleteAction != null) {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.deleteMessageTitle),
                content: Text(common.deleteMessagePrompt),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(common.cancel)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(common.deleteMessageTitle),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              onDeleteAction!(message);
            }
            return;
          }
          if (context.mounted) {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.deleteMessageTitle),
                content: Text(common.deleteMessagePrompt),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(common.deleteMessageTitle),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await chatProvider.deleteForMe(
                message.id,
                message.conversationId,
              );
            }
          }
        } else if (action == 'forward') {
          if (onForwardAction != null) {
            onForwardAction!(message);
            return;
          }
          final forwardProvider = context.read<ForwardProvider>();
          forwardProvider.startForwarding([message]);

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForwardScreen()),
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
      case MessageType.STICKER:
        return _buildSticker(context);
      case MessageType.VIDEO:
        return _buildVideoPlayer(context);
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color:
                isMine
                    ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                    : (isDarkMode
                        ? DarkColors.textPrimary
                        : LightColors.textPrimary),
            height: 1.3,
          ),
        );
    }
  }

  Widget _buildCallLogCard(
    BuildContext context,
    bool isDarkMode,
    CallLogMessage callLog,
    CommonTexts common,
  ) {
    final incoming = !isMine;
    final isVideo = callLog.mediaType == CallMediaType.video;
    final canCallAgain = _resolveCallAgainTarget(context, callLog) != null;
    final cardColor =
        isDarkMode
            ? (isMine ? DarkColors.callLogSent : DarkColors.callLogReceived)
            : (isMine ? LightColors.callLogSent : LightColors.callLogReceived);

    final titleColor = _callLogTitleColor(callLog.outcome, isDarkMode);
    final isMissed =
        callLog.outcome == CallOutcome.missed ||
        callLog.outcome == CallOutcome.failed;

    // Contrast text colors for Light Mode
    final labelColor =
        isDarkMode
            ? Colors.white60
            : (isMine ? const Color(0xFF5D6470) : LightColors.textSecondary);
    final dividerColor =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

    final title = _callLogTitle(callLog, incoming, isVideo);
    final subtitle = _callLogSubtitle(callLog, isVideo);
    final subtitleIcon = _callLogSubtitleIcon(callLog, isVideo, incoming);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 16),
        ),
        border: isDarkMode
            ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)
            : null,
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                const SizedBox(width: 180), // Đảm bảo chiều rộng tối thiểu đẹp như Zalo
                Row(
                  children: [
                    Icon(
                      subtitleIcon,
                      size: 15,
                      color: isMissed ? titleColor.withValues(alpha: 0.8) : labelColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: dividerColor),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  canCallAgain
                      ? () => _handleCallAgain(context, callLog)
                      : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                common.callAgainAction,
                style: TextStyle(
                  color:
                      canCallAgain ? const Color(0xFF1890FF) : (isDarkMode ? Colors.white30 : Colors.black26),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  String _callLogTitle(CallLogMessage callLog, bool incoming, bool isVideo) {
    final base = isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';

    switch (callLog.outcome) {
      case CallOutcome.answered:
        return incoming ? '$base đến' : '$base đi';
      case CallOutcome.declined:
        return incoming ? 'Bạn đã từ chối' : 'Người nhận đã từ chối';
      case CallOutcome.missed:
        return incoming ? 'Bạn bị nhỡ' : 'Không trả lời';
      case CallOutcome.busy:
        return incoming ? 'Bạn bận' : 'Người nhận bận';
      case CallOutcome.canceled:
        return incoming ? 'Cuộc gọi đã hủy' : 'Bạn đã hủy cuộc gọi';
      case CallOutcome.failed:
        return 'Cuộc gọi thất bại';
    }
  }

  String _callLogSubtitle(CallLogMessage callLog, bool isVideo) {
    if (callLog.outcome == CallOutcome.answered) {
      final minutes = callLog.durationSeconds ~/ 60;
      final seconds = callLog.durationSeconds % 60;
      return '$minutes phút $seconds giây';
    }
    return isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
  }

  String? _resolveCallAgainTarget(
    BuildContext context,
    CallLogMessage callLog,
  ) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null || currentUserId.isEmpty) return null;

    if (callLog.callerId == currentUserId) return callLog.calleeId;
    if (callLog.calleeId == currentUserId) return callLog.callerId;

    return message.senderId == currentUserId
        ? callLog.calleeId
        : callLog.callerId;
  }

  void _handleCallAgain(BuildContext context, CallLogMessage callLog) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final targetUserId = _resolveCallAgainTarget(context, callLog);
    if (currentUserId == null || targetUserId == null || targetUserId.isEmpty) {
      return;
    }

    final targetDisplayName =
        senderDisplayName ?? message.senderName ?? 'Người dùng';
    final targetAvatar = senderAvatarUrl ?? message.senderAvatarUrl;
    final route = MaterialPageRoute(
      builder: (_) {
        if (callLog.mediaType == CallMediaType.video) {
          return VideoCallScreen(
            conversationId: message.conversationId,
            callId: generateCallId(
              conversationId: message.conversationId,
              callerUserId: currentUserId,
              audioOnly: false,
            ),
            targetUserId: targetUserId,
            targetDisplayName: targetDisplayName,
            targetAvatarUrl: targetAvatar,
            isCaller: true,
          );
        }

        return VoiceCallScreen(
          conversationId: message.conversationId,
          callId: generateCallId(
            conversationId: message.conversationId,
            callerUserId: currentUserId,
            audioOnly: true,
          ),
          targetUserId: targetUserId,
          targetDisplayName: targetDisplayName,
          targetAvatarUrl: targetAvatar,
          isCaller: true,
        );
      },
    );
    Navigator.push(context, route);
  }

  IconData _callLogSubtitleIcon(
    CallLogMessage callLog,
    bool isVideo,
    bool incoming,
  ) {
    if (isVideo) {
      return Icons.videocam_outlined;
    }

    if (callLog.outcome == CallOutcome.missed) {
      return Icons.call_missed;
    }

    if (callLog.outcome == CallOutcome.declined) {
      return Icons.call_end;
    }

    return incoming ? Icons.call_received : Icons.call_made;
  }

  Color _callLogTitleColor(CallOutcome outcome, bool isDarkMode) {
    switch (outcome) {
      case CallOutcome.declined:
      case CallOutcome.missed:
      case CallOutcome.busy:
      case CallOutcome.failed:
        return const Color(0xFFFF6B6B);
      default:
        return isDarkMode ? Colors.white : LightColors.textPrimary;
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
          final isLocal =
              url.startsWith('/') ||
              url.contains('Users') ||
              url.contains('storage');
          
          final resolvedUrl = isLocal ? url : (AvatarResolver.resolveUrl(url) ?? url);
          final auth = context.read<AuthProvider>();
          final token = auth.accessToken;

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => FullScreenImageViewer(
                        imageUrl: resolvedUrl,
                        isLocal: isLocal,
                        accessToken: token,
                      ),
                ),
              );
            },
            child:
                isLocal
                    ? Image.file(File(url), fit: BoxFit.cover)
                    : CachedNetworkImage(
                      imageUrl: resolvedUrl,
                      fit: BoxFit.cover,
                      httpHeaders: (token != null && AvatarResolver.isInternalUrl(resolvedUrl))
                          ? {'Authorization': 'Bearer $token'}
                          : const {},
                      placeholder: (context, url) => Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
          );
        },
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final rawUrl = message.mediaUrl ?? '';
    if (rawUrl.isEmpty) return const SizedBox.shrink();

    final isLocal = rawUrl.startsWith('/') || rawUrl.contains('Users') || rawUrl.contains('storage');
    final url = isLocal ? rawUrl : (AvatarResolver.resolveUrl(rawUrl) ?? rawUrl);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => FullScreenImageViewer(imageUrl: url, isLocal: isLocal),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 280,
          minWidth: 150, // Minimum width so it doesn't look too skinny
        ),
        child: isLocal
            ? Image.file(File(url), fit: BoxFit.cover)
            : Builder(
                builder: (context) {
                  final token = context.watch<AuthProvider>().accessToken;
                  return CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    ),
                  );
                }
              ),
      ),
    );
  }

  Widget _buildSticker(BuildContext context) {
    final rawUrl = message.mediaUrl ?? '';
    final url = AvatarResolver.resolveUrl(rawUrl) ?? rawUrl;
    final token = context.watch<AuthProvider>().accessToken;

    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
            ? {'Authorization': 'Bearer $token'}
            : const {},
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget:
            (context, url, error) =>
                const Icon(Icons.error_outline, color: Colors.grey),
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
                  message.content ?? 'Document',
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
                    color:
                        isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
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
    return AudioPlayerWidget(audioUrl: message.mediaUrl ?? '', isMine: isMine);
  }


  Widget _buildVideoPlayer(BuildContext context) {
    final thumbnailUrl = message.mediaThumbnailUrl ?? '';
    final url = AvatarResolver.resolveUrl(thumbnailUrl.isNotEmpty ? thumbnailUrl : (message.mediaUrl ?? '')) ?? '';
    
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (url.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Builder(
                  builder: (context) {
                    final token = context.watch<AuthProvider>().accessToken;
                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
                          ? {'Authorization': 'Bearer $token'}
                          : const {},
                      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.videocam, size: 40, color: Colors.grey)),
                    );
                  }
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context, bool isDarkMode, CommonTexts common) {
    if (!showStatus && !showTime && readByMembers?.isEmpty == true) {
      return const SizedBox.shrink();
    }

    final bool isImage =
        message.messageType == MessageType.IMAGE ||
        (groupedMessages != null && groupedMessages!.isNotEmpty);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTime && isImage) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.1),
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
            Text(
              common.msgSending,
              style: TextStyle(fontSize: 10, color: Colors.grey),
            )
          else if (message.status == MessageStatus.FAILED)
            Text(
              common.msgSendFailed,
              style: const TextStyle(fontSize: 10, color: Colors.red),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.status == MessageStatus.DELIVERED ||
                            message.status == MessageStatus.READ
                        ? Icons.done_all
                        : Icons.done,
                    size: 12,
                    color:
                        message.status == MessageStatus.READ
                            ? Colors.blue
                            : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(message.status, common),
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          message.status == MessageStatus.READ
                              ? Colors.blue
                              : (isDarkMode ? Colors.white70 : Colors.black54),
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
    if (readByMembers == null || readByMembers!.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayed = readByMembers!.take(4).toList();
    final remainingCount = readByMembers!.length - displayed.length;

    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...displayed.map(
            (m) => Padding(
              padding: const EdgeInsets.only(left: 2),
              child: ClipOval(
              child: Builder(
                builder: (context) {
                  final token = context.watch<AuthProvider>().accessToken;
                  final url = AvatarResolver.resolveUrl(m.user?.avatarUrl) ??
                      'https://ui-avatars.com/api/?name=${m.user?.displayName ?? 'U'}';
                  return CachedNetworkImage(
                    imageUrl: url,
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                    httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    errorWidget: (_, __, ___) => Container(
                      width: 14,
                      height: 14,
                      color: Colors.grey,
                      child: const Icon(
                        Icons.person,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
              ),
              ),
            ),
          ),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText(MessageStatus status, CommonTexts common) {
    switch (status) {
      case MessageStatus.SENT:
        return common.msgSent;
      case MessageStatus.DELIVERED:
        return common.msgDelivered;
      case MessageStatus.READ:
        return common.msgSeen;
      default:
        return '';
    }
  }

  Widget _buildReplyQuote(BuildContext context, bool isDarkMode) {
    String replyName = message.replyToSenderName ?? 'User';
    if (message.replyToSenderName == null && message.replyToSenderId != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      replyName = chatProvider.getSenderName(message.conversationId, message.replyToSenderId!);
    }

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
          color:
              isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isDarkMode ? Colors.blue[300]! : const Color(0xFF0068FF),
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isDarkMode ? Colors.blue[300] : const Color(0xFF0068FF),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.replyToContent ?? '[Media]',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDarkMode
                        ? DarkColors.textSecondary
                        : const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
