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

  Message copyWith({
    String? id,
    String? conversationId,
    int? serverSeq,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? clientMessageId,
    MessageType? messageType,
    String? content,
    String? mediaUrl,
    String? mediaThumbnailUrl,
    String? mediaMimeType,
    int? mediaSizeBytes,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToContent,
    String? forwardFromMessageId,
    String? forwardFromConversationId,
    MessageStatus? status,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      serverSeq: serverSeq ?? this.serverSeq,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl ?? this.mediaThumbnailUrl,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToContent: replyToContent ?? this.replyToContent,
      forwardFromMessageId: forwardFromMessageId ?? this.forwardFromMessageId,
      forwardFromConversationId:
          forwardFromConversationId ?? this.forwardFromConversationId,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Factory constructor to create a Message instance from JSON
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] ?? json['_id'] ?? '',
    conversationId: json['conversationId'] ??
        json['conversation_id'] ??
        json['cid'] ??
        json['conversation']?['id'] ??
        '',
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
