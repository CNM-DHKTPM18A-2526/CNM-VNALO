import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, IsNull } from 'typeorm';
import {
  Conversation,
  ConversationType,
  ConversationStatus,
  JoinMode,
} from '../entities/conversation.entity';
import {
  ConversationMember,
  MemberRole,
} from '../entities/conversation-member.entity';
import { ConversationDirectMap } from '../entities/conversation-direct-map.entity';
import { ConversationJoinRequest } from '../entities/conversation-join-request.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { UpdateConversationDto } from '../dto/update-conversation.dto';

@Injectable()
export class ConversationService {
  private readonly logger = new Logger(ConversationService.name);

  constructor(
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(ConversationDirectMap)
    private readonly directMapRepo: Repository<ConversationDirectMap>,
    @InjectRepository(ConversationJoinRequest)
    private readonly joinRequestRepo: Repository<ConversationJoinRequest>,
    @InjectRepository(ConversationInbox)
    private readonly inboxRepo: Repository<ConversationInbox>,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * Create or retrieve a direct (1:1) conversation.
   * Uses conversation_direct_map for O(1) lookup, ordering user IDs to avoid duplicates.
   */
  async createDirect(userId: string, targetUserId: string) {
    if (userId === targetUserId) {
      throw new BadRequestException('Cannot create conversation with yourself');
    }

    // Enforce ordering: userId1 < userId2
    const [uid1, uid2] =
      userId < targetUserId ? [userId, targetUserId] : [targetUserId, userId];

    // Check if direct conversation already exists
    const existing = await this.directMapRepo.findOne({
      where: { userId1: uid1, userId2: uid2 },
    });

    if (existing) {
      return this.getConversation(existing.conversationId, userId);
    }

    // Create within a transaction
    const conversationId = await this.dataSource.transaction(
      async (manager) => {
        const conversation = manager.create(Conversation, {
          type: ConversationType.DIRECT,
          createdBy: userId,
          status: ConversationStatus.ACTIVE,
        });
        const saved = await manager.save(conversation);

        // Add both users as members
        await manager.save(ConversationMember, [
          { conversationId: saved.id, userId, role: MemberRole.MEMBER },
          {
            conversationId: saved.id,
            userId: targetUserId,
            role: MemberRole.MEMBER,
          },
        ]);

        // Create direct map for fast lookup
        await manager.save(ConversationDirectMap, {
          userId1: uid1,
          userId2: uid2,
          conversationId: saved.id,
        });

        // Create inbox entries for both users so the conversation appears in messages tab
        await manager.save(ConversationInbox, [
          {
            userId,
            conversationId: saved.id,
            lastMessageSeq: 0,
            unreadCount: 0,
            isPinned: false,
            isMuted: false,
            isHidden: false,
          },
          {
            userId: targetUserId,
            conversationId: saved.id,
            lastMessageSeq: 0,
            unreadCount: 0,
            isPinned: false,
            isMuted: false,
            isHidden: false,
          },
        ]);

        this.logger.log(
          `Direct conversation created: ${saved.id} between ${uid1} and ${uid2}`,
        );
        return saved.id;
      },
    );

    return this.getConversation(conversationId, userId);
  }

  /** Create a group conversation with initial members. Creator becomes OWNER. */
  async createGroup(userId: string, dto: CreateGroupConversationDto) {
    const conversationId = await this.dataSource.transaction(
      async (manager) => {
        const conversation = manager.create(Conversation, {
          type: ConversationType.GROUP,
          title: dto.title,
          description: dto.description ?? null,
          avatarUrl: dto.avatarUrl ?? null,
          joinMode: dto.joinMode,
          createdBy: userId,
          status: ConversationStatus.ACTIVE,
        });
        const saved = await manager.save(conversation);

        // Creator is always ADMIN (group owner — D-011 rename from OWNER)
        const members: Partial<ConversationMember>[] = [
          { conversationId: saved.id, userId, role: MemberRole.ADMIN },
        ];

        const uniqueInitialMembers = [...new Set(dto.memberIds)].filter(
          (memberId) => memberId !== userId,
        );
        const effectiveMemberLimit = saved.memberLimit ?? 100;
        if (uniqueInitialMembers.length + 1 > effectiveMemberLimit) {
          throw new BadRequestException(
            `Cannot exceed member limit of ${effectiveMemberLimit}. Initial members: ${uniqueInitialMembers.length + 1}`,
          );
        }

        // Add initial members
        for (const memberId of uniqueInitialMembers) {
          members.push({
            conversationId: saved.id,
            userId: memberId,
            role: MemberRole.MEMBER,
            joinedBy: userId,
          });
        }

        await manager.save(ConversationMember, members);
        this.logger.log(
          `Group created: ${saved.id} "${dto.title}" with ${members.length} members`,
        );

        return saved.id;
      },
    );

    return this.getConversation(conversationId, userId);
  }

  /** Get conversation with active member list. Verifies user has access. */
  async getConversation(conversationId: string, userId: string) {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');

    // Verify user is a member
    await this.assertMember(conversationId, userId);

    const members = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
    });

