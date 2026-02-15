import { Entity, Column, PrimaryColumn, Index } from 'typeorm';

@Entity('message_receipt')
@Index('idx_receipt_user', ['userId', 'seenAt'])
export class MessageReceipt {
  @PrimaryColumn({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @PrimaryColumn({ name: 'message_id', type: 'uuid' })
  messageId: string;

  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'server_seq', type: 'bigint' })
  serverSeq: number;

  @Column({ name: 'delivered_at', type: 'timestamptz', nullable: true })
  deliveredAt: Date | null;

  @Column({ name: 'seen_at', type: 'timestamptz', nullable: true })
  seenAt: Date | null;
}
