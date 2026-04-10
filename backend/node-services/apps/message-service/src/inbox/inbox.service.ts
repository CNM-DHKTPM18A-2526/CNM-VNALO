import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { Conversation } from '../entities/conversation.entity';
import { ConversationMember } from '../entities/conversation-member.entity';

type AccessPolicyContext = {
  clientPlatform?: string;
  restrictedWebMode?: boolean;
  loginAtEpochSec?: number;
};

@Injectable()
export class InboxService {
  private readonly logger = new Logger(InboxService.name);

  constructor(
    @InjectRepository(ConversationInbox)
    private readonly inboxRepo: Repository<ConversationInbox>,
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
  ) { }

  /**
   * Get user's conversation inbox: sorted by pinned first, then by latest message.
   * Uses batch query (IN clause) instead of N+1 pattern for conversation details.
   */
  async getInbox(userId: string, limit = 50, offset = 0, access?: AccessPolicyContext) {
    const qb = this.inboxRepo
      .createQueryBuilder('inbox')
      .where('inbox.user_id = :userId', { userId })
      .andWhere('inbox.is_hidden = false')
      .orderBy('inbox.is_pinned', 'DESC')
      .addOrderBy('inbox.last_message_seq', 'DESC')
      .take(Math.min(limit, 100))
      .skip(offset);

    const restrictedWeb = this.isRestrictedWeb(access);
    if (restrictedWeb) {
      const loginAt = this.resolveLoginTime(access?.loginAtEpochSec);
      qb.andWhere('(inbox.is_pinned = true OR inbox.last_message_at >= :loginAt)', { loginAt });
    }

    const inbox = await qb.getMany();

    if (inbox.length === 0) return [];

    // Batch fetch all conversation details in a single query (fixes N+1)
    const convIds = inbox.map((e) => e.conversationId);
    const conversations = await this.conversationRepo.find({
      where: { id: In(convIds) },
    });

    // Batch fetch active members for all conversations
    const members = await this.memberRepo.find({
      where: { conversationId: In(convIds), leftAt: IsNull() },
    });

    // Build O(1) lookup maps
    const convMap = new Map(conversations.map((c) => [c.id, c]));
    const memberMap = new Map<string, { userId: string; role: string; nickname: string | null }[]>();
    for (const m of members) {
      const list = memberMap.get(m.conversationId) ?? [];
      list.push({ userId: m.userId, role: m.role, nickname: m.nickname });
      memberMap.set(m.conversationId, list);
    }

    // Enrich inbox entries with conversation details and members
    return inbox.map((entry) => {
      const conv = convMap.get(entry.conversationId);
      return {
        ...entry,
        isFavorite: entry.isFavorite,
        autoDeleteSeconds: entry.autoDeleteSeconds,
        notifyCall: entry.notifyCall,
        personalWallpaperUrl: entry.wallpaperUrl,
        lastMessagePreview: restrictedWeb ? 'Noi dung duoc an tren web do chinh sach dong bo.' : entry.lastMessagePreview,
        conversation: conv
          ? {
            id: conv.id,
            type: conv.type,
            title: conv.title,
            avatarUrl: conv.avatarUrl,
            status: conv.status,
            members: memberMap.get(conv.id) ?? [],
          }
          : null,
      };
    });
  }

  /** Get total unread message count across all conversations. */
  async getTotalUnreadCount(userId: string, access?: AccessPolicyContext): Promise<number> {
    if (this.isRestrictedWeb(access)) {
      return 0;
    }

    const { total } = await this.inboxRepo
      .createQueryBuilder('inbox')
      .select('COALESCE(SUM(inbox.unread_count), 0)', 'total')
      .where('inbox.user_id = :userId', { userId })
      .getRawOne();

    return parseInt(total, 10);
  }

  /** Update personal settings for a conversation. */
  async updateSettings(userId: string, conversationId: string, settings: any) {
    const entry = await this.inboxRepo.findOne({ where: { userId, conversationId } });
    if (!entry) return null;

    if (settings.isPinned !== undefined) entry.isPinned = settings.isPinned;
    if (settings.isMuted !== undefined) entry.isMuted = settings.isMuted;
    if (settings.isHidden !== undefined) entry.isHidden = settings.isHidden;
    if (settings.isFavorite !== undefined) entry.isFavorite = settings.isFavorite;
    if (settings.autoDeleteSeconds !== undefined) entry.autoDeleteSeconds = settings.autoDeleteSeconds;
    if (settings.notifyCall !== undefined) entry.notifyCall = settings.notifyCall;
    if (settings.wallpaperUrl !== undefined) entry.wallpaperUrl = settings.wallpaperUrl;

    return this.inboxRepo.save(entry);
  }

  /** Hide conversation history for the user by setting the clear threshold. */
  async clearHistory(userId: string, conversationId: string) {
    const entry = await this.inboxRepo.findOne({ where: { userId, conversationId } });
    if (!entry) return null;

    entry.historyClearedAt = new Date();
    // Also clear unread count as history is "gone"
    entry.unreadCount = 0;
    entry.lastMessagePreview = null;
    
    return this.inboxRepo.save(entry);
  }

  private isRestrictedWeb(access?: AccessPolicyContext): boolean {
    if (!access) {
      return false;
    }
    const platform = (access.clientPlatform ?? 'WEB').toUpperCase();
    return Boolean(access.restrictedWebMode) && (platform === 'WEB' || platform === 'PC');
  }

  private resolveLoginTime(epochSec?: number): Date {
    if (!epochSec || Number.isNaN(epochSec)) {
      return new Date(0);
    }
    return new Date(epochSec * 1000);
  }
}
