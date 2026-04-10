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
  final String? wallpaperUrl;
  final DateTime? historyClearedAt;

  // Fields for client-side use (not from server)
  final List<ConversationMember> members;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isHidden;
  final bool isFavorite;
  final int autoDeleteSeconds;
  final bool notifyCall;
  final String? personalWallpaperUrl;

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
    this.wallpaperUrl,
    this.historyClearedAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isHidden = false,
    this.isFavorite = false,
    this.autoDeleteSeconds = 0,
    this.notifyCall = true,
    this.personalWallpaperUrl,
  });

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? title,
    String? avatarUrl,
    String? description,
    String? createdBy,
    ConversationStatus? status,
    JoinMode? joinMode,
    int? memberLimit,
    String? inviteLink,
    DateTime? inviteLinkExpiresAt,
    bool? isEncrypted,
    bool? allowMemberInvite,
    bool? allowMemberPin,
    bool? allowMemberEditInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationMember>? members,
    Message? lastMessage,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isHidden,
    bool? isFavorite,
    int? autoDeleteSeconds,
    bool? notifyCall,
    String? personalWallpaperUrl,
    String? wallpaperUrl,
    DateTime? historyClearedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      joinMode: joinMode ?? this.joinMode,
      memberLimit: memberLimit ?? this.memberLimit,
      inviteLink: inviteLink ?? this.inviteLink,
      inviteLinkExpiresAt: inviteLinkExpiresAt ?? this.inviteLinkExpiresAt,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      allowMemberPin: allowMemberPin ?? this.allowMemberPin,
      allowMemberEditInfo: allowMemberEditInfo ?? this.allowMemberEditInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isHidden: isHidden ?? this.isHidden,
      isFavorite: isFavorite ?? this.isFavorite,
      autoDeleteSeconds: autoDeleteSeconds ?? this.autoDeleteSeconds,
      notifyCall: notifyCall ?? this.notifyCall,
      personalWallpaperUrl: personalWallpaperUrl ?? this.personalWallpaperUrl,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      historyClearedAt: historyClearedAt ?? this.historyClearedAt,
    );
  }

  // Method to get display name for the conversation based on its type and members
  String getDisplayName(String currentUserId, {int maxWidth = 0}) {
    if (type == ConversationType.DIRECT) {
      if (members.isEmpty) return title ?? 'Chat';
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

    if (members.isEmpty) return avatarUrl;

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

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

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
    joinMode: enumFromString(JoinMode.values, json['joinMode'] ?? 'OPEN'),
    memberLimit: _toInt(json['memberLimit'], 100),
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
    wallpaperUrl: json['wallpaperUrl'],
    historyClearedAt:
        json['historyClearedAt'] != null
            ? DateTime.parse(json['historyClearedAt'])
            : null,
    members:
        (json['members'] as List?)
            ?.map((m) => ConversationMember.fromJson(m))
            .toList() ??
        [],
    lastMessage:
        json['lastMessage'] != null
            ? Message.fromJson(json['lastMessage'])
            : null,
    unreadCount: _toInt(json['unreadCount']),
    isPinned: json['isPinned'] ?? json['is_pinned'] ?? false,
    isMuted: json['isMuted'] ?? json['is_muted'] ?? false,
    isHidden: json['isHidden'] ?? json['is_hidden'] ?? false,
    isFavorite: json['isFavorite'] ?? json['is_favorite'] ?? false,
    autoDeleteSeconds: _toInt(json['autoDeleteSeconds'] ?? json['auto_delete_seconds']),
    notifyCall: json['notifyCall'] ?? json['notify_call'] ?? true,
    personalWallpaperUrl: json['personalWallpaperUrl'] ?? json['personal_wallpaper_url'],
  );
}
