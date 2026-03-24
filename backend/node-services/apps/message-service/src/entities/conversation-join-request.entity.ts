import { Entity, Column, CreateDateColumn, PrimaryColumn, Index } from 'typeorm';

@Entity('conversation_join_request')
@Index('idx_conv_join_request_conversation', ['conversationId'])
@Index('idx_conv_join_request_requested_by', ['requestedBy'])
export class ConversationJoinRequest {
  @PrimaryColumn({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'requested_by', type: 'uuid' })
  requestedBy: string;

  @CreateDateColumn({ name: 'requested_at', type: 'timestamptz' })
  requestedAt: Date;
}