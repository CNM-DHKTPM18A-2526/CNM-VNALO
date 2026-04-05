import { JwtService } from '@nestjs/jwt';
import { RealtimeGateway } from './realtime.gateway';
import { PresenceService } from '../presence/presence.service';

describe('RealtimeGateway', () => {
  let gateway: RealtimeGateway;
  let jwtService: jest.Mocked<JwtService>;
  let presenceService: jest.Mocked<PresenceService>;

  beforeEach(() => {
    jwtService = { verify: jest.fn() } as unknown as jest.Mocked<JwtService>;
    presenceService = {
      setOnline: jest.fn(),
      setOffline: jest.fn(),
      getPresence: jest.fn(),
      getBulkPresence: jest.fn(),
      heartbeat: jest.fn(),
      setTyping: jest.fn(),
    } as unknown as jest.Mocked<PresenceService>;
    gateway = new RealtimeGateway(jwtService, presenceService);
  });

  it('rejects connection without token', async () => {
    const client = {
      id: 'socket-1',
      handshake: { auth: {}, query: {} },
      disconnect: jest.fn(),
      data: {},
    } as any;

    await gateway.handleConnection(client);
    expect(client.disconnect).toHaveBeenCalled();
    expect(presenceService.setOnline).not.toHaveBeenCalled();
  });

  it('accepts valid token and sets user online', async () => {
    const client = {
      id: 'socket-2',
      handshake: { auth: { token: 'token' } },
      disconnect: jest.fn(),
      data: {},
    } as any;
    jwtService.verify.mockReturnValue({ sub: 'user-1', phone: '123' } as any);

    await gateway.handleConnection(client);

    expect(client.disconnect).not.toHaveBeenCalled();
    expect(client.data.user.userId).toBe('user-1');
    expect(presenceService.setOnline).toHaveBeenCalledWith('user-1', 'socket-2');
  });
});
