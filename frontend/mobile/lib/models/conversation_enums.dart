enum ConversationType { DIRECT, GROUP }

enum ConversationStatus { ACTIVE, ARCHIVED, DISABLED }

enum JoinMode { OPEN, APPROVAL, INVITE_ONLY }

enum MemberRole { ADMIN, DEPUTY, MEMBER }

enum NotificationSetting { ALL, MENTIONS, NONE }

enum MessageType {
  TEXT,
  IMAGE,
  VIDEO,
  FILE,
  AUDIO,
  STICKER,
  SYSTEM,
  REPLY,
  FORWARD,
  POLL,
}

enum MessageStatus { SENDING, SENT, DELIVERED, READ, FAILED, RECALLED }

T enumFromString<T>(List<T> values, String value) {
  for (final v in values) {
    if (v.toString().split('.').last == value) {
      return v;
    }
  }
  return values.first;
}
