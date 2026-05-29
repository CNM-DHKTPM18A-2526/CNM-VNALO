import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/theme/app_typography.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/features/ai_assistant/theme/ai_assistant_tokens.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class AiConversationDisambiguationSheet extends StatefulWidget {
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
  State<AiConversationDisambiguationSheet> createState() =>
      _AiConversationDisambiguationSheetState();
}

class _AiConversationDisambiguationSheetState
    extends State<AiConversationDisambiguationSheet> {
  static const double _sheetRadius = AiAssistantTokens.sheetRadius;
  static const double _cardRadius = AiAssistantTokens.cardRadius;
  static const double _buttonRadius = AiAssistantTokens.pillRadius;

  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? DarkColors.textPrimary : LightColors.textPrimary;
    final textSecondary =
        isDark ? DarkColors.textSecondary : const Color(0xFF475569);
    final sheetBackground = isDark ? DarkColors.surface : Colors.white;
    final list = widget.matches
        .where((conversation) {
          if (_keyword.trim().isEmpty) return true;
          final displayName = conversation.getDisplayName(widget.currentUserId);
          final normalizedName = displayName.toLowerCase();
          final normalizedKeyword = _keyword.trim().toLowerCase();
          return normalizedName.contains(normalizedKeyword);
        })
        .toList(growable: false);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_sheetRadius),
          ),
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
                  'Chọn cuộc trò chuyện cho "${widget.targetName}"',
                  style: AppTypography.titleLarge.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Có nhiều kết quả khớp. Hãy chọn đúng người hoặc nhóm trước khi trợ lý tiếp tục.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? DarkColors.surfaceLight
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(_cardRadius),
                    border: Border.all(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _keyword = value),
                    style: AppTypography.bodyMedium.copyWith(
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Tìm nhanh theo tên hiển thị',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.white54 : AppColors.iconSubtle,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child:
                      list.isEmpty
                          ? Center(
                            child: Text(
                              'Không có kết quả phù hợp',
                              style: AppTypography.bodyMedium.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          )
                          : ListView.separated(
                            shrinkWrap: true,
                            itemCount: list.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final conversation = list[index];
                              final displayName = conversation.getDisplayName(
                                widget.currentUserId,
                              );
                              final avatarName = _avatarNameForConversation(
                                conversation,
                              );
                              final avatarUrl = _avatarUrlForConversation(
                                conversation,
                              );
                              final subtitle = _subtitleForConversation(
                                conversation,
                              );
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey(
                                    'ai_conversation_disambiguation_item_${conversation.id}',
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    _cardRadius,
                                  ),
                                  onTap:
                                      () => Navigator.of(
                                        context,
                                      ).pop(conversation),
                                  child: Ink(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(
                                        _cardRadius,
                                      ),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _ConversationAvatar(
                                          imageUrl: avatarUrl,
                                          name: avatarName,
                                          size: 44,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.titleMedium
                                                    .copyWith(
                                                      color: textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodySmall
                                                    .copyWith(
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
                    key: const ValueKey(
                      'ai_conversation_disambiguation_cancel',
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark
                              ? DarkColors.surfaceLight
                              : AppColors.itemPressBackground,
                      foregroundColor: textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_buttonRadius),
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
      ),
    );
  }

  String _avatarNameForConversation(Conversation conversation) {
    if (conversation.type.name == 'DIRECT' && conversation.members.isNotEmpty) {
      final otherMember = conversation.members.firstWhere(
        (member) => member.userId != widget.currentUserId,
        orElse: () => conversation.members.first,
      );
      final directName = otherMember.user?.displayName.trim();
      if (directName != null && directName.isNotEmpty) {
        return directName;
      }
    }

    final title = conversation.getDisplayName(widget.currentUserId).trim();
    if (title.isNotEmpty) {
      return title;
    }
    return conversation.type.name == 'DIRECT' ? 'Liên hệ' : 'Nhóm';
  }

  String? _avatarUrlForConversation(Conversation conversation) {
    if (conversation.type.name == 'DIRECT' && conversation.members.isNotEmpty) {
      final otherMember = conversation.members.firstWhere(
        (member) => member.userId != widget.currentUserId,
        orElse: () => conversation.members.first,
      );
      final directAvatar = otherMember.user?.avatarUrl?.trim();
      if (directAvatar != null && directAvatar.isNotEmpty) {
        return directAvatar;
      }
    }

    final conversationAvatar = conversation.avatarUrl?.trim();
    if (conversationAvatar != null && conversationAvatar.isNotEmpty) {
      return conversationAvatar;
    }
    return null;
  }

  String _subtitleForConversation(Conversation conversation) {
    if (conversation.type.name != 'DIRECT') {
      return 'Nhóm • ${conversation.members.length} thành viên';
    }

    if (conversation.members.isEmpty) {
      return 'Trò chuyện 1-1';
    }

    final otherMember = conversation.members.firstWhere(
      (member) => member.userId != widget.currentUserId,
      orElse: () => conversation.members.first,
    );
    final phone = otherMember.user?.phone?.trim();
    final email = otherMember.user?.email?.trim();

    if (phone != null && phone.isNotEmpty) {
      return '1-1 • $phone';
    }
    if (email != null && email.isNotEmpty) {
      return '1-1 • $email';
    }
    return 'Trò chuyện 1-1';
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool isDark;

  const _ConversationAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AvatarWidget(
      imageUrl: imageUrl,
      name: name,
      size: size,
    );
  }
}

