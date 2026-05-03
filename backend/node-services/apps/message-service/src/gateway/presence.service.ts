import { Injectable, Logger } from '@nestjs/common';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';

const PRESENCE_KEY = (userId: string) => `presence:${userId}`;
const ONLINE_SET = 'presence:online';
const TTL_SECONDS = 60;

@Injectable()
export class PresenceService {
  private readonly logger = new Logger(PresenceService.name);

  constructor(
    @InjectRedis() private readonly redis: Redis,
  ) {
    this.logger.log(`PresenceService initialized with shared Redis client`);
  }

  /** Mark a user as online and save their socketId */
  async setOnline(userId: string, socketId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    await this.redis.hset(key, {
      status: 'online',
      socketId,
      lastSeen: new Date().toISOString(),
    });
    await this.redis.expire(key, TTL_SECONDS);
    await this.redis.sadd(ONLINE_SET, userId);
    this.logger.debug(`[Presence] SET ONLINE: ${userId} (socket: ${socketId})`);
  }

  /** Mark a user as offline and save lastSeen */
  async setOffline(userId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    await this.redis.hset(key, {
      status: 'offline',
      lastSeen: new Date().toISOString(),
    });
    await this.redis.expire(key, 86400);
    await this.redis.srem(ONLINE_SET, userId);
    this.logger.debug(`[Presence] SET OFFLINE: ${userId}`);
  }

  /** Extend TTL when user sends heartbeat */
  async heartbeat(userId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    const exists = await this.redis.exists(key);
    if (exists) {
      await this.redis.expire(key, TTL_SECONDS);
      await this.redis.hset(key, 'lastSeen', new Date().toISOString());
    }
  }

  /** Get presence of a single user */
  async getPresence(userId: string): Promise<{
    userId: string;
    status: string;
    lastSeen: string | null;
  }> {
    const data = await this.redis.hgetall(PRESENCE_KEY(userId));
    return {
      userId,
      status: data?.status || 'offline',
      lastSeen: data?.lastSeen || null,
    };
  }

  /** Get presence of multiple users */
  async getBulkPresence(userIds: string[]): Promise<Array<{
    userId: string;
    status: string;
    lastSeen: string | null;
  }>> {
    if (userIds.length === 0) return [];
    const pipeline = this.redis.pipeline();
    for (const uid of userIds) {
      pipeline.hgetall(PRESENCE_KEY(uid));
    }
    const results = await pipeline.exec();
    return userIds.map((userId, idx) => {
      const data = results?.[idx]?.[1] as Record<string, string> | null;
      return {
        userId,
        status: data?.status || 'offline',
        lastSeen: data?.lastSeen || null,
      };
    });
  }

  /** Get all currently online user IDs */
  async getOnlineUsers(): Promise<string[]> {
    return this.redis.smembers(ONLINE_SET);
  }
}
