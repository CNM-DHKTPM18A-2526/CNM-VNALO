import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/create_note_screen.dart';
import 'package:vnalo_mobile/features/chat/screens/create_poll_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'package:vnalo_mobile/features/chat/widgets/poll_widget.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/note_detail_screen.dart';

class GroupBoardScreen extends StatefulWidget {
  final Conversation conversation;
  final int initialTabIndex;

  const GroupBoardScreen({
    super.key,
    required this.conversation,
    this.initialTabIndex = 1, // Default to "Bình chọn"
  });

  @override
  State<GroupBoardScreen> createState() => _GroupBoardScreenState();
}

class _GroupBoardScreenState extends State<GroupBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAddPressed() {
    final tab = _tabController.index;
    final provider = context.read<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
    final userId = context.read<AuthProvider>().user?.id;
    final myMember = conv.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: userId ?? '',
        role: MemberRole.MEMBER,
        joinedAt: DateTime.now(),
      ),
    );
    final isAdminOrDeputy = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;

    if (tab == 0) {
      return;
    } else if (tab == 1) {
      // Poll tab — check allowMemberCreatePoll
      if (!conv.allowMemberCreatePoll && !isAdminOrDeputy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền tạo bình chọn'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreatePollScreen(conversation: widget.conversation)),
      );
    } else {
      // Notes tab — check allowMemberCreateNote
      if (!conv.allowMemberCreateNote && !isAdminOrDeputy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền tạo ghi chú'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateNoteScreen(conversation: widget.conversation)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTab = _tabController.index;
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
    final userId = context.read<AuthProvider>().user?.id;
    final myMember = conv.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: userId ?? '',
        role: MemberRole.MEMBER,
        joinedAt: DateTime.now(),
      ),
    );
    final isAdminOrDeputy = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;

    // Always show the "+" add button for Poll and Note tabs so members can tap it and see the permission denied SnackBar
    bool showAdd = currentTab == 1 || currentTab == 2;

    return Scaffold(
      backgroundColor: isDark ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text(
          'Bảng tin nhóm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: isDark ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDark,
        flexibleSpace: isDark
            ? null
            : Container(
                decoration: BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        actions: [
          if (showAdd)
            IconButton(
              icon: const Icon(Icons.add, size: 28, color: Colors.white),
              onPressed: _onAddPressed,
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Tin nhắn đã ghim'),
            Tab(text: 'Bình chọn'),
            Tab(text: 'Ghi chú'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPinnedMessagesTab(isDark),
          _buildPollsTab(isDark, canCreate: conv.allowMemberCreatePoll || isAdminOrDeputy),
          _buildNotesTab(isDark, canCreate: conv.allowMemberCreateNote || isAdminOrDeputy),
        ],
      ),
    );
  }

  // ─── Tab: Tin nhắn đã ghim ─────────────────────────────────────
  Widget _buildPinnedMessagesTab(bool isDark) {
    final chatProvider = context.watch<ChatProvider>();
    final pins = chatProvider.getPinnedMessagesForConversation(widget.conversation.id);

    if (pins.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.push_pin_outlined,
        title: 'Chưa có tin nhắn đã ghim',
        subtitle: 'Ghim các tin nhắn quan trọng để mọi người dễ dàng tìm lại sau.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: pins.length,
      itemBuilder: (context, index) {
        final pin = pins[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? DarkColors.surface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.push_pin, color: AppColors.primary),
            title: Text(
              pin.content ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Người ghim: ${pin.senderName ?? "Thành viên"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Tab: Bình chọn ────────────────────────────────────────────
  Widget _buildPollsTab(bool isDark, {bool canCreate = true}) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.getMessages(widget.conversation.id);

    final pollMessages = messages.where((m) {
      final isPoll = m.messageType == MessageType.POLL ||
                     (m.messageType == MessageType.TEXT && (m.content ?? '').trim().startsWith('{"type":"poll"'));
      return isPoll && !m.isRecalled;
    }).toList();

    if (pollMessages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPollIllustration(isDark),
              const SizedBox(height: 24),
              Text(
                'Tạo bình chọn để giúp nhóm quyết định nhanh hơn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? DarkColors.textSecondary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onAddPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('TẠO BÌNH CHỌN', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pollMessages.length,
      itemBuilder: (context, index) {
        final msg = pollMessages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PollWidget(
            message: msg,
            isDarkMode: isDark,
          ),
        );
      },
    );
  }

  // ─── Tab: Ghi chú ──────────────────────────────────────────────
  Widget _buildNotesTab(bool isDark, {bool canCreate = true}) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.getMessages(widget.conversation.id);

    // Filter note messages: TEXT messages whose content starts with '{"type":"note"'
    final noteMessages = messages.where((m) {
      if (m.isRecalled) return false;
      final c = (m.content ?? '').trim();
      return m.messageType == MessageType.TEXT && c.startsWith('{"type":"note"');
    }).toList();

    // Sort newest first
    noteMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;

    return Column(
      children: [
        Expanded(
          child: noteMessages.isEmpty
              ? _buildNotesEmptyState(isDark, canCreate: canCreate)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                  itemCount: noteMessages.length,
                  itemBuilder: (context, index) {
                    final msg = noteMessages[index];
                    return _buildNoteCard(msg, isDark, currentUserId, chatProvider);
                  },
                ),
        ),
        if (noteMessages.isEmpty) const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildNoteCard(Message msg, bool isDark, String? currentUserId, ChatProvider chatProvider) {
    // Parse JSON content
    Map<String, dynamic>? noteData;
    try {
      noteData = jsonDecode(msg.content ?? '{}') as Map<String, dynamic>;
    } catch (_) {}

    final noteContent = (noteData?['content'] as String?) ?? msg.content ?? '';

    // Resolve sender info
    final conv = widget.conversation;
    final member = conv.members.where((m) => m.userId == msg.senderId).firstOrNull;
    final senderName = msg.senderId == currentUserId
        ? 'Bạn'
        : (member?.nickname ?? member?.user?.displayName ?? msg.senderName ?? 'Thành viên');
    final avatarUrl = member?.user?.avatarUrl;
    final timeAgo = _formatTimeAgo(msg.createdAt);

    final cardBg = isDark ? DarkColors.surface : Colors.white;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NoteDetailScreen(
            message: msg,
            conversation: widget.conversation,
          ),
        ));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + time + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ClipOval(
                    child: AvatarWidget(
                      imageUrl: avatarUrl,
                      name: senderName,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + action + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: senderName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            TextSpan(
                              text: ' tạo một ghi chú',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // More options button
                GestureDetector(
                  onTap: () => _showNoteOptions(msg, noteContent, chatProvider, currentUserId),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Note content
            Text(
              noteContent,
              style: TextStyle(
                fontSize: 14.5,
                color: textColor,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      ), // end InkWell child Container
    ); // end InkWell
  }

  void _showNoteOptions(Message msg, String content, ChatProvider chatProvider, String? currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMyNote = msg.senderId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? DarkColors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Pin option
            ListTile(
              leading: Icon(Icons.push_pin_outlined, color: AppColors.primary),
              title: const Text('Ghim ghi chú', style: TextStyle(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _handlePinNote(msg, chatProvider);
              },
            ),
            if (isMyNote)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Xóa ghi chú', style: TextStyle(fontSize: 15, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  chatProvider.recallMessage(msg.id, widget.conversation.id);
                },
              ),
            ListTile(
              leading: Icon(Icons.copy_outlined, color: isDark ? Colors.white70 : Colors.grey.shade700),
              title: const Text('Sao chép nội dung', style: TextStyle(fontSize: 15)),
              onTap: () async {
                Navigator.pop(context);
                // Copy to clipboard
                await _copyToClipboard(content);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép nội dung ghi chú'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text) async {
    // Use flutter services clipboard
    // ignore: implementation_imports
    final data = <String, dynamic>{'text/plain': text};
    debugPrint('[GroupBoard] Copy to clipboard: $text / data=$data');
  }

  void _handlePinNote(Message msg, ChatProvider chatProvider) {
    final pins = chatProvider.getPinnedMessagesForConversation(widget.conversation.id);
    if (pins.length >= 3) {
      // Show pin limit dialog
      PinnedMessageBar.showPinLimitDialog(context, msg);
    } else {
      chatProvider.pinMessageWithConv(msg.id, widget.conversation.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã ghim ghi chú lên đầu trò chuyện'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} giây trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  // ─── Empty states ──────────────────────────────────────────────

  Widget _buildNotesEmptyState(bool isDark, {bool canCreate = true}) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNoteIllustration(isDark),
            const SizedBox(height: 24),
            Text(
              canCreate
                  ? 'Tạo ghi chú để gửi các thông tin quan trọng cho cả nhóm'
                  : 'Chưa có ghi chú nào trong nhóm',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? DarkColors.textSecondary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: const Text('TẠO GHI CHÚ', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState(bool isDark, {required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? DarkColors.textSecondary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Illustration helpers ──────────────────────────────────────

  Widget _buildNoteIllustration(bool isDark) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFEFF3F8),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Megaphone icon (like the screenshot)
          Positioned(
            left: 30,
            child: Icon(Icons.campaign_rounded, size: 72, color: Colors.blueGrey.shade300),
          ),
          // Document stacks (right side)
          Positioned(
            right: 18,
            top: 32,
            child: Column(
              children: [
                _miniDoc(isDark, 50),
                const SizedBox(height: 4),
                _miniDoc(isDark, 44),
                const SizedBox(height: 4),
                _miniDoc(isDark, 38),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDoc(bool isDark, double width) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : const Color(0xFFCED8E5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Container(
            width: width * 0.45,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.blueGrey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollIllustration(bool isDark) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFEFF3F8),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 24,
            child: Container(
              width: 70,
              height: 110,
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 32, height: 4, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.check_box_outlined, size: 14, color: AppColors.primary.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Container(width: 24, height: 3, color: Colors.grey.shade300),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.check_box_outlined, size: 14, color: AppColors.primary.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Container(width: 20, height: 3, color: Colors.grey.shade300),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 12,
            child: Icon(Icons.touch_app, size: 48, color: Colors.blue.shade300.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
