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

  ConversationMember copyWith({
    String? conversationId,
    String? userId,
    MemberRole? role,
    String? nickname,
    DateTime? joinedAt,
    String? joinedBy,
    DateTime? leftAt,
    String? removedBy,
    DateTime? muteUntil,
    bool? isPinned,
    int? pinOrder,
    bool? isHidden,
    int? lastReadSeq,
    DateTime? lastReadAt,
    NotificationSetting? notificationSetting,
    User? user,
  }) {
    return ConversationMember(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      nickname: nickname ?? this.nickname,
      joinedAt: joinedAt ?? this.joinedAt,
      joinedBy: joinedBy ?? this.joinedBy,
      leftAt: leftAt ?? this.leftAt,
      removedBy: removedBy ?? this.removedBy,
      muteUntil: muteUntil ?? this.muteUntil,
      isPinned: isPinned ?? this.isPinned,
      pinOrder: pinOrder ?? this.pinOrder,
      isHidden: isHidden ?? this.isHidden,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      notificationSetting: notificationSetting ?? this.notificationSetting,
      user: user ?? this.user,
    );
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory ConversationMember.fromJson(
    Map<String, dynamic> json,
  ) => ConversationMember(
    conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
    userId: json['userId'] ?? json['user_id'] ?? '',
    role: enumFromString(MemberRole.values, json['role'] ?? 'MEMBER'),
    nickname: json['nickname'],
    joinedAt:
        json['joinedAt'] != null || json['joined_at'] != null
            ? DateTime.parse(json['joinedAt'] ?? json['joined_at'])
            : DateTime.now(),
    joinedBy: json['joinedBy'] ?? json['joined_by'],
    leftAt: json['leftAt'] != null || json['left_at'] != null 
        ? DateTime.parse(json['leftAt'] ?? json['left_at']) : null,
    removedBy: json['removedBy'] ?? json['removed_by'],
    muteUntil:
        json['muteUntil'] != null || json['mute_until'] != null 
            ? DateTime.parse(json['muteUntil'] ?? json['mute_until']) : null,
    isPinned: json['isPinned'] ?? json['is_pinned'] ?? false,
    pinOrder: _toInt(json['pinOrder'] ?? json['pin_order'], 0),
    isHidden: json['isHidden'] ?? json['is_hidden'] ?? false,
    lastReadSeq: _toInt(json['lastReadSeq'] ?? json['last_read_seq'], 0),
    lastReadAt:
        json['lastReadAt'] != null || json['last_read_at'] != null 
            ? DateTime.parse(json['lastReadAt'] ?? json['last_read_at']) : null,
    notificationSetting: enumFromString(
      NotificationSetting.values,
      json['notificationSetting'] ?? json['notification_setting'] ?? 'ALL',
    ),
    user: json['user'] != null ? User.fromJson(json['user']) : null,
  );
}
