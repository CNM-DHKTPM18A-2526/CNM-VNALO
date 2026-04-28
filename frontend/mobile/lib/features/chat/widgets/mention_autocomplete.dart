import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';

class MentionAutocompleteOverlay extends StatefulWidget {
  final List<ConversationMember> members;
  final String query;
  final Function(ConversationMember member) onSelected;
  final VoidCallback onDismiss;

  const MentionAutocompleteOverlay({
    super.key,
    required this.members,
    required this.query,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<MentionAutocompleteOverlay> createState() => _MentionAutocompleteOverlayState();
}

class _MentionAutocompleteOverlayState extends State<MentionAutocompleteOverlay> {
  late List<ConversationMember> _filtered;

  @override
  void initState() {
    super.initState();
    _filter();
  }

  @override
  void didUpdateWidget(MentionAutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _filter();
    }
  }

  void _filter() {
    final q = widget.query.toLowerCase().trim();
    if (q.isEmpty) {
      _filtered = widget.members.take(8).toList();
    } else {
      _filtered = widget.members.where((m) {
        final name = m.user?.displayName ?? m.nickname ?? '';
        return name.toLowerCase().contains(q);
      }).take(8).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxH = _filtered.length > 5 ? 240.0 : _filtered.length * 56.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? DarkColors.surface : Colors.white,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: _filtered.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không tìm thấy thành viên',
                  style: TextStyle(
                    color: isDark ? DarkColors.textSecondary : LightColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final member = _filtered[index];
                  final name = member.nickname ?? member.user?.displayName ?? 'User';
                  final avatarUrl = member.user?.avatarUrl;
                  final role = member.role;

                  Color? roleColor;
                  String? roleLabel;
                  if (role == MemberRole.ADMIN) {
                    roleColor = Colors.orange;
                    roleLabel = 'Trưởng nhóm';
                  } else if (role == MemberRole.DEPUTY) {
                    roleColor = Colors.blue;
                    roleLabel = 'Phó nhóm';
                  }

                  return InkWell(
                    onTap: () => widget.onSelected(member),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          AvatarWidget(
                            imageUrl: avatarUrl,
                            name: name,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? DarkColors.textPrimary : LightColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (roleLabel != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: roleColor?.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          roleLabel!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: roleColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
