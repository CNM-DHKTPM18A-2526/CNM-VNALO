import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/core/database/local_database.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/chat/widgets/chat_input_bar.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vnalo_mobile/features/chat/providers/forward_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/forward_screen.dart';
import 'package:vnalo_mobile/features/chat/widgets/message_bubble.dart';
import 'package:vnalo_mobile/services/media_service.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

// A simple local message model for self-storage
// Migrated from private _LocalMessage to global LocalMessage

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

extension LocalMessageExtension on LocalMessage {
  Message toMessage(String currentUserId) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      messageType: MessageType.values.firstWhere(
        (e) => e.name == messageType,
        orElse: () => MessageType.TEXT,
      ),
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      mediaSizeBytes: mediaSizeBytes,
      replyToMessageId: replyToId,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      createdAt: createdAt,
      status: MessageStatus.SENT, // 1 tick "Đã gửi" per Zalo style
    );
  }
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  static const _storageKey = 'my_documents_messages';
  static const _convId = 'MY_DOCUMENTS';

  int _selectedTabIndex = 0;
  final List<LocalMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      // Load from DB and migrate any legacy SharedPreferences payload once.
      final db = context.read<LocalDatabase>();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final myId = auth.user?.id ?? 'ME';

      // 1. One-time Migration from SharedPreferences to SQLite
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        try {
          final List<dynamic> decoded = jsonDecode(raw);

          final List<LocalMessage> toMigrate = [];
          for (final item in decoded) {
            toMigrate.add(LocalMessage(
              id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              ownerId: myId,
              conversationId: _convId,
              senderId: myId,
              messageType: 'TEXT',
              content: item['content'] ?? '',
              createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
            ));
          }
          if (toMigrate.isNotEmpty) {
            await db.saveMessagesBatch(toMigrate);
          }
          await prefs.remove(_storageKey); // Clear legacy storage
        } catch (e) {
          debugPrint('Migration failed: $e');
        }
      }

      // 2. Fetch from SQLite
      final msgs = await db.getMessagesByConversation(_convId, myId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final db = context.read<LocalDatabase>();
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id ?? 'ME';
    final myName = auth.user?.displayName ?? 'Tôi';

    final chat = context.read<ChatProvider>();
    final reply = chat.replyingTo;

    final msg = LocalMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: myId,
      conversationId: _convId,
      senderId: myId,
      messageType: 'TEXT',
      content: content.trim(),
      createdAt: DateTime.now(),
      replyToId: reply?.id,
      replyToSenderId: reply?.senderId,
      replyToSenderName: reply != null ? (reply.senderName ?? 'Tôi') : null,
      replyToContent: reply?.content,
    );

    await db.saveMessage(msg);
    if (!mounted) return;
    setState(() {
      _messages.insert(0, msg);
    });
    chat.setReplyTo(null);
    context.read<ChatProvider>().refreshCloudPreview();
    _inputController.clear();
    setState(() => _hasText = false);
  }

  List<LocalMessage> get _filteredMessages {
    switch (_selectedTabIndex) {
      case 0: // Tất cả
        return _messages;
      case 1: // Văn bản
        return _messages.where((m) => m.messageType == 'TEXT').toList();
      case 2: // Ảnh
        return _messages.where((m) => m.messageType == 'IMAGE').toList();
      case 3: // File
        return _messages.where((m) => m.messageType == 'FILE' || m.messageType == 'VIDEO').toList();
      case 4: // Link
        return _messages.where((m) => 
          m.messageType == 'LINK' || 
          (m.messageType == 'TEXT' && m.content.contains('http'))
        ).toList();
      default:
        return _messages;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateGroup(DateTime dt, CommonTexts texts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return texts.today;
    if (diff == 1) return texts.yesterday;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : Colors.transparent;
    final bgColor = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final cardColor = isDarkMode ? DarkColors.surface : Colors.white;

    final texts = CommonTexts.of(context);
    final tabs = texts.docTabs;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        forceMaterialTransparency: !isDarkMode,
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
              ),
        title: Row(
          children: [
            Text(
              texts.myDocumentsHeader,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified, color: Colors.orange, size: 18),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final isSelected = _selectedTabIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode ? DarkColors.primary : AppColors.primary)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: isDarkMode ? DarkColors.divider : AppColors.itemDivider),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Message list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMessages.isEmpty
                    ? _buildEmpty(isDarkMode)
                    : RefreshIndicator(
                        onRefresh: _loadMessages,
                        child: _buildMessageList(isDarkMode),
                      ),
          ),
          ChatInputBar(
            conversationId: _convId,
            onSend: (text) => _sendMessage(text),
            onSendImages: (images) async {
              for (var img in images) {
                await _saveMedia(img.path, MessageType.IMAGE);
              }
            },
            onSendVideos: (paths) async {
              for (var p in paths) {
                await _saveMedia(p, MessageType.VIDEO);
              }
            },
            onSendFiles: (paths) async {
              for (var p in paths) {
                await _saveMedia(p, MessageType.FILE);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDarkMode) {
    final hintColor = isDarkMode ? DarkColors.textHint : Colors.grey[400];
    final subColor = isDarkMode ? DarkColors.textSecondary : Colors.grey[600];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: hintColor),
          const SizedBox(height: 12),
          Text(
            'No content yet',
            style: TextStyle(color: subColor, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message, image, or file to store it here',
            style: TextStyle(color: hintColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDarkMode) {
    final msgs = _filteredMessages;
    final texts = CommonTexts.of(context);

    // Group by date - msgs is newest first
    final Map<String, List<LocalMessage>> grouped = {};
    final List<String> dateOrder = [];
    for (final m in msgs) {
      final key = _formatDateGroup(m.createdAt, texts);
      if (!grouped.containsKey(key)) {
        dateOrder.add(key);
        grouped[key] = [];
      }
      grouped[key]!.add(m);
    }

    final List<Widget> items = [];
    // With reverse: true, we want items[0] to be at the bottom (newest)
    // So we iterate dates from newest to oldest
    for (final date in dateOrder) {
      final messages = grouped[date]!;
      
      // Add messages in that date (already newest first)
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        
        // i == 0 is newest in this date group
        bool showTime = true;
        if (i < messages.length - 1) {
          final older = messages[i + 1];
          final gap = msg.createdAt.difference(older.createdAt).inMinutes.abs();
          if (gap < 5) {
            showTime = false;
          }
        }
        
        bool showStatus = false;
        if (msg.id == msgs.first.id) {
          showStatus = true; // Sent status for overall newest
        }

        items.add(_buildBubble(msg, isDarkMode, showTime, showStatus));
      }

      // Add Date header AFTER messages of that date (it will appear ABOVE them in reverse: true)
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                date,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: items,
    );
  }

  void _handleReply(Message msg) {
    context.read<ChatProvider>().setReplyTo(msg);
  }

  void _deleteMessage(Message msg) async {
    final db = context.read<LocalDatabase>();
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id ?? 'ME';
    await db.deleteMessage(msg.id!, myId);
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
    });
    context.read<ChatProvider>().refreshCloudPreview();
  }

  void _forwardMessage(Message msg) {
    // Parity with regular chat: use ForwardProvider
    context.read<ForwardProvider>().startForwarding([msg]);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForwardScreen()),
    );
  }

  Future<void> _saveMedia(String path, MessageType type) async {
    final db = context.read<LocalDatabase>();
    final auth = context.read<AuthProvider>();
    final media = context.read<MediaService>();
    final chat = context.read<ChatProvider>();
    final myId = auth.user?.id ?? 'ME';
    final myName = auth.user?.displayName ?? 'Tôi';
    final fileName = path.split(Platform.isWindows ? '\\' : '/').last;

    // 0. Get reply state
    final reply = chat.replyingTo;

    // 1. Add optimistic message
    final optimisticId = 'opt-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = LocalMessage(
      id: optimisticId,
      ownerId: myId,
      conversationId: _convId,
      senderId: myId,
      messageType: type.name,
      content: fileName,
      mediaUrl: path, // Local path for preview
      createdAt: DateTime.now(),
      replyToId: reply?.id,
      replyToSenderId: reply?.senderId,
      replyToSenderName: reply != null ? (reply.senderName ?? 'Tôi') : null,
      replyToContent: reply?.content,
    );

    setState(() {
      _messages.insert(0, optimistic);
    });

    try {
      // 2. Upload to server
      final category = type == MessageType.IMAGE ? MediaCategory.CHAT_IMAGE : 
                       (type == MessageType.VIDEO ? MediaCategory.CHAT_VIDEO : MediaCategory.CHAT_FILE);
      final mediaId = await media.uploadFile(File(path), category);
      final publicUrl = media.getPublicUrl(mediaId);

      // 3. Finalize message
      final finalized = optimistic.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        mediaUrl: Value(publicUrl),
        // status: 'SENT', // Remove status
      );

      // 4. Save to DB
      await db.saveMessage(finalized);
      
      // 5. Update UI and clear reply
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == optimisticId);
        if (idx != -1) {
          _messages[idx] = finalized;
        }
      });
      chat.setReplyTo(null);

      // 6. Sync chat list preview
      chat.refreshCloudPreview();
      
    } catch (e) {
      debugPrint('Media upload failed: $e');
      // On failure, we keep the local version but maybe mark it for retry in UI later
    }
  }

  Widget _buildBubble(LocalMessage msg, bool isDarkMode, bool showTime, bool showStatus) {
    final currentUserId = context.read<AuthProvider>().user?.id ?? 'ME';
    final message = msg.toMessage(currentUserId);

    return MessageBubble(
      message: message,
      isMine: true,
      showTime: showTime,
      showStatus: showStatus,
      onReplyAction: _handleReply,
      onDeleteAction: _deleteMessage,
      onForwardAction: _forwardMessage,
      onReplyTap: (id) {
        // Implement jump to message if needed
      },
    );
  }
}
