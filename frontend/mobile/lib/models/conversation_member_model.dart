import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/user_model.dart';

class ConversationMember {
  final String conversationId;
  final String userId;
  final MemberRole role; // OWNER, ADMIN, MEMBER
  final String? nickname;
  final DateTime joinedAt;
  final String? joinedBy;
  final DateTime? leftAt;
  final String? removedBy;
  final DateTime? muteUntil;
  final bool isPinned;
  final int? pinOrder;
  final bool isHidden;
  final int lastReadSeq;
  final DateTime? lastReadAt;
  final NotificationSetting notificationSetting;

  // Demo purpose only, not stored in backend
  final User? user;

  ConversationMember({
    required this.conversationId,
    required this.userId,
    this.role = MemberRole.MEMBER,
    this.nickname,
    required this.joinedAt,
    this.joinedBy,
    this.leftAt,
    this.removedBy,
    this.muteUntil,
    this.isPinned = false,
    this.pinOrder,
    this.isHidden = false,
    this.lastReadSeq = 0,
    this.lastReadAt,
    this.notificationSetting = NotificationSetting.ALL,
    this.user,
  });

  bool get isActive => leftAt == null;
  bool get isOwner => role == MemberRole.OWNER;
  bool get isAdmin => role == MemberRole.ADMIN || role == MemberRole.OWNER;

  factory ConversationMember.fromJson(
    Map<String, dynamic> json,
  ) => ConversationMember(
    conversationId: json['conversationId'] ?? '',
    userId: json['userId'] ?? '',
    role: enumFromString(MemberRole.values, json['role'] ?? 'MEMBER'),
    nickname: json['nickname'],
    joinedAt:
        json['joinedAt'] != null
            ? DateTime.parse(json['joinedAt'])
            : DateTime.now(),
    joinedBy: json['joinedBy'],
    leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
    removedBy: json['removedBy'],
    muteUntil:
        json['muteUntil'] != null ? DateTime.parse(json['muteUntil']) : null,
    isPinned: json['isPinned'] ?? false,
    pinOrder: json['pinOrder'],
    isHidden: json['isHidden'] ?? false,
    lastReadSeq: json['lastReadSeq'] ?? 0,
    lastReadAt:
        json['lastReadAt'] != null ? DateTime.parse(json['lastReadAt']) : null,
    notificationSetting: enumFromString(
      NotificationSetting.values,
      json['notificationSetting'] ?? 'ALL',
    ),
    user: json['user'] != null ? User.fromJson(json['user']) : null,
  );
}
