import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/poll_details_screen.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/user_model.dart';

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
    final chatProvider = context.watch<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;

    // Parse JSON Poll data
    Map<String, dynamic>? pollData;
    try {
      final contentStr = message.content ?? '';
      if (contentStr.trim().startsWith('{')) {
        pollData = jsonDecode(contentStr) as Map<String, dynamic>;
      }
    } catch (_) {
      pollData = null;
    }

    if (pollData == null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
          ),
        ),
      );
    }

    final question = pollData['question']?.toString() ?? 'Bình chọn';
    final rawOptions = pollData['options'] as List<dynamic>? ?? [];

    // Map index -> option id to support both formats:
    // - vote:0 / vote:1 (index-based, used by web)
    // - vote:<optionId> (id-based)
    final Map<String, String> indexToOptionId = {
      for (int i = 0; i < rawOptions.length; i++)
        i.toString(): (rawOptions[i] is Map
            ? ((rawOptions[i] as Map)['id']?.toString() ?? i.toString())
            : i.toString()),
    };

    // Debug: help verify mapping between poll option ids and reaction vote ids
    debugPrint(
      '[PollWidget] poll msg=${message.id} options=${rawOptions.map((e) => (e is Map ? (e['id']?.toString() ?? '') : '')).toList()} indexMap=$indexToOptionId',
    );
    
    // Parse live votes from reactions
    final reactions = chatProvider.getReactionsForMessage(message.id);

    // optionId -> userIds
    final Map<String, List<String>> optionVotes = {};

    void addVote(String optionKey, String userId) {
      // If the optionKey directly matches an actual option ID, use it.
      // Otherwise, assume it's an index (sent by Web for "o0", "o1" format) and map it.
      final isDirectId = rawOptions.any((opt) => opt is Map && opt['id']?.toString() == optionKey);
      final resolvedId = isDirectId ? optionKey : (indexToOptionId[optionKey] ?? optionKey);
      optionVotes.putIfAbsent(resolvedId, () => []).add(userId);
    }

    for (final reaction in reactions) {
      final emoji = reaction.emoji;
      if (emoji.startsWith('vote:') || emoji.startsWith('v:')) {
        final prefixLen = emoji.startsWith('vote:') ? 5 : 2;
        final optionIds = emoji.substring(prefixLen).split(',');
        for (final optId in optionIds) {
          final trimmed = optId.trim();
          if (trimmed.isNotEmpty) {
            addVote(trimmed, reaction.userId);
          }
        }
      }
    }

    final allVoters = optionVotes.values.expand((userIds) => userIds).toSet();
    final totalVotersCount = allVoters.length;
    final hasVotedAny = allVoters.contains(currentUserId);

    final conv = chatProvider.conversations.firstWhere(
      (c) => c.id == message.conversationId,
      orElse: () => chatProvider.conversations.first,
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? DarkColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header info
          GestureDetector(
            onTap: () => _openPollDetails(context, conv),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_outlined,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bình chọn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$totalVotersCount người bình chọn',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.unfold_more_outlined,
                      size: 14,
                      color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Question text
          Text(
            question,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Options items
          ...List.generate(rawOptions.length, (index) {
            final opt = rawOptions[index] as Map<String, dynamic>;
            final optId = opt['id']?.toString() ?? index.toString();
            final label = opt['label']?.toString() ?? '';
            final voters = optionVotes[optId] ?? [];
            final voteCount = voters.length;
            final isSelected = voters.contains(currentUserId);
            final ratio = totalVotersCount > 0 ? voteCount / totalVotersCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _openPollDetails(context, conv),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : (isDarkMode ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF4F5F7)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Progress bar background
                            if (voteCount > 0)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: constraints.maxWidth * ratio,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? AppColors.primary.withValues(alpha: 0.15) 
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                ),
                              ),
                            // Option text and voter avatars
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Voter avatars overlapping
                                  if (voters.isNotEmpty) ...[
                                    _buildOverlappingAvatars(voters, conv),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$voteCount',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Bottom button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () => _openPollDetails(context, conv),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDarkMode ? Colors.white12 : const Color(0xFFE5E9F0),
                ),
                backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF7F8FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                hasVotedAny ? 'ĐỔI BÌNH CHỌN' : 'BÌNH CHỌN',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPollDetails(BuildContext context, dynamic conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PollDetailsScreen(
          conversation: conv,
          message: message,
        ),
      ),
    );
  }

  Widget _buildOverlappingAvatars(List<String> userIds, dynamic conv) {
    final displayedIds = userIds.take(3).toList();
    const double avatarSize = 18.0;
    const double overlap = 12.0;

    final members = (conv.members is List)
        ? (conv.members as List).whereType<ConversationMember>().toList()
        : <ConversationMember>[];

    return SizedBox(
      height: avatarSize,
      width: ((displayedIds.length - 1) * overlap + avatarSize).clamp(avatarSize, 80.0),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: List.generate(displayedIds.length, (i) {
          final userId = displayedIds[i];

          final member = members.where((m) => m.userId == userId).isNotEmpty
              ? members.firstWhere((m) => m.userId == userId)
              : null;

          final User? user = member?.user;
          final String? avatarUrl = user?.avatarUrl;
          final String displayName =
              (member?.nickname?.trim().isNotEmpty == true)
                  ? member!.nickname!
                  : (user?.displayName?.trim().isNotEmpty == true)
                      ? user!.displayName!
                      : 'U';

          return Positioned(
            left: i * overlap,
            top: 0,
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: ClipOval(
                child: AvatarWidget(
                  imageUrl: avatarUrl,
                  name: displayName,
                  size: avatarSize,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
