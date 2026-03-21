class PinnedMessage {
  final String id;
  final String conversationId;
  final String messageId;
  final int serverSeq;
  final String pinnedBy;
  final DateTime pinnedAt;

  PinnedMessage({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.serverSeq,
    required this.pinnedBy,
    required this.pinnedAt,
  });

  factory PinnedMessage.fromJson(Map<String, dynamic> json) => PinnedMessage(
    id: json['id'],
    conversationId: json['conversationId'],
    messageId: json['messageId'],
    serverSeq: json['serverSeq'],
    pinnedBy: json['pinnedBy'],
    pinnedAt: DateTime.parse(json['pinnedAt']),
  );
}