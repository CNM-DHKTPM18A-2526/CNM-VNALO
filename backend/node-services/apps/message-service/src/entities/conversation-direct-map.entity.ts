import { Entity, PrimaryColumn, Column, CreateDateColumn, Index } from 'typeorm';

/** Maps a pair of users to their direct (1:1) conversation. user_id_1 < user_id_2 enforced at service layer. */
@Entity('conversation_direct_map')
@Index('idx_direct_map_conv', ['conversationId'])
export class ConversationDirectMap {
  @PrimaryColumn({ name: 'user_id_1', type: 'uuid' })
  userId1: string;

  @PrimaryColumn({ name: 'user_id_2', type: 'uuid' })
  userId2: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
