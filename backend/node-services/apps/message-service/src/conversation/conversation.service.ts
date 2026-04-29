import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
  Inject,
  forwardRef,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';
import {
  Repository,
  DataSource,
  IsNull,
  OptimisticLockVersionMismatchError,
} from 'typeorm';
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
import { MembershipCacheService } from './membership-cache.service';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { Message } from '../entities/message.entity';
import { MessageReaction } from '../entities/message-reaction.entity';
import { MessageReceipt } from '../entities/message-receipt.entity';
import { PinnedMessage } from '../entities/pinned-message.entity';
import { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { UpdateConversationDto } from '../dto/update-conversation.dto';
import { KafkaProducerService } from '../kafka/kafka-producer.service';
import { MessageService } from '../message/message.service';

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
    private readonly kafkaProducer: KafkaProducerService,
    @Inject(forwardRef(() => MessageService))
    private readonly messageService: MessageService,
    private readonly membershipCache: MembershipCacheService,
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

    // V-03 Fix
    await this.membershipCache.invalidate(conversationId, userId);
    await this.membershipCache.invalidate(conversationId, targetUserId);

    return this.getConversation(conversationId, userId);
  }

  /** Create a group conversation with initial members. Creator becomes ADMIN. */
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

        // V-03 Fix: Invalidate cache for ALL initial members
        const allInitialMembers = [userId, ...uniqueInitialMembers];
        await Promise.all(
          allInitialMembers.map((id) => this.membershipCache.invalidate(saved.id, id)),
        );

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
    if (
      member.role === MemberRole.MEMBER &&
      !conversation.allowMemberEditInfo
    ) {
      throw new ForbiddenException(
        'You do not have permission to edit group settings',
      );
    }

    // Security Fix: Whitelist fields to prevent Elevation of Privilege
    const { title, description, avatarUrl, ...rest } = dto;
    
    if (member.role === MemberRole.MEMBER) {
      // MEMBER can only update basic info (if allowMemberEditInfo is true)
      Object.assign(conversation, {
        ...(title && { title }),
        ...(description && { description }),
        ...(avatarUrl && { avatarUrl }),
      });
    } else if (member.role === MemberRole.DEPUTY) {
      // DEPUTY can update basic info but NOT admin-only settings.
      // SECURITY: MUST update this whitelist when adding new admin-only fields to Conversation entity!
      const adminOnlyFields = [
        'onlyAdminCanPost',
        'allowMemberInvite',
        'allowMemberPin',
        'allowMemberEditInfo',
        'highlightAdminMessages',
        'showHistoryToNewMembers',
        'allowMemberCreateNote',
        'allowMemberCreatePoll',
        'joinMode',       // structural: controls how members join the group
        'memberLimit',    // structural: controls max group capacity
      ];

      
      const safeUpdate: any = {
        ...(title && { title }),
        ...(description && { description }),
        ...(avatarUrl && { avatarUrl }),
      };
      
      // Filter out admin-only fields from the deputy update
      for (const key of Object.keys(rest)) {
        if (!adminOnlyFields.includes(key)) {
          safeUpdate[key] = rest[key];
        }
      }
      
      Object.assign(conversation, safeUpdate);
    } else {
      // ADMIN can update everything
      Object.assign(conversation, dto);
    }

    return this.conversationRepo.save(conversation);
  }

  /** Add members to a group. Requires ADMIN or allowed member invite. */
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

    // V-03 Fix: Invalidate cache for all new members
    if (newMembers.length > 0) {
      await Promise.all(
        newMembers.map((m) => this.membershipCache.invalidate(conversationId, m.userId!))
      );
    }

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
    silent = false,
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

    // G-013 Fix & TI-1 Hardening: Use transaction for atomic soft-delete and inbox cleanup
    try {
      await this.dataSource.transaction(async (manager) => {
        // Re-fetch target inside transaction to ensure we have the latest version for optimistic lock
        const memberToUpdate = await manager.findOne(ConversationMember, {
          where: { conversationId, userId: targetUserId, leftAt: IsNull() },
        });

        if (!memberToUpdate) {
          throw new NotFoundException('Member not found or already left');
        }

        // Soft-delete: set leftAt
        memberToUpdate.leftAt = new Date();
        memberToUpdate.removedBy = isSelf ? null : requesterId;
        
        // TypeORM automatically handles @VersionColumn check here
        await manager.save(ConversationMember, memberToUpdate);

        // Delete inbox entry when leaving/removed to avoid orphaned data
        await manager.delete(ConversationInbox, {
          conversationId: conversationId,
          userId: targetUserId,
        });

        // V-08 Fix: Invalidate cache INSIDE transaction to ensure consistency
        await this.membershipCache.invalidate(conversationId, targetUserId);
      });
    } catch (err) {
      if (err instanceof OptimisticLockVersionMismatchError) {
        throw new ConflictException('Member status was modified by another request. Please retry.');
      }
      throw err;
    }

    // G-014: Send system message about member leaving/removal
    try {
      const targetName = target.nickname || 'Một thành viên';
      const requesterName = isSelf ? null : requester.nickname || 'Quản trị viên';
      
      let systemContent = '';
      if (isSelf) {
        systemContent = `${targetName} đã rời khỏi nhóm.`;
      } else {
        systemContent = `${targetName} đã bị ${requesterName} mời ra khỏi nhóm.`;
      }

      const targetRoles = silent ? [MemberRole.ADMIN, MemberRole.DEPUTY] : undefined;
      await this.messageService.createSystemMessage(conversationId, systemContent, targetRoles);
    } catch (err) {
      this.logger.error(`Failed to send system message for member removal: ${err.message}`);
    }

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
      // V-03 Fix
      await this.membershipCache.invalidate(conversationId, userId);
      return { status: 'JOINED', conversationId, userId };
    }

    await this.joinRequestRepo
      .createQueryBuilder()
      .insert()
      .values({ conversationId, userId, requestedBy: userId })
      .orIgnore()
      .execute();

    // V-03 Fix: Invalidate requester cache even for pending approval
    await this.membershipCache.invalidate(conversationId, userId);

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
      // V-08 Fix
      await this.membershipCache.invalidate(conversationId, targetUserId);
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

    // Always allow pinning in 1:1 chats. For groups, check allowMemberPin or admin role.
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
    silent = false,
  ): Promise<{ status: string; conversationId: string }> {
    await this.removeMember(conversationId, userId, userId, silent);
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

  /** Verify user is an active member. Throws if not. Optimized with Redis cache. */
  async assertMember(
    conversationId: string,
    userId: string,
  ): Promise<ConversationMember> {
    const member = await this.membershipCache.getActiveMember(conversationId, userId);
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
        // TI-1 Hardening: Admin transfer MUST be atomic
        try {
          await this.dataSource.transaction(async (manager) => {
            // 1. Demote current admin
            const currentAdmin = await manager.findOne(ConversationMember, {
              where: { conversationId, role: MemberRole.ADMIN, leftAt: IsNull() },
            });
            if (currentAdmin && currentAdmin.userId !== targetUserId) {
              currentAdmin.role = MemberRole.MEMBER;
              await manager.save(ConversationMember, currentAdmin);
            }

            // 2. Promote target to ADMIN
            const targetToPromote = await manager.findOne(ConversationMember, {
              where: { conversationId, userId: targetUserId, leftAt: IsNull() },
            });
            if (!targetToPromote) throw new NotFoundException('Target member not found');
            
            targetToPromote.role = MemberRole.ADMIN;
            if (dto.nickname !== undefined) targetToPromote.nickname = dto.nickname;
            
            await manager.save(ConversationMember, targetToPromote);

            // V-08 Fix: Invalidate INSIDE transaction
            await this.membershipCache.invalidate(conversationId, requesterId);
            await this.membershipCache.invalidate(conversationId, targetUserId);
          });
        } catch (err) {
          if (err instanceof OptimisticLockVersionMismatchError) {
            throw new ConflictException('Admin role was modified by another request. Please retry.');
          }
          throw err;
        }
        
        return { success: true };
      }
      member.role = dto.role as MemberRole;
    }

    if (dto.nickname !== undefined) member.nickname = dto.nickname;
    
    try {
      const result = await this.memberRepo.save(member);
      await this.membershipCache.invalidate(conversationId, targetUserId);
      return result;
    } catch (err) {
      if (err instanceof OptimisticLockVersionMismatchError) {
        throw new ConflictException('Member status was modified. Please refresh.');
      }
      throw err;
    }
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
  ): Promise<{ conversationId: string; disbandedBy: string; disbandedAt: Date }> {
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
      // 1. Delete all message reactions, receipts, and pins first (satisfy FK constraints)
      await manager.delete(MessageReaction, { conversationId });
      await manager.delete(MessageReceipt, { conversationId });
      await manager.delete(PinnedMessage, { conversationId });

      // 2. Delete all messages in the conversation
      await manager.delete(Message, { conversationId });

      // 3. Delete all join requests
      await manager.delete(ConversationJoinRequest, { conversationId });

      // 4. Delete all inbox entries for this conversation
      await manager.delete(ConversationInbox, { conversationId });

      // 5. Delete all members (including soft-deleted ones)
      await manager.delete(ConversationMember, { conversationId });

      // 6. Delete conversation itself
      await manager.delete(Conversation, { id: conversationId });

      // V-07 Fix: Bulk invalidate all members in Redis BEFORE commit to ensure no ghosts
      const invalidations = memberUserIds.map((id) => this.membershipCache.invalidate(conversationId, id));
      await Promise.all(invalidations);
    });

    this.logger.log(
      `Group ${conversationId} disbanded by ${userId}. ${memberUserIds.length} members affected.`,
    );

    // Single timestamp for all events — ensures idempotent correlation
    const disbandedAt = new Date();

    // Notify all members via Kafka
    const promises = memberUserIds.map((memberId) =>
      this.kafkaProducer.sendRealtimeEvent(memberId, 'group.disbanded', {
        conversationId,
        disbandedBy: userId,
        disbandedAt,
      }).catch((err) => {
        this.logger.error(`Failed to send group.disbanded event to ${memberId}: ${err.message}`);
      })
    );
    await Promise.all(promises);

    // G-015: Notify media-service to clean up all media files (Async)
    await this.kafkaProducer.sendRealtimeEvent(userId, 'GROUP_DISBANDED_MEDIA_CLEANUP', {
      conversationId,
      disbandedBy: userId,
      disbandedAt,
    });

    return { conversationId, disbandedBy: userId, disbandedAt };
  }
}
