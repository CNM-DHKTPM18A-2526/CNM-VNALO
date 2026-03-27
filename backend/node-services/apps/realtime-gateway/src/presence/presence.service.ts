import { Injectable } from '@nestjs/common';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';

const PRESENCE_KEY = (userId: string) => `presence:${userId}`;
const ONLINE_SET = 'presence:online';
const TTL_SECONDS = 60; // heartbeat, auto-expire if no ping

@Injectable()
export class PresenceService {
  constructor(@InjectRedis() private readonly redis: Redis) {}

  /** Đánh dấu user online, lưu socketId để multi-device */
  async setOnline(userId: string, socketId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    await this.redis.hset(key, {
      status: 'online',
      socketId,
      lastSeen: new Date().toISOString(),
    });
    await this.redis.expire(key, TTL_SECONDS * 5); // 5 phút TTL
    await this.redis.sadd(ONLINE_SET, userId);
  }

  /** Đánh dấu user offline, lưu lastSeen */
  async setOffline(userId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    await this.redis.hset(key, {
      status: 'offline',
      lastSeen: new Date().toISOString(),
    });
    // Giữ lại lastSeen 24 tiếng
    await this.redis.expire(key, 86400);
    await this.redis.srem(ONLINE_SET, userId);
  }

  /** Gia hạn TTL khi user còn active (heartbeat) */
  async heartbeat(userId: string): Promise<void> {
    const key = PRESENCE_KEY(userId);
    const exists = await this.redis.exists(key);
    if (exists) {
      await this.redis.expire(key, TTL_SECONDS * 5);
      await this.redis.hset(key, 'lastSeen', new Date().toISOString());
    }
  }

  /** Lấy trạng thái presence của 1 user */
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

  /** Lấy bulk presence của nhiều user */
  async getBulkPresence(userIds: string[]): Promise<
    { userId: string; status: string; lastSeen: string | null }[]
  > {
    return Promise.all(userIds.map((id) => this.getPresence(id)));
  }

  /** Lấy danh sách tất cả user đang online */
  async getOnlineUsers(): Promise<string[]> {
    return this.redis.smembers(ONLINE_SET);
  }

  /** Cập nhật typing indicator (expire nhanh 5 giây) */
  async setTyping(userId: string, conversationId: string, isTyping: boolean): Promise<void> {
    const key = `typing:${conversationId}:${userId}`;
    if (isTyping) {
      await this.redis.set(key, '1', 'EX', 5);
    } else {
      await this.redis.del(key);
    }
  }

  /** Lấy danh sách ai đang gõ trong conversation */
  async getTypingUsers(conversationId: string): Promise<string[]> {
    // Scan pattern typing:{conversationId}:*
    const keys = await this.redis.keys(`typing:${conversationId}:*`);
    return keys.map((k) => k.split(':')[2]);
  }
}
