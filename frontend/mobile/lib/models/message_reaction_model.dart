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
        id: json['id'],
        conversationId: json['conversationId'],
        messageId: json['messageId'],
        serverSeq: json['serverSeq'],
        userId: json['userId'],
        emoji: json['emoji'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
