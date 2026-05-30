import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';

class CreatePollScreen extends StatefulWidget {
  final Conversation conversation;

  const CreatePollScreen({super.key, required this.conversation});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  
  bool _pinToTop = false;
  bool _allowMultiple = true;
  bool _allowAddOption = true;
  bool _isAnonymous = false;
  bool _isOptionLimitReached = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_validateForm);
    for (final controller in _optionControllers) {
      controller.addListener(_validateForm);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _validateForm() {
    final question = _questionController.text.trim();
    final filledOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    
    final valid = question.isNotEmpty && filledOptions.length >= 2;
    if (_isValid != valid) {
      setState(() {
        _isValid = valid;
      });
    }
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    final controller = TextEditingController();
    controller.addListener(_validateForm);
    setState(() {
      _optionControllers.add(controller);
      _isOptionLimitReached = _optionControllers.length >= 10;
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      final controller = _optionControllers.removeAt(index);
      controller.dispose();
      _isOptionLimitReached = _optionControllers.length >= 10;
    });
    _validateForm();
  }

  Future<void> _createPoll() async {
    if (!_isValid) return;

    final question = _questionController.text.trim();
    final filledOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final chatProvider = context.read<ChatProvider>();
    // Map options to Web-compatible pollPayload options array
    final List<Map<String, dynamic>> optionsPayload = [];
    for (int i = 0; i < filledOptions.length; i++) {
      optionsPayload.add({
        'id': (i + 1).toString(), // String option ID (1, 2, 3...)
        'label': filledOptions[i],
        'votes': [],
      });
    }

    final pollPayload = {
      'type': 'poll',
      'question': question,
      'options': optionsPayload,
      'allowMultiple': _allowMultiple,
      'allowAddOption': _allowAddOption,
      'isAnonymous': _isAnonymous,
      'expiresAt': null,
      'totalVotes': 0,
    };

    // Send TEXT message with JSON payload
    final contentStr = jsonEncode(pollPayload);
    chatProvider.sendMessage(
      conversationId: widget.conversation.id,
      content: contentStr,
      messageType: 'TEXT',
    );

    // If "Ghim lên đầu trò chuyện" is checked, we pin this new poll!
    // Since we don't have the message ID yet (generated locally or on server), 
    // we can wait a split second or let ChatProvider automatically handle local pin.
    // In our ChatProvider, pinMessage expects a messageId. Let's find the newly added message.
    if (_pinToTop) {
      // Find the message from messages list that has this content
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final list = chatProvider.getMessages(widget.conversation.id);
        final newPollMsg = list.firstWhere(
          (m) => m.content == contentStr,
          orElse: () => list.first,
        );
        chatProvider.pinMessage(newPollMsg.id);
      });
    }

    // Dismiss screens to return to chat thread
    // Double pop: from CreatePoll -> GroupBoard -> Chat
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final conv = provider.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commonBg = isDark ? DarkColors.scaffold : const Color(0xFFF4F5F7);
    final cardBg = isDark ? DarkColors.surface : Colors.white;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final dividerColor = isDark ? DarkColors.divider : AppColors.itemDivider;

    final userId = provider.currentUserId;
    final myMember = conv.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => ConversationMember(
        conversationId: conv.id,
        userId: userId ?? '',
        role: MemberRole.MEMBER,
        joinedAt: DateTime.now(),
      ),
    );
    final isAdminOrDeputy = myMember.role == MemberRole.ADMIN || myMember.role == MemberRole.DEPUTY;
    final canPin = conv.allowMemberPin || isAdminOrDeputy;

    return Scaffold(
      backgroundColor: commonBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo bình chọn mới',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              conv.title ?? 'Nhóm',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: isDark ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        forceMaterialTransparency: !isDark,
        flexibleSpace: isDark
            ? null
            : Container(
                decoration: BoxDecoration(gradient: AppColors.appBarGradient),
              ),
        actions: [
          TextButton(
            onPressed: _isValid ? _createPoll : null,
            child: Text(
              'TẠO',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: _isValid ? Colors.white : Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        children: [
          // Pin to top checkbox row
          if (canPin) ...[
            Container(
              color: cardBg,
              child: ListTile(
                leading: GestureDetector(
                  onTap: () => setState(() => _pinToTop = !_pinToTop),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _pinToTop ? AppColors.primary : Colors.grey,
                        width: 1.5,
                      ),
                      color: _pinToTop ? AppColors.primary : Colors.transparent,
                    ),
                    child: _pinToTop
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                title: Text(
                  'Ghim lên đầu trò chuyện',
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
                onTap: () => setState(() => _pinToTop = !_pinToTop),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Question text field
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _questionController,
              style: TextStyle(fontSize: 16, color: textColor),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Đặt câu hỏi bình chọn',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Divider(height: 1, color: dividerColor, indent: 16),
          // Dynamic options list
          Container(
            color: cardBg,
            child: Column(
              children: [
                ...List.generate(_optionControllers.length, (index) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                style: TextStyle(fontSize: 15, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Phương án ${index + 1}',
                                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                onPressed: () => _removeOption(index),
                              ),
                          ],
                        ),
                      ),
                      if (index < _optionControllers.length - 1)
                        Divider(height: 1, color: dividerColor, indent: 16),
                    ],
                  );
                }),
                // Add option link
                if (!_isOptionLimitReached) ...[
                  Divider(height: 1, color: dividerColor, indent: 16),
                  InkWell(
                    onTap: _addOption,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Thêm phương án',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primary.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Spacing
          const SizedBox(height: 10),
          // Options Section
          Container(
            color: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                _buildOptionTile(
                  title: 'Đặt thời hạn',
                  subtitle: 'Không có thời hạn',
                  onTap: () {
                    // Show a simple bottom sheet for choosing timeline as mock
                    _showDeadlineMockSheet(isDark);
                  },
                  isDark: isDark,
                ),
                _buildDivider(dividerColor),
                _buildSwitchTile(
                  title: 'Ẩn người bình chọn',
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                  isDark: isDark,
                ),
                _buildDivider(dividerColor),
                _buildSwitchTile(
                  title: 'Ẩn kết quả khi chưa bình chọn',
                  value: _allowAddOption == false, // Map logically
                  onChanged: (val) => setState(() => _allowAddOption = !val),
                  isDark: isDark,
                ),
                _buildDivider(dividerColor),
                _buildSwitchTile(
                  title: 'Chọn nhiều phương án',
                  value: _allowMultiple,
                  onChanged: (val) => setState(() => _allowMultiple = val),
                  isDark: isDark,
                ),
                _buildDivider(dividerColor),
                _buildSwitchTile(
                  title: 'Có thể thêm phương án',
                  value: _allowAddOption,
                  onChanged: (val) => setState(() => _allowAddOption = val),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOptionTile({required String title, required String subtitle, required VoidCallback onTap, required bool isDark}) {
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildSwitchTile({required String title, required bool value, required ValueChanged<bool> onChanged, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(height: 1, color: color, indent: 16);
  }

  void _showDeadlineMockSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Đặt thời hạn bình chọn',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Không có thời hạn'),
                trailing: const Icon(Icons.check, color: AppColors.primary),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                title: const Text('1 ngày'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                title: const Text('3 ngày'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                title: const Text('7 ngày'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
