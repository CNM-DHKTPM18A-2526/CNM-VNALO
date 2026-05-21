import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_prompt_chips.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_status_pill.dart';

class AiChatBoard extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onClear;
  final VoidCallback? onOpenConversation;
  final Future<void> Function(String text) onSubmitPrompt;
  final double? maxWidth;
  final double? maxHeight;

  const AiChatBoard({
    super.key,
    required this.onClose,
    required this.onClear,
    required this.onSubmitPrompt,
    this.onOpenConversation,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<AiChatBoard> createState() => _AiChatBoardState();
}

class _AiChatBoardState extends State<AiChatBoard> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitTextPrompt() async {
    if (_isSending) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await widget.onSubmitPrompt(text);
      _inputController.clear();
      if (mounted) {
        _inputFocusNode.unfocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _copyResponse(BuildContext context, String response) async {
    if (response.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: response));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép phản hồi của trợ lý'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildHeaderAction({
    required Key key,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      icon: Icon(icon, size: 17),
      color: Colors.white,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      splashRadius: 18,
    );
  }

  Widget _buildEntryBubble({
    required BuildContext context,
    required AiConversationEntry entry,
    required bool isDarkMode,
    required bool allowCopy,
  }) {
    final isUser = entry.role == AiConversationRole.user;
    final bubbleColor =
        isUser
            ? (isDarkMode
                ? const Color(0xFF1C355A)
                : const Color(0xFFDCEBFF))
            : (isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.82));

    final bubbleTextColor =
        isUser
            ? (isDarkMode ? Colors.white : const Color(0xFF123A77))
            : (isDarkMode ? Colors.white70 : Colors.black87);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border:
              isUser
                  ? null
                  : Border.all(
                    color:
                        isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                  ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                entry.text,
                style: TextStyle(
                  color: bubbleTextColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              )
            else
              MarkdownBody(
                data: entry.text,
                selectable: true,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: bubbleTextColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            if (allowCopy && !isUser) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _copyResponse(context, entry.text),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        isDarkMode ? Colors.white70 : AppColors.primary,
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Sao chép'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final viewSize = MediaQuery.of(context).size;

    final boardMaxWidth =
        widget.maxWidth ?? (viewSize.width > 360 ? 340.0 : viewSize.width - 20);
    final boardMaxHeight =
        widget.maxHeight ??
        (viewSize.height > 760 ? 440.0 : viewSize.height * 0.58);
    final isCompactLayout = boardMaxHeight < 360 || viewSize.shortestSide < 360;
    final showPromptChips = !isCompactLayout && boardMaxHeight >= 340;
    final blurSigma = viewSize.shortestSide < 380 ? 8.0 : 14.0;
    final transcriptEntries =
        aiProvider.conversationHistory.length > 4
            ? aiProvider.conversationHistory.sublist(
              aiProvider.conversationHistory.length - 4,
            )
            : aiProvider.conversationHistory;

    final borderColor =
        isDarkMode
            ? const Color(0xFF5DA6FF).withValues(alpha: 0.35)
            : const Color(0xFF2B6CF6).withValues(alpha: 0.32);

    return Material(
      key: const ValueKey('ai_chat_board'),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: boardMaxHeight,
              maxWidth: boardMaxWidth,
              minWidth: boardMaxWidth < 280 ? boardMaxWidth : 280,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isDarkMode
                        ? [
                          const Color(0xFF101A2D).withValues(alpha: 0.86),
                          const Color(0xFF0E223E).withValues(alpha: 0.82),
                        ]
                        : [
                          Colors.white.withValues(alpha: 0.92),
                          const Color(0xFFEAF3FF).withValues(alpha: 0.9),
                        ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isDarkMode
                              ? const [Color(0xFF1C2840), Color(0xFF17355C)]
                              : const [Color(0xFF1D7BFF), Color(0xFF4CA6FF)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.smart_toy_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'VNALO AI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isCompactLayout) ...[
                              const SizedBox(height: 6),
                              AiStatusPill(
                                state: aiProvider.state,
                                compact: true,
                                degraded: aiProvider.isResponseDegraded,
                                providerStatus: aiProvider.providerStatus,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 0,
                        runSpacing: 0,
                        children: [
                          if (widget.onOpenConversation != null)
                            _buildHeaderAction(
                              key: const ValueKey('ai_chat_open_conversation'),
                              icon: Icons.open_in_full,
                              onPressed: widget.onOpenConversation,
                            ),
                          _buildHeaderAction(
                            key: const ValueKey('ai_chat_clear'),
                            icon: Icons.clear_all,
                            onPressed: widget.onClear,
                          ),
                          _buildHeaderAction(
                            key: const ValueKey('ai_chat_close'),
                            icon: Icons.close,
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      isCompactLayout ? 10 : 12,
                      12,
                      isCompactLayout ? 4 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (aiProvider.isResponseDegraded)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(
                                alpha: isDarkMode ? 0.16 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aiProvider.isProviderUnavailable
                                        ? 'AI đang bảo trì. Một số thao tác cục bộ vẫn có thể dùng.'
                                        : 'AI đang chạy ở chế độ dự phòng.',
                                    style: TextStyle(
                                      color:
                                          isDarkMode
                                              ? Colors.white70
                                              : const Color(0xFF7C4A03),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: transcriptEntries.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          isDarkMode
                                              ? Colors.white.withValues(
                                                alpha: 0.06,
                                              )
                                              : Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            isDarkMode
                                                ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                                : Colors.black.withValues(
                                                  alpha: 0.06,
                                                ),
                                      ),
                                    ),
                                    child: Text(
                                      aiProvider.state == AiState.listening
                                          ? 'Đang nghe giọng nói. Bạn cũng có thể nhập câu hỏi bên dưới.'
                                          : aiProvider.state == AiState.thinking
                                          ? 'Đang xử lý yêu cầu của bạn...'
                                          : 'Nhập câu hỏi hoặc chọn gợi ý để bắt đầu.',
                                      style: TextStyle(
                                        color:
                                            isDarkMode
                                                ? Colors.white60
                                                : Colors.black54,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (var index = 0;
                                          index < transcriptEntries.length;
                                          index++)
                                        _buildEntryBubble(
                                          context: context,
                                          entry: transcriptEntries[index],
                                          isDarkMode: isDarkMode,
                                          allowCopy:
                                              index ==
                                              transcriptEntries.length - 1,
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showPromptChips)
                  AiPromptChips(
                    compact: true,
                    onSelected: (prompt) {
                      _inputController.text = prompt;
                      _inputController.selection = TextSelection.collapsed(
                        offset: prompt.length,
                      );
                      _inputFocusNode.requestFocus();
                    },
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    isCompactLayout ? 6 : 8,
                    10,
                    isCompactLayout ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color:
                            isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Nói với trợ lý',
                        onPressed:
                            _isSending || aiProvider.isBusy
                                ? null
                                : () => aiProvider.onPrimaryAction(
                                  source: 'ai_chat_board_mic',
                                  surface: AiResponseSurface.bubble,
                                ),
                        icon: Icon(
                          aiProvider.state == AiState.listening
                              ? Icons.mic
                              : Icons.mic_none_rounded,
                          color:
                              aiProvider.state == AiState.listening
                                  ? AppColors.error
                                  : (isDarkMode
                                      ? Colors.white70
                                      : AppColors.iconSubtle),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : AppColors.itemDivider,
                            ),
                          ),
                          child: TextField(
                            key: const ValueKey('ai_chat_input'),
                            controller: _inputController,
                            focusNode: _inputFocusNode,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitTextPrompt(),
                            minLines: 1,
                            maxLines: 3,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Nhập để chat với trợ lý...',
                              hintStyle: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white38
                                        : Colors.black38,
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: ElevatedButton(
                          key: const ValueKey('ai_chat_send'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor:
                                _isSending || aiProvider.isBusy
                                    ? Colors.grey
                                    : AppColors.primary,
                          ),
                          onPressed:
                              _isSending || aiProvider.isBusy
                                  ? null
                                  : _submitTextPrompt,
                          child:
                              _isSending
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
