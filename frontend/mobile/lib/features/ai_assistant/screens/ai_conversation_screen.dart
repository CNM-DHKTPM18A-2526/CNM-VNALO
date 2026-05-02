import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class AiConversationScreen extends StatefulWidget {
  const AiConversationScreen({super.key});

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(AiAssistantProvider provider) async {
    if (_isSending) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await provider.submitTextPrompt(text, source: 'ai_conversation_screen');
      _inputController.clear();
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _statusLabel(AiState state) {
    return switch (state) {
      AiState.listening => 'Đang lắng nghe...',
      AiState.thinking => 'Đang xử lý...',
      AiState.speaking => 'Đang phản hồi...',
      AiState.idle => 'Đang hoạt động',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id ?? '';
    final userAvatarUrl = authProvider.user?.avatarUrl;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Convert AI history to standard Message models
    final messages = provider.getHistoryAsMessages(currentUserId, userAvatarUrl: userAvatarUrl).reversed.toList();

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        flexibleSpace: isDarkMode 
          ? null 
          : Container(decoration: BoxDecoration(gradient: AppColors.appBarGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trợ lý AI VNALO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              _statusLabel(provider.state),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => provider.setCloudBackupEnabled(!provider.cloudBackupEnabled),
            icon: Icon(
              provider.cloudBackupEnabled ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Sao lưu Cloud',
          ),
          IconButton(
            onPressed: messages.isEmpty ? null : () => provider.clearConversationHistory(clearCurrentResponse: true),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Xóa lịch sử',
          ),
        ],
      ),
      body: Column(
        children: [
          // Security/Backup Banner
          _buildInfoBanner(provider, isDarkMode),
          
          Expanded(
            child: messages.isEmpty
                ? _EmptyAiConversation(
                    statusLabel: _statusLabel(provider.state),
                    isDarkMode: isDarkMode,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.isMine(currentUserId);
                      
                      // Calculate milestones and time visibility
                      bool showTime = true;
                      String? milestoneText;
                      
                      if (index < messages.length - 1) {
                        final olderMsg = messages[index + 1];
                        final gap = message.createdAt.difference(olderMsg.createdAt).inMinutes.abs();
                        if (gap < 5 && olderMsg.senderId == message.senderId) {
                          showTime = false;
                        }
                        if (gap > 20) {
                          milestoneText = DateFormatter.formatTimelineDate(message.createdAt);
                        }
                      } else {
                        // Very first message
                        milestoneText = DateFormatter.formatTimelineDate(message.createdAt);
                      }

                      return MessageBubble(
                        message: message,
                        isMine: isMine,
                        showTime: showTime,
                        showAvatar: !isMine,
                        senderAvatarUrl: message.senderAvatarUrl,
                        senderDisplayName: message.senderName,
                        milestoneText: milestoneText,
                      );
                    },
                  ),
          ),
          
          // Zalo-style Input Bar
          _buildInputBar(provider, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AiAssistantProvider provider, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Row(
        children: [
          Icon(
            provider.cloudBackupEnabled ? Icons.lock_outline : Icons.shield_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.cloudBackupEnabled
                  ? 'Cuộc trò chuyện được mã hóa và sao lưu trên Cloud.'
                  : 'Chế độ Local-first: Dữ liệu chỉ lưu trên thiết bị này.',
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AiAssistantProvider provider, bool isDarkMode) {
    final bgColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                provider.state == AiState.listening ? Icons.mic_off : Icons.mic_none_outlined,
                color: provider.state == AiState.listening ? AppColors.error : (isDarkMode ? Colors.white70 : AppColors.iconSubtle),
              ),
              onPressed: () => provider.onPrimaryAction(source: 'conversation_screen_mic'),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendPrompt(provider),
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                    decoration: InputDecoration(
                      hintText: 'Hỏi trợ lý VNALO AI...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? DarkColors.textHint : const Color(0xFFA1A3A7),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                ),
              ),
            ),
            if (_hasText)
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: () => _sendPrompt(provider),
              )
            else
              IconButton(
                icon: Icon(Icons.image_outlined, color: isDarkMode ? Colors.white70 : AppColors.iconSubtle),
                onPressed: () {
                  // Placeholder for future AI vision features
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAiConversation extends StatelessWidget {
  final String statusLabel;
  final bool isDarkMode;

  const _EmptyAiConversation({
    required this.statusLabel,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tôi có thể giúp gì cho bạn?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Hãy đặt câu hỏi về công việc, dịch thuật hoặc tóm tắt video cho tôi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildQuickAction(context, 'Dịch tin nhắn này sang tiếng Anh'),
            _buildQuickAction(context, 'Tóm tắt nội dung cuộc họp'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
