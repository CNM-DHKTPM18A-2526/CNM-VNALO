import {
  Entity,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  PrimaryColumn,
  Index,
} from 'typeorm';
import { Conversation } from './conversation.entity';

export enum MemberRole {
  /** Trưởng nhóm — exactly 1 per group. Previously called OWNER (D-011). */
  ADMIN = 'ADMIN',
  /** Phó nhóm — 0..N per group. Previously called ADMIN (D-011). */
  DEPUTY = 'DEPUTY',
  MEMBER = 'MEMBER',
}

export enum NotificationSetting {
  ALL = 'ALL',
  MENTIONS = 'MENTIONS',
  NONE = 'NONE',
}

@Entity('conversation_member')
@Index('idx_conv_member_user', ['userId', 'isPinned'], {
  where: '"left_at" IS NULL',
})
@Index('idx_conv_member_conv', ['conversationId'], {
  where: '"left_at" IS NULL',
})
export class ConversationMember {
  @PrimaryColumn({ name: 'conversation_id', type: 'uuid' })
  conversationId: string;

  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({
    type: 'varchar',
    length: 20,
    enum: MemberRole,
    default: MemberRole.MEMBER,
  })
  role: MemberRole;

  @Column({ type: 'varchar', length: 50, nullable: true })
  nickname: string | null;

  @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
  joinedAt: Date;

  @Column({ name: 'joined_by', type: 'uuid', nullable: true })
  joinedBy: string | null;

  @Column({ name: 'left_at', type: 'timestamptz', nullable: true })
  leftAt: Date | null;

  @Column({ name: 'removed_by', type: 'uuid', nullable: true })
  removedBy: string | null;

  @Column({ name: 'mute_until', type: 'timestamptz', nullable: true })
  muteUntil: Date | null;

  @Column({ name: 'is_pinned', type: 'boolean', default: false })
  isPinned: boolean;

  @Column({ name: 'pin_order', type: 'int', nullable: true })
  pinOrder: number | null;

  @Column({ name: 'is_hidden', type: 'boolean', default: false })
  isHidden: boolean;

  @Column({ name: 'last_read_seq', type: 'bigint', default: 0 })
  lastReadSeq: number;

  @Column({ name: 'last_read_at', type: 'timestamptz', nullable: true })
  lastReadAt: Date | null;

  @Column({
    name: 'notification_setting',
    type: 'varchar',
    length: 20,
    enum: NotificationSetting,
    default: NotificationSetting.ALL,
  })
  notificationSetting: NotificationSetting;

  // Relations
  @ManyToOne(() => Conversation, (c) => c.members, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conversation_id' })
  conversation: Conversation;
}
