import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/pinned_message_bar.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';

class CreateNoteScreen extends StatefulWidget {
  final Conversation conversation;

  const CreateNoteScreen({super.key, required this.conversation});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _pinToTop = false;
  bool _isLoading = false;

  bool get _isValid => _contentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createNote() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);

    final chatProvider = context.read<ChatProvider>();
    final content = _contentController.text.trim();
    final convId = widget.conversation.id;

    // Build note JSON payload (compatible with web side)
    final notePayload = {'type': 'note', 'content': content};
    final contentStr = jsonEncode(notePayload);

    // Send as TEXT message with JSON payload
    chatProvider.sendMessage(
      conversationId: convId,
      content: contentStr,
      messageType: 'TEXT',
    );

    // If user wants to pin — wait for server to confirm the message (real ID)
    if (_pinToTop) {
      String? confirmedId;

      // Poll up to 2000ms in 250ms intervals for a server-confirmed (non-local) ID
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        final list = chatProvider.getMessages(convId);
        final found = list.where((m) => m.content == contentStr).firstOrNull;
        if (found != null && !found.id.startsWith('local-')) {
          confirmedId = found.id;
          break;
        }
      }

      if (!mounted) return;

      if (confirmedId != null) {
        final pins = chatProvider.getPinnedMessagesForConversation(convId);
        if (pins.length >= 3) {
          // Need to remove one pin first — build a fake Message to pass to pin limit dialog
          final list = chatProvider.getMessages(convId);
          final newNoteMsg = list.firstWhere(
            (m) => m.id == confirmedId,
            orElse: () => list.last,
          );
          // Navigate back first, then show dialog
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          if (mounted) {
            PinnedMessageBar.showPinLimitDialog(context, newNoteMsg);
          }
          return;
        } else {
          // Pin directly using explicit conversationId
          chatProvider.pinMessageInConversation(confirmedId, convId);
        }
      } else {
        // Server didn't confirm in time — try pinning with local ID as fallback
        final list = chatProvider.getMessages(convId);
        final found = list.where((m) => m.content == contentStr).firstOrNull;
        if (found != null) {
          chatProvider.pinMessageInConversation(found.id, convId);
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // Double pop: CreateNote → GroupBoard → (stay in Chat)
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? DarkColors.scaffold : const Color(0xFFF5F5F5);
    final cardBg = isDark ? DarkColors.surface : Colors.white;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final groupName = conv.title ?? 'Nhóm';

    final userId = provider.currentUserId;
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
    final canPin = conv.allowMemberPin || isAdminOrDeputy;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo mới',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              groupName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
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
          TextButton(
            onPressed: (_isValid && !_isLoading) ? _createNote : null,
            child: Text(
              'TẠO',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: (_isValid && !_isLoading)
                    ? Colors.white
                    : Colors.white38,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pin toggle row ──
          if (canPin) ...[
            Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
                onTap: () => setState(() => _pinToTop = !_pinToTop),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    // Circle indicator (radio style)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _pinToTop ? AppColors.primary : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: _pinToTop ? AppColors.primary : Colors.transparent,
                      ),
                      child: _pinToTop
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ghim lên đầu trò chuyện',
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 1),
          ],
          // ── Content text field ──
          Expanded(
            child: Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontSize: 15.5, color: textColor, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung cho nhóm...',
                  hintStyle: TextStyle(
                    fontSize: 15.5,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                    fontStyle: FontStyle.normal,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
