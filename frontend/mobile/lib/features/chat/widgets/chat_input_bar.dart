import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';
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
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _hasText = false;
  bool _showStickers = false;
  bool _isRecording = false;

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
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      context.read<ChatProvider>().sendImage(
        conversationId: widget.conversationId,
        imagePath: image.path,
      );
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) {
      context.read<ChatProvider>().sendVideo(
        conversationId: widget.conversationId,
        videoPath: video.path,
      );
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && mounted) {
      context.read<ChatProvider>().sendFile(
        conversationId: widget.conversationId,
        filePath: result.files.single.path!,
      );
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(color: isDarkMode ? DarkColors.divider : Colors.black12, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: !_showStickers,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                      color: isDarkMode ? Colors.white10 : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
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
                        hintText: common.messageHint,
                        hintStyle: TextStyle(
                          color: isDarkMode ? DarkColors.textHint : const Color(0xFFA1A3A7),
                          fontSize: 16,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                        onPressed: () {},
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
    final common = CommonTexts.of(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? DarkColors.divider : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.image, color: isDarkMode ? DarkColors.textPrimary : Colors.black87),
              title: Text(common.imageLabel, style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: isDarkMode ? DarkColors.textPrimary : Colors.black87),
              title: Text(common.videoAction, style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: isDarkMode ? DarkColors.textPrimary : Colors.black87),
              title: Text('${common.documentLabel} (${common.fileLimitNote})', style: TextStyle(color: isDarkMode ? DarkColors.textPrimary : Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
