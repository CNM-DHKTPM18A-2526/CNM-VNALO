import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { ConversationMember } from './conversation-member.entity';

export enum ConversationType {
  DIRECT = 'DIRECT',
  GROUP = 'GROUP',
}

export enum ConversationStatus {
  ACTIVE = 'ACTIVE',
  ARCHIVED = 'ARCHIVED',
  DISABLED = 'DISABLED',
}

export enum JoinMode {
  OPEN = 'OPEN',
  APPROVAL = 'APPROVAL',
  INVITE_ONLY = 'INVITE_ONLY',
}

@Entity('conversation')
@Index('idx_conv_type', ['type'])
@Index('idx_conv_invite_link', ['inviteLink'], {
  where: '"invite_link" IS NOT NULL',
})
export class Conversation {
  @PrimaryGeneratedColumn('uuid', { name: 'conversation_id' })
  id: string;

  @Column({ type: 'varchar', length: 20, enum: ConversationType })
  type: ConversationType;

  @Column({ type: 'varchar', length: 100, nullable: true })
  title: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', length: 500, nullable: true })
  avatarUrl: string | null;

  @Column({ name: 'wallpaper_url', type: 'varchar', nullable: true })
  wallpaperUrl: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  description: string | null;

  @Column({ name: 'created_by', type: 'uuid' })
  createdBy: string;

  @Column({
    type: 'varchar',
    length: 20,
    enum: ConversationStatus,
    default: ConversationStatus.ACTIVE,
  })
  status: ConversationStatus;

  @Column({
    name: 'join_mode',
    type: 'varchar',
    length: 20,
    enum: JoinMode,
    default: JoinMode.OPEN,
  })
  joinMode: JoinMode;

  @Column({ name: 'member_limit', type: 'int', default: 100 })
  memberLimit: number;

  @Column({
    name: 'invite_link',
    type: 'varchar',
    length: 100,
    nullable: true,
    unique: true,
  })
  inviteLink: string | null;

  @Column({
    name: 'invite_link_expires_at',
    type: 'timestamptz',
    nullable: true,
  })
  inviteLinkExpiresAt: Date | null;

  @Column({ name: 'is_encrypted', type: 'boolean', default: false })
  isEncrypted: boolean;

  @Column({ name: 'allow_member_invite', type: 'boolean', default: true })
  allowMemberInvite: boolean;

  @Column({ name: 'allow_member_pin', type: 'boolean', default: true })
  allowMemberPin: boolean;

  @Column({ name: 'allow_member_edit_info', type: 'boolean', default: true })
  allowMemberEditInfo: boolean;

  /** When true, only ADMIN and DEPUTY can send messages (announcement/broadcast mode). */
  @Column({ name: 'only_admin_can_post', type: 'boolean', default: false })
  onlyAdminCanPost: boolean;

  @Column({ name: 'highlight_admin_messages', type: 'boolean', default: true })
  highlightAdminMessages: boolean;

  @Column({ name: 'show_history_to_new_members', type: 'boolean', default: true })
  showHistoryToNewMembers: boolean;

  @Column({ name: 'allow_member_create_note', type: 'boolean', default: true })
  allowMemberCreateNote: boolean;

  @Column({ name: 'allow_member_create_poll', type: 'boolean', default: true })
  allowMemberCreatePoll: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  // Relations
  @OneToMany(
    () => ConversationMember,
    (m: ConversationMember) => m.conversation,
  )
  members: ConversationMember[];
}
