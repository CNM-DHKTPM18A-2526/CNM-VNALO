import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class PollDetailsScreen extends StatefulWidget {
  final Conversation conversation;
  final Message message;

  const PollDetailsScreen({
    super.key,
    required this.conversation,
    required this.message,
  });

  @override
  State<PollDetailsScreen> createState() => _PollDetailsScreenState();
}

class _PollDetailsScreenState extends State<PollDetailsScreen> {
  final Set<String> _selectedOptionIds = {};
  Map<String, dynamic>? _pollData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _parsePollData();
    _loadInitialVotes();
  }

  void _parsePollData() {
    try {
      final contentStr = widget.message.content ?? '';
      if (contentStr.trim().startsWith('{')) {
        setState(() {
          _pollData = jsonDecode(contentStr) as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('[PollDetailsScreen] Error parsing poll data: $e');
    }
  }

  void _loadInitialVotes() {
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;
    if (currentUserId == null) return;

    final reactions = chatProvider.getReactionsForMessage(widget.message.id);
    final options = (_pollData?['options'] as List<dynamic>?) ?? const [];

    // Support both formats:
    // - vote:0 / vote:1 (index-based)
    // - vote:<optionId> (id-based)
    final Map<String, String> indexToOptionId = {
      for (int i = 0; i < options.length; i++)
        i.toString(): (options[i] is Map
            ? ((options[i] as Map)['id']?.toString() ?? i.toString())
            : i.toString()),
    };

    for (final reaction in reactions) {
      if (reaction.userId == currentUserId) {
        final emoji = reaction.emoji;
        if (emoji.startsWith('vote:') || emoji.startsWith('v:')) {
          final prefixLen = emoji.startsWith('vote:') ? 5 : 2;
          final optionIds = emoji.substring(prefixLen).split(',');
          for (final optId in optionIds) {
            final trimmed = optId.trim();
            if (trimmed.isNotEmpty) {
              final resolved = indexToOptionId[trimmed] ?? trimmed;
              _selectedOptionIds.add(resolved);
            }
          }
        }
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  void _toggleOption(String optId, bool allowMultiple) {
    setState(() {
      if (allowMultiple) {
        if (_selectedOptionIds.contains(optId)) {
          _selectedOptionIds.remove(optId);
        } else {
          _selectedOptionIds.add(optId);
        }
      } else {
        _selectedOptionIds.clear();
        _selectedOptionIds.add(optId);
      }
    });
  }

  Future<void> _submitVote() async {
    if (_selectedOptionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một phương án để bình chọn.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      final newEmoji = 'v:${_selectedOptionIds.join(',')}';
      await chatProvider.addReaction(widget.message.id, newEmoji);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi bình chọn: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addNewOption() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final newOptionLabel = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? DarkColors.surface : Colors.white,
          title: const Text(
            'Thêm phương án mới',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nhập phương án bình chọn',
              hintStyle: TextStyle(fontSize: 14.5, color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            style: TextStyle(
              fontSize: 15,
              color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('HỦY', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.isNotEmpty ? text : null);
              },
              child: const Text('THÊM', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (newOptionLabel == null || newOptionLabel.isEmpty) return;

    if (_pollData == null) return;
    
    final options = List<Map<String, dynamic>>.from(
      (_pollData!['options'] as List<dynamic>).map((x) => Map<String, dynamic>.from(x as Map))
    );

    // Verify option limit
    if (options.length >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số lượng phương án tối đa là 10.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Check duplicate
    if (options.any((o) => o['label']?.toString().toLowerCase() == newOptionLabel.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phương án này đã tồn tại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Create new option payload
    final nextId = (options.length + 1).toString();
    options.add({
      'id': nextId,
      'label': newOptionLabel,
      'votes': [],
    });

    final updatedPoll = Map<String, dynamic>.from(_pollData!);
    updatedPoll['options'] = options;

    // NOTE: Editing poll options via REST API is not yet supported.
    // For now, update local state only and show a message.
    setState(() {
      _pollData = updatedPoll;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm phương án mới (chỉ hiện thị local).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_pollData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bình chọn')),
        body: const Center(child: Text('Lỗi tải dữ liệu bình chọn.')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? DarkColors.surface : Colors.white;
    final textColor = isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final dividerColor = isDark ? DarkColors.divider : AppColors.itemDivider;

    final question = _pollData!['question']?.toString() ?? 'Bình chọn';
    final rawOptions = _pollData!['options'] as List<dynamic>? ?? [];
    final allowMultiple = _pollData!['allowMultiple'] as bool? ?? true;
    final allowAddOption = _pollData!['allowAddOption'] as bool? ?? true;

    final creatorName = widget.message.senderName ?? 'Thành viên nhóm';
    final timeStr = _formatTimeAgo(widget.message.createdAt);

    // Get hasVotedAny from live reactions for the bottom button label
    final chatProvider = context.watch<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;
    final reactions = chatProvider.getReactionsForMessage(widget.message.id);
    final hasVotedAny = reactions.any((r) => r.userId == currentUserId && (r.emoji.startsWith('vote:') || r.emoji.startsWith('v:')));

    return Scaffold(
      backgroundColor: isDark ? DarkColors.scaffold : const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết bình chọn',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              widget.conversation.title ?? 'Nhóm',
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
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 24, color: Colors.white),
            onPressed: () {
              // Placeholder for more options
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Question
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Creator info
                Text(
                  '$creatorName • $timeStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                // Instruction banner
                Row(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allowMultiple ? 'Chọn được nhiều phương án' : 'Chọn 1 phương án',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 16),
                // Options list
                ...List.generate(rawOptions.length, (index) {
                  final opt = rawOptions[index] as Map<String, dynamic>;
                  final optId = opt['id']?.toString() ?? index.toString();
                  final label = opt['label']?.toString() ?? '';
                  final isSelected = _selectedOptionIds.contains(optId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _toggleOption(optId, allowMultiple),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.grey.shade200),
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Custom circular indicator
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                color: isSelected ? AppColors.primary : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // Add new option action link
                if (allowAddOption) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _addNewOption,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.grey, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'THÊM PHƯƠNG ÁN',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
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
          // Bottom button section
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                top: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitVote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        hasVotedAny ? 'ĐỔI BÌNH CHỌN' : 'BÌNH CHỌN',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
