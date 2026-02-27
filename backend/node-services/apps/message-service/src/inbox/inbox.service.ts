import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { Conversation } from '../entities/conversation.entity';

@Injectable()
export class InboxService {
  private readonly logger = new Logger(InboxService.name);

  constructor(
    @InjectRepository(ConversationInbox)
    private readonly inboxRepo: Repository<ConversationInbox>,
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
  ) { }

  /**
   * Get user's conversation inbox: sorted by pinned first, then by latest message.
   * Uses batch query (IN clause) instead of N+1 pattern for conversation details.
   */
  async getInbox(userId: string, limit = 50, offset = 0) {
    const inbox = await this.inboxRepo.find({
      where: { userId, isHidden: false },
      order: { isPinned: 'DESC', lastMessageSeq: 'DESC' },
      take: Math.min(limit, 100),
      skip: offset,
    });

    if (inbox.length === 0) return [];

    // Batch fetch all conversation details in a single query (fixes N+1)
    const convIds = inbox.map((e) => e.conversationId);
    const conversations = await this.conversationRepo.find({
      where: { id: In(convIds) },
    });

    // Build O(1) lookup map
    const convMap = new Map(conversations.map((c) => [c.id, c]));

    // Enrich inbox entries with conversation details
    return inbox.map((entry) => {
      const conv = convMap.get(entry.conversationId);
      return {
        ...entry,
        conversation: conv
          ? {
            id: conv.id,
            type: conv.type,
            title: conv.title,
            avatarUrl: conv.avatarUrl,
            status: conv.status,
          }
          : null,
      };
    });
  }

  /** Get total unread message count across all conversations. */
  async getTotalUnreadCount(userId: string): Promise<number> {
    const { total } = await this.inboxRepo
      .createQueryBuilder('inbox')
      .select('COALESCE(SUM(inbox.unread_count), 0)', 'total')
      .where('inbox.user_id = :userId', { userId })
      .getRawOne();

    return parseInt(total, 10);
  }
}
