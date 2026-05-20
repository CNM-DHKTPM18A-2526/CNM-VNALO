import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class AiConversationDisambiguationSheet extends StatelessWidget {
  final List<Conversation> matches;
  final String currentUserId;
  final String targetName;

  const AiConversationDisambiguationSheet({
    super.key,
    required this.matches,
    required this.currentUserId,
    required this.targetName,
  });

  static Future<Conversation?> show(
    BuildContext context, {
    required List<Conversation> matches,
    required String currentUserId,
    required String targetName,
  }) {
    return showModalBottomSheet<Conversation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => AiConversationDisambiguationSheet(
            matches: matches,
            currentUserId: currentUserId,
            targetName: targetName,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondary =
        isDark ? DarkColors.textSecondary : const Color(0xFF475569);
    final sheetBackground = isDark ? DarkColors.surface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : AppColors.sectionDivider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chọn cuộc trò chuyện "$targetName"',
                style: AppTypography.titleLarge.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Có nhiều kết quả khớp. Vui lòng chọn đúng người hoặc nhóm để trợ lý tiếp tục.',
                style: AppTypography.bodyMedium.copyWith(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.48,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final conversation = matches[index];
                    final displayName = conversation.getDisplayName(
                      currentUserId,
                    );
                    final isDirect = conversation.type.name == 'DIRECT';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey(
                          'ai_conversation_disambiguation_item_${conversation.id}',
                        ),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(conversation),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  isDirect
                                      ? Icons.person
                                      : Icons.groups_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isDirect
                                          ? 'Trò chuyện 1-1'
                                          : 'Nhóm • ${conversation.members.length} thành viên',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const ValueKey('ai_conversation_disambiguation_cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark
                            ? DarkColors.surfaceLight
                            : AppColors.itemPressBackground,
                    foregroundColor: textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Hủy',
                    style: AppTypography.labelLarge.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
