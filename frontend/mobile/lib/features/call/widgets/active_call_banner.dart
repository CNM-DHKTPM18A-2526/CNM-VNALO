import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/widgets/avatar_widget.dart';
import 'package:vnalo_mobile/core/widgets/group_avatar.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/call/services/group_call_tracker.dart';
import 'package:vnalo_mobile/features/call/screens/group_call_screen.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/main.dart';

class ActiveCallBanner extends StatelessWidget {
  final String conversationId;
  final String conversationName;
  final String? conversationAvatarUrl;

  const ActiveCallBanner({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.conversationAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupCallTracker, ChatProvider>(
      builder: (context, tracker, chatProvider, child) {
        final activeCall = tracker.activeCall;
        if (activeCall == null || activeCall.conversationId != conversationId) {
          return const SizedBox.shrink();
        }

        final convIndex = chatProvider.conversations.indexWhere(
          (c) => c.id == conversationId,
        );
        final members = convIndex == -1
            ? <_ParticipantInfo>[]
            : chatProvider.conversations[convIndex].members
                .where((m) =>
                    activeCall.participantUserIds.contains(m.userId) ||
                    m.userId == chatProvider.currentUserId)
                .map((m) => _ParticipantInfo(
                      userId: m.userId,
                      displayName:
                          m.nickname ?? m.user?.displayName ?? 'User',
                      avatarUrl: m.user?.avatarUrl,
                    ))
                .toList();

        final total = activeCall.participantUserIds.length + 1;
        final displayCount = total > 3 ? 3 : total;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => GroupCallScreen(
                      conversationId: activeCall.conversationId,
                      callId: activeCall.callId,
                      conversationName: activeCall.conversationName,
                      conversationAvatarUrl: activeCall.conversationAvatarUrl,
                      audioOnly: activeCall.audioOnly,
                      isCaller: activeCall.isCaller,
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (conversationAvatarUrl != null)
                      AvatarWidget(
                        imageUrl: conversationAvatarUrl,
                        name: conversationName,
                        size: 44,
                        borderWidth: 2,
                      )
                    else
                      GroupAvatar(
                        members: [
                          (name: conversationName,
                              imageUrl: conversationAvatarUrl),
                        ],
                        size: 44,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                activeCall.audioOnly
                                    ? 'Cuộc gọi thoại'
                                    : 'Cuộc gọi video',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              for (int i = 0; i < displayCount && i < members.length; i++)
                                Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  child: AvatarWidget(
                                    name: members[i].displayName,
                                    imageUrl: members[i].avatarUrl,
                                    size: 18,
                                    borderWidth: 1,
                                  ),
                                ),
                              if (total > 3)
                                Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${total - 3}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Text(
                                '$total người',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Tham gia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantInfo {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  _ParticipantInfo({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });
}
