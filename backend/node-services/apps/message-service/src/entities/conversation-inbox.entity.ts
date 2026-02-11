import { Entity, Column, PrimaryColumn, UpdateDateColumn, Index } from 'typeorm';

/** CQRS read model: denormalized inbox for fast conversation list queries. */
@Entity('conversation_inbox')
@Index('idx_inbox_user_sort', ['userId', 'isPinned', 'lastMessageSeq'])
@Index('idx_inbox_unread', ['userId', 'unreadCount'], { where: '"unread_count" > 0' })
export class ConversationInbox {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @PrimaryColumn({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @Column({ name: 'last_message_seq', type: 'bigint', default: 0 })
  lastMessageSeq: number;

  @Column({ name: 'last_message_at', type: 'timestamptz', nullable: true })
  lastMessageAt: Date | null;

  @Column({ name: 'last_message_preview', type: 'varchar', length: 200, nullable: true })
  lastMessagePreview: string | null;

  @Column({ name: 'last_message_sender_id', type: 'uuid', nullable: true })
  lastMessageSenderId: string | null;

  @Column({ name: 'last_message_type', type: 'varchar', length: 30, nullable: true })
  lastMessageType: string | null;

  @Column({ name: 'unread_count', type: 'int', default: 0 })
  unreadCount: number;

  @Column({ name: 'is_pinned', type: 'boolean', default: false })
  isPinned: boolean;

  @Column({ name: 'is_muted', type: 'boolean', default: false })
  isMuted: boolean;

  @Column({ name: 'is_hidden', type: 'boolean', default: false })
  isHidden: boolean;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
