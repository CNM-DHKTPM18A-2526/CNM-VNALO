import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/widgets/group_avatar.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_input_bar.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';
import 'package:vnalo_mobile/features/chat/widgets/system_message.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_options_screen.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/group_call_picker_screen.dart';
import 'package:vnalo_mobile/features/call/widgets/active_call_banner.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/chat/screens/group_chat_options_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/reaction_detail_screen.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'dart:async';

class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final User? friendUser;
  final String? prefilledText;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.friendUser,
    this.prefilledText,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  Timer? _subtextTimer;
  bool _showGroupMembers = false;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  User? _friendSnapshot;
  ChatProvider? _chatProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= context.read<ChatProvider>();
  }

  @override
  void initState() {
    super.initState();
    _friendSnapshot = widget.friendUser;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUserId = context.read<AuthProvider>().user?.id ?? '';
      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentUserId(currentUserId);
      chatProvider.openConversation(widget.conversation.id);
      chatProvider.loadPinnedMessages(widget.conversation.id);

      // Auto-switch to group member subtitle after a short delay.
      if (widget.conversation.type == ConversationType.GROUP) {
        _subtextTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showGroupMembers = true);
          }
        });
      }

      _scrollController.addListener(_onScroll);
    });
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    // In reverse mode, scroll position increases as we scroll UP
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final chatProvider = context.read<ChatProvider>();
      final messages = chatProvider.getMessagesForConversation(
        widget.conversation.id,
      );

      if (messages.isNotEmpty) {
        setState(() => _isLoadingMore = true);
        final oldestId = messages.last.id;

        chatProvider
            .loadMessages(widget.conversation.id, before: oldestId)
            .then((_) {
              if (mounted) setState(() => _isLoadingMore = false);
            })
            .catchError((_) {
              if (mounted) setState(() => _isLoadingMore = false);
            });
      }
    }
  }

  @override
  void dispose() {
    _subtextTimer?.cancel();
    _scrollController.dispose();
    _chatProvider?.closeConversation();
    super.dispose();
  }

  void _jumpToMessage(String messageId, List<dynamic> items) {
    final index = items.indexWhere((item) {
      if (item is Message) return item.id == messageId;
      if (item is List<Message>) {
        return item.any((m) => m.id == messageId);
      }
      return false;
    });

    if (index != -1) {
      _scrollController
          .animateTo(
            index * 80.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (mounted) {
              context.read<ChatProvider>().highlightMessage(messageId);
            }
          });
    }
  }

  String _getDisplayName(String currentUserId, Conversation conversation) {
    if (conversation.type == ConversationType.DIRECT &&
        conversation.members.isNotEmpty) {
      return conversation.getDisplayName(currentUserId);
    }
    if (_friendSnapshot != null) {
      return _friendSnapshot!.displayName;
    }
    return conversation.getDisplayName(currentUserId);
  }

  String? _getAvatarUrl(String currentUserId, Conversation conversation) {
    if (conversation.type == ConversationType.DIRECT &&
        conversation.members.isNotEmpty) {
      return conversation.getDisplayAvatarUrl(currentUserId);
    }
    if (_friendSnapshot != null) {
      return _friendSnapshot!.avatarUrl;
    }
    return conversation.getDisplayAvatarUrl(currentUserId);
  }

  String? _getCoverUrl(String currentUserId, Conversation conversation) {
    if (_friendSnapshot != null) {
      return _friendSnapshot!.coverUrl;
    }
    final isDirect = conversation.type == ConversationType.DIRECT;
    if (isDirect && conversation.members.isNotEmpty) {
      final other = conversation.members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => conversation.members.first,
      );
      return other.user?.coverUrl;
    }
    return null;
  }

  String? _resolvePeerUserId(String currentUserId, Conversation conversation) {
    if (_friendSnapshot != null && _friendSnapshot!.id.isNotEmpty) {
      return _friendSnapshot!.id;
    }

    if (conversation.type == ConversationType.DIRECT &&
        conversation.members.isNotEmpty) {
      final other = conversation.members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => conversation.members.first,
      );
      if (other.userId == currentUserId) {
        return null;
      }
      return other.userId;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Consumer<ChatProvider>(
      builder: (context, chat, child) {
        final conv = chat.conversations.firstWhere(
          (c) => c.id == widget.conversation.id,
          orElse: () => widget.conversation,
        );

        final displayName = _getDisplayName(currentUserId, conv);
        final avatarUrl = _getAvatarUrl(currentUserId, conv);
        final coverUrl = _getCoverUrl(currentUserId, conv);
        final isDirect =
            conv.type == ConversationType.DIRECT || widget.friendUser != null;
        final wallpaperUrl = conv.personalWallpaperUrl ?? conv.wallpaperUrl;

        final isRestrictedSending = conv.type == ConversationType.GROUP && chat.isReadOnlyForMembers(conv.id);
        final myMember = conv.members.isEmpty 
            ? ConversationMember(conversationId: conv.id, userId: 'none', joinedAt: DateTime.now())
            : conv.members.firstWhere((m) => m.userId == currentUserId, orElse: () => conv.members.first);
        final canSend = !isRestrictedSending || myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;

        return Scaffold(
          backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
          appBar: AppBar(
            titleSpacing: 0,
            backgroundColor:
                isDarkMode ? DarkColors.appBarBg : Colors.transparent,
            elevation: 0,
            forceMaterialTransparency: !isDarkMode,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace:
                isDarkMode
                    ? null
                    : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.appBarGradient,
                      ),
                    ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                _buildSubtext(isDirect),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call_outlined, color: Colors.white),
                onPressed: () {
                  if (!isDirect) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupCallPickerScreen(conversation: conv),
                      ),
                    );
                    return;
                  }

                  final peerUserId = _resolvePeerUserId(currentUserId, conv);
                  if (peerUserId == null || peerUserId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(common.cannotOpenChat)),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VoiceCallScreen(
                            conversationId: conv.id,
                            callId: generateCallId(
                              conversationId: conv.id,
                              callerUserId: currentUserId,
                              audioOnly: true,
                            ),
                            targetUserId: peerUserId,
                            targetDisplayName: displayName,
                            targetAvatarUrl: avatarUrl,
                            isCaller: true,
                          ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined, color: Colors.white),
                onPressed: () {
                  if (!isDirect) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupCallPickerScreen(conversation: conv),
                      ),
                    );
                    return;
                  }

                  final peerUserId = _resolvePeerUserId(currentUserId, conv);
                  if (peerUserId == null || peerUserId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(common.cannotOpenChat)),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VideoCallScreen(
                            conversationId: conv.id,
                            callId: generateCallId(
                              conversationId: conv.id,
                              callerUserId: currentUserId,
                              audioOnly: false,
                            ),
                            targetUserId: peerUserId,
                            targetDisplayName: displayName,
                            targetAvatarUrl: avatarUrl,
                            isCaller: true,
                          ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => conv.type == ConversationType.GROUP 
                        ? GroupChatOptionsScreen(conversation: conv)
                        : ChatOptionsScreen(conversation: conv),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration:
                wallpaperUrl != null
                    ? BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(wallpaperUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(
                            alpha: isDarkMode ? 0.35 : 0.15,
                          ),
                          BlendMode.darken,
                        ),
                      ),
                    )
                    : null,
            child: Column(
              children: [
                PinnedMessageBar(
                  conversationId: conv.id,
                  onMessageTap: (msgId) {
                    final rawItems = chat.getMessagesForConversation(conv.id);
                    _jumpToMessage(msgId, rawItems);
                  },
                ),
                ActiveCallBanner(
                  conversationId: conv.id,
                  conversationName: displayName,
                  conversationAvatarUrl: avatarUrl,
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final rawItems = chat.getMessagesForConversation(conv.id);
                      final List<dynamic> items = [];
                      for (int i = 0; i < rawItems.length; i++) {
                        final msg = rawItems[i];
                        if (msg.messageType == MessageType.IMAGE && msg.status != MessageStatus.RECALLED) {
                          if (items.isNotEmpty && items.last is List<Message>) {
                            final group = items.last as List<Message>;
                            final newestInGroup = group.first;
                            if (newestInGroup.senderId == msg.senderId &&
                                newestInGroup.createdAt
                                        .difference(msg.createdAt)
                                        .inMinutes
                                        .abs() <
                                    2) {
                              group.add(msg);
                              continue;
                            }
                          }
                          items.add([msg]);
                        } else {
                          items.add(msg);
                        }
                      }

                      for (int i = 0; i < items.length; i++) {
                        if (items[i] is List<Message> &&
                            (items[i] as List<Message>).length == 1) {
                          items[i] = (items[i] as List<Message>).first;
                        }
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            if (isDirect) {
                              return _buildFriendProfileCard(displayName, avatarUrl, coverUrl, chat, conv, currentUserId, isDirect);
                            } else {
                              return _buildGroupProfileCard(displayName, conv, chat, currentUserId);
                            }
                          }

                          final item = items[index];
                          final message =
                              item is List<Message>
                                  ? item.first
                                  : item as Message;
                          final groupedMessages =
                              item is List<Message> ? item : null;
                          final isMine = message.isMine(currentUserId);

                          bool showTime = true;
                          if (index > 0) {
                            final nextRecentItem = items[index - 1];
                            final nextRecentMsg =
                                nextRecentItem is List<Message>
                                    ? nextRecentItem.last
                                    : nextRecentItem as Message;
                            final sameSender =
                                nextRecentMsg.senderId == message.senderId;
                            final timeGap =
                                nextRecentMsg.createdAt
                                    .difference(message.createdAt)
                                    .inMinutes
                                    .abs();
                            // Show time only on the newest message of each consecutive group
                            // Hide if same sender AND within 5-minute window
                            if (sameSender && timeGap < 5) showTime = false;
                          }

                          final rawMyLatestIndex = rawItems.indexWhere(
                            (m) => m.senderId == currentUserId,
                          );
                          bool showStatus =
                              (isMine &&
                                  rawMyLatestIndex != -1 &&
                                  rawItems[rawMyLatestIndex].id == message.id);

                          String? milestoneText;
                          if (index == items.length - 1) {
                            milestoneText = DateFormatter.formatTimelineDate(
                              message.createdAt,
                            );
                          } else {
                            final olderItem = items[index + 1];
                            final olderMsg =
                                olderItem is List<Message>
                                    ? olderItem.first
                                    : olderItem as Message;
                            final gap =
                                message.createdAt
                                    .difference(olderMsg.createdAt)
                                    .inMinutes
                                    .abs();
                            if (gap > 20) {
                              milestoneText = DateFormatter.formatTimelineDate(
                                message.createdAt,
                              );
                            }
                          }

                          List<ConversationMember>? readByMembers;
                          if (isMine && message.serverSeq != null) {
                            readByMembers =
                                conv.members.where((m) {
                                  return m.userId != currentUserId &&
                                      m.lastReadSeq >= message.serverSeq!;
                                }).toList();
                          }

                          // Display system messages differently
                          if (message.isSystemMessage) {
                            return SystemMessage(
                              content: message.content ?? '',
                              timestamp: message.createdAt,
                              conversationId: conv.id,
                            );
                          }

                          final senderMember = conv.members.firstWhere(
                            (m) => m.userId == message.senderId,
                            orElse:
                                () => ConversationMember(
                                  conversationId: conv.id,
                                  userId: message.senderId,
                                  joinedAt: DateTime.now(),
                                ),
                          );

                          final isGroup = conv.type == ConversationType.GROUP;
                          final myRole = myMember.role;
                          final isAdmin = myRole == MemberRole.ADMIN || myRole == MemberRole.DEPUTY || myRole == MemberRole.DEPUTY;
                          
                          // Members can pin only if allowed
                          final canPin = !isGroup || conv.allowMemberPin || isAdmin;
                          
                          // Recall: normally members can recall their own messages. 
                          // If we wanted to restrict this, we'd use conv.allowMemberRecall (not yet in DTO).
                          // For now, let's just pass canPin logic as a proxy if needed, or keep it true for own messages.
                          const canRecall = true;

                          bool showAvatar = false;
                          if (!isMine) {
                            if (index == items.length - 1 || milestoneText != null) {
                              showAvatar = true;
                            } else {
                              final olderItem = items[index + 1];
                              final olderMsg = olderItem is List<Message> ? (olderItem as List<Message>).first : olderItem as Message;
                              if (olderMsg.senderId != message.senderId) {
                                showAvatar = true;
                              }
                            }
                          }

                          return MessageBubble(
                            message: message,
                            isMine: isMine,
                            showTime: showTime,
                            showAvatar: showAvatar,
                            senderAvatarUrl:
                                message.senderAvatarUrl ??
                                senderMember.user?.avatarUrl,
                            senderDisplayName:
                                message.senderName ??
                                senderMember.user?.displayName,
                            showStatus: showStatus,
                            milestoneText: milestoneText,
                            groupedMessages: groupedMessages,
                            readByMembers: readByMembers,
                            canPin: canPin,
                            canRecall: canRecall,
                            onReplyTap: (msgId) => _jumpToMessage(msgId, items),
                            onRetry:
                                message.status == MessageStatus.FAILED
                                    ? () => chat.retryMessage(message)
                                    : null,
                            reactions: chat.getReactionsForMessage(message.id),
                            currentUserId: _chatProvider?.currentUserId,
                            onToggleReaction: (emoji) {
                              debugPrint('onToggleReaction callback called in chat_detail_screen: emoji=$emoji');
                              _chatProvider?.toggleReaction(message.id, emoji);
                            },
                            onShowReactors: (emoji) {
                              debugPrint('onShowReactors callback called: emoji=$emoji');
                              _showReactionDetail(message.id, emoji);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (canSend)
                  ChatInputBar(
                    conversationId: conv.id,
                    onSend: (text) => chat.sendMessage(conversationId: conv.id, content: text),
                    onSendWithType: (content, messageType) => chat.sendMessage(
                      conversationId: conv.id,
                      content: content,
                      messageType: messageType,
                    ),
                    initialText: widget.prefilledText,
                    members: conv.members,
                    isGroup: conv.type == ConversationType.GROUP,
                  )
                else
                  _buildReadOnlyBanner(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtext(bool isDirect) {
    final common = CommonTexts.of(context);
    final chat = context.read<ChatProvider>();
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    
    if (isDirect) {
      final otherMember = widget.conversation.members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => widget.conversation.members.first,
      );
      
      final otherUserId = otherMember.userId;
      
      // Get the latest user object from provider to access lastSeen
      final convInProvider = chat.conversations.firstWhere((c) => c.id == widget.conversation.id, orElse: () => widget.conversation);
      final latestUser = convInProvider.members.firstWhere((m) => m.userId == otherMember.userId, orElse: () => otherMember).user;
      
      final bool isOnline = chat.isUserOnline(otherUserId);
      final DateTime? lastSeen = latestUser?.lastSeen;

      if (isOnline) {
        return const Text(
          'Đang hoạt động',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white, // Bright white for active status
            fontWeight: FontWeight.w500,
          ),
        );
      }

      if (lastSeen != null) {
        return Text(
          'Truy cập ${DateFormatter.relative(lastSeen)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
        );
      }

      return const SizedBox.shrink();
    }

    return Text(
      _showGroupMembers
          ? common.membersCountAtChat(widget.conversation.activeMemberCount)
          : common.clickForInfo,
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.8),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildFriendProfileCard(
    String displayName,
    String? avatarUrl,
    String? coverUrl,
    ChatProvider chat,
    Conversation conv,
    String currentUserId,
    bool isDirect,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: Column(
        children: [
          // Cover photo
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              color:
                  isDarkMode
                      ? DarkColors.primary.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
              image:
                  coverUrl != null
                      ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          AvatarResolver.resolveUrl(coverUrl) ?? coverUrl,
                          headers: (context.read<AuthProvider>().accessToken != null && AvatarResolver.isInternalUrl(AvatarResolver.resolveUrl(coverUrl) ?? coverUrl))
                              ? {'Authorization': 'Bearer ${context.read<AuthProvider>().accessToken}'}
                              : {},
                        ),
                        fit: BoxFit.cover,
                      )
                      : null,
              gradient:
                  coverUrl == null
                      ? LinearGradient(
                        colors:
                            isDarkMode
                                ? [
                                  DarkColors.primary,
                                  DarkColors.primary.withValues(alpha: 0.8),
                                ]
                                : [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.8),
                                ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
            ),
          ),
          // Avatar + Name
          Transform.translate(
            offset: const Offset(0, -30),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: AvatarWidget(
                    imageUrl: avatarUrl,
                    name: displayName,
                    size: 60,
                    showOnline: isDirect,
                    isOnline: isDirect && chat.isUserOnline(conv.members.firstWhere((m) => m.userId != currentUserId, orElse: () => conv.members.first).userId),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  common.startConversationNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionChip('👋', common.helloAction),
                    _buildActionChip('😊', common.niceToMeetAction),
                    _buildActionChip('🎉', common.hiAction),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupProfileCard(String displayName, Conversation conv, ChatProvider chat, String currentUserId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        children: [
          // Large Group Avatar
          if (conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty)
            AvatarWidget(imageUrl: conv.avatarUrl, name: displayName, size: 80)
          else
            GroupAvatar(
              members: conv.members
                  .where((m) => m.userId != currentUserId)
                  .take(3)
                  .map((m) => (imageUrl: m.user?.avatarUrl, name: m.user?.displayName ?? 'User'))
                  .toList(),
              totalMemberCount: conv.members.length,
              size: 80,
            ),
          const SizedBox(height: 12),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            common.startConversationNote,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Action card like Image 4
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDarkMode ? null : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : AppColors.itemPressBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle, size: 28),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(common.setGroupNameAction, style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, size: 18, color: isDarkMode ? DarkColors.textHint : AppColors.iconSubtle),
                  ],
                ),
                const SizedBox(height: 4),
                Text(common.groupCreatedNote, style: TextStyle(color: isDarkMode ? DarkColors.textHint : LightColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                // Tiny avatars row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...conv.members.take(4).map((m) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AvatarWidget(
                          imageUrl: m.user?.avatarUrl, 
                          name: m.user?.displayName ?? m.nickname ?? common.groupMemberLabel, 
                          size: 32,
                          showOnline: m.userId != currentUserId,
                          isOnline: m.userId != currentUserId && (m.user?.isOnline ?? false),
                        ),
                      )),
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blue.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add, size: 16, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildActionChip('👋', common.waveHandAction),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: Text(common.viewGroupQrAction, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String emoji, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        context.read<ChatProvider>().sendMessage(
          conversationId: widget.conversation.id,
          content: '$emoji $label',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surfaceLight : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDarkMode ? DarkColors.primary : AppColors.primary)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? DarkColors.primary : AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDarkMode ? DarkColors.surface : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.4),
                  children: const [
                    TextSpan(text: 'Chá»‰ '),
                    TextSpan(text: 'trÆ°á»Ÿng vÃ  phÃ³ cá»™ng Ä‘á»“ng', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' Ä‘Æ°á»£c gá»­i tin nháº¯n vÃ o cá»™ng Ä‘á»“ng. '),
                    TextSpan(text: 'TÃ¬m hiá»ƒu thÃªm', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionDetail(String messageId, String emoji) {
    final reactions = _chatProvider?.getReactionsForMessage(messageId) ?? [];
    final filteredReactions = reactions.where((r) => r.emoji == emoji).toList();
    
    if (filteredReactions.isEmpty) return;

    // Close any open dialogs (action menu)
    Navigator.pop(context);

    // Fetch user profiles for reactors
    final userIds = filteredReactions.map((r) => r.userId).toSet();
    final users = <String, User>{};
    
    for (final userId in userIds) {
      final member = widget.conversation.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => ConversationMember(
          conversationId: widget.conversation.id,
          userId: userId,
          role: MemberRole.MEMBER,
          joinedAt: DateTime.now(),
        ),
      );
      if (member.user != null) {
        users[userId] = member.user!;
      }
    }

    ReactionDetailScreen.show(
      context,
      emoji: emoji,
      reactions: filteredReactions,
      users: users,
    );
  }
}
