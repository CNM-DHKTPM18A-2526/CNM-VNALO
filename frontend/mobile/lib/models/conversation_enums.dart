enum ConversationType { DIRECT, GROUP }

enum ConversationStatus { ACTIVE, ARCHIVED, DISABLED }

enum JoinMode { OPEN, APPROVAL, INVITE_ONLY }

enum MemberRole { OWNER, ADMIN, MEMBER }

enum NotificationSetting { ALL, MENTIONS, NONE }

enum MessageType { TEXT, IMAGE, VIDEO, FILE, AUDIO, STICKER, SYSTEM, REPLY, FORWARD }

enum MessageStatus { SENT, DELIVERED, RECALLED }

T enumFromString<T>(List<T> values, String value) {
  return values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => values.first,
  );
}