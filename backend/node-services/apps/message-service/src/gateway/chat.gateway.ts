import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  OnGatewayConnection, OnGatewayDisconnect, MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { MessageService } from '../message/message.service';
import { SendMessageDto } from '../dto/send-message.dto';

/**
 * WebSocket gateway for real-time chat.
 *
 * Flow:
 * 1. Client connects with JWT in handshake auth
 * 2. Server verifies token and joins user to their conversation rooms
 * 3. Client emits events (message.send, message.typing, message.read)
 * 4. Server broadcasts to appropriate rooms
 *
 * Room naming: `conversation:{conversationId}`
 */
@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
  transports: ['websocket', 'polling'],
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  /** Maps userId -> Set of socketIds for multi-device support */
  private readonly userSockets = new Map<string, Set<string>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly messageService: MessageService,
  ) { }

  // ─── Connection Lifecycle ─────────────────────────────────

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake?.auth?.token || client.handshake?.query?.token;
      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token as string);
      const userId = payload.sub;
      client.data.user = { userId, phone: payload.phone };

      // Track socket for this user
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(client.id);

      this.logger.log(`Client connected: ${client.id} (user: ${userId})`);

      // Broadcast presence
      this.server.emit('presence.changed', { userId, status: 'online' });
    } catch (err) {
      this.logger.warn(`Connection rejected: ${err.message}`);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data?.user?.userId;
    if (userId) {
      this.userSockets.get(userId)?.delete(client.id);
      if (this.userSockets.get(userId)?.size === 0) {
        this.userSockets.delete(userId);
        // Only emit offline if no more sockets for this user
        this.server.emit('presence.changed', { userId, status: 'offline' });
      }
    }
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  // ─── Chat Events ──────────────────────────────────────────

  /** Join a conversation room to receive messages. */
  @SubscribeMessage('conversation.join')
  async handleJoinConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const room = `conversation:${data.conversationId}`;
    await client.join(room);
    this.logger.debug(`${client.data.user.userId} joined room ${room}`);
    return { event: 'conversation.joined', data: { conversationId: data.conversationId } };
  }

  /** Leave a conversation room. */
  @SubscribeMessage('conversation.leave')
  async handleLeaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const room = `conversation:${data.conversationId}`;
    await client.leave(room);
  }

  /**
   * Send a message via WebSocket.
   * Persists to DB then broadcasts to all members in the room.
   */
  @SubscribeMessage('message.send')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() dto: SendMessageDto,
  ) {
    const userId = client.data.user.userId;

    try {
      const message = await this.messageService.sendMessage(userId, dto);

      // Broadcast to all clients in the conversation room
      const room = `conversation:${dto.conversationId}`;
      this.server.to(room).emit('message.received', message);

      return { event: 'message.sent', data: message };
    } catch (err) {
      this.logger.error(`Send message failed: ${err.message}`);
      return { event: 'message.error', data: { error: err.message } };
    }
  }

  /** Recall a message and broadcast to conversation room. */
  @SubscribeMessage('message.recall')
  async handleRecallMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { messageId: string; conversationId: string },
  ) {
    const userId = client.data.user.userId;

    try {
      const recalled = await this.messageService.recallMessage(userId, data.messageId);

      // Broadcast recall event to all clients in the room
      const room = `conversation:${data.conversationId}`;
      this.server.to(room).emit('message.recalled', {
        messageId: recalled.id,
        conversationId: data.conversationId,
        recalledBy: userId,
      });

      return { event: 'message.recalled', data: recalled };
    } catch (err) {
      this.logger.error(`Recall message failed: ${err.message}`);
      return { event: 'message.error', data: { error: err.message } };
    }
  }

  /** Typing indicator: broadcast to conversation room. */
  @SubscribeMessage('message.typing')
  handleTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string; isTyping: boolean },
  ) {
    const room = `conversation:${data.conversationId}`;
    client.to(room).emit('message.typing', {
      userId: client.data.user.userId,
      conversationId: data.conversationId,
      isTyping: data.isTyping,
    });
  }

  /** Read receipt: mark messages as read and notify sender. */
  @SubscribeMessage('message.read')
  async handleMarkRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string; lastReadSeq: number },
  ) {
    const userId = client.data.user.userId;

    try {
      await this.messageService.markAsRead(userId, data.conversationId, data.lastReadSeq);

      // Broadcast read receipt to conversation
      const room = `conversation:${data.conversationId}`;
      client.to(room).emit('message.read', {
        userId,
        conversationId: data.conversationId,
        lastReadSeq: data.lastReadSeq,
      });
    } catch (err) {
      this.logger.error(`Mark read failed: ${err.message}`);
    }
  }

  // ─── Utility ──────────────────────────────────────────────

  /** Check if a user is currently online (has at least one active socket). */
  isUserOnline(userId: string): boolean {
    return this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0;
  }

  /** Emit an event to a specific user's sockets. */
  emitToUser(userId: string, event: string, data: any) {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      for (const socketId of sockets) {
        this.server.to(socketId).emit(event, data);
      }
    }
  }
}
