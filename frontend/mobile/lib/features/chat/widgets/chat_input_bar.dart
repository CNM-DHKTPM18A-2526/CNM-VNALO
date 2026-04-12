import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/widgets/sticker_picker.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class ChatInputBar extends StatefulWidget {
  final String conversationId;
  final ValueChanged<String> onSend;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _imagePicker = ImagePicker();
  bool _hasText = false;
  bool _showStickers = false;
  bool _isRecording = false;

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final replyTo = context.read<ChatProvider>().replyingTo;
    widget.onSend(text);
    if (replyTo != null) {
       // Optional: additional logic if needed, but provider handle it
    }
    
    _controller.clear();
    setState(() {
      _hasText = false;
      _showStickers = false;
    });
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      if (mounted) {
        for (final image in images) {
          context.read<ChatProvider>().sendMediaMessage(
            conversationId: widget.conversationId,
            file: File(image.path),
            type: MessageType.IMAGE,
          );
        }
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final file = File(video.path);
      final sizeMb = file.lengthSync() / (1024 * 1024);
      
      if (sizeMb > 20) { // Limit video size to ~20MB
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video phải dưới 20MB')),
          );
        }
        return;
      }

      if (mounted) {
        context.read<ChatProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          file: file,
          type: MessageType.VIDEO,
        );
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final sizeMb = file.lengthSync() / (1024 * 1024);
      
      if (sizeMb > 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File must be under 5MB')),
          );
        }
        return;
      }

      if (mounted) {
        context.read<ChatProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          file: file,
          type: MessageType.FILE,
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null && mounted) {
        context.read<ChatProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          file: File(path),
          type: MessageType.AUDIO,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _toggleStickers() {
    setState(() {
      _showStickers = !_showStickers;
      if (_showStickers) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReplyPreview(context),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : LightColors.surface,
            border: Border(
              top: BorderSide(
                color: isDarkMode ? Colors.white10 : const Color(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // Giảm padding vertical để sát hơn
          child: SafeArea(
            bottom: !_showStickers, // Quan trọng: Tắt padding dưới khi hiện sticker picker
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: _showStickers ? AppColors.primary : (isDarkMode ? Colors.white70 : const Color(0xFF5D6470)),
                    size: 28,
                  ),
                  onPressed: _toggleStickers,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: _isRecording
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.mic, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Recording...', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white10 : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _controller,
                            onTap: () {
                              if (_showStickers) setState(() => _showStickers = false);
                            },
                            onChanged: (value) => setState(() => _hasText = value.trim().isNotEmpty),
                            minLines: 1,
                            maxLines: 5,
                            style: TextStyle(
                              fontSize: 17,
                              color: isDarkMode ? Colors.white : LightColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tin nhắn',
                              hintStyle: TextStyle(
                                color: isDarkMode ? Colors.white38 : const Color(0xFFA1A3A7),
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                if (_hasText)
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary, size: 28),
                    onPressed: _send,
                    padding: const EdgeInsets.all(8),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470), size: 28),
                        onPressed: () => _showAttachmentMenu(context),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
                      ),
                      GestureDetector(
                        onLongPress: _startRecording,
                        onLongPressUp: _stopRecording,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          color: Colors.transparent,
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none,
                            color: _isRecording ? Colors.red : (isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470)),
                            size: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.image_outlined, color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470), size: 28),
                        onPressed: _pickImage,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(),
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
                   selection: TextSelection.collapsed(offset: selection.start + emoji.length),
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
    final chatProvider = context.watch<ChatProvider>();
    final replyMsg = chatProvider.replyingTo;
    if (replyMsg == null) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
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
                  replyMsg.senderName ?? 'Người dùng',
                  style: TextStyle(
                    color: isDarkMode ? Colors.blue[300] : const Color(0xFF0068FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  replyMsg.messageType == MessageType.TEXT
                      ? (replyMsg.content ?? '')
                      : '[Hình ảnh/Phương tiện]',
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Hình ảnh'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Tài liệu (Dưới 5MB)'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }
}
