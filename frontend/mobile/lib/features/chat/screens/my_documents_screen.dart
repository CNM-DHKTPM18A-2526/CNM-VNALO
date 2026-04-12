import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

// A simple local message model for self-storage
class _LocalMessage {
  final String id;
  final String content;
  final String type; // 'text', 'image', 'file', 'link'
  final DateTime createdAt;

  _LocalMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _LocalMessage.fromJson(Map<String, dynamic> json) => _LocalMessage(
    id: json['id'],
    content: json['content'],
    type: json['type'] ?? 'text',
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  static const _storageKey = 'my_documents_messages';
  static const List<String> _tabs = ['Tất cả', 'Văn bản', 'Ảnh', 'File', 'Link'];

  int _selectedTabIndex = 0;
  final List<_LocalMessage> _messages = [];
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        _messages.addAll(decoded.map((e) => _LocalMessage.fromJson(e)));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  void _sendMessage(String content) {
    if (content.trim().isEmpty) return;

    final String type = _detectType(content);
    final msg = _LocalMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      type: type,
      createdAt: DateTime.now(),
    );

    setState(() => _messages.insert(0, msg));
    _inputController.clear();
    setState(() => _hasText = false);
    _saveMessages();
  }

  String _detectType(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return 'link';
    }
    return 'text';
  }

  List<_LocalMessage> get _filteredMessages {
    if (_selectedTabIndex == 0) return _messages;
    final typeMap = ['', 'text', 'image', 'file', 'link'];
    final targetType = typeMap[_selectedTabIndex];
    return _messages.where((m) => m.type == targetType).toList();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateGroup(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${dt.day} tháng ${dt.month}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFEBEDF0);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
        title: const Row(
          children: [
            Text(
              'My Documents',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 6),
            Icon(Icons.verified, color: Colors.orange, size: 18),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {}),
        ],
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
                children: List.generate(_tabs.length, (i) {
                  final isSelected = _selectedTabIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode ? const Color(0xFF333333) : const Color(0xFFE5E7EB))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey.withOpacity(0.4)),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          color: isSelected
                              ? (isDarkMode ? Colors.white : Colors.black87)
                              : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    ? _buildEmpty()
                    : _buildMessageList(isDarkMode),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : LightColors.surface,
          border: Border(
            top: BorderSide(
              color: isDarkMode ? DarkColors.divider : const Color(0xFFE5E7EB),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined, 
                    color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470)),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                    minLines: 1,
                    maxLines: 5,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tin nhắn',
                      hintStyle: TextStyle(
                        color: isDarkMode ? DarkColors.textHint : const Color(0xFFA1A3A7),
                        fontSize: 16,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_hasText)
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: () => _sendMessage(_inputController.text),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470)),
                        onPressed: () {},
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: Icon(Icons.mic_none_outlined, color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470)),
                        onPressed: () {},
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: Icon(Icons.image_outlined, color: isDarkMode ? DarkColors.textHint : const Color(0xFF5D6470)),
                        onPressed: () {},
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Chưa có nội dung nào',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy gửi tin nhắn, ảnh hoặc file để lưu trữ',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDarkMode) {
    final msgs = _filteredMessages;

    // Group by date
    final Map<String, List<_LocalMessage>> grouped = {};
    for (final m in msgs) {
      final key = _formatDateGroup(m.createdAt);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(m);
    }

    final List<Widget> items = [];
    grouped.forEach((date, messages) {
      // Date header
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
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

      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        
        // Grouping logic for MyDocuments (all messages are 'Mine')
        // showTime: if it's the newest message (i == 0) OR gap with message above it (i-1) is > 5 mins
        bool showTime = true;
        if (i > 0) {
          final nextRecent = messages[i - 1]; // nextRecent is "below" in UI (reverse: true)
          final gap = nextRecent.createdAt.difference(msg.createdAt).inMinutes.abs();
          if (gap < 5) {
            showTime = false;
          }
        }

        // showStatus: only for the absolute newest message in the newest date group
        bool showStatus = false;
        if (i == 0 && date == _formatDateGroup(msgs.first.createdAt)) {
          showStatus = true;
        }

        items.add(_buildBubble(msg, isDarkMode, showTime, showStatus));
      }
    });

    return ListView(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: items,
    );
  }

  Widget _buildBubble(_LocalMessage msg, bool isDarkMode, bool showTime, bool showStatus) {
    final bubbleColor = isDarkMode ? DarkColors.chatBubbleSent : LightColors.chatBubbleSent;

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: EdgeInsets.only(
              top: showTime ? 8 : 2,
              bottom: 2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              msg.content,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
          if (showTime || showStatus)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 8, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTime)
                    Text(
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? DarkColors.textHint : Colors.grey.shade500,
                      ),
                    ),
                  if (showStatus) ...[
                    if (showTime) const SizedBox(width: 6),
                    const Icon(Icons.done_all, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text(
                      'Đã nhận',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
