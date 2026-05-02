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
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_reactions.dart';
import 'package:vnalo_mobile/models/message_reaction_model.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/poll_widget.dart';
import 'package:vnalo_mobile/services/chat_service.dart';

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
  final List<MessageReaction>? reactions;
  final String? currentUserId;
  final Function(String emoji)? onToggleReaction;
  final Function(String emoji)? onShowReactors;
  final bool canPin;
  final bool canRecall;

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
    this.reactions,
    this.currentUserId,
    this.onToggleReaction,
    this.onShowReactors,
    this.canPin = true,
    this.canRecall = true,
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
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine)
                SizedBox(
                  width: 30,
                  child: Align(
                    alignment: Alignment.topLeft,
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
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _buildBubbleWrapper(context, isDarkMode),
                    if (reactions != null && reactions!.isNotEmpty && currentUserId != null)
                      MessageReactions(
                        reactions: reactions!,
                        currentUserId: currentUserId!,
                        onToggleReaction: onToggleReaction,
                        onShowReactors: onShowReactors,
                      ),
                    if (showTime) ...[
                      const SizedBox(height: 4),
                      _buildStatusLabel(context, isDarkMode, common),
                    ],
                  ],
                ),
              ),
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
          color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          border: Border.all(color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
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
          if (!isDarkMode && !isMediaOnly)
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
        ],
      ),
    );
  }

  Widget _buildBubbleWrapper(BuildContext context, bool isDarkMode) {
    final chatProvider = context.read<ChatProvider>();
    final isHighlighted =
        context.watch<ChatProvider>().highlightedMessageId == message.id;

    return GestureDetector(
      onTap: message.replyToMessageId != null ? () => onReplyTap?.call(message.replyToMessageId!) : null,
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
    final isAiAssistant = message.conversationId == 'AI_ASSISTANT_LOCAL';

    FocusedMessageDialog.show(
      context,
      message: message,
      isMine: isMine,
      isCloud: isCloud,
      isPinned: chatProvider.isMessagePinned(message.conversationId, message.id),
      isAiAssistant: isAiAssistant,
      canPin: canPin,
      canRecall: isMine && canRecall,
      position: position,
      size: size,
      child: _buildBubbleContent(context, isDarkMode),
      onAction: (action) async {
        if (action == 'ask_ai') {
          final aiProvider = context.read<AiAssistantProvider>();
          aiProvider.analyzeMessageContext(message);
        } else if (action == 'ai_translate') {
          final aiProvider = context.read<AiAssistantProvider>();
          aiProvider.translateMessage(message);
        } else if (action == 'summarize_video') {
          final aiProvider = context.read<AiAssistantProvider>();
          aiProvider.summarizeVideo(message);
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
            final common = CommonTexts.of(context, listen: false);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.recallAction),
                content: Text(common.confirmRecallMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: Text(common.recallAction),
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
            final common = CommonTexts.of(context, listen: false);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.deleteForMeAction),
                content: Text(common.deleteHistoryWarning),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(common.deleteForMeAction),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              if (message.conversationId == 'AI_ASSISTANT_LOCAL') {
                await context.read<AiAssistantProvider>().deleteMessage(message.id);
              } else {
                await chatProvider.deleteForMe(
                  message.id,
                  message.conversationId,
                );
              }
            }
          }
        } else if (action == 'pin') {
          final pins = chatProvider.getPinnedMessagesForConversation(message.conversationId);
          if (pins.length >= 3) {
            // Already 3 pins — show dialog to unpin first
            if (context.mounted) {
              PinnedMessageBar.showPinLimitDialog(context, message);
            }
          } else {
            chatProvider.pinMessage(message.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(common.pinActionTag)),
              );
            }
          }
        } else if (action == 'unpin') {
          if (context.mounted) {
            final common = CommonTexts.of(context, listen: false);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(common.confirmUnpinTitle),
                content: Text('${common.confirmUnpinTitle} "${message.content ?? ''}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(common.unpinAction),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              chatProvider.unpinMessage(message.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(common.unpinSuccess)),
                );
              }
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
        } else if (action.startsWith('emoji_')) {
          final emoji = action.substring(6); // Remove 'emoji_' prefix
          debugPrint('Emoji action received: $emoji');
          // Close the action menu when selecting an emoji
          Navigator.pop(context);
          if (onToggleReaction != null) {
            debugPrint('Calling onToggleReaction with emoji: $emoji');
            onToggleReaction!(emoji);
          } else {
            debugPrint('onToggleReaction is null');
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
      case MessageType.POLL:
        return PollWidget(
          message: message,
          isDarkMode: isDarkMode,
          onVote: (optionIndex) async {
            final chatService = context.read<ChatService>();
            try {
              await chatService.votePoll(message.id, optionIndex);
            } catch (e) {
              debugPrint('[PollWidget] Vote failed: $e');
            }
          },
        );
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 16,
            color:
                isMine
                    ? (isDarkMode ? Colors.white : LightColors.textPrimary)
                    : (isDarkMode
                        ? DarkColors.textPrimary
                        : LightColors.textPrimary),
            height: 1.35,
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

    final labelColor =
        isDarkMode
            ? DarkColors.textSecondary
            : (isMine ? AppColors.iconSubtle : LightColors.textSecondary);
    final dividerColor =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.itemDivider;

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
                  const SizedBox(width: 180),
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
                        canCallAgain ? AppColors.primary : (isDarkMode ? Colors.white24 : Colors.black26),
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
    if (callLog.isGroup) {
      return isVideo ? 'Cuộc gọi video nhóm' : 'Cuộc gọi thoại nhóm';
    }

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
                      placeholder: (context, url) => Container(
                        color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('[MEDIA] ❌ Load Failed: $url - Error: $error');
                        return Container(
                          color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                              if (isDarkMode) const SizedBox(height: 4),
                              const Text('Lỗi tải ảnh', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        );
                      },
                    ),
          );
        },
      ),
    );
  }

  /// Trả về true nếu URL là ảnh GIF (từ Giphy, Tenor hoặc đuôi .gif)
  bool _isGifUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.gif') ||
        lower.contains('giphy.com') ||
        lower.contains('tenor.com') ||
        lower.contains('media.tenor') ||
        lower.contains('media.giphy');
  }

  Widget _buildImage(BuildContext context) {
    final rawUrl = message.mediaUrl ?? '';
    debugPrint('[_buildImage] msgId=${message.id} type=${message.messageType} rawUrl="$rawUrl" content="${message.content}"');
    if (rawUrl.isEmpty) {
      debugPrint('[_buildImage] ⚠️ rawUrl is EMPTY, checking content="${message.content}"');
      return const SizedBox.shrink();
    }

    // Check if it's a real local file path (mobile storage paths)
    final isLocalFile = rawUrl.startsWith('/data/') || 
                        rawUrl.startsWith('/var/') ||
                        rawUrl.startsWith('file://') ||
                        (rawUrl.contains('/storage/emulated/') && !rawUrl.contains('/api/')) ||
                        (rawUrl.contains('Users/') && Platform.isIOS) ||
                        (rawUrl.contains('DCIM/') || rawUrl.contains('Pictures/') && Platform.isIOS);
    
    // Determine if we should use file or network loading
    final useLocalFile = isLocalFile && File(rawUrl.replaceFirst('file://', '')).existsSync();
    
    // If it's just an ID and not local, resolve it via MediaService pattern
    String resolvedRaw = rawUrl;
    if (!useLocalFile && !rawUrl.contains('/') && !rawUrl.contains('.') && !rawUrl.startsWith('http')) {
      // We don't have direct access to MediaService here easily without context.read,
      // but we know the pattern from MediaService.getPublicUrl.
      // However, AvatarResolver.resolveUrl already handles prepending the base.
      // We just need to make sure it has the /media/public/ prefix if it's an ID.
      resolvedRaw = '/media/public/$rawUrl';
    }

    final url = useLocalFile ? rawUrl.replaceFirst('file://', '') : (AvatarResolver.resolveUrl(resolvedRaw) ?? resolvedRaw);
    final isGif = !useLocalFile && _isGifUrl(url);

    // GIF hiển thị nhỏ gọn (160×160), ảnh thường thì full width
    final double maxW = isGif ? 160 : MediaQuery.of(context).size.width * 0.75;
    final double maxH = isGif ? 160 : 300;

    debugPrint('[_buildImage] rawUrl=$rawUrl isLocalFile=$isLocalFile useLocalFile=$useLocalFile resolvedUrl=$url');

    return GestureDetector(
      onTap: () {
        final auth = context.read<AuthProvider>();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => FullScreenImageViewer(
                  imageUrl: url,
                  isLocal: useLocalFile,
                  accessToken: auth.accessToken,
                ),
          ),
        );
      },
      child: Hero(
        tag: 'message_${message.id}',
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              useLocalFile
                  ? Image.file(File(url), fit: BoxFit.cover)
                  : CachedNetworkImage(
                    imageUrl: url,
                    fit: isGif ? BoxFit.contain : BoxFit.cover,
                    httpHeaders: (AvatarResolver.isInternalUrl(url))
                        ? {'Authorization': 'Bearer ${context.read<AuthProvider>().accessToken}'}
                        : const {},
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      width: isGif ? 160 : 200,
                      height: isGif ? 160 : 200,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, bool isDarkMode) {
    final common = CommonTexts.of(context);
    final fileName = message.content ?? 'File';
    final isDownloaded = message.mediaUrl != null && File(message.mediaUrl!).existsSync();

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? DarkColors.surfaceLight 
            : (isMine ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isDarkMode ? Colors.white : (isMine ? AppColors.primary : AppColors.primary),
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : (isMine ? LightColors.textPrimary : LightColors.textPrimary),
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    Text(
                      isDownloaded ? common.downloadedLabel : common.documentLabel,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : (isMine ? LightColors.textSecondary : LightColors.textSecondary),
                        fontSize: 12
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (isDownloaded) {
                  OpenFile.open(message.mediaUrl);
                } else {
                  // Trigger download via ChatProvider
                  context.read<ChatProvider>().downloadFile(message);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isDownloaded ? common.openFileAction : common.downloadAction),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(BuildContext context) {
    final url = AvatarResolver.resolveUrl(message.mediaUrl ?? '') ?? '';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AudioPlayerWidget(
        audioUrl: url,
        isMine: isMine,
        transcriptText: message.content,
      ),
    );
  }

  Widget _buildSticker(BuildContext context) {
    final rawUrl = message.mediaUrl ?? '';
    if (rawUrl.isEmpty) return const SizedBox.shrink();
    
    final url = AvatarResolver.resolveUrl(rawUrl) ?? rawUrl;
    final token = context.read<AuthProvider>().accessToken;

    return SizedBox(
      width: 120,
      height: 120,
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
            ? {'Authorization': 'Bearer $token'}
            : const {},
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    final common = CommonTexts.of(context);
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            Text(common.videoAction, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context, bool isDarkMode, CommonTexts common) {
    final timeStr = DateFormatter.time(message.createdAt);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (showTime)
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
            ),
          ),
        if (isMine && showStatus) ...[
          if (showTime) const SizedBox(width: 4),
          _StatusIcon(status: message.status),
        ],
        if (readByMembers != null && readByMembers!.isNotEmpty) ...[
          if (showTime) const SizedBox(width: 6),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayed.map(
          (m) => Padding(
            padding: const EdgeInsets.only(left: 2),
            child: ClipOval(
              child: Builder(
                builder: (context) {
                  final token = context.watch<AuthProvider>().accessToken;
                  final url = AvatarResolver.resolveUrl(m.user?.avatarUrl);
                  
                  if (url == null) {
                    return Container(
                      width: 14,
                      height: 14,
                      color: Colors.grey,
                      child: const Icon(Icons.person, size: 10, color: Colors.white),
                    );
                  }

                  return CachedNetworkImage(
                    imageUrl: url,
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                    httpHeaders: (token != null && AvatarResolver.isInternalUrl(url))
                        ? {'Authorization': 'Bearer $token'}
                        : const {},
                    placeholder: (_, __) => Container(width: 14, height: 14, color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) => Container(
                      width: 14,
                      height: 14,
                      color: Colors.grey,
                      child: const Icon(Icons.person, size: 10, color: Colors.white),
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
    );
  }

  Widget _buildReplyQuote(BuildContext context, bool isDarkMode) {
    String replyName = message.replyToSenderName ?? 'User';
    if (message.replyToSenderName == null && message.replyToSenderId != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      replyName = chatProvider.getSenderName(message.conversationId, message.replyToSenderId!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : (isMine ? Colors.white.withValues(alpha: 0.4) : AppColors.itemPressBackground),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isDarkMode ? DarkColors.primary : AppColors.primary,
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
              color: isDarkMode ? DarkColors.primary : AppColors.primary,
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
                      : LightColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.SENDING:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
        );
      case MessageStatus.SENT:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case MessageStatus.DELIVERED:
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case MessageStatus.READ:
        return const Icon(Icons.done_all, size: 14, color: AppColors.primary);
      case MessageStatus.FAILED:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
      case MessageStatus.RECALLED:
        return Icon(
          Icons.history_rounded,
          size: 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white38
              : Colors.grey.shade400,
        );
    }
  }
}
