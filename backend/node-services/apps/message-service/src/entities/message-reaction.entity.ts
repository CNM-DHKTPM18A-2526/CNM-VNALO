import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';

@Entity('message_reaction')
@Unique('unique_reaction', ['messageId', 'userId'])
@Index('idx_reaction_msg', ['messageId'])
@Index('idx_reaction_conv', ['conversationId', 'serverSeq'])
export class MessageReaction {
  @PrimaryGeneratedColumn('uuid', { name: 'reaction_id' })
  id: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @Column({ name: 'message_id', type: 'uuid' })
  messageId: string;

  @Column({ name: 'server_seq', type: 'bigint' })
  serverSeq: number;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'varchar', length: 20 })
  emoji: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
