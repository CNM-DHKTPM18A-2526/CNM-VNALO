import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';

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
      await widget.onSubmitPrompt(text);
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

  Future<void> _copyResponse(String response) async {
    if (response.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: response));
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
        (viewSize.height > 760 ? 420.0 : viewSize.height * 0.56);

    final hasResponse = aiProvider.aiResponse.trim().isNotEmpty;
    final hasPrompt = aiProvider.lastUserPrompt.trim().isNotEmpty;

    final statusLabel = switch (aiProvider.state) {
      AiState.listening => 'Dang nghe',
      AiState.thinking => 'Dang xu ly',
      AiState.speaking => 'Dang phan hoi',
      AiState.idle => 'San sang',
    };

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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                          Colors.white.withValues(alpha: 0.9),
                          const Color(0xFFEAF3FF).withValues(alpha: 0.88),
                        ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: borderColor, width: 1.1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: const BoxDecoration(
                    gradient: AppColors.appBarGradient,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.smart_toy_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'VNALO AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.onOpenConversation != null)
                            IconButton(
                              key: const ValueKey('ai_chat_open_conversation'),
                              icon: const Icon(Icons.open_in_full, size: 18),
                              color: Colors.white,
                              onPressed: widget.onOpenConversation,
                            ),
                          IconButton(
                            icon: const Icon(Icons.clear_all, size: 18),
                            color: Colors.white,
                            onPressed: widget.onClear,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: Colors.white,
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasPrompt)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 255,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? const Color(0xFF1C355A)
                                          : const Color(0xFFDCEBFF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  aiProvider.lastUserPrompt,
                                  style: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : const Color(0xFF123A77),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child:
                                hasResponse
                                    ? MarkdownBody(
                                      data: aiProvider.aiResponse,
                                      selectable: true,
                                      softLineBreak: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          color:
                                              isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    )
                                    : Text(
                                      aiProvider.state == AiState.listening
                                          ? 'Dang nghe giong noi. Ban cung co the nhap cau hoi ben duoi.'
                                          : aiProvider.state == AiState.thinking
                                          ? 'Dang xu ly yeu cau cua ban...'
                                          : 'Nhap cau hoi de bat dau chat voi tro ly.',
                                      style: TextStyle(
                                        color:
                                            isDarkMode
                                                ? Colors.white60
                                                : Colors.black54,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed:
                                    hasResponse
                                        ? () =>
                                            _copyResponse(aiProvider.aiResponse)
                                        : null,
                                icon: const Icon(Icons.copy_outlined, size: 16),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
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
                      Expanded(
                        child: TextField(
                          key: const ValueKey('ai_chat_input'),
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitTextPrompt(),
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Nhap de chat voi tro ly...',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDarkMode
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDarkMode
                                        ? Colors.white.withValues(alpha: 0.16)
                                        : Colors.black.withValues(alpha: 0.12),
                              ),
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
