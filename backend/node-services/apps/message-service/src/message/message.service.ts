import {
  Injectable, NotFoundException, ForbiddenException,
  BadRequestException, Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, DataSource, IsNull } from 'typeorm';
import { Message, MessageType, MessageStatus } from '../entities/message.entity';
import { MessageReaction } from '../entities/message-reaction.entity';
import { PinnedMessage } from '../entities/pinned-message.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { ConversationService } from '../conversation/conversation.service';
import { SendMessageDto } from '../dto/send-message.dto';

@Injectable()
export class MessageService {
  private readonly logger = new Logger(MessageService.name);

  /**
   * In-memory sequence counters per conversation.
   * In production, this should use Redis INCR for distributed safety.
   */
  private seqCounters = new Map<string, number>();

  constructor(
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(MessageReaction)
    private readonly reactionRepo: Repository<MessageReaction>,
    @InjectRepository(PinnedMessage)
    private readonly pinRepo: Repository<PinnedMessage>,
    @InjectRepository(ConversationInbox)
    private readonly inboxRepo: Repository<ConversationInbox>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    private readonly conversationService: ConversationService,
    private readonly dataSource: DataSource,
  ) {}

  /**
   * Send a message to a conversation.
   * - Validates membership
   * - Assigns monotonic server_seq
   * - Handles reply/forward denormalization
   * - Updates inbox for all active members (CQRS)
   */
  async sendMessage(userId: string, dto: SendMessageDto): Promise<Message> {
    // Verify sender is a member
    await this.conversationService.assertMember(dto.conversationId, userId);

    // Idempotency: check if message with same clientMessageId already exists
    if (dto.clientMessageId) {
      const existing = await this.messageRepo.findOne({
        where: { clientMessageId: dto.clientMessageId, senderId: userId },
      });
      if (existing) return existing;
    }

    const serverSeq = await this.getNextSeq(dto.conversationId);

    // Build message entity
    const message = this.messageRepo.create({
      conversationId: dto.conversationId,
      serverSeq,
      senderId: userId,
      clientMessageId: dto.clientMessageId ?? null,
      messageType: dto.messageType ?? MessageType.TEXT,
      content: dto.content ?? null,
      mediaUrl: dto.mediaUrl ?? null,
      mediaThumbnailUrl: dto.mediaThumbnailUrl ?? null,
      mediaMimeType: dto.mediaMimeType ?? null,
      mediaSizeBytes: dto.mediaSizeBytes ?? null,
      status: MessageStatus.SENT,
    });

    // Denormalize reply info for fast rendering
    if (dto.replyToMessageId) {
      const original = await this.messageRepo.findOne({ where: { id: dto.replyToMessageId } });
      if (original) {
        message.replyToMessageId = original.id;
        message.replyToSenderId = original.senderId;
        message.replyToContent = original.content?.substring(0, 200) ?? null;
        message.messageType = MessageType.REPLY;
      }
    }

    // Handle forward
    if (dto.forwardFromMessageId) {
      message.forwardFromMessageId = dto.forwardFromMessageId;
      message.forwardFromConversationId = dto.forwardFromConversationId ?? null;
      message.messageType = MessageType.FORWARD;
    }

    const saved = await this.messageRepo.save(message);

    // Update inbox for all active members (async, non-blocking)
    this.updateInboxForMembers(dto.conversationId, saved, userId).catch((err) =>
      this.logger.error(`Failed to update inbox: ${err.message}`),
    );

    this.logger.log(`Message sent: ${saved.id} in ${dto.conversationId} seq=${serverSeq}`);
    return saved;
  }

  /** Get paginated message history for a conversation (cursor-based on server_seq). */
  async getMessages(conversationId: string, userId: string, before?: number, limit = 50) {
    await this.conversationService.assertMember(conversationId, userId);

    const where: any = { conversationId };
    if (before !== undefined) {
      where.serverSeq = LessThan(before);
    }

    return this.messageRepo.find({
      where,
      order: { serverSeq: 'DESC' },
      take: Math.min(limit, 100),
    });
  }

  /** Edit a message. Only the sender can edit, and only text content. */
  async editMessage(userId: string, messageId: string, content: string): Promise<Message> {
    const message = await this.findMessageOrFail(messageId);

    if (message.senderId !== userId) {
      throw new ForbiddenException('You can only edit your own messages');
    }
    if (message.status === MessageStatus.RECALLED) {
      throw new BadRequestException('Cannot edit a recalled message');
    }

    message.content = content;
    message.isEdited = true;
    message.editedAt = new Date();

    return this.messageRepo.save(message);
  }

  /** Recall (soft-delete) a message. Only the sender can recall. */
  async recallMessage(userId: string, messageId: string): Promise<Message> {
    const message = await this.findMessageOrFail(messageId);

    if (message.senderId !== userId) {
      throw new ForbiddenException('You can only recall your own messages');
    }

    message.status = MessageStatus.RECALLED;
    message.content = null; // Clear content for recalled messages

    return this.messageRepo.save(message);
  }

