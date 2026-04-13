// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class Messages extends Table with TableInfo<Messages, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Messages(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _clientMessageIdMeta = const VerificationMeta(
    'clientMessageId',
  );
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
    'client_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta('messageType');
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: "NOT NULL DEFAULT 'TEXT'",
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta('mediaUrl');
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _mediaThumbnailUrlMeta = const VerificationMeta('mediaThumbnailUrl');
  late final GeneratedColumn<String> mediaThumbnailUrl = GeneratedColumn<String>(
    'media_thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _mediaMimeTypeMeta = const VerificationMeta('mediaMimeType');
  late final GeneratedColumn<String> mediaMimeType = GeneratedColumn<String>(
    'media_mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _mediaSizeBytesMeta = const VerificationMeta('mediaSizeBytes');
  late final GeneratedColumn<int> mediaSizeBytes = GeneratedColumn<int>(
    'media_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta('replyToMessageId');
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _replyToSenderIdMeta = const VerificationMeta('replyToSenderId');
  late final GeneratedColumn<String> replyToSenderId = GeneratedColumn<String>(
    'reply_to_sender_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _replyToContentMeta = const VerificationMeta('replyToContent');
  late final GeneratedColumn<String> replyToContent = GeneratedColumn<String>(
    'reply_to_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: "NOT NULL DEFAULT 'SENT'",
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderId,
    clientMessageId,
    messageType,
    content,
    mediaUrl,
    mediaThumbnailUrl,
    mediaMimeType,
    mediaSizeBytes,
    replyToMessageId,
    replyToSenderId,
    replyToContent,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
        _clientMessageIdMeta,
        clientMessageId.isAcceptableOrUnknown(
          data['client_message_id']!,
          _clientMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    // Note: content is nullable, no 'missing' error needed
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      clientMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_message_id']),
      messageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_type'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content']),
      mediaUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_url']),
      mediaThumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_thumbnail_url']),
      mediaMimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_mime_type']),
      mediaSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_size_bytes']),
      replyToMessageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_message_id']),
      replyToSenderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_sender_id']),
      replyToContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_content']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  Messages createAlias(String alias) {
    return Messages(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String id;
  final String conversationId;
  final String senderId;
  final String? clientMessageId;
  final String messageType;
  final String? content;
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final String? mediaMimeType;
  final int? mediaSizeBytes;
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToContent;
  final String status;
  final DateTime createdAt;
  const LocalMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.clientMessageId,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaMimeType,
    this.mediaSizeBytes,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToContent,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    if (!nullToAbsent || clientMessageId != null) {
      map['client_message_id'] = Variable<String>(clientMessageId);
    }
    map['message_type'] = Variable<String>(messageType);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || mediaThumbnailUrl != null) {
      map['media_thumbnail_url'] = Variable<String>(mediaThumbnailUrl);
    }
    if (!nullToAbsent || mediaMimeType != null) {
      map['media_mime_type'] = Variable<String>(mediaMimeType);
    }
    if (!nullToAbsent || mediaSizeBytes != null) {
      map['media_size_bytes'] = Variable<int>(mediaSizeBytes);
    }
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || replyToSenderId != null) {
      map['reply_to_sender_id'] = Variable<String>(replyToSenderId);
    }
    if (!nullToAbsent || replyToContent != null) {
      map['reply_to_content'] = Variable<String>(replyToContent);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      clientMessageId: clientMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientMessageId),
      messageType: Value(messageType),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaThumbnailUrl: mediaThumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaThumbnailUrl),
      mediaMimeType: mediaMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaMimeType),
      mediaSizeBytes: mediaSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaSizeBytes),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      replyToSenderId: replyToSenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToSenderId),
      replyToContent: replyToContent == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToContent),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversation_id']),
      senderId: serializer.fromJson<String>(json['sender_id']),
      clientMessageId: serializer.fromJson<String?>(json['client_message_id']),
      messageType: serializer.fromJson<String>(json['message_type']),
      content: serializer.fromJson<String?>(json['content']),
      mediaUrl: serializer.fromJson<String?>(json['media_url']),
      mediaThumbnailUrl: serializer.fromJson<String?>(json['media_thumbnail_url']),
      mediaMimeType: serializer.fromJson<String?>(json['media_mime_type']),
      mediaSizeBytes: serializer.fromJson<int?>(json['media_size_bytes']),
      replyToMessageId: serializer.fromJson<String?>(json['reply_to_message_id']),
      replyToSenderId: serializer.fromJson<String?>(json['reply_to_sender_id']),
      replyToContent: serializer.fromJson<String?>(json['reply_to_content']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversation_id': serializer.toJson<String>(conversationId),
      'sender_id': serializer.toJson<String>(senderId),
      'client_message_id': serializer.toJson<String?>(clientMessageId),
      'message_type': serializer.toJson<String>(messageType),
      'content': serializer.toJson<String?>(content),
      'media_url': serializer.toJson<String?>(mediaUrl),
      'media_thumbnail_url': serializer.toJson<String?>(mediaThumbnailUrl),
      'media_mime_type': serializer.toJson<String?>(mediaMimeType),
      'media_size_bytes': serializer.toJson<int?>(mediaSizeBytes),
      'reply_to_message_id': serializer.toJson<String?>(replyToMessageId),
      'reply_to_sender_id': serializer.toJson<String?>(replyToSenderId),
      'reply_to_content': serializer.toJson<String?>(replyToContent),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    Value<String?> clientMessageId = const Value.absent(),
    String? messageType,
    Value<String?> content = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> mediaThumbnailUrl = const Value.absent(),
    Value<String?> mediaMimeType = const Value.absent(),
    Value<int?> mediaSizeBytes = const Value.absent(),
    Value<String?> replyToMessageId = const Value.absent(),
    Value<String?> replyToSenderId = const Value.absent(),
    Value<String?> replyToContent = const Value.absent(),
    String? status,
    DateTime? createdAt,
  }) =>
      LocalMessage(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        clientMessageId: clientMessageId.present
            ? clientMessageId.value
            : this.clientMessageId,
        messageType: messageType ?? this.messageType,
        content: content.present ? content.value : this.content,
        mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
        mediaThumbnailUrl: mediaThumbnailUrl.present
            ? mediaThumbnailUrl.value
            : this.mediaThumbnailUrl,
        mediaMimeType:
            mediaMimeType.present ? mediaMimeType.value : this.mediaMimeType,
        mediaSizeBytes:
            mediaSizeBytes.present ? mediaSizeBytes.value : this.mediaSizeBytes,
        replyToMessageId: replyToMessageId.present
            ? replyToMessageId.value
            : this.replyToMessageId,
        replyToSenderId: replyToSenderId.present
            ? replyToSenderId.value
            : this.replyToSenderId,
        replyToContent:
            replyToContent.present ? replyToContent.value : this.replyToContent,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalMessage copyWithCompanion(MessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      messageType:
          data.messageType.present ? data.messageType.value : this.messageType,
      content: data.content.present ? data.content.value : this.content,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaThumbnailUrl: data.mediaThumbnailUrl.present
          ? data.mediaThumbnailUrl.value
          : this.mediaThumbnailUrl,
      mediaMimeType:
          data.mediaMimeType.present ? data.mediaMimeType.value : this.mediaMimeType,
      mediaSizeBytes:
          data.mediaSizeBytes.present ? data.mediaSizeBytes.value : this.mediaSizeBytes,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      replyToSenderId: data.replyToSenderId.present
          ? data.replyToSenderId.value
          : this.replyToSenderId,
      replyToContent:
          data.replyToContent.present ? data.replyToContent.value : this.replyToContent,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conversationId,
      senderId,
      clientMessageId,
      messageType,
      content,
      mediaUrl,
      mediaThumbnailUrl,
      mediaMimeType,
      mediaSizeBytes,
      replyToMessageId,
      replyToSenderId,
      replyToContent,
      status,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.clientMessageId == this.clientMessageId &&
          other.messageType == this.messageType &&
          other.content == this.content &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaThumbnailUrl == this.mediaThumbnailUrl &&
          other.mediaMimeType == this.mediaMimeType &&
          other.mediaSizeBytes == this.mediaSizeBytes &&
          other.replyToMessageId == this.replyToMessageId &&
          other.replyToSenderId == this.replyToSenderId &&
          other.replyToContent == this.replyToContent &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String?> clientMessageId;
  final Value<String> messageType;
  final Value<String?> content;
  final Value<String?> mediaUrl;
  final Value<String?> mediaThumbnailUrl;
  final Value<String?> mediaMimeType;
  final Value<int?> mediaSizeBytes;
  final Value<String?> replyToMessageId;
  final Value<String?> replyToSenderId;
  final Value<String?> replyToContent;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaThumbnailUrl = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaSizeBytes = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToSenderId = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    this.clientMessageId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaThumbnailUrl = const Value.absent(),
    this.mediaMimeType = const Value.absent(),
    this.mediaSizeBytes = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToSenderId = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderId = Value(senderId),
       createdAt = Value(createdAt);
  static Insertable<LocalMessage> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? clientMessageId,
    Expression<String>? messageType,
    Expression<String>? content,
    Expression<String>? mediaUrl,
    Expression<Expression<String>>? mediaThumbnailUrl,
    Expression<String>? mediaMimeType,
    Expression<int>? mediaSizeBytes,
    Expression<String>? replyToMessageId,
    Expression<String>? replyToSenderId,
    Expression<String>? replyToContent,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (messageType != null) 'message_type': messageType,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaThumbnailUrl != null) 'media_thumbnail_url': mediaThumbnailUrl,
      if (mediaMimeType != null) 'media_mime_type': mediaMimeType,
      if (mediaSizeBytes != null) 'media_size_bytes': mediaSizeBytes,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (replyToSenderId != null) 'reply_to_sender_id': replyToSenderId,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderId,
    Value<String?>? clientMessageId,
    Value<String>? messageType,
    Value<String?>? content,
    Value<String?>? mediaUrl,
    Value<String?>? mediaThumbnailUrl,
    Value<String?>? mediaMimeType,
    Value<int?>? mediaSizeBytes,
    Value<String?>? replyToMessageId,
    Value<String?>? replyToSenderId,
    Value<String?>? replyToContent,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
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
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaThumbnailUrl.present) {
      map['media_thumbnail_url'] = Variable<String>(mediaThumbnailUrl.value);
    }
    if (mediaMimeType.present) {
      map['media_mime_type'] = Variable<String>(mediaMimeType.value);
    }
    if (mediaSizeBytes.present) {
      map['media_size_bytes'] = Variable<int>(mediaSizeBytes.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (replyToSenderId.present) {
      map['reply_to_sender_id'] = Variable<String>(replyToSenderId.value);
    }
    if (replyToContent.present) {
      map['reply_to_content'] = Variable<String>(replyToContent.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('messageType: $messageType, ')
          ..write('content: $content, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaThumbnailUrl: $mediaThumbnailUrl, ')
          ..write('mediaMimeType: $mediaMimeType, ')
          ..write('mediaSizeBytes: $mediaSizeBytes, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('replyToSenderId: $replyToSenderId, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Contacts extends Table with TableInfo<Contacts, LocalContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Contacts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [id, displayName, phone, avatarUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContact(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      displayName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}display_name'],
          )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
    );
  }

  @override
  Contacts createAlias(String alias) {
    return Contacts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalContact extends DataClass implements Insertable<LocalContact> {
  final String id;
  final String displayName;
  final String? phone;
  final String? avatarUrl;
  const LocalContact({
    required this.id,
    required this.displayName,
    this.phone,
    this.avatarUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      avatarUrl:
          avatarUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(avatarUrl),
    );
  }

  factory LocalContact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContact(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['display_name']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatarUrl: serializer.fromJson<String?>(json['avatar_url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'display_name': serializer.toJson<String>(displayName),
      'phone': serializer.toJson<String?>(phone),
      'avatar_url': serializer.toJson<String?>(avatarUrl),
    };
  }

  LocalContact copyWith({
    String? id,
    String? displayName,
    Value<String?> phone = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
  }) => LocalContact(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    phone: phone.present ? phone.value : this.phone,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
  );
  LocalContact copyWithCompanion(ContactsCompanion data) {
    return LocalContact(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContact(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, phone, avatarUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContact &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.phone == this.phone &&
          other.avatarUrl == this.avatarUrl);
}

class ContactsCompanion extends UpdateCompanion<LocalContact> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> phone;
  final Value<String?> avatarUrl;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String id,
    required String displayName,
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName);
  static Insertable<LocalContact> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? phone,
    Expression<String>? avatarUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String?>? phone,
    Value<String?>? avatarUrl,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Conversations extends Table
    with TableInfo<Conversations, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Conversations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    avatarUrl,
    lastMessage,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  Conversations createAlias(String alias) {
    return Conversations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final String id;
  final String? name;
  final String type;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime updatedAt;
  const LocalConversation({
    required this.id,
    this.name,
    required this.type,
    this.avatarUrl,
    this.lastMessage,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      type: Value(type),
      avatarUrl:
          avatarUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(avatarUrl),
      lastMessage:
          lastMessage == null && nullToAbsent
              ? const Value.absent()
              : Value(lastMessage),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      avatarUrl: serializer.fromJson<String?>(json['avatar_url']),
      lastMessage: serializer.fromJson<String?>(json['last_message']),
      updatedAt: serializer.fromJson<DateTime>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'type': serializer.toJson<String>(type),
      'avatar_url': serializer.toJson<String?>(avatarUrl),
      'last_message': serializer.toJson<String?>(lastMessage),
      'updated_at': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalConversation copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    String? type,
    Value<String?> avatarUrl = const Value.absent(),
    Value<String?> lastMessage = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalConversation(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    type: type ?? this.type,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalConversation copyWithCompanion(ConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, avatarUrl, lastMessage, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.avatarUrl == this.avatarUrl &&
          other.lastMessage == this.lastMessage &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String> type;
  final Value<String?> avatarUrl;
  final Value<String?> lastMessage;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required String type,
    this.avatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<LocalConversation> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? avatarUrl,
    Expression<String>? lastMessage,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (lastMessage != null) 'last_message': lastMessage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String>? type,
    Value<String?>? avatarUrl,
    Value<String?>? lastMessage,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final Messages messages = Messages(this);
  late final Contacts contacts = Contacts(this);
  late final Conversations conversations = Conversations(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    contacts,
    conversations,
  ];
}

typedef $MessagesCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String conversationId,
      required String senderId,
      Value<String?> clientMessageId,
      required String content,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $MessagesUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderId,
      Value<String?> clientMessageId,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $MessagesFilterComposer extends Composer<_$LocalDatabase, Messages> {
  $MessagesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $MessagesOrderingComposer extends Composer<_$LocalDatabase, Messages> {
  $MessagesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MessagesAnnotationComposer extends Composer<_$LocalDatabase, Messages> {
  $MessagesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $MessagesTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          Messages,
          LocalMessage,
          $MessagesFilterComposer,
          $MessagesOrderingComposer,
          $MessagesAnnotationComposer,
          $MessagesCreateCompanionBuilder,
          $MessagesUpdateCompanionBuilder,
          (
            LocalMessage,
            BaseReferences<_$LocalDatabase, Messages, LocalMessage>,
          ),
          LocalMessage,
          PrefetchHooks Function()
        > {
  $MessagesTableManager(_$LocalDatabase db, Messages table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $MessagesFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $MessagesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $MessagesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String?> clientMessageId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                clientMessageId: clientMessageId,
                content: content,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderId,
                Value<String?> clientMessageId = const Value.absent(),
                required String content,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderId: senderId,
                clientMessageId: clientMessageId,
                messageType: const Value.absent(), // Default for manager
                content: Value(content),
                status: const Value.absent(), // Default for manager
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MessagesProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      Messages,
      LocalMessage,
      $MessagesFilterComposer,
      $MessagesOrderingComposer,
      $MessagesAnnotationComposer,
      $MessagesCreateCompanionBuilder,
      $MessagesUpdateCompanionBuilder,
      (LocalMessage, BaseReferences<_$LocalDatabase, Messages, LocalMessage>),
      LocalMessage,
      PrefetchHooks Function()
    >;
typedef $ContactsCreateCompanionBuilder =
    ContactsCompanion Function({
      required String id,
      required String displayName,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<int> rowid,
    });
typedef $ContactsUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<int> rowid,
    });

class $ContactsFilterComposer extends Composer<_$LocalDatabase, Contacts> {
  $ContactsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $ContactsOrderingComposer extends Composer<_$LocalDatabase, Contacts> {
  $ContactsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ContactsAnnotationComposer extends Composer<_$LocalDatabase, Contacts> {
  $ContactsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);
}

class $ContactsTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          Contacts,
          LocalContact,
          $ContactsFilterComposer,
          $ContactsOrderingComposer,
          $ContactsAnnotationComposer,
          $ContactsCreateCompanionBuilder,
          $ContactsUpdateCompanionBuilder,
          (
            LocalContact,
            BaseReferences<_$LocalDatabase, Contacts, LocalContact>,
          ),
          LocalContact,
          PrefetchHooks Function()
        > {
  $ContactsTableManager(_$LocalDatabase db, Contacts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $ContactsFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $ContactsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $ContactsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                id: id,
                displayName: displayName,
                phone: phone,
                avatarUrl: avatarUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                id: id,
                displayName: displayName,
                phone: phone,
                avatarUrl: avatarUrl,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ContactsProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      Contacts,
      LocalContact,
      $ContactsFilterComposer,
      $ContactsOrderingComposer,
      $ContactsAnnotationComposer,
      $ContactsCreateCompanionBuilder,
      $ContactsUpdateCompanionBuilder,
      (LocalContact, BaseReferences<_$LocalDatabase, Contacts, LocalContact>),
      LocalContact,
      PrefetchHooks Function()
    >;
typedef $ConversationsCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      Value<String?> name,
      required String type,
      Value<String?> avatarUrl,
      Value<String?> lastMessage,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $ConversationsUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String?> name,
      Value<String> type,
      Value<String?> avatarUrl,
      Value<String?> lastMessage,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $ConversationsFilterComposer
    extends Composer<_$LocalDatabase, Conversations> {
  $ConversationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $ConversationsOrderingComposer
    extends Composer<_$LocalDatabase, Conversations> {
  $ConversationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ConversationsAnnotationComposer
    extends Composer<_$LocalDatabase, Conversations> {
  $ConversationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $ConversationsTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          Conversations,
          LocalConversation,
          $ConversationsFilterComposer,
          $ConversationsOrderingComposer,
          $ConversationsAnnotationComposer,
          $ConversationsCreateCompanionBuilder,
          $ConversationsUpdateCompanionBuilder,
          (
            LocalConversation,
            BaseReferences<_$LocalDatabase, Conversations, LocalConversation>,
          ),
          LocalConversation,
          PrefetchHooks Function()
        > {
  $ConversationsTableManager(_$LocalDatabase db, Conversations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $ConversationsFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $ConversationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $ConversationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                name: name,
                type: type,
                avatarUrl: avatarUrl,
                lastMessage: lastMessage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                required String type,
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                name: name,
                type: type,
                avatarUrl: avatarUrl,
                lastMessage: lastMessage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ConversationsProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      Conversations,
      LocalConversation,
      $ConversationsFilterComposer,
      $ConversationsOrderingComposer,
      $ConversationsAnnotationComposer,
      $ConversationsCreateCompanionBuilder,
      $ConversationsUpdateCompanionBuilder,
      (
        LocalConversation,
        BaseReferences<_$LocalDatabase, Conversations, LocalConversation>,
      ),
      LocalConversation,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $MessagesTableManager get messages =>
      $MessagesTableManager(_db, _db.messages);
  $ContactsTableManager get contacts =>
      $ContactsTableManager(_db, _db.contacts);
  $ConversationsTableManager get conversations =>
      $ConversationsTableManager(_db, _db.conversations);
}
