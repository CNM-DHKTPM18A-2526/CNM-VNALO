import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/theme/ai_assistant_tokens.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_prompt_chips.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_status_pill.dart';
import 'package:vnalo_mobile/navigation/main_shell.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  int _lastTranscriptSize = 0;
  bool _lastTypingState = false;
  String? _lastClarificationKey;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
  }

  void _handleInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_handleInputChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearInputField(String submittedText) {
    _inputController.value = const TextEditingValue();
    if (_hasText) {
      setState(() {
        _hasText = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final currentText = _inputController.text.trim();
      if (currentText.isEmpty || currentText != submittedText.trim()) {
        return;
      }
      _inputController.value = const TextEditingValue();
    });
  }

  void _restoreInputField(String text) {
    if (!mounted) {
      return;
    }
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _queueScrollToLatest({double bottomInset = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final target = (position.maxScrollExtent - bottomInset).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openFullConversation() async {
    widget.onOpenConversation?.call();
  }

  void _submitTextPrompt() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _clearInputField(text);
    try {
      unawaited(widget.onSubmitPrompt(text));
    } catch (_) {
      _restoreInputField(text);
      // Provider handles async failures; this guards only synchronous dispatch.
    }

    _inputFocusNode.requestFocus();
  }

  void _applyQuickPrompt(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    if (normalized == AiPromptChips.openContactsPrompt) {
      MainShellState.globalKey.currentState?.setTabIndex(1);
      widget.onClose();
      return;
    }
    _inputController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _inputFocusNode.requestFocus();
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
    String? tooltip,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      enabled: onPressed != null,
      child: IconButton(
        key: key,
        icon: Icon(icon, size: 16),
        color: Colors.white,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        splashRadius: 16,
      ),
    );
  }

  Widget _buildEntryBubble({
    required BuildContext context,
    required AiConversationEntry entry,
    required bool isDarkMode,
    required bool allowCopy,
  }) {
    final isUser = entry.role == AiConversationRole.user;
    final isClarification =
        !isUser && entry.source.startsWith('ai_action_ambiguity');
    final isMissingTarget =
        !isUser && entry.source.startsWith('ai_action_missing');
    final clarificationCandidates =
        AiCommandRouting.parseAmbiguityCandidatesFromSource(entry.source);
    final bubbleColor =
        isUser
            ? (isDarkMode ? const Color(0xFF1C355A) : const Color(0xFFDCEBFF))
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
        constraints: const BoxConstraints(maxWidth: 252),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AiAssistantTokens.bubbleRadius),
            topRight: Radius.circular(AiAssistantTokens.bubbleRadius),
            bottomLeft: Radius.circular(
              isUser
                  ? AiAssistantTokens.bubbleRadius
                  : AiAssistantTokens.bubbleTailRadius,
            ),
            bottomRight: Radius.circular(
              isUser
                  ? AiAssistantTokens.bubbleTailRadius
                  : AiAssistantTokens.bubbleRadius,
            ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isClarification || isMissingTarget) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isClarification
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : AppColors.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          AiAssistantTokens.pillRadius,
                        ),
                      ),
                      child: Text(
                        isClarification ? 'Cần làm rõ' : 'Chưa tìm thấy',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isClarification
                                  ? AppColors.primary
                                  : AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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
                  if (isClarification || isMissingTarget) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...clarificationCandidates
                            .take(3)
                            .map(
                              (candidate) => _BoardActionChip(
                                label: candidate,
                                key: ValueKey('ai_board_chip_$candidate'),
                                onTap:
                                    () => context
                                        .read<AiAssistantProvider>()
                                        .submitDisambiguationSelection(
                                          candidate,
                                          source: 'ai_board_candidate_chip',
                                        ),
                              ),
                            ),
                        _BoardActionChip(
                          label:
                              isClarification
                                  ? 'Nói rõ họ tên'
                                  : 'Thử tên khác',
                          onTap:
                              () => _applyQuickPrompt(
                                isClarification
                                    ? 'Mình muốn người có họ tên đầy đủ là '
                                    : 'Kiểm tra lại liên hệ tên ',
                              ),
                        ),
                        _BoardActionChip(
                          label: AiPromptChips.openContactsPrompt,
                          onTap:
                              () => _applyQuickPrompt(
                                AiPromptChips.openContactsPrompt,
                              ),
                        ),
                        if (widget.onOpenConversation != null)
                          _BoardActionChip(
                            label: 'Mở AI chat',
                            onTap: widget.onOpenConversation!,
                          ),
                      ],
                    ),
                  ],
                ],
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

  Widget _buildAssistantTypingBubble({
    required bool isDarkMode,
    required String label,
  }) {
    final bubbleColor =
        isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.82);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 252),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AiAssistantTokens.bubbleRadius),
            topRight: Radius.circular(AiAssistantTokens.bubbleRadius),
            bottomLeft: Radius.circular(AiAssistantTokens.bubbleTailRadius),
            bottomRight: Radius.circular(AiAssistantTokens.bubbleRadius),
          ),
          border: Border.all(
            color:
                isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDots(isDarkMode: isDarkMode),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
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
    final clarification = aiProvider.clarificationState;
    final showPromptChips =
        clarification == null && !isCompactLayout && boardMaxHeight >= 380;
    final blurSigma = viewSize.shortestSide < 380 ? 8.0 : 14.0;
    final showAiTyping = aiProvider.isAssistantGenerating;
    final showProviderIssue = aiProvider.hasProviderIssue;
    final isWarningIssue =
        aiProvider.isProviderHardFailure ||
        aiProvider.isProviderRateLimited ||
        aiProvider.isProviderTimeout;
    const actionButtonConstraints = BoxConstraints.tightFor(
      width: 40,
      height: 40,
    );
    final transcriptLimit = clarification == null ? 4 : 3;
    final transcriptEntries =
        aiProvider.conversationHistory.length > transcriptLimit
            ? aiProvider.conversationHistory.sublist(
              aiProvider.conversationHistory.length - transcriptLimit,
            )
            : aiProvider.conversationHistory;

    final clarificationKey =
        clarification == null
            ? null
            : '${clarification.source}:${clarification.candidates.join('|')}';

    if (_lastTranscriptSize != transcriptEntries.length ||
        _lastTypingState != showAiTyping ||
        _lastClarificationKey != clarificationKey) {
      _lastTranscriptSize = transcriptEntries.length;
      _lastTypingState = showAiTyping;
      _lastClarificationKey = clarificationKey;
      _queueScrollToLatest(bottomInset: clarificationKey == null ? 0 : 132);
    }

    final borderColor =
        isDarkMode
            ? const Color(0xFF5DA6FF).withValues(alpha: 0.35)
            : const Color(0xFF2B6CF6).withValues(alpha: 0.32);

    return Material(
      key: const ValueKey('ai_chat_board'),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AiAssistantTokens.surfaceRadius),
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
              borderRadius: BorderRadius.circular(
                AiAssistantTokens.surfaceRadius,
              ),
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
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? const Color(0xFF111827).withValues(alpha: 0.84)
                            : Colors.white.withValues(alpha: 0.78),
                    border: Border(
                      bottom: BorderSide(
                        color:
                            isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Trợ lý AI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!isCompactLayout) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: AiStatusPill(
                                  state: aiProvider.state,
                                  compact: true,
                                  degraded: aiProvider.hasProviderIssue,
                                  providerStatus: aiProvider.providerStatus,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onOpenConversation != null)
                            _buildHeaderAction(
                              key: const ValueKey('ai_chat_open_conversation'),
                              icon: Icons.open_in_full,
                              tooltip: 'Mở chat AI đầy đủ',
                              onPressed: _openFullConversation,
                            ),
                          _buildHeaderAction(
                            key: const ValueKey('ai_chat_clear'),
                            icon: Icons.clear_all,
                            tooltip: 'Xóa đoạn chat nhanh',
                            onPressed: widget.onClear,
                          ),
                          _buildHeaderAction(
                            key: const ValueKey('ai_chat_close'),
                            icon: Icons.close,
                            tooltip: 'Đóng trợ lý',
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
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
                        if (showProviderIssue)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: (isWarningIssue
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.primary)
                                  .withValues(alpha: isDarkMode ? 0.16 : 0.12),
                              borderRadius: BorderRadius.circular(
                                AiAssistantTokens.fieldRadius,
                              ),
                              border: Border.all(
                                color: (isWarningIssue
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.primary)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isWarningIssue
                                      ? Icons.warning_amber_rounded
                                      : Icons.sync_problem_rounded,
                                  size: 16,
                                  color:
                                      isWarningIssue
                                          ? const Color(0xFFF59E0B)
                                          : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aiProvider.providerIssueMessage,
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
                            controller: _scrollController,
                            child:
                                transcriptEntries.isEmpty
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
                                        borderRadius: BorderRadius.circular(
                                          AiAssistantTokens.surfaceRadius,
                                        ),
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
                                            : aiProvider.state ==
                                                AiState.thinking
                                            ? aiProvider.assistantActivityLabel
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
                                        for (
                                          var index = 0;
                                          index < transcriptEntries.length;
                                          index++
                                        )
                                          _buildEntryBubble(
                                            context: context,
                                            entry: transcriptEntries[index],
                                            isDarkMode: isDarkMode,
                                            allowCopy:
                                                index ==
                                                transcriptEntries.length - 1,
                                          ),
                                        if (showAiTyping)
                                          _buildAssistantTypingBubble(
                                            isDarkMode: isDarkMode,
                                            label:
                                                aiProvider
                                                    .assistantActivityLabel,
                                          ),
                                        if (clarification != null) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AiAssistantTokens
                                                          .pillRadius,
                                                    ),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.16),
                                                ),
                                              ),
                                              child: Text(
                                                clarification.isAmbiguous
                                                    ? 'Đang chờ bạn chọn đúng người'
                                                    : 'Đang chờ bạn thử lại tên',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                      _inputController.value = TextEditingValue(
                        text: prompt,
                        selection: TextSelection.collapsed(
                          offset: prompt.length,
                        ),
                      );
                      _inputFocusNode.requestFocus();
                    },
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    6,
                    isCompactLayout ? 5 : 6,
                    6,
                    isCompactLayout ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? DarkColors.surface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color:
                            isDarkMode
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.itemDivider,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _inputFocusNode.requestFocus(),
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          color:
                              isDarkMode
                                  ? Colors.white70
                                  : AppColors.iconSubtle,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: actionButtonConstraints,
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('ai_chat_input'),
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          textInputAction: TextInputAction.send,
                          onTapOutside: (_) => _inputFocusNode.unfocus(),
                          onSubmitted: (_) => _submitTextPrompt(),
                          minLines: 1,
                          maxLines: 3,
                          style: AppTypography.bodyMedium.copyWith(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Nhắn trợ lý AI',
                            hintStyle: TextStyle(
                              color:
                                  isDarkMode
                                      ? DarkColors.textHint
                                      : const Color(0xFFA1A3A7),
                              fontSize: 16,
                            ),
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal:
                                  AiAssistantTokens.inputHorizontalPadding,
                              vertical: AiAssistantTokens.inputVerticalPadding,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_hasText)
                        IconButton(
                          key: const ValueKey('ai_chat_send'),
                          icon: Icon(
                            Icons.send,
                            color:
                                isDarkMode
                                    ? DarkColors.primary
                                    : AppColors.primary,
                          ),
                          onPressed: _submitTextPrompt,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: actionButtonConstraints,
                        )
                      else
                        IconButton(
                          key: const ValueKey('ai_chat_mic_idle'),
                          icon: Icon(
                            aiProvider.state == AiState.listening
                                ? Icons.mic_off
                                : Icons.mic_none_outlined,
                            color:
                                aiProvider.state == AiState.listening
                                    ? AppColors.error
                                    : (isDarkMode
                                        ? Colors.white70
                                        : AppColors.iconSubtle),
                          ),
                          onPressed:
                              () => aiProvider.onPrimaryAction(
                                source: 'ai_chat_board_mic_idle',
                                surface: AiResponseSurface.bubble,
                              ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: actionButtonConstraints,
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

class _BoardActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BoardActionChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: AppTypography.bodySmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AiAssistantTokens.pillRadius),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final bool isDarkMode;

  const _TypingDots({required this.isDarkMode});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDarkMode ? Colors.white70 : AppColors.iconSubtle;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final start = index * 0.18;
            final progress = ((_controller.value - start) % 1.0).clamp(
              0.0,
              1.0,
            );
            final scale =
                0.7 + (progress < 0.5 ? progress : 1 - progress) * 0.8;
            return Transform.translate(
              offset: Offset(0, -progress * 2),
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: baseColor.withValues(
                    alpha: 0.45 + (scale - 0.7) * 0.9,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
