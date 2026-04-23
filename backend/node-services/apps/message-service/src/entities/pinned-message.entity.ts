import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Message } from './message.entity';

@Entity('pinned_message')
@Unique('unique_pin', ['conversationId', 'messageId'])
@Index('idx_pin_conv', ['conversationId', 'pinnedAt'])
export class PinnedMessage {
  @PrimaryGeneratedColumn('uuid', { name: 'pin_id' })
  id: string;

  @Column({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @Column({ name: 'message_id', type: 'uuid' })
  messageId: string;

  @ManyToOne(() => Message)
  @JoinColumn({ name: 'message_id' })
  message: Message;

  @Column({ name: 'server_seq', type: 'bigint' })
  serverSeq: number;

  @Column({ name: 'pinned_by', type: 'uuid' })
  pinnedBy: string;

  @CreateDateColumn({ name: 'pinned_at', type: 'timestamptz' })
  pinnedAt: Date;
}
