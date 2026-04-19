class MessageReaction {
  final String id;
  final String conversationId;
  final String messageId;
  final int serverSeq;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.serverSeq,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        id: json['id'] ?? json['reaction_id'] ?? '',
        conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
        messageId: json['messageId'] ?? json['message_id'] ?? '',
        serverSeq: json['serverSeq'] != null || json['server_seq'] != null
            ? int.tryParse(json['serverSeq']?.toString() ?? json['server_seq']?.toString() ?? '0') ?? 0
            : 0,
        userId: json['userId'] ?? json['user_id'] ?? '',
        emoji: json['emoji'] ?? '',
        createdAt: json['createdAt'] != null || json['created_at'] != null
            ? DateTime.parse(json['createdAt'] ?? json['created_at'])
            : DateTime.now(),
      );
}

// Predefined emojis for reactions
class ReactionEmojis {
  static const List<String> emojis = [
    '❤️', // Heart
    '👍', // Thumbs up
    '😂', // Laughing
    '😮', // Surprised
    '😢', // Crying
    '😡', // Angry
  ];
}
