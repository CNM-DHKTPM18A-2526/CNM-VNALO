import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index,
  Unique,
} from 'typeorm';

export enum MessageType {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
  VIDEO = 'VIDEO',
  FILE = 'FILE',
  AUDIO = 'AUDIO',
  STICKER = 'STICKER',
  SYSTEM = 'SYSTEM',       // join/leave/rename events
  REPLY = 'REPLY',
  FORWARD = 'FORWARD',
}

export enum MessageStatus {
  SENT = 'SENT',
  DELIVERED = 'DELIVERED',
  RECALLED = 'RECALLED',   // soft-deleted by sender
}

@Entity('message')
@Unique('uq_msg_conv_seq', ['conversationId', 'serverSeq'])
@Unique('uq_msg_sender_client_id', ['senderId', 'clientMessageId'])
@Index('idx_msg_conv_seq', ['conversationId', 'serverSeq'])
@Index('idx_msg_sender', ['senderId', 'createdAt'])
export class Message {
  @PrimaryGeneratedColumn('uuid', { name: 'message_id' })
  id: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  /** Monotonically increasing per conversation, generated via Redis INCR */
  @Column({ name: 'server_seq', type: 'bigint' })
  serverSeq: number;

  @Column({ name: 'sender_id', type: 'uuid' })
  senderId: string;

  /** Client-generated UUID for idempotency */
  @Column({ name: 'client_message_id', type: 'uuid', nullable: true })
  clientMessageId: string | null;

  @Column({ name: 'message_type', type: 'varchar', length: 20, enum: MessageType, default: MessageType.TEXT })
  messageType: MessageType;

  @Column({ type: 'text', nullable: true })
  content: string | null;

  // Media fields (denormalized for fast access)
  @Column({ name: 'media_url', type: 'varchar', length: 500, nullable: true })
  mediaUrl: string | null;

  @Column({ name: 'media_thumbnail_url', type: 'varchar', length: 500, nullable: true })
  mediaThumbnailUrl: string | null;

  @Column({ name: 'media_mime_type', type: 'varchar', length: 100, nullable: true })
  mediaMimeType: string | null;

  @Column({ name: 'media_size_bytes', type: 'bigint', nullable: true })
  mediaSizeBytes: number | null;

  @Column('uuid', { name: 'hidden_by_users', array: true, default: () => "'{}'" })
  hiddenByUsers: string[];

  // Reply fields
  @Column({ name: 'reply_to_message_id', type: 'uuid', nullable: true })
  replyToMessageId: string | null;

  @Column({ name: 'reply_to_sender_id', type: 'uuid', nullable: true })
  replyToSenderId: string | null;

  @Column({ name: 'reply_to_content', type: 'varchar', length: 200, nullable: true })
  replyToContent: string | null;

  // Forward fields
  @Column({ name: 'forward_from_message_id', type: 'uuid', nullable: true })
  forwardFromMessageId: string | null;

  @Column({ name: 'forward_from_conversation_id', type: 'uuid', nullable: true })
  forwardFromConversationId: string | null;

  @Column({ type: 'varchar', length: 20, enum: MessageStatus, default: MessageStatus.SENT })
  status: MessageStatus;

  @Column({ name: 'is_edited', type: 'boolean', default: false })
  isEdited: boolean;

  @Column({ name: 'edited_at', type: 'timestamptz', nullable: true })
  editedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
