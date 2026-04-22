import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/date_formatter.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

class AiConversationScreen extends StatefulWidget {
  const AiConversationScreen({super.key});

  @override
  State<AiConversationScreen> createState() => _AiConversationScreenState();
}

class _AiConversationScreenState extends State<AiConversationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(AiAssistantProvider provider) async {
    if (_isSending) {
      return;
    }

    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await provider.submitTextPrompt(text, source: 'ai_conversation_screen');
      _inputController.clear();
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _statusLabel(AiState state) {
    return switch (state) {
      AiState.listening => 'Đang lắng nghe',
      AiState.thinking => 'Đang xử lý',
      AiState.speaking => 'Đang phản hồi',
      AiState.idle => 'Sẵn sàng',
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final history = provider.conversationHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hội thoại AI'),
        actions: [
          IconButton(
            onPressed: () async {
              await provider.setCloudBackupEnabled(
                !provider.cloudBackupEnabled,
                reason: 'conversation_screen_toggle',
              );
            },
            icon: Icon(
              provider.cloudBackupEnabled
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
            ),
          ),
          IconButton(
            onPressed:
                history.isEmpty
                    ? null
                    : () async {
                      await provider.clearConversationHistory(
                        clearCurrentResponse: true,
                        reason: 'conversation_screen_clear',
                      );
                    },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDarkMode
                        ? Colors.white.withValues(alpha: 0.09)
                        : const Color(0xFFD5E5FF),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  provider.cloudBackupEnabled
                      ? Icons.lock_clock_outlined
                      : Icons.shield_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.cloudBackupEnabled
                        ? 'Lưu local + cloud backup (theo quyền riêng tư).'
                        : 'Local-first: chỉ lưu trên thiết bị. Cloud backup đang tắt.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                history.isEmpty
                    ? _EmptyAiConversation(
                      statusLabel: _statusLabel(provider.state),
                      isDarkMode: isDarkMode,
                    )
                    : ListView.builder(
                      key: const ValueKey('ai_conversation_list'),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        final isUser = entry.role == AiConversationRole.user;
                        final isSystem =
                            entry.role == AiConversationRole.system;

                        final bubbleColor =
                            isUser
                                ? AppColors.primary.withValues(alpha: 0.92)
                                : isSystem
                                ? (isDarkMode
                                    ? const Color(0xFF3A404A)
                                    : const Color(0xFFE9EEF8))
                                : (isDarkMode
                                    ? const Color(0xFF1E2A3B)
                                    : Colors.white);
                        final textColor =
                            isUser
                                ? Colors.white
                                : (isDarkMode
                                    ? Colors.white70
                                    : Colors.black87);

                        return Align(
                          alignment:
                              isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: const BoxConstraints(maxWidth: 320),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.text,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    height: 1.42,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormatter.relative(entry.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isUser
                                            ? Colors.white70
                                            : (isDarkMode
                                                ? Colors.white54
                                                : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                    onPressed: () {
                      provider.onPrimaryAction(
                        source: 'conversation_screen_mic',
                      );
                    },
                    icon: Icon(
                      provider.state == AiState.listening
                          ? Icons.mic_off
                          : Icons.mic,
                      color:
                          provider.state == AiState.listening
                              ? Colors.redAccent
                              : AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ai_conversation_input'),
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendPrompt(provider),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Nhập câu hỏi cho trợ lý AI...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: ElevatedButton(
                      key: const ValueKey('ai_conversation_send'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor:
                            _isSending || provider.isBusy
                                ? Colors.grey
                                : AppColors.primary,
                      ),
                      onPressed:
                          _isSending || provider.isBusy
                              ? null
                              : () => _sendPrompt(provider),
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
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có hội thoại AI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn micro hoặc gửi câu hỏi để tạo hội thoại AI local-first.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trạng thái hiện tại: $statusLabel',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
