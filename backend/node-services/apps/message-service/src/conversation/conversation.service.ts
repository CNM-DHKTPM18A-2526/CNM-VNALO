import {
  Injectable, NotFoundException, ForbiddenException,
  BadRequestException, ConflictException, Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, IsNull } from 'typeorm';
import { Conversation, ConversationType, ConversationStatus, JoinMode } from '../entities/conversation.entity';
import { ConversationMember, MemberRole } from '../entities/conversation-member.entity';
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
  ) { }

  /**
   * Create or retrieve a direct (1:1) conversation.
   * Uses conversation_direct_map for O(1) lookup, ordering user IDs to avoid duplicates.
   */
  async createDirect(userId: string, targetUserId: string) {
    if (userId === targetUserId) {
      throw new BadRequestException('Cannot create conversation with yourself');
    }

    // Enforce ordering: userId1 < userId2
    const [uid1, uid2] = userId < targetUserId ? [userId, targetUserId] : [targetUserId, userId];

    // Check if direct conversation already exists
    const existing = await this.directMapRepo.findOne({
      where: { userId1: uid1, userId2: uid2 },
    });

    if (existing) {
      return this.getConversation(existing.conversationId, userId);
    }

    // Create within a transaction
    const conversationId = await this.dataSource.transaction(async (manager) => {
      const conversation = manager.create(Conversation, {
        type: ConversationType.DIRECT,
        createdBy: userId,
        status: ConversationStatus.ACTIVE,
      });
      const saved = await manager.save(conversation);

      // Add both users as members
      await manager.save(ConversationMember, [
        { conversationId: saved.id, userId, role: MemberRole.MEMBER },
        { conversationId: saved.id, userId: targetUserId, role: MemberRole.MEMBER },
      ]);

      // Create direct map for fast lookup
      await manager.save(ConversationDirectMap, {
        userId1: uid1,
        userId2: uid2,
        conversationId: saved.id,
      });

      // Create inbox entries for both users so the conversation appears in messages tab
      await manager.save(ConversationInbox, [
        { userId, conversationId: saved.id, lastMessageSeq: 0, unreadCount: 0, isPinned: false, isMuted: false, isHidden: false },
        { userId: targetUserId, conversationId: saved.id, lastMessageSeq: 0, unreadCount: 0, isPinned: false, isMuted: false, isHidden: false },
      ]);

      this.logger.log(`Direct conversation created: ${saved.id} between ${uid1} and ${uid2}`);
      return saved.id;
    });

    return this.getConversation(conversationId, userId);
  }

  /** Create a group conversation with initial members. Creator becomes OWNER. */
  async createGroup(userId: string, dto: CreateGroupConversationDto) {
    const conversationId = await this.dataSource.transaction(async (manager) => {
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

      // Creator is always OWNER
      const members: Partial<ConversationMember>[] = [
        { conversationId: saved.id, userId, role: MemberRole.OWNER },
      ];

      const uniqueInitialMembers = [...new Set(dto.memberIds)].filter((memberId) => memberId !== userId);
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
      this.logger.log(`Group created: ${saved.id} "${dto.title}" with ${members.length} members`);

      return saved.id;
    });

    return this.getConversation(conversationId, userId);
  }

  /** Get conversation with active member list. Verifies user has access. */
  async getConversation(conversationId: string, userId: string) {
    const conversation = await this.conversationRepo.findOne({ where: { id: conversationId } });
    if (!conversation) throw new NotFoundException('Conversation not found');

    // Verify user is a member
    await this.assertMember(conversationId, userId);

    const members = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
    });

    return { ...conversation, members };
  }

  /** Update group conversation settings. Only OWNER/ADMIN can update. */
  async updateGroup(conversationId: string, userId: string, dto: UpdateConversationDto) {
    const conversation = await this.conversationRepo.findOne({ where: { id: conversationId } });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only update group conversations');
    }

    await this.assertAdminOrOwner(conversationId, userId);
    Object.assign(conversation, dto);
    return this.conversationRepo.save(conversation);
  }

  /** Add members to a group. Requires ADMIN/OWNER or allowed member invite. */
  async addMembers(conversationId: string, userId: string, memberIds: string[]) {
    const conversation = await this.conversationRepo.findOne({ where: { id: conversationId } });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only add members to group conversations');
    }

    const membership = await this.assertMember(conversationId, userId);

    // Only admin/owner or if allowMemberInvite is enabled
    if (membership.role === MemberRole.MEMBER && !conversation.allowMemberInvite) {
      throw new ForbiddenException('You do not have permission to add members');
    }

    if (conversation.joinMode === JoinMode.INVITE_ONLY && membership.role === MemberRole.MEMBER) {
      throw new ForbiddenException('Only admin or owner can add members in invite-only groups');
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

      if (conversation.joinMode === JoinMode.APPROVAL && membership.role === MemberRole.MEMBER) {
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
        });
      }
    }

    if (newMembers.length > 0) {
      await this.ensureUnderMemberLimit(conversationId, conversation.memberLimit, newMembers.length);
      await this.memberRepo.save(newMembers);
      this.logger.log(`Added ${newMembers.length} members to ${conversationId}`);
    }

    const members = await this.getMembers(conversationId, userId);
    if (pendingApprovals.length > 0) {
      return { members, pendingApprovals, status: 'PENDING_APPROVAL' };
    }

    return { members, pendingApprovals, status: 'ADDED' };
  }

  /** Remove a member or leave conversation. OWNER cannot leave without transfer. */
  async removeMember(conversationId: string, requesterId: string, targetUserId: string) {
    const requester = await this.assertMember(conversationId, requesterId);
    const target = await this.assertMember(conversationId, targetUserId);

    const isSelf = requesterId === targetUserId;

    if (!isSelf) {
      // Only admin/owner can remove others
      if (requester.role === MemberRole.MEMBER) {
        throw new ForbiddenException('Only admin or owner can remove members');
      }
      // Admin cannot remove owner
      if (target.role === MemberRole.OWNER) {
        throw new ForbiddenException('Cannot remove the group owner');
      }
    }

    // Soft-delete: set leftAt
    target.leftAt = new Date();
    target.removedBy = isSelf ? null : requesterId;
    await this.memberRepo.save(target);

    this.logger.log(`Member ${targetUserId} removed from ${conversationId} by ${requesterId}`);
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
      await this.ensureUnderMemberLimit(conversationId, conversation.memberLimit, 1);
      await this.memberRepo.save({
        conversationId,
        userId,
        role: MemberRole.MEMBER,
        joinedBy: null,
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

  /** Get pending requests. Only ADMIN/OWNER. */
  async getJoinRequests(conversationId: string, userId: string) {
    await this.assertAdminOrOwner(conversationId, userId);
    return this.joinRequestRepo.find({
      where: { conversationId },
      order: { requestedAt: 'ASC' },
    });
  }

  /** Approve a join request and add member. */
  async approveJoinRequest(conversationId: string, approverId: string, targetUserId: string) {
    const conversation = await this.getConversationOrFail(conversationId);
    if (conversation.type !== ConversationType.GROUP) {
      throw new BadRequestException('Can only approve for group conversations');
    }

    await this.assertAdminOrOwner(conversationId, approverId);

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
      await this.joinRequestRepo.delete({ conversationId, userId: targetUserId });
      return { status: 'ALREADY_MEMBER', conversationId, userId: targetUserId };
    }

    await this.ensureUnderMemberLimit(conversationId, conversation.memberLimit, 1);

    await this.dataSource.transaction(async (manager) => {
      await manager.save(ConversationMember, {
        conversationId,
        userId: targetUserId,
        role: MemberRole.MEMBER,
        joinedBy: approverId,
      });
      await manager.delete(ConversationJoinRequest, { conversationId, userId: targetUserId });
    });

    return { status: 'APPROVED', conversationId, userId: targetUserId };
  }

  /** Reject a pending join request. */
  async rejectJoinRequest(conversationId: string, approverId: string, targetUserId: string) {
    await this.assertAdminOrOwner(conversationId, approverId);
    const result = await this.joinRequestRepo.delete({ conversationId, userId: targetUserId });
    if ((result.affected ?? 0) === 0) {
      throw new NotFoundException('Join request not found');
    }
    return { status: 'REJECTED', conversationId, userId: targetUserId };
  }

  /** Verify role/setting policy for pin/unpin actions. */
  async assertCanPinMessage(conversationId: string, userId: string): Promise<void> {
    const conversation = await this.getConversationOrFail(conversationId);
    const member = await this.assertMember(conversationId, userId);
    if (member.role === MemberRole.MEMBER && !conversation.allowMemberPin) {
      throw new ForbiddenException('Only admin/owner can pin in this group');
    }
  }

  /** Verify user is an active member. Throws if not. */
  async assertMember(conversationId: string, userId: string): Promise<ConversationMember> {
    const member = await this.memberRepo.findOne({
      where: { conversationId, userId, leftAt: IsNull() },
    });
    if (!member) throw new ForbiddenException('You are not a member of this conversation');
    return member;
  }

  /** Verify user is ADMIN or OWNER. */
  private async assertAdminOrOwner(conversationId: string, userId: string) {
    const member = await this.assertMember(conversationId, userId);
    if (member.role === MemberRole.MEMBER) {
      throw new ForbiddenException('Admin or owner access required');
    }
    return member;
  }

  private async getConversationOrFail(conversationId: string): Promise<Conversation> {
    const conversation = await this.conversationRepo.findOne({ where: { id: conversationId } });
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
  async updateMember(conversationId: string, requesterId: string, targetUserId: string, dto: { nickname?: string; role?: any }) {
    const member = await this.memberRepo.findOne({
      where: { conversationId, userId: targetUserId, leftAt: IsNull() },
    });
    if (!member) throw new NotFoundException('Member not found');

    const isSelf = requesterId === targetUserId;
    if (!isSelf) {
      await this.assertAdminOrOwner(conversationId, requesterId);
    }

    if (dto.nickname !== undefined) member.nickname = dto.nickname;
    if (dto.role !== undefined && !isSelf) {
      if (dto.role === MemberRole.OWNER) {
        // Ownership transfer logic: demote current owner
        const currentOwner = await this.memberRepo.findOne({
          where: { conversationId, role: MemberRole.OWNER, leftAt: IsNull() },
        });
        if (currentOwner && currentOwner.userId !== targetUserId) {
          currentOwner.role = MemberRole.MEMBER;
          await this.memberRepo.save(currentOwner);
        }
      }
      member.role = dto.role as MemberRole;
    }

    return this.memberRepo.save(member);
  }

  /** Update conversation wallpaper. */
  async updateWallpaper(conversationId: string, userId: string, wallpaperUrl: string, isGlobal = true) {
    if (isGlobal) {
      const conversation = await this.getConversationOrFail(conversationId);
      await this.assertAdminOrOwner(conversationId, userId);

      conversation.wallpaperUrl = wallpaperUrl;
      return this.conversationRepo.save(conversation);
    } else {
      const entry = await this.inboxRepo.findOne({ where: { userId, conversationId } });
      if (!entry) {
        throw new NotFoundException('Conversation not found in your inbox');
      }
      entry.wallpaperUrl = wallpaperUrl;
      return this.inboxRepo.save(entry);
    }
  }
}