    return { ...conversation, members };
  }

  /** Update group conversation settings. ADMIN/DEPUTY always allowed. MEMBER allowed if allowMemberEditInfo is true. */
  async updateGroup(
    conversationId: string,
    userId: string,
    dto: UpdateConversationDto,
  ) {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only update group conversations');
    }

    // Check permissions: ADMIN/DEPUTY always allowed, MEMBER only if allowMemberEditInfo is true
    const member = await this.assertMember(conversationId, userId);
    if (member.role === MemberRole.MEMBER && !conversation.allowMemberEditInfo) {
      throw new ForbiddenException(
        'You do not have permission to edit group settings',
      );
    }

    Object.assign(conversation, dto);
    return this.conversationRepo.save(conversation);
  }

  /** Add members to a group. Requires ADMIN/OWNER or allowed member invite. */
  async addMembers(
    conversationId: string,
    userId: string,
    memberIds: string[],
  ) {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException(
        'Can only add members to group conversations',
      );
    }

    const membership = await this.assertMember(conversationId, userId);

    // Only admin/owner or if allowMemberInvite is enabled
    if (
      membership.role === MemberRole.MEMBER &&
      !conversation.allowMemberInvite
    ) {
      throw new ForbiddenException('You do not have permission to add members');
    }

    if (
      conversation.joinMode === JoinMode.INVITE_ONLY &&
      membership.role === MemberRole.MEMBER
    ) {
      throw new ForbiddenException(
        'Only admin or owner can add members in invite-only groups',
      );
    }

    const newMembers: Partial<ConversationMember>[] = [];
    const pendingApprovals: string[] = [];
    for (const memberId of memberIds) {
      if (memberId === userId) {
        continue;
      }

      // Skip if already a member
      const exists = await this.memberRepo.findOne({
        where: { conversationId, userId: memberId, leftAt: IsNull() },
      });

      if (exists) {
        continue;
      }

      if (
        conversation.joinMode === JoinMode.APPROVAL &&
        membership.role === MemberRole.MEMBER
      ) {
        await this.joinRequestRepo
          .createQueryBuilder()
          .insert()
          .values({ conversationId, userId: memberId, requestedBy: userId })
          .orIgnore()
          .execute();
        pendingApprovals.push(memberId);
      } else {
        newMembers.push({
          conversationId,
          userId: memberId,
          role: MemberRole.MEMBER,
          joinedBy: userId,
          leftAt: null,
          removedBy: null,
          joinedAt: new Date(),
        });
      }
    }

    if (newMembers.length > 0) {
      await this.ensureUnderMemberLimit(
        conversationId,
        conversation.memberLimit,
        newMembers.length,
      );
      await this.memberRepo.save(newMembers);
      this.logger.log(
        `Added ${newMembers.length} members to ${conversationId}`,
      );
    }

    const members = await this.getMembers(conversationId, userId);
    if (pendingApprovals.length > 0) {
      return { members, pendingApprovals, status: 'PENDING_APPROVAL' };
    }

    return { members, pendingApprovals, status: 'ADDED' };
  }

  /** Remove a member or leave conversation.
   * G-007: ADMIN cannot leave while other members exist — must transfer or disband first.
   */
  async removeMember(
    conversationId: string,
    requesterId: string,
    targetUserId: string,
  ) {
    const requester = await this.assertMember(conversationId, requesterId);
    const target = await this.assertMember(conversationId, targetUserId);

    const isSelf = requesterId === targetUserId;

    // G-007: ADMIN cannot leave while there are still other members in the group
    if (isSelf && requester.role === MemberRole.ADMIN) {
      const conversation = await this.getConversationOrFail(conversationId);
      if (conversation.type === ConversationType.GROUP) {
        const memberCount = await this.memberRepo.count({
          where: { conversationId, leftAt: IsNull() },
        });
        if (memberCount > 1) {
          throw new ForbiddenException(
            'Group admin cannot leave while other members exist. Transfer admin role or disband the group first.',
          );
        }
      }
    }

    // MEMBER cannot remove others. DEPUTY cannot remove ADMIN.
    if (!isSelf) {
      // Only admin/deputy can remove others
      if (requester.role === MemberRole.MEMBER) {
        throw new ForbiddenException('Only admin or deputy can remove members');
      }
      // Deputy cannot remove admin
      if (target.role === MemberRole.ADMIN) {
        throw new ForbiddenException('Cannot remove the group admin');
      }
      // Deputy cannot remove another deputy
      if (
        requester.role === MemberRole.DEPUTY &&
        target.role === MemberRole.DEPUTY
      ) {
        throw new ForbiddenException('Deputies cannot remove other deputies');
      }
    }

    // Soft-delete: set leftAt
    target.leftAt = new Date();
    target.removedBy = isSelf ? null : requesterId;
    await this.memberRepo.save(target);

    this.logger.log(
      `Member ${targetUserId} removed from ${conversationId} by ${requesterId}`,
    );
  }

  /** Get active members of a conversation. */
  async getMembers(conversationId: string, userId: string) {
    await this.assertMember(conversationId, userId);
    return this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
      order: { joinedAt: 'ASC' },
    });
  }

  /** Join a group by QR/invite link. */
  async requestJoin(conversationId: string, userId: string) {
    const conversation = await this.getConversationOrFail(conversationId);
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only join group conversations');
    }

    const existingMember = await this.memberRepo.findOne({
      where: { conversationId, userId, leftAt: IsNull() },
    });
    if (existingMember) {
      return { status: 'ALREADY_MEMBER', conversationId, userId };
    }

    if (conversation.joinMode === JoinMode.INVITE_ONLY) {
      throw new ForbiddenException('Group is invite-only');
    }

    if (conversation.joinMode === JoinMode.OPEN) {
      await this.ensureUnderMemberLimit(
        conversationId,
        conversation.memberLimit,
        1,
      );
      await this.memberRepo.save({
        conversationId,
        userId,
        role: MemberRole.MEMBER,
        joinedBy: null,
        leftAt: null,
        removedBy: null,
        joinedAt: new Date(),
      });
      return { status: 'JOINED', conversationId, userId };
    }

    await this.joinRequestRepo
      .createQueryBuilder()
      .insert()
      .values({ conversationId, userId, requestedBy: userId })
      .orIgnore()
      .execute();

    return { status: 'PENDING_APPROVAL', conversationId, userId };
  }

  /** Get pending requests. Only ADMIN/DEPUTY. */
  async getJoinRequests(conversationId: string, userId: string) {
    await this.assertAdminOrDeputy(conversationId, userId);

    return this.joinRequestRepo.find({
      where: { conversationId },
      order: { requestedAt: 'ASC' },
    });
  }

  /** Approve a join request and add member. */
  async approveJoinRequest(
    conversationId: string,
    approverId: string,
    targetUserId: string,
  ) {
    const conversation = await this.getConversationOrFail(conversationId);
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only approve for group conversations');
    }

    await this.assertAdminOrDeputy(conversationId, approverId);

    const request = await this.joinRequestRepo.findOne({
      where: { conversationId, userId: targetUserId },
    });
    if (!request) {
      throw new NotFoundException('Join request not found');
    }

    const existingMember = await this.memberRepo.findOne({
      where: { conversationId, userId: targetUserId, leftAt: IsNull() },
    });
    if (existingMember) {
      await this.joinRequestRepo.delete({
        conversationId,
        userId: targetUserId,
      });
      return { status: 'ALREADY_MEMBER', conversationId, userId: targetUserId };
    }

    await this.ensureUnderMemberLimit(
      conversationId,
      conversation.memberLimit,
      1,
    );

    await this.dataSource.transaction(async (manager) => {
      await manager.save(ConversationMember, {
        conversationId,
        userId: targetUserId,
        role: MemberRole.MEMBER,
        joinedBy: approverId,
        leftAt: null,
        removedBy: null,
        joinedAt: new Date(),
      });
      await manager.delete(ConversationJoinRequest, {
        conversationId,
        userId: targetUserId,
      });
    });

    return { status: 'APPROVED', conversationId, userId: targetUserId };
  }

  /** Reject a pending join request. */
  async rejectJoinRequest(
    conversationId: string,
    approverId: string,
    targetUserId: string,
  ) {
    await this.assertAdminOrDeputy(conversationId, approverId);

    const result = await this.joinRequestRepo.delete({
      conversationId,
      userId: targetUserId,
    });
    if ((result.affected ?? 0) === 0) {
      throw new NotFoundException('Join request not found');
    }
    return { status: 'REJECTED', conversationId, userId: targetUserId };
  }

  /** Verify role/setting policy for pin/unpin actions. */
  async assertCanPinMessage(
    conversationId: string,
    userId: string,
  ): Promise<void> {
    const conversation = await this.getConversationOrFail(conversationId);
    const member = await this.assertMember(conversationId, userId);

    // Always allow pinning in 1:1 chats. For groups, check allowMemberPin or admin/owner role.
    if (conversation.type === ConversationType.DIRECT) return;

    if (member.role === MemberRole.MEMBER && !conversation.allowMemberPin) {
      throw new ForbiddenException('Only admin/deputy can pin in this group');
    }
  }

  /**
   * G-008: Verify that user is allowed to send messages in a conversation.
   * If onlyAdminCanPost is enabled, only ADMIN and DEPUTY can send.
   * Both frontend (input bar disabled) and backend must enforce this.
   */
  async assertCanSendMessage(
    conversationId: string,
    userId: string,
  ): Promise<ConversationMember> {
    const conversation = await this.getConversationOrFail(conversationId);
    const member = await this.assertMember(conversationId, userId);

    if (conversation.type === ConversationType.GROUP && conversation.onlyAdminCanPost) {
      if (member.role === MemberRole.MEMBER) {
        throw new ForbiddenException(
          'Only admin and deputy can send messages in announcement mode',
        );
      }
    }
    return member;
  }

  /**
   * G-013: Convenience method for a member leaving a group.
   * Delegates to removeMember (self-removal) and returns the memberCount.
   */
  async leaveGroup(
    conversationId: string,
    userId: string,
  ): Promise<{ status: string; conversationId: string }> {
    await this.removeMember(conversationId, userId, userId);
    return { status: 'LEFT', conversationId };
  }

  /**
   * G-017: Auto-transfer admin role or disband group if no eligible successor.
   * Called when the current ADMIN needs to be removed forcefully (e.g. account deletion,
   * inactive-admin cleanup job, or admin self-forced exit).
   *
   * Priority: DEPUTY (oldest joinedAt first) → MEMBER (oldest joinedAt) → disband
   *
   * @param conversationId - the group to process
   * @param currentAdminId - the admin being removed/stepping down
   * @returns { action: 'TRANSFERRED' | 'DISBANDED', newAdminId?: string }
   */
  async autoTransferOrDisbandGroup(
    conversationId: string,
    currentAdminId: string,
  ): Promise<{ action: 'TRANSFERRED' | 'DISBANDED'; newAdminId?: string }> {
    const conversation = await this.getConversationOrFail(conversationId);
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Not a group conversation');
    }

    // Find active members excluding the current admin, ordered by seniority
    const candidates = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
      order: { joinedAt: 'ASC' },
    });

    const others = candidates.filter((m) => m.userId !== currentAdminId);

    if (others.length === 0) {
      // No other members — disband the group
      await this.disbandGroup(conversationId, currentAdminId);
      return { action: 'DISBANDED' };
    }

    // Prefer existing DEPUTY, else promote oldest MEMBER
    const successor =
      others.find((m) => m.role === MemberRole.DEPUTY) ?? others[0];

    // Promote successor to ADMIN
    await this.updateMember(conversationId, currentAdminId, successor.userId, {
      role: MemberRole.ADMIN,
    });

    this.logger.log(
      `[autoTransfer] Group ${conversationId}: admin transferred from ${currentAdminId} to ${successor.userId}`,
    );
    return { action: 'TRANSFERRED', newAdminId: successor.userId };
  }

  /** Verify user is an active member. Throws if not. */
  async assertMember(
    conversationId: string,
    userId: string,
  ): Promise<ConversationMember> {
    const member = await this.memberRepo.findOne({
      where: { conversationId, userId, leftAt: IsNull() },
    });
    if (!member)
      throw new ForbiddenException('You are not a member of this conversation');
    return member;
  }

  /** Verify user is ADMIN or DEPUTY (can do most privileged actions). */
  private async assertAdminOrDeputy(conversationId: string, userId: string) {
    const member = await this.assertMember(conversationId, userId);
    if (member.role === MemberRole.MEMBER) {
      throw new ForbiddenException('Admin or deputy access required');
    }
    return member;
  }

  /** Verify user is ADMIN (group owner — exclusive actions: disband, transfer, toggle settings). */
  private async assertIsAdmin(conversationId: string, userId: string) {
    const member = await this.assertMember(conversationId, userId);
    if (member.role !== MemberRole.ADMIN) {
      throw new ForbiddenException(
        'Only the group admin can perform this action',
      );
    }
    return member;
  }

  private async getConversationOrFail(
    conversationId: string,
  ): Promise<Conversation> {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) {
      throw new NotFoundException('Conversation not found');
    }
    return conversation;
  }

  async ensureUnderMemberLimit(
    conversationId: string,
    memberLimit: number,
    addingCount: number,
  ): Promise<void> {
    const currentMemberCount = await this.memberRepo.count({
      where: { conversationId, leftAt: IsNull() },
    });

    if (currentMemberCount + addingCount > memberLimit) {
      throw new BadRequestException(
        `Cannot exceed member limit of ${memberLimit}. Current: ${currentMemberCount}, adding: ${addingCount}`,
      );
    }
  }

  /** Update member nickname or role. */
  async updateMember(
    conversationId: string,
    requesterId: string,
    targetUserId: string,
    dto: { nickname?: string; role?: any },
  ) {
    const member = await this.memberRepo.findOne({
      where: { conversationId, userId: targetUserId, leftAt: IsNull() },
    });
    if (!member) throw new NotFoundException('Member not found');

    const isSelf = requesterId === targetUserId;

    if (dto.role !== undefined && !isSelf) {
      // B-7: Only check assertIsAdmin for role changes — avoids double DB assertMember
      await this.assertIsAdmin(conversationId, requesterId);
    } else if (!isSelf) {
      // For nickname-only changes by others, admin/deputy is sufficient
      await this.assertAdminOrDeputy(conversationId, requesterId);
    }

    if (dto.nickname !== undefined) member.nickname = dto.nickname;
    if (dto.role !== undefined && !isSelf) {
      if (dto.role === MemberRole.ADMIN) {
        // Admin transfer: demote current admin to MEMBER first
        const currentAdmin = await this.memberRepo.findOne({
          where: { conversationId, role: MemberRole.ADMIN, leftAt: IsNull() },
        });
        if (currentAdmin && currentAdmin.userId !== targetUserId) {
          currentAdmin.role = MemberRole.MEMBER;
          await this.memberRepo.save(currentAdmin);
        }
      }
      member.role = dto.role as MemberRole;
    }

    return this.memberRepo.save(member);
  }

  /** Update conversation wallpaper. */
  async updateWallpaper(
    conversationId: string,
    userId: string,
    wallpaperUrl: string,
    isGlobal = true,
  ) {
    if (isGlobal) {
      const conversation = await this.getConversationOrFail(conversationId);
      await this.assertAdminOrDeputy(conversationId, userId);

      conversation.wallpaperUrl = wallpaperUrl;
      return this.conversationRepo.save(conversation);
    } else {
      const entry = await this.inboxRepo.findOne({
        where: { userId, conversationId },
      });
      if (!entry) {
        throw new NotFoundException('Conversation not found in your inbox');
      }
      entry.wallpaperUrl = wallpaperUrl;
      return this.inboxRepo.save(entry);
    }
  }

  /**
   * Disband (permanently delete) a group conversation.
   * Only the ADMIN (group owner) can disband the group.
   * Hard-deletes: all messages, members, inbox entries, join requests, and the conversation.
   * Decision D-012: atomic hard-delete, no soft-delete, no recovery.
   *
   * @returns payload for the group.disbanded socket event
   */
  async disbandGroup(
    conversationId: string,
    userId: string,
  ): Promise<{ conversationId: string; disbandedBy: string }> {
    const conversation = await this.getConversationOrFail(conversationId);

    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only disband group conversations');
    }

    // Only ADMIN (group owner) can disband — D-012
    await this.assertIsAdmin(conversationId, userId);

    // Collect ACTIVE member IDs before deletion (B-5: filter leftAt IS NULL)
    const members = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
    });
    const memberUserIds = members.map((m) => m.userId);

    await this.dataSource.transaction(async (manager) => {
      // 1. Delete all messages in the conversation
      await manager.query(`DELETE FROM message WHERE conversation_id = $1`, [
        conversationId,
      ]);

      // 2. Delete all message receipts and reactions (cascaded via FK in most setups, explicit for safety)
      await manager.query(
        `DELETE FROM message_reaction WHERE conversation_id = $1`,
        [conversationId],
      );
      await manager.query(
        `DELETE FROM message_receipt WHERE conversation_id = $1`,
        [conversationId],
      );
      await manager.query(
        `DELETE FROM pinned_message WHERE conversation_id = $1`,
        [conversationId],
      );

      // 3. Delete all join requests
      await manager.query(
        `DELETE FROM conversation_join_request WHERE conversation_id = $1`,
        [conversationId],
      );

      // 4. Delete all inbox entries for this conversation
      await manager.query(
        `DELETE FROM conversation_inbox WHERE conversation_id = $1`,
        [conversationId],
      );

      // 5. Delete all members (including soft-deleted ones)
      await manager.query(
        `DELETE FROM conversation_member WHERE conversation_id = $1`,
        [conversationId],
      );

      // 6. Delete conversation itself
      await manager.query(
        `DELETE FROM conversation WHERE conversation_id = $1`,
        [conversationId],
      );
    });

    this.logger.log(
      `Group ${conversationId} disbanded by ${userId}. ${memberUserIds.length} members affected.`,
    );

    return { conversationId, disbandedBy: userId };
  }
}
