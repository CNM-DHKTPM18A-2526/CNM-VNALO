import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PresenceService } from '../presence/presence.service';

/**
 * realtime-gateway — WebSocket Gateway (port 8085, namespace /realtime)
 *
 * Events từ client:
 *   conversation.join    → vào room để nhận message
 *   conversation.leave   → rời room
 *   presence.get         → lấy presence của danh sách users
 *   typing.start         → bắt đầu gõ
 *   typing.stop          → dừng gõ
 *   heartbeat            → giữ presence alive
 *
 * Events server emit:
 *   presence.changed     → { userId, status, lastSeen }
 *   typing.changed       → { userId, conversationId, isTyping }
 *   message.received     → message mới từ RabbitMQ broadcast
 *   message.recalled     → tin nhắn bị thu hồi
 */
@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
  transports: ['websocket', 'polling'],
  // Explicit ping/pong timeouts — prevents load-balancer/proxy from closing idle connections.
  // pingInterval (how often server sends a ping) < pingTimeout (how long client waits for pong).
  pingTimeout: 60000,    // 60s — server-side wait for pong before considering connection dead
  pingInterval: 25000,   // 25s — server sends ping every 25s
})
export class RealtimeGateway
  implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  /** userId → Set<socketId> (đa thiết bị) — kept for multi-device count on THIS node only */
  private readonly userSockets = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly presenceService: PresenceService,
  ) { }

  // ─── Connection Lifecycle ────────────────────────────────────────────

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake?.auth?.token ||
        (client.handshake?.query?.token as string);

      if (!token) {
        this.logger.warn(`Connection rejected — no token: ${client.id}`);
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token);
      const userId: string = payload.sub;

      client.data.user = { userId, phone: payload.phone };

      // B-01: Join user's personal room so emitToUser can work across all nodes
      await client.join(`user:${userId}`);

      // Theo dõi socket theo userId (for multi-device count on this node only)
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(client.id);

      // Lưu presence online vào Redis
      await this.presenceService.setOnline(userId, client.id);

      // Chỉ thông báo tới các rooms mà user đang có mặt (không broadcast toàn bộ)
      // — sẽ notify sau khi user join conversation room

      this.logger.log(`Connected: ${client.id} (user: ${userId})`);
    } catch (err) {
      this.logger.warn(`Connection rejected: ${err.message}`);
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data?.user?.userId;
    if (userId) {
      const sockets = this.userSockets.get(userId);
      sockets?.delete(client.id);

      // B-01: Leave user's personal room (Redis adapter auto-cleans socket from room on disconnect)
      await client.leave(`user:${userId}`);

      // Chỉ offline nếu không còn socket nào active
      if (!sockets || sockets.size === 0) {
        this.userSockets.delete(userId);
        await this.presenceService.setOffline(userId);
        const presence = await this.presenceService.getPresence(userId);

        // Chỉ notify tới các conversation rooms user từng ở — không broadcast toàn cầu
        const presenceEvent = {
          userId,
          status: 'offline',
          lastSeen: presence.lastSeen,
        };
        for (const room of client.rooms) {
          if (room.startsWith('conversation:')) {
            this.server.to(room).emit('presence.changed', presenceEvent);
          }
        }
      }
    }
    this.logger.log(`Disconnected: ${client.id}`);
  }

  // ─── Room Management ─────────────────────────────────────────────────

  @SubscribeMessage('conversation.join')
  async handleJoinConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    // Giới hạn số rooms để tránh memory leak
    const MAX_ROOMS = 50;
    const currentRooms = [...client.rooms].filter((r) =>
      r.startsWith('conversation:'),
    );
    if (currentRooms.length >= MAX_ROOMS) {
      return {
        event: 'error',
        data: { message: 'Exceeded max conversation limit' },
      };
    }

    const room = `conversation:${data.conversationId}`;
    await client.join(room);
    this.logger.debug(`${client.data.user.userId} joined ${room}`);

    // Notify presence online khi vào room
    this.server.to(room).emit('presence.changed', {
      userId: client.data.user.userId,
      status: 'online',
      lastSeen: new Date().toISOString(),
    });

    return {
      event: 'conversation.joined',
      data: { conversationId: data.conversationId },
    };
  }

  @SubscribeMessage('conversation.leave')
  async handleLeaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const room = `conversation:${data.conversationId}`;
    await client.leave(room);
    return {
      event: 'conversation.left',
      data: { conversationId: data.conversationId },
    };
  }

  // ─── Presence ─────────────────────────────────────────────────────────

  @SubscribeMessage('presence.get')
  async handleGetPresence(@MessageBody() data: { userIds: string[] }) {
    const presenceList = await this.presenceService.getBulkPresence(
      data.userIds,
    );
    return { event: 'presence.list', data: presenceList };
  }

  // Handles 'presence.set' emitted by Flutter client (also extends Redis TTL like heartbeat)
  @SubscribeMessage('presence.set')
  async handlePresenceSet(@ConnectedSocket() client: Socket, @MessageBody() data: { isOnline: boolean }) {
    const userId = client.data?.user?.userId;
    if (userId && data.isOnline) {
      await this.presenceService.heartbeat(userId);
    }
    return { event: 'presence.set.ack' };
  }

  @SubscribeMessage('heartbeat')
  async handleHeartbeat(@ConnectedSocket() client: Socket) {
    const userId = client.data?.user?.userId;
    if (userId) {
      await this.presenceService.heartbeat(userId);
    }
    return { event: 'heartbeat.ack' };
  }

  // ─── Typing ───────────────────────────────────────────────────────────

  @SubscribeMessage('typing.start')
  async handleTypingStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const userId = client.data.user.userId;
    await this.presenceService.setTyping(userId, data.conversationId, true);
    const room = `conversation:${data.conversationId}`;
    client.to(room).emit('typing.changed', {
      userId,
      conversationId: data.conversationId,
      isTyping: true,
    });
  }

  @SubscribeMessage('typing.stop')
  async handleTypingStop(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const userId = client.data.user.userId;
    await this.presenceService.setTyping(userId, data.conversationId, false);
    const room = `conversation:${data.conversationId}`;
    client.to(room).emit('typing.changed', {
      userId,
      conversationId: data.conversationId,
      isTyping: false,
    });
  }

  // ─── Broadcast utils (dùng bởi RabbitMQ consumer) ────────────────────

  /** Broadcast tới tất cả client trong 1 room */
  broadcastToRoom(room: string, event: string, data: any) {
    this.server.to(room).emit(event, data);
  }

  /** Emit event tới 1 user cụ thể (đa thiết bị) — works cross-node via Redis user:{userId} room */
  emitToUser(userId: string, event: string, data: any) {
    // B-01: Use Redis-backed user room instead of in-memory Map.
    // With RedisIoAdapter, `server.to('user:${userId}')` reaches ALL sockets of that user
    // across ALL gateway nodes.
    this.server.to(`user:${userId}`).emit(event, data);
  }

  isUserOnline(userId: string): boolean {
    return (
      this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0
    );
  }

  // ─── Group Call Signaling ─────────────────────────────────────────────
  // Tất cả event group-call:* đều được relay qua đây.
  // KHÔNG đụng vào logic call đơn (call:*, offer, answer...).

  /**
   * Caller phát tín hiệu bắt đầu cuộc gọi nhóm.
   * Server relay tới TẤT CẢ thành viên trong conversation room (trừ caller).
   */
  @SubscribeMessage('group-call:started')
  handleGroupCallStarted(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      conversationName: string;
      callId: string;
      callerUserId: string;
      callerName: string;
      callerAvatar?: string;
      audioOnly: boolean;
    },
  ) {
    const room = `conversation:${data.conversationId}`;
    this.logger.log(
      `[GroupCall] group-call:started from ${data.callerUserId} in ${room}`,
    );
    // Broadcast tới tất cả thành viên trong room, TRỪ người gửi
    client.to(room).emit('group-call:started', data);
  }

  /**
   * Thành viên tham gia phòng gọi.
   * Server relay group-call:user-joined tới tất cả người đang trong room.
   * Những người đó sẽ tạo offer tới người vừa join.
   */
  @SubscribeMessage('group-call:join')
  handleGroupCallJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
      displayName: string;
      avatarUrl?: string;
      audioOnly: boolean;
    },
  ) {
    const room = `conversation:${data.conversationId}`;
    this.logger.log(
      `[GroupCall] group-call:join from ${data.senderUserId} in ${room}`,
    );
    // Relay tới TẤT CẢ người trong room (trừ người join) dưới dạng user-joined
    client.to(room).emit('group-call:user-joined', data);
  }

  /**
   * Relay WebRTC offer từ A → B (point-to-point).
   * Chỉ gửi tới targetUserId.
   */
  @SubscribeMessage('group-call:offer')
  handleGroupCallOffer(
    @ConnectedSocket() _client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
      targetUserId: string;
      displayName?: string;
      avatarUrl?: string;
      sdp: any;
    },
  ) {
    this.logger.debug(
      `[GroupCall] offer ${data.senderUserId} → ${data.targetUserId}`,
    );
    this.emitToUser(data.targetUserId, 'group-call:offer', data);
  }

  /**
   * Relay WebRTC answer từ B → A (point-to-point).
   */
  @SubscribeMessage('group-call:answer')
  handleGroupCallAnswer(
    @ConnectedSocket() _client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
      targetUserId: string;
      sdp: any;
    },
  ) {
    this.logger.debug(
      `[GroupCall] answer ${data.senderUserId} → ${data.targetUserId}`,
    );
    this.emitToUser(data.targetUserId, 'group-call:answer', data);
  }

  /**
   * Relay ICE candidate từ A → B (point-to-point).
   */
  @SubscribeMessage('group-call:ice-candidate')
  handleGroupCallIce(
    @ConnectedSocket() _client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
      targetUserId: string;
      candidate: any;
    },
  ) {
    this.emitToUser(data.targetUserId, 'group-call:ice-candidate', data);
  }

  /**
   * Thành viên rời phòng gọi.
   * Relay tới tất cả người trong room dưới dạng user-left.
   */
  @SubscribeMessage('group-call:leave')
  handleGroupCallLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
    },
  ) {
    const room = `conversation:${data.conversationId}`;
    this.logger.log(
      `[GroupCall] group-call:leave from ${data.senderUserId} in ${room}`,
    );
    client.to(room).emit('group-call:user-left', data);
  }

  /**
   * Cuộc gọi kết thúc hoàn toàn (người cuối rời).
   * Broadcast tới toàn bộ room để dismiss banner cho người chưa bắt máy.
   */
  @SubscribeMessage('group-call:ended')
  handleGroupCallEnded(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      endedByUserId: string;
    },
  ) {
    const room = `conversation:${data.conversationId}`;
    this.logger.log(
      `[GroupCall] group-call:ended by ${data.endedByUserId} in ${room}`,
    );
    // Broadcast tới TẤT CẢ (kể cả người gửi) để đảm bảo không ai còn banner
    this.server.to(room).emit('group-call:ended', data);
  }

  // ─── Minimal 1-1 Call Relay ────────────────────────────────────────
  @SubscribeMessage('call.offer')
  handleCallOffer(@ConnectedSocket() _c: Socket, @MessageBody() data: any) {
    this.emitToUser(data.targetUserId, 'call.offer', data);
  }

  @SubscribeMessage('call.answer')
  handleCallAnswer(@ConnectedSocket() _c: Socket, @MessageBody() data: any) {
    this.emitToUser(data.targetUserId, 'call.answer', data);
  }

  @SubscribeMessage('call.ice-candidate')
  handleIceCandidate(@ConnectedSocket() _c: Socket, @MessageBody() data: any) {
    this.emitToUser(data.targetUserId, 'call.ice-candidate', data);
  }

  @SubscribeMessage('call.end')
  handleCallEnd(@ConnectedSocket() _c: Socket, @MessageBody() data: any) {
    this.emitToUser(data.targetUserId, 'call.end', data);
  }
}
