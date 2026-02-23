import {
  Injectable, NotFoundException, ForbiddenException,
  BadRequestException, ConflictException, Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, IsNull } from 'typeorm';
import { Conversation, ConversationType, ConversationStatus } from '../entities/conversation.entity';
import { ConversationMember, MemberRole } from '../entities/conversation-member.entity';
import { ConversationDirectMap } from '../entities/conversation-direct-map.entity';
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
      });
      const saved = await manager.save(conversation);

      // Creator is always OWNER
      const members: Partial<ConversationMember>[] = [
        { conversationId: saved.id, userId, role: MemberRole.OWNER },
      ];

      // Add initial members
      for (const memberId of dto.memberIds) {
        if (memberId !== userId) {
          members.push({
            conversationId: saved.id,
            userId: memberId,
            role: MemberRole.MEMBER,
            joinedBy: userId,
          });
        }
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

    const newMembers: Partial<ConversationMember>[] = [];
    for (const memberId of memberIds) {
      // Skip if already a member
      const exists = await this.memberRepo.findOne({
        where: { conversationId, userId: memberId, leftAt: IsNull() },
      });
      if (!exists) {
        newMembers.push({
          conversationId,
          userId: memberId,
          role: MemberRole.MEMBER,
          joinedBy: userId,
        });
      }
    }

    if (newMembers.length > 0) {
      await this.memberRepo.save(newMembers);
      this.logger.log(`Added ${newMembers.length} members to ${conversationId}`);
    }

    return this.getMembers(conversationId);
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
  async getMembers(conversationId: string) {
    return this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
      order: { joinedAt: 'ASC' },
    });
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
}
