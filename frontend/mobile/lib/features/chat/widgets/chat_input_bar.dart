import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/widgets/sticker_picker.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/attachment_action_sheets.dart';
import 'package:vnalo_mobile/features/chat/widgets/mention_autocomplete.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/features/chat/widgets/voice_recording_overlay.dart';
import 'package:vnalo_mobile/features/chat/widgets/poll_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

class ChatInputBar extends StatefulWidget {
  final String conversationId;
  final ValueChanged<String> onSend;
  final Future<void> Function(List<XFile> images)? onSendImages;
  final Future<void> Function(List<String> videoPaths)? onSendVideos;
  final Future<void> Function(List<String> filePaths)? onSendFiles;
  final void Function(String content, String messageType)? onSendWithType;
  final List<ConversationMember> members;
  final bool isGroup;

  final String? initialText;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.onSend,
    this.onSendImages,
    this.onSendVideos,
    this.onSendFiles,
    this.onSendWithType,
    this.members = const [],
    this.isGroup = false,
    this.initialText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final FocusNode _focusNode = FocusNode();

  bool _hasText = false;
  bool _showStickers = false;
  bool _showVoiceRecording = false;

  // @Mention state
  bool _showMention = false;
  String _mentionQuery = '';
  int _mentionStart = -1;

  // Typing indicator
  Timer? _typingTimer;
  static const _typingDebounceMs = 2000;
  StreamSubscription? _aiComposeDraftSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _applyDraftText(widget.initialText!);
    }
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = context.read<ChatProvider>();
      _aiComposeDraftSub = chat.aiComposeDraftStream.listen((event) {
        if (!mounted || event.conversationId != widget.conversationId) {
          return;
        }
        _applyDraftText(event.text);
        _focusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _aiComposeDraftSub?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _recorder.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialText?.trim();
    final previous = oldWidget.initialText?.trim();
    if (incoming != null &&
        incoming.isNotEmpty &&
        incoming != previous &&
        incoming != _controller.text.trim()) {
      _applyDraftText(incoming);
    }
  }

  void _applyDraftText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    _controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _hideMention();
    if (!_hasText) {
      setState(() => _hasText = true);
    }
  }

  // â”€â”€â”€ @Mention Detection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _onTextChanged() {
    final text = _controller.text;
    final sel = _controller.selection;

    if (!sel.isValid || sel.baseOffset != sel.extentOffset) {
      _hideMention();
      return;
    }

    final cursorPos = sel.baseOffset;
    if (cursorPos < 1) {
      _hideMention();
      return;
    }

    // Look for @ that appears after a word boundary or start of text
    final before = text.substring(0, cursorPos);
    final atIdx = before.lastIndexOf('@');

    if (atIdx == -1) {
      _hideMention();
      return;
    }

    // Make sure there's no space between @ and cursor
    final afterAt = before.substring(atIdx);
    if (afterAt.contains(' ')) {
      _hideMention();
      return;
    }

    final query = afterAt.substring(1); // text after @
    _mentionStart = atIdx;
    _mentionQuery = query;

    if (!_showMention) {
      setState(() => _showMention = true);
    } else {
      setState(() {});
    }

    // Emit typing indicator with debounce
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: _typingDebounceMs), () {
      if (mounted) {
        context.read<ChatProvider>().emitTyping(widget.conversationId);
      }
    });
  }

  void _hideMention() {
    if (_showMention) {
      setState(() {
        _showMention = false;
        _mentionQuery = '';
        _mentionStart = -1;
      });
    }
  }

  void _insertMention(ConversationMember member) {
    final name = member.nickname ?? member.user?.displayName ?? 'User';
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    final newText =
        '${text.substring(0, _mentionStart)}@$name ${text.substring(cursorPos)}';

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _mentionStart + name.length + 2,
      ),
    );
    _hideMention();
    setState(() => _hasText = _controller.text.trim().isNotEmpty);
  }

  void _onSend() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSend(_controller.text.trim());
      _controller.clear();
      _hideMention();
      setState(() => _hasText = false);
    }
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty && mounted) {
      if (widget.onSendImages != null) {
        await widget.onSendImages!(images);
        return;
      }
      final provider = context.read<ChatProvider>();
      for (final image in images) {
        final length = await image.length();
        if (length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'KhÃ´ng há»— trá»£ gá»­i file/áº£nh lá»›n hÆ¡n 5MB',
                ),
              ),
            );
          }
          continue;
        }
        provider.sendImage(
          conversationId: widget.conversationId,
          imagePath: image.path,
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && mounted) {
      final paths =
          result.files.map((f) => f.path).whereType<String>().toList();
      if (widget.onSendVideos != null) {
        await widget.onSendVideos!(paths);
        return;
      }
      final provider = context.read<ChatProvider>();
      for (final file in result.files) {
        if (file.path == null) continue;
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('KhÃ´ng há»— trá»£ gá»­i video lá»›n hÆ¡n 5MB'),
              ),
            );
          }
          continue;
        }
        provider.sendVideo(
          conversationId: widget.conversationId,
          videoPath: file.path!,
        );
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      final paths =
          result.files.map((f) => f.path).whereType<String>().toList();
      if (widget.onSendFiles != null) {
        await widget.onSendFiles!(paths);
        return;
      }
      final provider = context.read<ChatProvider>();
      for (final file in result.files) {
        if (file.path == null) continue;
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('KhÃ´ng há»— trá»£ gá»­i file lá»›n hÆ¡n 5MB'),
              ),
            );
          }
          continue;
        }
        provider.sendFile(
          conversationId: widget.conversationId,
          filePath: file.path!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? DarkColors.surface : LightColors.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // @Mention autocomplete overlay
        if (_showMention && widget.isGroup)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
            child: MentionAutocompleteOverlay(
              members: widget.members,
              query: _mentionQuery,
              onSelected: _insertMention,
              onDismiss: _hideMention,
            ),
          ),

        _buildReplyPreview(context),
        // Typing indicator row
        _buildTypingIndicator(context),
        if (_showVoiceRecording)
          VoiceRecordingOverlay(
            conversationId: widget.conversationId,
            onCancel: () => setState(() => _showVoiceRecording = false),
            onSendAudio: (path, transcription) {
              context.read<ChatProvider>().sendVoiceMessage(
                conversationId: widget.conversationId,
                audioPath: path,
                transcription: transcription,
              );
              setState(() => _showVoiceRecording = false);
            },
            onSendText: (text) {
              if (text.isNotEmpty) {
                widget.onSend(text);
              }
              setState(() => _showVoiceRecording = false);
            },
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                top: BorderSide(
                  color:
                      isDarkMode ? DarkColors.divider : AppColors.itemDivider,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: !_showStickers,
              minimum: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _showStickers
                          ? Icons.keyboard
                          : Icons.emoji_emotions_outlined,
                      color:
                          isDarkMode
                              ? DarkColors.textSecondary
                              : AppColors.iconSubtle,
                    ),
                    onPressed: () {
                      setState(() => _showStickers = !_showStickers);
                      if (_showStickers) FocusScope.of(context).unfocus();
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged:
                            (v) =>
                                setState(() => _hasText = v.trim().isNotEmpty),
                        onTap: () => setState(() => _showStickers = false),
                        minLines: 1,
                        maxLines: 5,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tin nháº¯n',
                          hintStyle: TextStyle(
                            color:
                                isDarkMode
                                    ? DarkColors.textHint
                                    : const Color(0xFFA1A3A7),
                            fontSize: 16,
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
                      icon: Icon(
                        Icons.send,
                        color:
                            isDarkMode ? DarkColors.primary : AppColors.primary,
                      ),
                      onPressed: _onSend,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.more_horiz,
                            color:
                                isDarkMode
                                    ? DarkColors.textSecondary
                                    : AppColors.iconSubtle,
                          ),
                          onPressed: () => _showAttachmentMenu(context),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.mic_none_outlined,
                            color:
                                isDarkMode
                                    ? DarkColors.textSecondary
                                    : AppColors.iconSubtle,
                          ),
                          onPressed: () {
                            setState(() {
                              _showVoiceRecording = true;
                              _showStickers = false;
                            });
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.image_outlined,
                            color:
                                isDarkMode
                                    ? DarkColors.textSecondary
                                    : AppColors.iconSubtle,
                          ),
                          onPressed: _pickImage,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (_showStickers)
          StickerPicker(
            conversationId: widget.conversationId,
            onSelected: () => setState(() => _showStickers = false),
            onEmojiSelected: (emoji) {
              if (emoji == '\b') {
                final text = _controller.text;
                final selection = _controller.selection;
                if (selection.start > 0) {
                  final newText = text.replaceRange(
                    selection.start - 1,
                    selection.start,
                    '',
                  );
                  _controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: selection.start - 1,
                    ),
                  );
                }
                setState(() => _hasText = _controller.text.trim().isNotEmpty);
                return;
              }
              final text = _controller.text;
              final selection = _controller.selection;
              if (selection.start >= 0 && selection.end >= 0) {
                final newText = text.replaceRange(
                  selection.start,
                  selection.end,
                  emoji,
                );
                _controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: (selection.start + emoji.length).toInt(),
                  ),
                );
              } else {
                _controller.text = text + emoji;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              }
              setState(() => _hasText = _controller.text.trim().isNotEmpty);
            },
          ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    // Show inline reply context above the input area.
    final chatProvider = context.watch<ChatProvider>();
    final replyMsg = chatProvider.replyingTo;
    if (replyMsg == null) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? DarkColors.divider : AppColors.itemDivider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.primary : AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyMsg.senderName ?? common.unknownUser,
                  style: TextStyle(
                    color:
                        isDarkMode
                            ? DarkColors.primary
                            : const Color(0xFF0068FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  replyMsg.messageType == MessageType.TEXT
                      ? (replyMsg.content ?? '')
                      : '[${common.imageMediaLabel}]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isDarkMode
                            ? DarkColors.textSecondary
                            : LightColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => chatProvider.setReplyTo(null),
            child: Icon(
              Icons.close,
              size: 20,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final typingUsers = chatProvider.getTypingUsers(widget.conversationId);

    if (typingUsers.isEmpty) return const SizedBox.shrink();

    final conv =
        chatProvider.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
    if (conv == null) return const SizedBox.shrink();

    final orderedTypers =
        typingUsers.entries.toList()
          ..sort((a, b) => a.value.lastSeen.compareTo(b.value.lastSeen));

    final text =
        orderedTypers.length == 1
            ? _singleTypingLabel(conv, orderedTypers.first)
            : _multiTypingLabel(conv, orderedTypers);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 16, height: 16, child: _TypingDots()),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _singleTypingLabel(
    Conversation conversation,
    MapEntry<String, ChatTypingState> typer,
  ) {
    final displayName = _typingDisplayName(conversation, typer.key);
    final suffix = _typingPlatformSuffix(typer.value.clientPlatform);
    return '$displayName ?ang nh?p tin nh?n$suffix...';
  }

  String _multiTypingLabel(
    Conversation conversation,
    List<MapEntry<String, ChatTypingState>> orderedTypers,
  ) {
    final visibleNames =
        orderedTypers
            .take(3)
            .map((entry) => _typingDisplayName(conversation, entry.key))
            .toList();
    final remaining = orderedTypers.length - visibleNames.length;
    final namesText = visibleNames.join(', ');

    if (remaining > 0) {
      return '$namesText v? $remaining ng??i kh?c ?ang nh?p tin nh?n...';
    }
    return '$namesText ?ang nh?p tin nh?n...';
  }

  String _typingDisplayName(Conversation conversation, String userId) {
    final member =
        conversation.members.where((m) => m.userId == userId).firstOrNull;
    final nickname = member?.nickname?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }

    final displayName = member?.user?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return 'Ai ??';
  }

  String _typingPlatformSuffix(String? platform) {
    switch (platform) {
      case 'DESKTOP':
      case 'WEB':
        return ' t? m?y t?nh';
      case 'ANDROID':
      case 'IOS':
      case 'MOBILE':
        return ' t? ?i?n tho?i';
      default:
        return '';
    }
  }

  void _showAttachmentMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? DarkColors.divider
                                : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.start,
                    children: [
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.location_on,
                        const Color(0xFFE56353),
                        'Vá»‹ trÃ­',
                        () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder:
                                (_) => LocationPickerSheet(
                                  onLocationSelected: (address, lat, lng) {
                                    widget.onSend('ðŸ“ $address');
                                  },
                                ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.attach_file,
                        const Color(0xFF4A89DF),
                        'TÃ i liá»‡u',
                        () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.videocam,
                        AppColors.success,
                        'Video',
                        () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.alarm,
                        AppColors.warning,
                        'Nháº¯c háº¹n',
                        () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder:
                                (_) => ReminderDialog(
                                  onReminderSet: (title, reminderTime) {
                                    widget.onSend(
                                      'â° Nháº¯c háº¹n: $title - ${_formatReminderTime(reminderTime)}',
                                    );
                                  },
                                ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.poll_rounded,
                        AppColors.primary,
                        'BÃ¬nh chá»n',
                        () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder:
                                (_) => CreatePollDialog(
                                  conversationId: widget.conversationId,
                                  onCreate: (question, options) {
                                    final encoded =
                                        'question=${Uri.encodeComponent(question)}&options=${options.map((o) => Uri.encodeComponent(o)).join('|')}&totalVotes=0';
                                    if (widget.onSendWithType != null) {
                                      widget.onSendWithType!(encoded, 'POLL');
                                    } else {
                                      widget.onSend(encoded);
                                    }
                                  },
                                ),
                          );
                        },
                      ),
                      _buildMenuButton(
                        context,
                        isDarkMode,
                        Icons.chat,
                        const Color(0xFF4A89DF),
                        'Tin nháº¯n nhanh',
                        () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder:
                                (_) => QuickMessageSheet(
                                  onQuickMessageSelected: (msg) {
                                    widget.onSend(msg);
                                  },
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }

  String _formatReminderTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays > 0) {
      return 'ngÃ y ${dt.day}/${dt.month} lÃºc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'lÃºc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMenuButton(
    BuildContext context,
    bool isDarkMode,
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.2, 0.4 + i * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white54 : Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.4 + _animations[i].value * 0.6,
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
