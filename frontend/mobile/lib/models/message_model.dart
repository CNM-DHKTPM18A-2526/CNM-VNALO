import 'package:vnalo_mobile/models/conversation_enums.dart';

class Message {
  final String id;
  final String conversationId;
  final int? serverSeq;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? clientMessageId;
  final MessageType messageType; // TEXT, IMAGE, VIDEO, FILE, etc.
  final String? content;

  // Media fields
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final String? mediaMimeType;
  final int? mediaSizeBytes;

  // Reply fields
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToContent;

  // Forward fields
  final String? forwardFromMessageId;
  final String? forwardFromConversationId;

  final MessageStatus status; // SENT, DELIVERED, READ, FAILED
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    this.serverSeq,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.clientMessageId,
    this.messageType = MessageType.TEXT,
    this.content,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaMimeType,
    this.mediaSizeBytes,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToContent,
    this.forwardFromMessageId,
    this.forwardFromConversationId,
    this.status = MessageStatus.SENT,
    this.isEdited = false,
    this.editedAt,
    required this.createdAt,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;
  bool get isRecalled => status == MessageStatus.RECALLED;
  bool get isSystemMessage => messageType == MessageType.SYSTEM;
  bool get hasMedia => mediaUrl != null;
  bool get isReply => replyToMessageId != null;
  bool get isForward => forwardFromMessageId != null;

  // Factory constructor to create a Message instance from JSON
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] ?? json['_id'] ?? '',
    conversationId: json['conversationId'] ?? '',
    serverSeq: json['serverSeq'],
    senderId: json['senderId'] ?? '',
    senderName: json['senderName'],
    senderAvatarUrl: json['senderAvatarUrl'],
    clientMessageId: json['clientMessageId'],
    messageType: enumFromString(
      MessageType.values,
      json['messageType'] ?? 'TEXT',
    ),
    content: json['content'],
    mediaUrl: json['mediaUrl'],
    mediaThumbnailUrl: json['mediaThumbnailUrl'],
    mediaMimeType: json['mediaMimeType'],
    mediaSizeBytes: json['mediaSizeBytes'],
    replyToMessageId: json['replyToMessageId'],
    replyToSenderId: json['replyToSenderId'],
    replyToContent: json['replyToContent'],
    forwardFromMessageId: json['forwardFromMessageId'],
    forwardFromConversationId: json['forwardFromConversationId'],
    status: enumFromString(MessageStatus.values, json['status'] ?? 'SENT'),
    isEdited: json['isEdited'] ?? false,
    editedAt:
        json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
    createdAt:
        json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
  );
}
