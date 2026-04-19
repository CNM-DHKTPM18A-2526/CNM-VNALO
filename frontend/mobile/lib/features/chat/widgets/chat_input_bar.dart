import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/widgets/sticker_picker.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/features/chat/widgets/voice_recording_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

class ChatInputBar extends StatefulWidget {
  final String conversationId;
  final ValueChanged<String> onSend;
  final Future<void> Function(List<XFile> images)? onSendImages;
  final Future<void> Function(List<String> videoPaths)? onSendVideos;
  final Future<void> Function(List<String> filePaths)? onSendFiles;

  final String? initialText;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.onSend,
    this.onSendImages,
    this.onSendVideos,
    this.onSendFiles,
    this.initialText,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _hasText = false;
  bool _showStickers = false;
  bool _showVoiceRecording = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _controller.text = widget.initialText!;
      _hasText = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onSend() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSend(_controller.text.trim());
      _controller.clear();
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
              const SnackBar(content: Text('Không hỗ trợ gửi file/ảnh lớn hơn 5MB')),
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && mounted) {
      final paths = result.files.map((f) => f.path).whereType<String>().toList();
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
              const SnackBar(content: Text('Không hỗ trợ gửi video lớn hơn 5MB')),
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
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      final paths = result.files.map((f) => f.path).whereType<String>().toList();
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
              const SnackBar(content: Text('Không hỗ trợ gửi file lớn hơn 5MB')),
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
    final common = CommonTexts.of(context);
    final bgColor = isDarkMode ? DarkColors.surface : LightColors.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyPreview(context),
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
                top: BorderSide(color: isDarkMode ? DarkColors.divider : Colors.black12, width: 0.5),
              ),
            // ),
            // child: SafeArea(
            //   bottom: !_showStickers,
            //   minimum: const EdgeInsets.symmetric(vertical: 2),
            //   child: Row(
            //     crossAxisAlignment: CrossAxisAlignment.center,
            //     children: [
          ),
          child: SafeArea(
            bottom: !_showStickers,
            minimum: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF5D6470),
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
                      onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                      onTap: () => setState(() => _showStickers = false),
                      minLines: 1,
                      maxLines: 5,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tin nhắn',
                        hintStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textHint : const Color(0xFFA1A3A7),
                          fontSize: 16,
                        ),
                        isDense: true,
                        filled: false, // Đảm bảo không bị fill màu xám mặc định
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                  if (_hasText)
                    IconButton(
                      icon: Icon(Icons.send, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                      onPressed: _onSend,
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF5D6470)),
                          onPressed: () => _showAttachmentMenu(context),
                        ),
                        IconButton(
                          icon: Icon(Icons.mic_none_outlined, color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF5D6470)),
                          onPressed: () {
                            setState(() {
                              _showVoiceRecording = true;
                              _showStickers = false;
                            });
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.image_outlined, color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF5D6470)),
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
                   final newText = text.replaceRange(selection.start - 1, selection.start, '');
                   _controller.value = TextEditingValue(
                     text: newText,
                     selection: TextSelection.collapsed(offset: selection.start - 1),
                   );
                 }
                 setState(() => _hasText = _controller.text.trim().isNotEmpty);
                 return;
               }
               final text = _controller.text;
               final selection = _controller.selection;
               if (selection.start >= 0 && selection.end >= 0) {
                 final newText = text.replaceRange(selection.start, selection.end, emoji);
                  _controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: (selection.start + emoji.length).toInt()),
                  );
               } else {
                 _controller.text = text + emoji;
                 _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
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
          top: BorderSide(color: isDarkMode ? DarkColors.divider : Colors.black12, width: 0.5),
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
                    color: isDarkMode ? DarkColors.primary : const Color(0xFF0068FF),
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
                    color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
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
              color: isDarkMode ? Colors.white54 : Colors.grey[600]
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? DarkColors.divider : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.start,
                children: [
                  _buildMenuButton(context, isDarkMode, Icons.location_on, const Color(0xFFE56353), 'Vị trí', () {
                    Navigator.pop(context);
                  }),
                  _buildMenuButton(context, isDarkMode, Icons.attach_file, const Color(0xFF4A89DF), 'Tài liệu', () {
                    Navigator.pop(context);
                    _pickFile();
                  }),
                  _buildMenuButton(context, isDarkMode, Icons.videocam, const Color(0xFF34A853), 'Video', () {
                    Navigator.pop(context);
                    _pickVideo();
                  }),
                  _buildMenuButton(context, isDarkMode, Icons.alarm, const Color(0xFFE56353), 'Nhắc hẹn', () {
                    Navigator.pop(context);
                  }),
                  _buildMenuButton(context, isDarkMode, Icons.chat, const Color(0xFF4A89DF), 'Tin nhắn nhanh', () {
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, bool isDarkMode, IconData icon, Color color, String label, VoidCallback onTap) {
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
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
