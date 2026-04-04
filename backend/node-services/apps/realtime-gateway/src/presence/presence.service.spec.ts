import { PresenceService } from './presence.service';

describe('PresenceService', () => {
  const redis = {
    hset: jest.fn(),
    expire: jest.fn(),
    sadd: jest.fn(),
    srem: jest.fn(),
    smembers: jest.fn(),
    exists: jest.fn(),
    set: jest.fn(),
    del: jest.fn(),
    hgetall: jest.fn(),
  };

  let service: PresenceService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PresenceService(redis as any);
  });

  it('setOnline should set presence ttl to heartbeat window', async () => {
    await service.setOnline('user-1', 'socket-1');
    expect(redis.expire).toHaveBeenCalledWith('presence:user-1', 60);
  });

  it('heartbeat should refresh ttl to heartbeat window', async () => {
    redis.exists.mockResolvedValue(1);
    await service.heartbeat('user-1');
    expect(redis.expire).toHaveBeenCalledWith('presence:user-1', 60);
  });

  it('getTypingUsers should read from conversation typing set', async () => {
    redis.smembers.mockResolvedValue(['u1', 'u2']);
    const users = await service.getTypingUsers('conv-1');
    expect(redis.smembers).toHaveBeenCalledWith('typing:conv-1:users');
    expect(users).toEqual(['u1', 'u2']);
  });
});
