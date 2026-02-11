import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
  ) {}

  /**
   * Get user's conversation inbox: sorted by pinned first, then by latest message.
   * Joins conversation details for display (title, avatar, type).
   */
  async getInbox(userId: string, limit = 50, offset = 0) {
    const inbox = await this.inboxRepo.find({
      where: { userId, isHidden: false },
      order: { isPinned: 'DESC', lastMessageSeq: 'DESC' },
      take: Math.min(limit, 100),
      skip: offset,
    });

    // Enrich with conversation details
    const result = await Promise.all(
      inbox.map(async (entry) => {
        const conversation = await this.conversationRepo.findOne({
          where: { id: entry.conversationId },
        });
        return {
          ...entry,
          conversation: conversation
            ? {
                id: conversation.id,
                type: conversation.type,
                title: conversation.title,
                avatarUrl: conversation.avatarUrl,
                status: conversation.status,
              }
            : null,
        };
      }),
    );

    return result;
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
