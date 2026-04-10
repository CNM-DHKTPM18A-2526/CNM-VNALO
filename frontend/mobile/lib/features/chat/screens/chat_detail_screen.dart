import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_input_bar.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_options_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vnalo_mobile/features/call/screens/call_screen.dart';
import 'package:vnalo_mobile/features/call/providers/call_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  /// Optional: pass friend info directly when opening from contacts
  /// so we don't depend on conversation.members having user data
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentUserId = context.read<AuthProvider>().user?.id ?? '';
      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentUserId(currentUserId);
      chatProvider.openConversation(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().closeConversation();
    super.dispose();
  }

  /// Get display name: prefer friendUser if passed, otherwise fallback to conversation
  String _getDisplayName(String currentUserId) {
    if (widget.friendUser != null) {
      return widget.friendUser!.displayName;
    }
    return widget.conversation.getDisplayName(currentUserId);
  }

  /// Get avatar URL
  String? _getAvatarUrl(String currentUserId) {
    if (widget.friendUser != null) {
      return widget.friendUser!.avatarUrl;
    }
    return widget.conversation.getDisplayAvatarUrl(currentUserId);
  }

  /// Get cover URL for direct chats
  String? _getCoverUrl(String currentUserId) {
    if (widget.friendUser != null) {
      return widget.friendUser!.coverUrl;
    }
    final isDirect = widget.conversation.type == ConversationType.DIRECT;
    if (isDirect && widget.conversation.members.isNotEmpty) {
      final other = widget.conversation.members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => widget.conversation.members.first,
      );
      return other.user?.coverUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ChatProvider>(
      builder: (context, chat, child) {
        final conv = chat.conversations.firstWhere(
          (c) => c.id == widget.conversation.id,
          orElse: () => widget.conversation,
        );

        final displayName = _getDisplayName(currentUserId);
        final avatarUrl = _getAvatarUrl(currentUserId);
        final coverUrl = _getCoverUrl(currentUserId);
        final isDirect = conv.type == ConversationType.DIRECT || widget.friendUser != null;
        final wallpaperUrl = conv.personalWallpaperUrl ?? conv.wallpaperUrl;

        return Scaffold(
          backgroundColor: isDarkMode ? DarkColors.scaffold : LightColors.scaffold,
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                AvatarWidget(name: displayName, imageUrl: avatarUrl, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 16)),
                      if (isDirect)
                        Text(
                          'Vừa truy cập',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call_outlined), 
                onPressed: () => _handleStartCall(context, conv, displayName, avatarUrl, false)
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined), 
                onPressed: () => _handleStartCall(context, conv, displayName, avatarUrl, true)
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatOptionsScreen(conversation: conv),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration: wallpaperUrl != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(wallpaperUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                        BlendMode.darken,
                      ),
                    ),
                  )
                : null,
            child: Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final items = chat.getMessagesForConversation(conv.id);
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: items.length + (isDirect ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isDirect && index == items.length) {
                            return _buildFriendProfileCard(displayName, avatarUrl, coverUrl);
                          }

                          final message = items[index];
                          final isMine = message.isMine(currentUserId);

                          bool showTime = true;
                          if (index > 0) {
                            final nextRecent = items[index - 1];
                            final sameSender = nextRecent.senderId == message.senderId;
                            final timeGap = nextRecent.createdAt.difference(message.createdAt).inMinutes.abs();
                            if (sameSender && timeGap < 5) showTime = false;
                          }

                          bool showStatus = (isMine && index == 0);

                          String? milestoneText;
                          if (index == items.length - 1) {
                            milestoneText = DateFormatter.formatTimelineDate(message.createdAt);
                          } else {
                            final olderMsg = items[index + 1];
                            final gap = message.createdAt.difference(olderMsg.createdAt).inMinutes.abs();
                            if (gap > 20) {
                              milestoneText = DateFormatter.formatTimelineDate(message.createdAt);
                            }
                          }

                          List<ConversationMember>? readByMembers;
                          if (isMine && message.serverSeq != null) {
                            readByMembers = conv.members.where((m) {
                              return m.userId != currentUserId && m.lastReadSeq >= message.serverSeq!;
                            }).toList();
                          }

                          return MessageBubble(
                            message: message,
                            isMine: isMine,
                            showTime: showTime,
                            showStatus: showStatus,
                            milestoneText: milestoneText,
                            readByMembers: readByMembers,
                            onRetry: message.status == MessageStatus.FAILED ? () => chat.retryMessage(message) : null,
                          );
                        },
                      );
                    },
                  ),
                ),
                ChatInputBar(
                  conversationId: conv.id,
                  onSend: (text) => chat.sendMessage(conversationId: conv.id, content: text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleStartCall(BuildContext context, Conversation conv, String displayName, String? avatarUrl, bool isVideo) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? '';
    final otherMember = conv.members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => conv.members.first,
    );

    context.read<CallProvider>().startCall(
      targetUserId: otherMember.userId,
      conversationId: conv.id,
      isVideo: isVideo,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          remoteUserName: displayName,
          remoteAvatarUrl: avatarUrl,
        ),
      ),
    );
  }

  Widget _buildFriendProfileCard(
    String displayName,
    String? avatarUrl,
    String? coverUrl,
  ) {
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              color: AppColors.primary.withValues(alpha: 0.1),
              image: coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: coverUrl == null
                  ? const LinearGradient(
                      colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
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
                  'Bắt đầu chia sẻ những câu chuyện thú vị\ncùng nhau',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionChip('👋', 'Xin chào!'),
                    const SizedBox(width: 8),
                    _buildActionChip('😊', 'Rất vui!'),
                    const SizedBox(width: 8),
                    _buildActionChip('🎉', 'Chào bạn!'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String emoji, String label) {
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
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          '$emoji $label',
          style: const TextStyle(fontSize: 13, color: AppColors.primary),
        ),
      ),
    );
  }
}
