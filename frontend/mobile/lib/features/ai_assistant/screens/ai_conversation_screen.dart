import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';

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
  int _lastMessageCount = 0;
  AiState? _lastProviderState;

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
      await provider.submitTextPrompt(
        text,
        source: 'ai_conversation_screen',
        surface: AiResponseSurface.conversation,
      );
      _inputController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _queueScrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _applyQuickPrompt(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    _inputController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _inputFocusNode.requestFocus();
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
    final authProvider = context.watch<AuthProvider?>();
    final currentUserId = authProvider?.user?.id ?? '';
    final userAvatarUrl = authProvider?.user?.avatarUrl;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Convert AI history to standard Message models
    final messages =
        provider
            .getHistoryAsMessages(currentUserId, userAvatarUrl: userAvatarUrl)
            .reversed
            .toList();

    if (_lastMessageCount != messages.length ||
        _lastProviderState != provider.state) {
      _lastMessageCount = messages.length;
      _lastProviderState = provider.state;
      _queueScrollToLatest();
    }

    return Scaffold(
      backgroundColor:
          isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        toolbarHeight: 60,
        centerTitle: false,
        titleSpacing: 10,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        flexibleSpace:
            isDarkMode
                ? null
                : Container(
                  decoration: BoxDecoration(gradient: AppColors.appBarGradient),
                ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          key: const ValueKey('ai_conversation_appbar'),
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trợ lý AI VNALO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(provider.state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed:
                () => provider.setCloudBackupEnabled(
                  !provider.cloudBackupEnabled,
                ),
            icon: Icon(
              provider.cloudBackupEnabled ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Sao lưu Cloud',
          ),
          IconButton(
            onPressed:
                messages.isEmpty
                    ? null
                    : () => provider.clearConversationHistory(
                      clearCurrentResponse: true,
                    ),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Xóa lịch sử',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(provider, isDarkMode),

          Expanded(
            child:
                messages.isEmpty
                    ? _EmptyAiConversation(
                      statusLabel: _statusLabel(provider.state),
                      isDarkMode: isDarkMode,
                      onQuickActionSelected: _applyQuickPrompt,
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message.isMine(currentUserId);

                        // Calculate milestones and time visibility
                        bool showTime = true;
                        String? milestoneText;

                        if (index < messages.length - 1) {
                          final olderMsg = messages[index + 1];
                          final gap =
                              message.createdAt
                                  .difference(olderMsg.createdAt)
                                  .inMinutes
                                  .abs();
                          if (gap < 5 &&
                              olderMsg.senderId == message.senderId) {
                            showTime = false;
                          }
                          if (gap > 20) {
                            milestoneText = DateFormatter.formatTimelineDate(
                              message.createdAt,
                            );
                          }
                        } else {
                          // Very first message
                          milestoneText = DateFormatter.formatTimelineDate(
                            message.createdAt,
                          );
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
    final infoText =
        provider.cloudBackupEnabled
            ? 'Cuộc trò chuyện được mã hóa và sao lưu trên Cloud.'
            : 'Chế độ Local-first: dữ liệu chỉ lưu trên thiết bị này.';
    final showDegradedBanner = provider.isResponseDegraded;
    final degradedText =
        provider.isProviderUnavailable
            ? 'AI đang bảo trì. Một số thao tác cục bộ vẫn có thể tiếp tục.'
            : 'AI đang chạy ở chế độ dự phòng.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDarkMode ? DarkColors.surface : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                provider.cloudBackupEnabled
                    ? Icons.lock_outline
                    : Icons.shield_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  infoText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          if (showDegradedBanner) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    provider.isProviderUnavailable
                        ? AppColors.warning.withValues(alpha: 0.14)
                        : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      provider.isProviderUnavailable
                          ? AppColors.warning.withValues(alpha: 0.45)
                          : AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isProviderUnavailable
                        ? Icons.warning_amber_rounded
                        : Icons.sync_problem_rounded,
                    size: 16,
                    color:
                        provider.isProviderUnavailable
                            ? AppColors.warning
                            : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      degradedText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(AiAssistantProvider provider, bool isDarkMode) {
    final bgColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final iconColor =
        isDarkMode ? DarkColors.textSecondary : AppColors.iconSubtle;
    final activeColor =
        provider.state == AiState.listening ? AppColors.error : iconColor;

    return Container(
      key: const ValueKey('ai_conversation_input_bar'),
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
        minimum: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.auto_awesome_rounded,
                color: isDarkMode ? DarkColors.textSecondary : AppColors.iconSubtle,
              ),
              onPressed: () => _inputFocusNode.requestFocus(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  key: const ValueKey('ai_conversation_input'),
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  textInputAction: TextInputAction.send,
                  onTapOutside: (_) => _inputFocusNode.unfocus(),
                  onSubmitted: (_) => _sendPrompt(provider),
                  minLines: 1,
                  maxLines: 5,
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhắn trợ lý AI',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      fontSize: 16,
                      color:
                          isDarkMode
                              ? DarkColors.textHint
                              : const Color(0xFFA1A3A7),
                    ),
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_hasText)
              IconButton(
                key: const ValueKey('ai_conversation_send'),
                onPressed: _isSending ? null : () => _sendPrompt(provider),
                icon:
                    _isSending
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                isDarkMode
                                    ? DarkColors.primaryLight
                                    : AppColors.primary,
                          ),
                        )
                        : Icon(
                          Icons.send,
                          color:
                              isDarkMode
                                  ? DarkColors.primary
                                  : AppColors.primary,
                        ),
              )
            else
              IconButton(
                key: const ValueKey('ai_conversation_mic'),
                icon: Icon(
                  provider.state == AiState.listening
                      ? Icons.mic_off
                      : Icons.mic_none_outlined,
                  color: activeColor,
                ),
                onPressed:
                    () => provider.onPrimaryAction(
                      source: 'conversation_screen_mic',
                      surface: AiResponseSurface.conversation,
                    ),
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
  final ValueChanged<String> onQuickActionSelected;

  const _EmptyAiConversation({
    required this.statusLabel,
    required this.isDarkMode,
    required this.onQuickActionSelected,
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
                  color:
                      isDarkMode
                          ? DarkColors.textSecondary
                          : LightColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onQuickActionSelected(text),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? DarkColors.surface
                        : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

