import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/message_model.dart';

class Conversation {
  final String id;
  final ConversationType type; // DIRECT, GROUP
  final String? title;
  final String? avatarUrl;
  final String? description;
  final String? createdBy;
  final ConversationStatus status; // ACTIVE, ARCHIVED, DISABLED
  final JoinMode joinMode;
  final int memberLimit;
  final String? inviteLink;
  final DateTime? inviteLinkExpiresAt;
  final bool isEncrypted;
  final bool allowMemberInvite;
  final bool allowMemberPin;
  final bool allowMemberEditInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Fields for client-side use (not from server)
  final List<ConversationMember> members;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isHidden;

  Conversation({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    this.description,
    this.createdBy,
    this.status = ConversationStatus.ACTIVE,
    this.joinMode = JoinMode.OPEN,
    this.memberLimit = 100,
    this.inviteLink,
    this.inviteLinkExpiresAt,
    this.isEncrypted = false,
    this.allowMemberInvite = true,
    this.allowMemberPin = false,
    this.allowMemberEditInfo = false,
    this.createdAt,
    this.updatedAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isHidden = false,
  });

  // Method to get display name for the conversation based on its type and members
  String getDisplayName(String currentUserId, {int maxWidth = 0}) {
    if (type == ConversationType.DIRECT) {
      final other = members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => members.first,
      );

      // For direct conversations, use the other user's nickname or display name
      return other.nickname ?? other.user?.displayName ?? 'User';
    }

    // For group conversations, use the conversation title if available
    if (title != null && title!.isNotEmpty) {
      return title!;
    }

    // If no title, concatenate the display names of members (excluding current user)
    final names =
        members
            .where((m) => m.userId != currentUserId && m.leftAt == null)
            .map((m) => m.user?.displayName ?? 'User')
            .toList();

    // If there are no other members, return a default name
    if (names.isEmpty) return 'Nhóm';

    // If there are 3 or fewer members, show all their names
    if (names.length <= 3) return names.join(', ');

    // If there are more than 3 members, show the first 3 and indicate there are more
    return '${names.take(3).join(', ')}...';
  }

  // Method to get the avatar URL for the conversation based on its type and members
  String? getDisplayAvatarUrl(String currentUserId) {
    // For group conversations, use the conversation avatar
    if (type == ConversationType.GROUP) return avatarUrl;

    // For direct conversations, use the other user's avatar
    final other = members.firstWhere(
      (m) => m.userId != currentUserId,
      orElse: () => members.first,
    );

    // If the other user has an avatar, return it; otherwise, return null
    return other.user?.avatarUrl;
  }

  // Method to get the count of active members (those who haven't left)
  int get activeMemberCount => members.where((m) => m.leftAt == null).length;

  // Factory constructor to create a Conversation instance from JSON data
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'],
    type: enumFromString(ConversationType.values, json['type'] ?? 'DIRECT'),
    title: json['title'] ?? json['name'],
    avatarUrl: json['avatarUrl'],
    description: json['description'],
    createdBy: json['createdBy'],
    status: enumFromString(
      ConversationStatus.values,
      json['status'] ?? 'ACTIVE',
    ),
    joinMode: enumFromString(
      JoinMode.values,
      json['joinMode'] ?? 'OPEN',
    ),
    memberLimit: json['memberLimit'] ?? 100,
    inviteLink: json['inviteLink'],
    inviteLinkExpiresAt:
        json['inviteLinkExpiresAt'] != null
            ? DateTime.parse(json['inviteLinkExpiresAt'])
            : null,
    isEncrypted: json['isEncrypted'] ?? false,
    allowMemberInvite: json['allowMemberInvite'] ?? true,
    allowMemberPin: json['allowMemberPin'] ?? false,
    allowMemberEditInfo: json['allowMemberEditInfo'] ?? false,
    createdAt:
        json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt:
        json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    members:
        (json['members'] as List?)
            ?.map((m) => ConversationMember.fromJson(m))
            .toList() ??
        [],
    lastMessage:
        json['lastMessage'] != null
            ? Message.fromJson(json['lastMessage'])
            : null,
    unreadCount: json['unreadCount'] ?? 0,
    isPinned: json['isPinned'] ?? false,
    isMuted: json['isMuted'] ?? false,
    isHidden: json['isHidden'] ?? false,
  );
}
