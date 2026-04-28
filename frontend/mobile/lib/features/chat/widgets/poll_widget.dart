import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';

class PollWidget extends StatelessWidget {
  final Message message;
  final bool isDarkMode;
  final void Function(int optionIndex)? onVote;

  const PollWidget({
    super.key,
    required this.message,
    required this.isDarkMode,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final voteCallback = onVote;
    // Poll data is embedded in message content as JSON
    // Format: { "question": "...", "options": [...], "totalVotes": N, "myVote": index_or_null }
    Map<String, dynamic>? pollData;
    try {
      final contentStr = message.content ?? '';
      if (contentStr.startsWith('{')) {
        pollData = Map<String, dynamic>.from(
          Uri.splitQueryString(contentStr).map(
            (k, v) => MapEntry(k, v),
          ),
        );
      }
    } catch (_) {
      pollData = null;
    }

    if (pollData == null) {
      return Text(
        message.content ?? '',
        style: TextStyle(
          fontSize: 15,
          color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
        ),
      );
    }

    final question = pollData['question']?.toString() ?? 'Poll';
    final optionsStr = pollData['options']?.toString() ?? '';
    final options = optionsStr.split('|');
    final totalVotes = int.tryParse(pollData['totalVotes']?.toString() ?? '0') ?? 0;
    final myVoteRaw = pollData['myVote']?.toString();
    final myVoteIndex = myVoteRaw != null ? int.tryParse(myVoteRaw) : null;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.poll_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bình chọn',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ),
              Text(
                '$totalVotes bình chọn',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (index) {
            final option = options[index];
            final isSelected = myVoteIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
              onTap: () {
                voteCallback?.call(index);
              },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDarkMode ? DarkColors.surfaceLight : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDarkMode ? Colors.white12 : Colors.grey.shade300),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey,
                            width: 1.5,
                          ),
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class CreatePollDialog extends StatefulWidget {
  final String conversationId;
  final Function(String question, List<String> options)? onCreate;

  const CreatePollDialog({
    super.key,
    required this.conversationId,
    this.onCreate,
  });

  @override
  State<CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<CreatePollDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final common = CommonTexts.of(context, listen: false);

    return Dialog(
      backgroundColor: isDark ? DarkColors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.poll_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Tạo bình chọn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                labelText: 'Câu hỏi',
                hintText: 'Nhập câu hỏi của bạn...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Các lựa chọn',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? DarkColors.textSecondary : LightColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Lựa chọn ${index + 1}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                        onPressed: () => _removeOption(index),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Thêm lựa chọn'),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(common.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final question = _questionController.text.trim();
                    if (question.isEmpty) return;
                    final options = _optionControllers
                        .map((c) => c.text.trim())
                        .where((o) => o.isNotEmpty)
                        .toList();
                    if (options.length < 2) return;

                    widget.onCreate?.call(question, options);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tạo bình chọn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
