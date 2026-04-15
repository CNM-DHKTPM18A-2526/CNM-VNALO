import 'package:flutter/material.dart';
import 'package:vnalo_mobile/models/message_reaction_model.dart';

class MessageReactions extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String currentUserId;
  final Function(String emoji)? onToggleReaction;
  final Function(String emoji)? onShowReactors;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onToggleReaction,
    this.onShowReactors,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji
    final Map<String, List<MessageReaction>> groupedReactions = {};
    for (final reaction in reactions) {
      if (!groupedReactions.containsKey(reaction.emoji)) {
        groupedReactions[reaction.emoji] = [];
      }
      groupedReactions[reaction.emoji]!.add(reaction);
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: groupedReactions.entries.map((entry) {
          final emoji = entry.key;
          final emojiReactions = entry.value;
          final count = emojiReactions.length;
          final hasReacted = emojiReactions.any((r) => r.userId == currentUserId);

          return _ReactionChip(
            emoji: emoji,
            count: count,
            hasReacted: hasReacted,
            onTap: () {
              if (onShowReactors != null) {
                onShowReactors!(emoji);
              }
            },
            onLongPress: () {
              if (onToggleReaction != null) {
                onToggleReaction!(emoji);
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool hasReacted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.hasReacted,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: hasReacted 
              ? const Color(0xFFE3F2FD) // Light blue for reacted
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: hasReacted
              ? Border.all(color: const Color(0xFF2196F3), width: 1)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            if (count > 1) ...[
              const SizedBox(width: 2),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: hasReacted 
                      ? const Color(0xFF2196F3) 
                      : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
