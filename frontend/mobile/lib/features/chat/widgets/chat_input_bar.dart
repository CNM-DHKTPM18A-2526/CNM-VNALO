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

    widget.onSend(text);
    _controller.clear();
    setState(() {
      _hasText = false;
      _showStickers = false;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        context.read<ChatProvider>().sendMediaMessage(
          conversationId: widget.conversationId,
          file: File(image.path),
          type: MessageType.IMAGE,
        );
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
      children: [
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SafeArea(
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
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF5D6470),
                    size: 28,
                  ),
                  onPressed: () => _showAttachmentMenu(context),
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
                      : TextField(
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
                              horizontal: 8,
                              vertical: 10,
                            ),
                            border: InputBorder.none,
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
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressUp: _stopRecording,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.mic,
                        color: _isRecording ? Colors.red : (isDarkMode ? Colors.white70 : const Color(0xFF5D6470)),
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showStickers)
          StickerPicker(
            conversationId: widget.conversationId,
            onSelected: () => setState(() => _showStickers = false),
          ),
      ],
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
