import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';

class AiConversationScreen extends StatefulWidget {
  const AiConversationScreen({super.key});

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  static const double _surfaceRadius = 12;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _hasText = false;
  int _lastMessageCount = 0;
  AiState? _lastProviderState;
  AiAssistantProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= context.read<AiAssistantProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider?.enterConversationSurface();
    });
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _provider?.leaveConversationSurface();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendPrompt(AiAssistantProvider provider) {
    if (_isSending) return;

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() {
      _isSending = true;
      _hasText = false;
    });

    try {
      unawaited(
        provider.submitTextPrompt(
          text,
          source: 'ai_conversation_screen',
          surface: AiResponseSurface.conversation,
        ),
      );
    } catch (_) {
      // Provider handles async failures; this guards only synchronous dispatch.
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isSending = false);
      }
    });
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

  String _statusLabel(AiAssistantProvider provider) {
    return provider.assistantActivityLabel;
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
    final showAiTyping = provider.isAssistantGenerating;

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
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        forceMaterialTransparency: !isDarkMode,
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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
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
                      statusLabel: _statusLabel(provider),
                      isDarkMode: isDarkMode,
                      onQuickActionSelected: _applyQuickPrompt,
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      itemCount: messages.length + (showAiTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showAiTyping && index == 0) {
                          return _AiTypingBubble(
                            isDarkMode: isDarkMode,
                            label: provider.assistantActivityLabel,
                          );
                        }

                        final messageIndex = showAiTyping ? index - 1 : index;
                        final message = messages[messageIndex];
                        final isMine = message.isMine(currentUserId);

                        // Calculate milestones and time visibility
                        bool showTime = true;
                        String? milestoneText;

                        if (messageIndex < messages.length - 1) {
                          final olderMsg = messages[messageIndex + 1];
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

                        return _AiConversationMessageBubble(
                          text: message.content ?? '',
                          isMine: isMine,
                          showTime: showTime,
                          milestoneText: milestoneText,
                          createdAt: message.createdAt,
                          isDarkMode: isDarkMode,
                          source: message.clientMessageId,
                          onQuickActionSelected: _applyQuickPrompt,
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
    final clarification = provider.clarificationState;
    final clarificationText =
        clarification == null
            ? null
            : clarification.isAmbiguous
            ? 'Trợ lý đang chờ bạn chọn đúng đối tượng để tiếp tục.'
            : 'Trợ lý đang chờ bạn xác nhận lại tên đối tượng.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoPill(
            icon:
                provider.cloudBackupEnabled
                    ? Icons.lock_outline
                    : Icons.shield_outlined,
            text: infoText,
            color: AppColors.primary,
            isDarkMode: isDarkMode,
            background: Colors.transparent,
            borderColor: Colors.transparent,
          ),
          if (showDegradedBanner) ...[
            const SizedBox(height: 5),
            _buildInfoPill(
              icon:
                  provider.isProviderUnavailable
                      ? Icons.warning_amber_rounded
                      : Icons.sync_problem_rounded,
              text: degradedText,
              color:
                  provider.isProviderUnavailable
                      ? AppColors.warning
                      : AppColors.primary,
              isDarkMode: isDarkMode,
              background: Colors.transparent,
              borderColor: Colors.transparent,
            ),
          ],
          if (clarificationText != null) ...[
            const SizedBox(height: 5),
            _buildInfoPill(
              icon: Icons.info_outline_rounded,
              text: clarificationText,
              color: AppColors.primary,
              isDarkMode: isDarkMode,
              background: Colors.transparent,
              borderColor: Colors.transparent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDarkMode,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_surfaceRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
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
              icon: Icon(Icons.auto_awesome_rounded, color: iconColor),
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

class _AiConversationMessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final bool showTime;
  final String? milestoneText;
  final DateTime createdAt;
  final bool isDarkMode;
  final String? source;
  final ValueChanged<String> onQuickActionSelected;

  const _AiConversationMessageBubble({
    required this.text,
    required this.isMine,
    required this.showTime,
    required this.milestoneText,
    required this.createdAt,
    required this.isDarkMode,
    required this.source,
    required this.onQuickActionSelected,
  });

  bool get _isClarificationBubble =>
      !isMine && (source?.startsWith('ai_action_ambiguity') ?? false);

  bool get _isMissingTargetBubble =>
      !isMine && (source?.startsWith('ai_action_missing') ?? false);

  List<String> get _clarificationCandidates =>
      AiCommandRouting.parseAmbiguityCandidatesFromSource(source);

  @override
  Widget build(BuildContext context) {
    final userBubbleColor =
        isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent;
    final assistantBubbleColor =
        isDarkMode
            ? DarkColors.chatBubbleReceived
            : LightColors.chatBubbleReceived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  milestoneText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMine ? userBubbleColor : assistantBubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border:
                  isDarkMode
                      ? Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      )
                      : (!isMine
                          ? Border.all(
                            color: AppColors.itemDivider.withValues(alpha: 0.8),
                            width: 0.6,
                          )
                          : null),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isClarificationBubble || _isMissingTargetBubble) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isClarificationBubble
                              ? AppColors.primary.withValues(alpha: 0.14)
                              : AppColors.warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _isClarificationBubble ? 'Cần làm rõ' : 'Chưa tìm thấy',
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            _isClarificationBubble
                                ? AppColors.primary
                                : AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Text(
                  text,
                  style: AppTypography.bodyMedium.copyWith(
                    height: 1.4,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (_isClarificationBubble || _isMissingTargetBubble) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._clarificationCandidates
                          .take(3)
                          .map(
                            (candidate) => _ActionPromptChip(
                              label: candidate,
                              onTap: () {
                                context
                                    .read<AiAssistantProvider>()
                                    .submitDisambiguationSelection(
                                      candidate,
                                      source: 'ai_conversation_candidate_chip',
                                    );
                              },
                            ),
                          ),
                      _ActionPromptChip(
                        label:
                            _isClarificationBubble
                                ? 'Nói rõ họ tên'
                                : 'Thử lại tên khác',
                        onTap:
                            () => onQuickActionSelected(
                              _isClarificationBubble
                                  ? 'Mình muốn người có họ tên đầy đủ là '
                                  : 'Kiểm tra lại liên hệ tên ',
                            ),
                      ),
                      _ActionPromptChip(
                        label: 'Mở danh bạ',
                        onTap: () => onQuickActionSelected('Mở danh bạ'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showTime)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                DateFormatter.time(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isDarkMode
                          ? DarkColors.textSecondary
                          : LightColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionPromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
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

class _AiTypingBubble extends StatelessWidget {
  final bool isDarkMode;
  final String label;

  const _AiTypingBubble({required this.isDarkMode, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? DarkColors.chatBubbleReceived
                    : LightColors.chatBubbleReceived,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border:
                isDarkMode
                    ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                    : Border.all(
                      color: AppColors.itemDivider.withValues(alpha: 0.8),
                    ),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AiTypingDots(isDarkMode: isDarkMode),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDarkMode
                            ? DarkColors.textSecondary
                            : LightColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiTypingDots extends StatefulWidget {
  final bool isDarkMode;

  const _AiTypingDots({required this.isDarkMode});

  @override
  State<_AiTypingDots> createState() => _AiTypingDotsState();
}

class _AiTypingDotsState extends State<_AiTypingDots>
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
