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
    final inputBgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final hintColor = isDarkMode ? Colors.grey[500]! : Colors.grey[400]!;

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

          // Input bar
          Container(
            color: inputBgColor,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined, color: hintColor),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tin nhắn',
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF2B2B2B) : const Color(0xFFF0F2F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_hasText)
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      onPressed: () => _sendMessage(_inputController.text),
                    )
                  else ...[
                    IconButton(
                      icon: Icon(Icons.more_horiz, color: hintColor),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.mic_none_outlined, color: hintColor),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.image_outlined, color: hintColor),
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

      for (final msg in messages) {
        items.add(_buildBubble(msg, isDarkMode));
      }
    });

    return ListView(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: items,
    );
  }

  Widget _buildBubble(_LocalMessage msg, bool isDarkMode) {
    final bool isLink = msg.type == 'link';
    final bubbleColor = isDarkMode ? const Color(0xFF2A5298) : const Color(0xFFD4E6FA);

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 4),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: isLink ? Colors.blue[200] : (isDarkMode ? Colors.white : Colors.black87),
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white60 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
