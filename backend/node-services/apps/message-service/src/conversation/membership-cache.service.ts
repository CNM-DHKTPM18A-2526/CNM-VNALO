import { Injectable, Logger } from '@nestjs/common';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import { ConversationMember } from '../entities/conversation-member.entity';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';

@Injectable()
export class MembershipCacheService {
  private readonly logger = new Logger(MembershipCacheService.name);
  private readonly TTL = 5; // Reduced to 5s (V-09) to minimize ghost windows
  
  // V-06: Simple Circuit Breaker state
  private lastFailureTime = 0;
  private failureCount = 0;
  private readonly FAILURE_THRESHOLD = 5;
  private readonly CIRCUIT_BREAKER_COOLDOWN = 60000; // 60 seconds

  constructor(
    @InjectRedis() private readonly redis: Redis,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
  ) {}

  private isCircuitOpen(): boolean {
    if (this.failureCount >= this.FAILURE_THRESHOLD) {
      const now = Date.now();
      if (now - this.lastFailureTime < this.CIRCUIT_BREAKER_COOLDOWN) {
        return true;
      }
      // Reset after cooldown
      this.failureCount = 0;
    }
    return false;
  }

  private handleRedisError(err: Error) {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    this.logger.warn(`Redis error (${this.failureCount}): ${err.message}`);
  }

  private getCacheKey(conversationId: string, userId: string): string {
    return `membership:${conversationId}:${userId}`;
  }

  /**
   * Get active membership from cache or DB.
   * V-05 Fix: Revive Date strings into Date objects.
   * V-06 Fix: Circuit breaker protection.
   */
  async getActiveMember(conversationId: string, userId: string): Promise<ConversationMember | null> {
    if (this.isCircuitOpen()) return this.fetchFromDb(conversationId, userId);

    const key = this.getCacheKey(conversationId, userId);
    try {
      const cached = await this.redis.get(key);
      if (cached) {
        this.failureCount = 0; // Success: reset circuit
        return JSON.parse(cached, (key, value) => {
          if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(value)) {
            return new Date(value);
          }
          return value;
        });
      }
    } catch (err) {
      this.handleRedisError(err);
    }

    const member = await this.fetchFromDb(conversationId, userId);
    if (member) await this.updateCache(conversationId, userId, member);
    return member;
  }

  private async fetchFromDb(conversationId: string, userId: string): Promise<ConversationMember | null> {
    return this.memberRepo.findOne({
      where: { conversationId, userId, leftAt: IsNull() },
    });
  }

  /**
   * Manual pre-warm or update of cache (V-11).
   */
  async updateCache(conversationId: string, userId: string, member: ConversationMember): Promise<void> {
    if (this.isCircuitOpen()) return;
    const key = this.getCacheKey(conversationId, userId);
    try {
      await this.redis.setex(key, this.TTL, JSON.stringify(member));
      this.failureCount = 0;
    } catch (err) {
      this.handleRedisError(err);
    }
  }

  /**
   * Invalidate membership cache.
   */
  async invalidate(conversationId: string, userId: string): Promise<void> {
    if (this.isCircuitOpen()) return;
    const key = this.getCacheKey(conversationId, userId);
    try {
      await this.redis.del(key);
      this.failureCount = 0;
    } catch (err) {
      this.handleRedisError(err);
    }
  }
}
