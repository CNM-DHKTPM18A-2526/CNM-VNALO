import {
  WebSocketGateway, WebSocketServer,
  SubscribeMessage, OnGatewayConnection, OnGatewayDisconnect,
  MessageBody, ConnectedSocket,
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
  namespace: '/realtime',
  transports: ['websocket', 'polling'],
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  /** userId → Set<socketId> (đa thiết bị) */
  private readonly userSockets = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly presenceService: PresenceService,
  ) {}

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

      // Theo dõi socket theo userId
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
    const currentRooms = [...client.rooms].filter(r => r.startsWith('conversation:'));
    if (currentRooms.length >= MAX_ROOMS) {
      return { event: 'error', data: { message: 'Exceeded max conversation limit' } };
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

    return { event: 'conversation.joined', data: { conversationId: data.conversationId } };
  }

  @SubscribeMessage('conversation.leave')
  async handleLeaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const room = `conversation:${data.conversationId}`;
    await client.leave(room);
    return { event: 'conversation.left', data: { conversationId: data.conversationId } };
  }

  // ─── Presence ─────────────────────────────────────────────────────────

  @SubscribeMessage('presence.get')
  async handleGetPresence(
    @MessageBody() data: { userIds: string[] },
  ) {
    const presenceList = await this.presenceService.getBulkPresence(data.userIds);
    return { event: 'presence.list', data: presenceList };
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

  /** Emit event tới 1 user cụ thể (đa thiết bị) */
  emitToUser(userId: string, event: string, data: any) {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      for (const socketId of sockets) {
        this.server.to(socketId).emit(event, data);
      }
    }
  }

  isUserOnline(userId: string): boolean {
    return this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0;
  }
}
