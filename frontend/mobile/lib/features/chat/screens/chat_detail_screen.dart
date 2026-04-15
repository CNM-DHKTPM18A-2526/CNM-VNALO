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
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_options_screen.dart';
import 'package:vnalo_mobile/features/call/screens/video_call_screen.dart';
import 'package:vnalo_mobile/features/call/screens/voice_call_screen.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';
import 'package:vnalo_mobile/features/chat/screens/group_chat_options_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/reaction_detail_screen.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/message_reaction_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/core/utils/avatar_resolver.dart';
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'dart:async';

class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final User? friendUser;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.friendUser,
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
        final myMember = conv.members.firstWhere((m) => m.userId == currentUserId, orElse: () => conv.members.first);
        final canSend = !isRestrictedSending || myMember.role == MemberRole.OWNER || myMember.role == MemberRole.ADMIN;

        return Scaffold(
          backgroundColor:
              wallpaperUrl != null
                  ? (isDarkMode ? Colors.black : LightColors.scaffold)
                  : (isDarkMode ? Colors.black : LightColors.scaffold),
          appBar: AppBar(
            titleSpacing: 0,
            backgroundColor:
                isDarkMode ? DarkColors.appBarBg : Colors.transparent,
            elevation: 0,
            forceMaterialTransparency: true,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace:
                isDarkMode
                    ? null
                    : Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.appBarGradient,
                      ),
                    ),
            title: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                  ),
                  child: conv.type == ConversationType.GROUP
                      ? GroupAvatar(
                          members: conv.members
                              .map((m) => (
                                    imageUrl: m.user?.avatarUrl,
                                    name: m.user?.displayName ?? m.nickname ?? 'User',
                                  ))
                              .toList(),
                          size: 36,
                        )
                      : AvatarWidget(
                          name: displayName,
                          imageUrl: avatarUrl,
                          size: 36,
                          // cacheVersion: avatarVersion, // Ignore for now
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      _buildSubtext(isDirect),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call_outlined, color: Colors.white),
                onPressed: () {
                  if (!isDirect) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(common.callFlowPlaceholder)),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(common.callFlowPlaceholder)),
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
                            alpha: isDarkMode ? 0.3 : 0.1,
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
                              return _buildFriendProfileCard(displayName, avatarUrl, coverUrl);
                            } else {
                              return _buildGroupProfileCard(displayName, conv);
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

                          final senderMember = conv.members.firstWhere(
                            (m) => m.userId == message.senderId,
                            orElse:
                                () => ConversationMember(
                                  conversationId: conv.id,
                                  userId: message.senderId,
                                  joinedAt: DateTime.now(),
                                ),
                          );

                          return MessageBubble(
                            message: message,
                            isMine: isMine,
                            showTime: showTime,
                            showAvatar: !isMine && showTime,
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
    if (isDirect) {
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
                                  const Color(0xFF0068FF),
                                  const Color(0xFF00A2ED),
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
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionChip('👋', common.helloAction),
                    const SizedBox(width: 8),
                    _buildActionChip('😊', common.niceToMeetAction),
                    const SizedBox(width: 8),
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

  Widget _buildGroupProfileCard(String displayName, Conversation conv) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    
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
                  .take(4)
                  .map((m) => (imageUrl: m.user?.avatarUrl, name: m.user?.displayName ?? 'User'))
                  .toList(),
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
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 28),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Đặt tên nhóm', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Bạn vừa tạo nhóm', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
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
                          name: m.user?.displayName ?? m.nickname ?? 'Thành viên', 
                          size: 32
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
                        child: const Icon(Icons.person_add, size: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildActionChip('👋', 'Vẫy tay chào'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: Text('Xem mã QR tham gia nhóm', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                    TextSpan(text: 'Chỉ '),
                    TextSpan(text: 'trưởng và phó cộng đồng', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' được gửi tin nhắn vào cộng đồng. '),
                    TextSpan(text: 'Tìm hiểu thêm', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
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