  /** Pin a message in a conversation. Requires admin/owner or allowMemberPin. */
  async pinMessage(userId: string, conversationId: string, messageId: string) {
    await this.conversationService.assertMember(conversationId, userId);
    const message = await this.findMessageOrFail(messageId);

    if (message.conversationId !== conversationId) {
      throw new BadRequestException('Message does not belong to this conversation');
    }

    // Check if already pinned
    const existing = await this.pinRepo.findOne({ where: { conversationId, messageId } });
    if (existing) throw new BadRequestException('Message is already pinned');

    return this.pinRepo.save({
      conversationId,
      messageId,
      serverSeq: message.serverSeq,
      pinnedBy: userId,
    });
  }

  /** Unpin a message from a conversation. */
  async unpinMessage(userId: string, conversationId: string, messageId: string) {
    await this.conversationService.assertMember(conversationId, userId);

    const pin = await this.pinRepo.findOne({ where: { conversationId, messageId } });
    if (!pin) throw new NotFoundException('Pin not found');

    await this.pinRepo.remove(pin);
  }

  /** Get all pinned messages in a conversation. */
  async getPinnedMessages(conversationId: string, userId: string) {
    await this.conversationService.assertMember(conversationId, userId);
    return this.pinRepo.find({
      where: { conversationId },
      order: { pinnedAt: 'DESC' },
    });
  }

  /** Add an emoji reaction to a message. Replaces existing reaction from same user. */
  async addReaction(userId: string, messageId: string, emoji: string) {
    const message = await this.findMessageOrFail(messageId);
    await this.conversationService.assertMember(message.conversationId, userId);

    // Upsert: remove old reaction if exists, then add new
    await this.reactionRepo.delete({ messageId, userId });

    return this.reactionRepo.save({
      conversationId: message.conversationId,
      messageId,
      serverSeq: message.serverSeq,
      userId,
      emoji,
    });
  }

  /** Remove user's reaction from a message. */
  async removeReaction(userId: string, messageId: string) {
    const result = await this.reactionRepo.delete({ messageId, userId });
    if (result.affected === 0) throw new NotFoundException('Reaction not found');
  }

  /** Get reactions for a message. */
  async getReactions(messageId: string) {
    return this.reactionRepo.find({
      where: { messageId },
      order: { createdAt: 'ASC' },
    });
  }

  /**
   * Mark messages as read up to a given sequence number.
   * Updates the member's last_read_seq and decrements inbox unread count.
   */
  async markAsRead(userId: string, conversationId: string, lastReadSeq: number) {
    const member = await this.conversationService.assertMember(conversationId, userId);

    // Only update if we're advancing the read cursor
    if (lastReadSeq <= member.lastReadSeq) return;

    member.lastReadSeq = lastReadSeq;
    member.lastReadAt = new Date();
    await this.memberRepo.save(member);

    // Reset unread count in inbox
    await this.inboxRepo.update(
      { userId, conversationId },
      { unreadCount: 0 },
    );
  }

  // ─── Private Helpers ────────────────────────────────────────

  private async findMessageOrFail(messageId: string): Promise<Message> {
    const message = await this.messageRepo.findOne({ where: { id: messageId } });
    if (!message) throw new NotFoundException('Message not found');
    return message;
  }

  /**
   * Generate next sequence number for a conversation.
   * Uses in-memory counter for dev; should use Redis INCR in production.
   */
  private async getNextSeq(conversationId: string): Promise<number> {
    if (!this.seqCounters.has(conversationId)) {
      // Initialize from database: find the max seq for this conversation
      const result = await this.messageRepo
        .createQueryBuilder('m')
        .select('COALESCE(MAX(m.server_seq), 0)', 'maxSeq')
        .where('m.conversation_id = :cid', { cid: conversationId })
        .getRawOne();
      this.seqCounters.set(conversationId, parseInt(result?.maxSeq ?? '0', 10));
    }

    const next = (this.seqCounters.get(conversationId) ?? 0) + 1;
    this.seqCounters.set(conversationId, next);
    return next;
  }

  /**
   * Update conversation_inbox for all active members after a new message.
   * Increments unread_count for everyone except the sender.
   */
  private async updateInboxForMembers(conversationId: string, message: Message, senderId: string) {
    const members = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
    });

    const preview = message.content?.substring(0, 200) ?? `[${message.messageType}]`;

    for (const member of members) {
      const isOwn = member.userId === senderId;

      await this.inboxRepo.upsert(
        {
          userId: member.userId,
          conversationId,
          lastMessageSeq: message.serverSeq,
          lastMessageAt: message.createdAt,
          lastMessagePreview: preview,
          lastMessageSenderId: message.senderId,
          lastMessageType: message.messageType,
          unreadCount: isOwn ? 0 : () => '"unread_count" + 1',
          isHidden: false, // Unhide on new message
        } as any,
        ['userId', 'conversationId'],
      );
    }
  }
}
