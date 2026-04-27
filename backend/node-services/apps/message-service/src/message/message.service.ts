import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, IsNull, type EntityManager } from 'typeorm';
import {
  Message,
  MessageType,
  MessageStatus,
} from '../entities/message.entity';
import { MessageReaction } from '../entities/message-reaction.entity';
import { PinnedMessage } from '../entities/pinned-message.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import {
  ConversationMember,
  MemberRole,
} from '../entities/conversation-member.entity';
import { ConversationService } from '../conversation/conversation.service';
import { SendMessageDto } from '../dto/send-message.dto';
import { InjectRedis } from '@nestjs-modules/ioredis';
import type Redis from 'ioredis';
import { KafkaProducerService, NotificationEventPayload } from '../kafka/kafka-producer.service';
import { v4 as uuidv4 } from 'uuid';

type AccessPolicyContext = {
  clientPlatform?: string;
  restrictedWebMode?: boolean;
  loginAtEpochSec?: number;
};

@Injectable()
export class MessageService {
  private readonly logger = new Logger(MessageService.name);

  /** Maximum recall window: 24 hours */
  private static readonly RECALL_TIME_LIMIT_MS = 24 * 60 * 60 * 1000;

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
    @InjectRedis()
    private readonly redis: Redis,
    private readonly kafkaProducer: KafkaProducerService,
  ) {}

  /**
   * Send a message to a conversation.
   * - Validates membership and content
   * - Assigns monotonic server_seq via Redis INCR
   * - Handles reply/forward denormalization
   * - Updates inbox for all active members within a transaction (CQRS)
   */
  async sendMessage(
    userId: string,
    dto: SendMessageDto,
    access?: AccessPolicyContext,
  ): Promise<Message> {
    if (this.isRestrictedWeb(access)) {
      throw new ForbiddenException(
        'Restricted web session cannot send messages.',
      );
    }

    // Verify sender membership and group posting permissions (consolidated check)
    await this.conversationService.assertCanSendMessage(dto.conversationId, userId);
    await this.assertNotBlockedForSend(dto.conversationId, userId);

    // Validate content based on message type
    this.validateMessageContent(dto);

    // Idempotency: check if message with same clientMessageId already exists
    if (dto.clientMessageId) {
      const existing = await this.messageRepo.findOne({
        where: { clientMessageId: dto.clientMessageId, senderId: userId },
      });
      if (existing) return existing;
    }

    // Cross-conversation auth check for forwarded messages
    if (dto.forwardFromMessageId && dto.forwardFromConversationId) {
      await this.conversationService.assertMember(
        dto.forwardFromConversationId,
        userId,
      );
    }

    const serverSeq = await this.getNextSeq(dto.conversationId);

    // Wrap message save + inbox update in a single DB transaction
    const saved = await this.dataSource.transaction(async (manager) => {
      // Build message entity
      const message = manager.create(Message, {
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
        const original = await manager.findOne(Message, {
          where: { id: dto.replyToMessageId },
        });
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
        message.forwardFromConversationId =
          dto.forwardFromConversationId ?? null;
        message.messageType = MessageType.FORWARD;
      }

      const savedMsg = await manager.save(message);

      // Update inbox for all active members (batch, within transaction)
      await this.updateInboxForMembersWithManager(
        manager,
        dto.conversationId,
        savedMsg,
        userId,
      );

      return savedMsg;
    });

    this.logger.log(
      `Message sent: ${saved.id} in ${dto.conversationId} seq=${serverSeq}`,
    );

    // Publish notification events asynchronously to Kafka
    // This does NOT block the message send response
    this.publishNotificationEvents(saved, userId).catch((err) => {
      this.logger.error(`Failed to publish notification events: ${err.message}`);
    });

    return saved;
  }

  /**
   * Publish notification events to Kafka for all message recipients (except sender).
   * Notifications are sent asynchronously and do not block the message flow.
   */
  private async publishNotificationEvents(
    message: Message,
    senderId: string,
  ): Promise<void> {
    try {
      // Get all conversation members to notify
      const members = await this.memberRepo.find({
        where: { conversationId: message.conversationId, leftAt: IsNull() },
        select: ['userId'],
      });

      // Get sender info for notification title
      const senderName = await this.getSenderDisplayName(senderId, message.conversationId);

      // Build notification title and body
      const title = senderName;
      const body = this.buildNotificationBody(message);

      // Get conversation info
      const conversation = await this.conversationService.getConversation(
        message.conversationId,
        senderId,
      );
      const conversationTitle = conversation?.title ?? 'Nhắn tin';

      // Send notification to each member (except sender)
      for (const member of members) {
        if (member.userId === senderId) {
          continue; // Don't notify sender
        }

        const event: NotificationEventPayload = {
          eventId: uuidv4(),
          eventType: 'CHAT_MESSAGE',
          userId: member.userId,
          title: title,
          body: body,
          data: {
            conversationId: message.conversationId,
            conversationTitle: conversationTitle,
            messageId: message.id,
            senderId: senderId,
            senderName: senderName,
            messageType: message.messageType,
            mediaUrl: message.mediaUrl,
          },
          createdAt: new Date().toISOString(),
        };

        await this.kafkaProducer.publishNotification(event);
      }
    } catch (error) {
      this.logger.error(`Error publishing notification events: ${error.message}`);
    }
  }

  /**
   * Get sender's display name from conversation members.
   */
  private async getSenderDisplayName(
    senderId: string,
    conversationId: string,
  ): Promise<string> {
    try {
      const member = await this.memberRepo.findOne({
        where: { conversationId, userId: senderId },
      });
      if (member) {
        return (member as any).nickname ?? (member as any).user?.displayName ?? 'Someone';
      }
    } catch {
      // Fallback
    }
    return 'Someone';
  }

  /**
   * Build notification body based on message type.
   */
  private buildNotificationBody(message: Message): string {
    const textContent = message.content?.trim();

    switch (message.messageType) {
      case MessageType.IMAGE:
        return 'Đã gửi một hình ảnh';
      case MessageType.VIDEO:
        return 'Đã gửi một video';
      case MessageType.AUDIO:
        return 'Đã gửi một tin nhắn thoại';
      case MessageType.FILE:
        return 'Đã gửi một tệp tin';
      case MessageType.STICKER:
        return 'Đã gửi một nhãn dán';
      case MessageType.REPLY:
        return textContent ? `Trả lời: ${textContent}` : 'Đã gửi một tin nhắn';
      case MessageType.FORWARD:
        return textContent ?? 'Đã chuyển tiếp một tin nhắn';
      case MessageType.SYSTEM:
        return textContent ?? '';
      default:
        return textContent ?? 'Đã gửi một tin nhắn';
    }
  }

  /** Get paginated message history for a conversation (cursor-based on server_seq). */
  async getMessages(
    conversationId: string,
    userId: string,
    before?: number,
    limit = 50,
    access?: AccessPolicyContext,
    forceSync = false,
  ) {
    await this.conversationService.assertMember(conversationId, userId);

    const qb = this.messageRepo
      .createQueryBuilder('m')
      .where('m.conversation_id = :cid', { cid: conversationId })
      .andWhere(
        `NOT EXISTS (
          SELECT 1
          FROM block_list b
          WHERE ((b.blocker_id = :userId::uuid AND b.blocked_id = m.sender_id)
             OR (b.blocker_id = m.sender_id AND b.blocked_id = :userId::uuid))
            AND b.block_and_hide_logs = true
        )`,
        { userId },
      )
      .andWhere(
        `NOT (:userId::uuid = ANY(COALESCE(m.hidden_by_users, ARRAY[]::uuid[])))`,
        { userId },
      )
      .orderBy('m.server_seq', 'DESC')
      .take(Math.min(limit, 100));

    // Filter by history cleared threshold
    const inboxEntry = await this.inboxRepo.findOne({
      where: { userId, conversationId },
    });
    if (inboxEntry?.historyClearedAt) {
      qb.andWhere('m.created_at > :clearedAt', {
        clearedAt: inboxEntry.historyClearedAt,
      });
    }

    if (before !== undefined) {
      qb.andWhere('m.server_seq < :before', { before });
    }

    // Apply restricted mode only if sync hasn't been forced for this session/request
    if (this.isRestrictedWeb(access) && !forceSync) {
      const loginAt = this.resolveLoginTime(access?.loginAtEpochSec);
      qb.andWhere('m.created_at >= :loginAt', { loginAt });
    }

    return qb.getMany();
  }

  /**
   * Search messages in a conversation by keyword and/or media type.
   * Supports text content search (case-insensitive) and message type filtering.
   */
  async searchMessages(
    conversationId: string,
    userId: string,
    keyword?: string,
    messageType?: MessageType,
    limit = 50,
    offset = 0,
    access?: AccessPolicyContext,
  ) {
    await this.conversationService.assertMember(conversationId, userId);

    if (this.isRestrictedWeb(access)) {
      if (!messageType || !this.isDocumentMessageType(messageType)) {
        throw new ForbiddenException(
          'Restricted web session can only search My Documents.',
        );
      }
    }

    const qb = this.messageRepo
      .createQueryBuilder('m')
      .where('m.conversation_id = :cid', { cid: conversationId })
      .andWhere(
        `NOT EXISTS (
          SELECT 1
          FROM block_list b
          WHERE ((b.blocker_id = :userId::uuid AND b.blocked_id = m.sender_id)
             OR (b.blocker_id = m.sender_id AND b.blocked_id = :userId::uuid))
            AND b.block_and_hide_logs = true
        )`,
        { userId },
      )
      .andWhere('m.status != :recalled', { recalled: MessageStatus.RECALLED })
      .andWhere(
        `NOT (:userId::uuid = ANY(COALESCE(m.hidden_by_users, ARRAY[]::uuid[])))`,
        { userId },
      );

    if (this.isRestrictedWeb(access)) {
      const loginAt = this.resolveLoginTime(access?.loginAtEpochSec);
      qb.andWhere('m.created_at >= :loginAt', { loginAt }).andWhere(
        'm.sender_id = :uid',
        { uid: userId },
      );
    }

    if (keyword) {
      qb.andWhere('m.content ILIKE :keyword', { keyword: `%${keyword}%` });
    }

    if (messageType) {
      qb.andWhere('m.message_type = :type', { type: messageType });
    }

    qb.orderBy('m.server_seq', 'DESC').skip(offset).take(Math.min(limit, 100));

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  /** Edit a message. Only the sender can edit, and only text content. */
  async editMessage(
    userId: string,
    messageId: string,
    content: string,
  ): Promise<Message> {
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

  /**
   * Recall (soft-delete) a message. Only the sender can recall.
   * - Enforces 24-hour time limit
   * - Clears content and media URLs
   * - Removes associated pins and reactions
   * - Updates inbox preview if this was the latest message
   */
  async recallMessage(userId: string, messageId: string): Promise<Message> {
    const message = await this.findMessageOrFail(messageId);

    if (message.senderId !== userId) {
      const member = await this.memberRepo.findOne({
        where: { conversationId: message.conversationId, userId },
      });
      // ADMIN (group owner) and DEPUTY can recall any message in the group
      if (
        !member ||
        (member.role !== MemberRole.ADMIN && member.role !== MemberRole.DEPUTY)
      ) {
        throw new ForbiddenException(
          'You can only recall your own messages or you must be an Admin',
        );
      }
    }

    if (message.status === MessageStatus.RECALLED) {
      throw new BadRequestException('Message is already recalled');
    }

    // Enforce 24-hour recall time limit
    const timeSinceSent = Date.now() - message.createdAt.getTime();
    if (timeSinceSent > MessageService.RECALL_TIME_LIMIT_MS) {
      throw new BadRequestException(
        'Cannot recall messages older than 24 hours',
      );
    }

    message.status = MessageStatus.RECALLED;
    message.content = null;
    message.mediaUrl = null;
    message.mediaThumbnailUrl = null;
    message.mediaMimeType = null;
    message.mediaSizeBytes = null;

    const saved = await this.messageRepo.save(message);

    // Cleanup: remove any pin for this message
    await this.pinRepo.delete({ messageId: message.id });

    // Cleanup: remove all reactions for this message
    await this.reactionRepo.delete({ messageId: message.id });

    // Update inbox preview if this was the latest message in the conversation
    await this.updateInboxPreviewAfterRecall(message);

    return saved;
  }

  /** Pin a message in a conversation. Requires admin/owner or allowMemberPin. */
  async pinMessage(userId: string, conversationId: string, messageId: string) {
    await this.conversationService.assertCanPinMessage(conversationId, userId);
    const message = await this.findMessageOrFail(messageId);

    if (message.conversationId !== conversationId) {
      throw new BadRequestException(
        'Message does not belong to this conversation',
      );
    }

    if (message.status === MessageStatus.RECALLED) {
      throw new BadRequestException('Cannot pin a recalled message');
    }

    // Check if already pinned
    const existing = await this.pinRepo.findOne({
      where: { conversationId, messageId },
    });
    if (existing) throw new BadRequestException('Message is already pinned');

    const saved = await this.pinRepo.save({
      conversationId,
      messageId,
      serverSeq: message.serverSeq,
      pinnedBy: userId,
    });

    return this.pinRepo.findOne({
      where: { id: saved.id },
      relations: ['message'],
    });
  }

  /** Unpin a message from a conversation. */
  async unpinMessage(
    userId: string,
    conversationId: string,
    messageId: string,
  ) {
    await this.conversationService.assertCanPinMessage(conversationId, userId);

    const pin = await this.pinRepo.findOne({
      where: { conversationId, messageId },
    });
    if (!pin) throw new NotFoundException('Pin not found');

    await this.pinRepo.remove(pin);
  }

  /** Get all pinned messages in a conversation. */
  async getPinnedMessages(conversationId: string, userId: string) {
    await this.conversationService.assertMember(conversationId, userId);
    return this.pinRepo.find({
      where: { conversationId },
      relations: ['message'],
      order: { pinnedAt: 'DESC' },
    });
  }

  /** Add an emoji reaction to a message. Uses upsert to replace existing reaction. */
  async addReaction(userId: string, messageId: string, emoji: string) {
    const message = await this.findMessageOrFail(messageId);
    await this.conversationService.assertMember(message.conversationId, userId);

    if (message.status === MessageStatus.RECALLED) {
      throw new BadRequestException('Cannot react to a recalled message');
    }

    // Upsert: replace existing reaction from this user in a single operation
    await this.reactionRepo.upsert(
      {
        conversationId: message.conversationId,
        messageId,
        serverSeq: message.serverSeq,
        userId,
        emoji,
      },
      ['messageId', 'userId'],
    );

    return this.reactionRepo.findOne({ where: { messageId, userId } });
  }

  /** Remove user's reaction from a message. */
  async removeReaction(userId: string, messageId: string) {
    const result = await this.reactionRepo.delete({ messageId, userId });
    if (result.affected === 0)
      throw new NotFoundException('Reaction not found');
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
   * Updates the member's last_read_seq and computes accurate unread count.
   */
  async markAsRead(
    userId: string,
    conversationId: string,
    lastReadSeq: number,
  ) {
    const member = await this.conversationService.assertMember(
      conversationId,
      userId,
    );

    // Only update if we're advancing the read cursor
    if (lastReadSeq <= member.lastReadSeq) return;

    member.lastReadSeq = lastReadSeq;
    member.lastReadAt = new Date();
    await this.memberRepo.save(member);

    // Compute accurate unread count instead of blindly setting to 0
    const unreadCount = await this.messageRepo
      .createQueryBuilder('m')
      .where('m.conversation_id = :cid', { cid: conversationId })
      .andWhere('m.server_seq > :seq', { seq: lastReadSeq })
      .andWhere('m.sender_id != :uid', { uid: userId })
      .andWhere('m.status != :recalled', { recalled: MessageStatus.RECALLED })
      .getCount();

    await this.inboxRepo.update({ userId, conversationId }, { unreadCount });
  }

  // ─── Private Helpers ────────────────────────────────────────

  private async findMessageOrFail(messageId: string): Promise<Message> {
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!message) throw new NotFoundException('Message not found');
    return message;
  }

  /** Validate message content based on type. */
  private validateMessageContent(dto: SendMessageDto): void {
    const effectiveType = dto.messageType ?? MessageType.TEXT;

    if (effectiveType === MessageType.TEXT && !dto.content?.trim()) {
      throw new BadRequestException('Text messages must have content');
    }

    const mediaTypes = [
      MessageType.IMAGE,
      MessageType.VIDEO,
      MessageType.FILE,
      MessageType.AUDIO,
    ];
    if (mediaTypes.includes(effectiveType) && !dto.mediaUrl) {
      throw new BadRequestException(
        `${effectiveType} messages must have a mediaUrl`,
      );
    }
  }

  /**
   * Generate next sequence number for a conversation using Redis INCR.
   * Atomic operation — safe for concurrent and multi-instance use.
   */
  private async getNextSeq(conversationId: string): Promise<number> {
    const key = `conv:${conversationId}:seq`;

    // Check if key exists in Redis
    const exists = await this.redis.exists(key);

    if (!exists) {
      // Initialize from database: find the max seq for this conversation
      const result = await this.messageRepo
        .createQueryBuilder('m')
        .select('COALESCE(MAX(m.server_seq), 0)', 'maxSeq')
        .where('m.conversation_id = :cid', { cid: conversationId })
        .getRawOne<{ maxSeq: string }>();

      const currentMax = parseInt(result?.maxSeq ?? '0', 10);

      // SETNX: only set if key doesn't exist (prevents race condition)
      await this.redis.setnx(key, currentMax);
    }

    // INCR is atomic — guarantees unique sequence across all instances
    const next = await this.redis.incr(key);
    return next;
  }

  /**
   * Update conversation_inbox for all active members after a new message.
   * Uses batch INSERT ... ON CONFLICT for efficiency (1 query instead of N).
   * Runs within the caller's transaction manager.
   */
  private async updateInboxForMembersWithManager(
    manager: EntityManager,
    conversationId: string,
    message: Message,
    senderId: string,
  ) {
    const members = await manager.find(ConversationMember, {
      where: { conversationId, leftAt: IsNull() },
      select: ['userId'],
    });

    if (!members.length) return;

    const preview =
      message.content?.substring(0, 200) ?? `[${message.messageType}]`;

    // Build values and parameters for raw SQL batch upsert
    const params: any[] = [];
    const valueSets: string[] = [];
    let paramIdx = 1;

    for (const member of members) {
      const isSender = member.userId === senderId;
      valueSets.push(
        `($${paramIdx++}, $${paramIdx++}, $${paramIdx++}, $${paramIdx++}, $${paramIdx++}, $${paramIdx++}, $${paramIdx++}, $${paramIdx++}, false, NOW())`,
      );
      params.push(
        member.userId,
        conversationId,
        message.serverSeq,
        message.createdAt,
        preview,
        message.senderId,
        message.messageType,
        isSender ? 0 : 1, // Initial value for new inbox entries
      );
    }

    // Sender ID as the last parameter for CASE expression
    params.push(senderId);
    const senderParamIdx = paramIdx;

    // Single batch upsert with proper unread_count handling:
    // - INSERT (new row): 0 for sender, 1 for non-sender
    // - ON CONFLICT (existing row): 0 for sender, increment by 1 for non-sender
    const sql = `
      INSERT INTO conversation_inbox (
        user_id, conversation_id, last_message_seq, last_message_at,
        last_message_preview, last_message_sender_id, last_message_type,
        unread_count, is_hidden, updated_at
      ) VALUES ${valueSets.join(', ')}
      ON CONFLICT (user_id, conversation_id) DO UPDATE SET
        last_message_seq = EXCLUDED.last_message_seq,
        last_message_at = EXCLUDED.last_message_at,
        last_message_preview = EXCLUDED.last_message_preview,
        last_message_sender_id = EXCLUDED.last_message_sender_id,
        last_message_type = EXCLUDED.last_message_type,
        unread_count = CASE
          WHEN conversation_inbox.user_id = $${senderParamIdx} THEN 0
          ELSE conversation_inbox.unread_count + 1
        END,
        is_hidden = false,
        updated_at = NOW()
    `;

    await manager.query(sql, params);
  }

  /**
   * After recalling a message, update inbox preview if the recalled message
   * was the latest message in the conversation.
   */
  private async updateInboxPreviewAfterRecall(recalledMessage: Message) {
    // Find the previous non-recalled message
    const prevMessage = await this.messageRepo.findOne({
      where: {
        conversationId: recalledMessage.conversationId,
        status: MessageStatus.SENT,
      },
      order: { serverSeq: 'DESC' },
    });

    const newPreview = prevMessage
      ? (prevMessage.content?.substring(0, 200) ??
        `[${prevMessage.messageType}]`)
      : null;

    const newSeq = prevMessage?.serverSeq ?? 0;
    const newSenderId = prevMessage?.senderId ?? null;
    const newType = prevMessage?.messageType ?? null;
    const newAt = prevMessage?.createdAt ?? null;

    // Update all inbox entries for this conversation where the recalled message was the latest
    await this.inboxRepo
      .createQueryBuilder()
      .update(ConversationInbox)
      .set({
        lastMessagePreview: newPreview,
        lastMessageSeq: newSeq,
        lastMessageSenderId: newSenderId,
        lastMessageType: newType,
        lastMessageAt: newAt,
      })
      .where('conversation_id = :cid AND last_message_seq = :seq', {
        cid: recalledMessage.conversationId,
        seq: recalledMessage.serverSeq,
      })
      .execute();
  }

  /**
   * Hide a message for the user ("Xóa ở máy tôi").
   * Appends the userId to the hiddenByUsers array in the database.
   */
  async deleteForMe(userId: string, messageId: string): Promise<void> {
    const message = await this.findMessageOrFail(messageId);
    await this.conversationService.assertMember(message.conversationId, userId);

    // Use raw query for efficiently appending to the array without fetching it
    await this.dataSource.query(
      `UPDATE message
       SET hidden_by_users = array_append(COALESCE(hidden_by_users, ARRAY[]::uuid[]), $1::uuid)
       WHERE message_id = $2::uuid
         AND NOT ($1::uuid = ANY(COALESCE(hidden_by_users, ARRAY[]::uuid[])))`,
      [userId, messageId],
    );

    this.logger.log(`Message ${messageId} deleted for me by user ${userId}`);
  }

  private isRestrictedWeb(access?: AccessPolicyContext): boolean {
    if (!access) return false;
    return access.clientPlatform === 'WEB' && Boolean(access.restrictedWebMode);
  }

  private resolveLoginTime(epochSec?: number): Date {
    if (!epochSec || Number.isNaN(epochSec)) {
      return new Date(0);
    }
    return new Date(epochSec * 1000);
  }

  private isDocumentMessageType(messageType: MessageType): boolean {
    return [
      MessageType.FILE,
      MessageType.IMAGE,
      MessageType.VIDEO,
      MessageType.AUDIO,
    ].includes(messageType);
  }

  private async assertNotBlockedForSend(
    conversationId: string,
    userId: string,
  ): Promise<void> {
    const members = await this.memberRepo.find({
      where: { conversationId, leftAt: IsNull() },
      select: ['userId'],
    });
    const counterpartIds = (members ?? [])
      .map((member) => member.userId)
      .filter((memberId) => memberId !== userId);

    // Block semantics currently apply strictly to direct conversations.
    if (counterpartIds.length !== 1) {
      return;
    }

    const [counterpartId] = counterpartIds;
    const result = await this.dataSource.query(
      `SELECT EXISTS (
         SELECT 1
         FROM block_list b
         WHERE ((b.blocker_id = $1::uuid AND b.blocked_id = $2::uuid)
            OR (b.blocker_id = $2::uuid AND b.blocked_id = $1::uuid))
           AND b.block_messages = true
       ) AS blocked`,
      [userId, counterpartId],
    );
    if (Boolean(result?.[0]?.blocked)) {
      throw new ForbiddenException(
        'Cannot send message because one side has blocked the other.',
      );
    }
  }

  /**
   * G-009: Create a system-generated message (join/leave/kick/rename events).
   * Uses senderId = 'system' (a virtual sender ID) so UI can style it differently.
   * The message is persisted with MessageType.SYSTEM and assigned a server_seq.
   *
   * @param conversationId - the group conversation
   * @param content - human-readable system event text (e.g. "User X joined the group")
   * @returns the persisted system Message entity
   */
  async createSystemMessage(
    conversationId: string,
    content: string,
    targetRoles?: MemberRole[],
  ): Promise<Message> {
    const serverSeq = await this.getNextSeq(conversationId);

    const saved = await this.dataSource.transaction(async (manager) => {
      const msg = manager.create(Message, {
        conversationId,
        serverSeq,
        senderId: null,
        clientMessageId: null,
        messageType: MessageType.SYSTEM,
        content,
        status: MessageStatus.SENT,
      });

      const persisted = await manager.save(msg);

      // Update inbox for members. If targetRoles is set, filter by role.
      const query = manager.createQueryBuilder(ConversationMember, 'member')
        .where('member.conversationId = :cid AND member.leftAt IS NULL', { cid: conversationId });
      
      if (targetRoles && targetRoles.length > 0) {
        query.andWhere('member.role IN (:...roles)', { roles: targetRoles });
      }

      const activeMembers = await query.getMany();

      for (const member of activeMembers) {
        await manager
          .createQueryBuilder()
          .update(ConversationInbox)
          .set({
            lastMessageSeq: serverSeq,
            unreadCount: () => 'unread_count + 1',
          })
          .where('userId = :uid AND conversationId = :cid', {
            uid: member.userId,
            cid: conversationId,
          })
          .execute();
      }

      return persisted;
    });

    this.logger.log(
      `[MessageService.systemMsg] Created system message seq=${serverSeq} conv=${conversationId}: "${content}"`,
    );
    return saved;
  }
}
