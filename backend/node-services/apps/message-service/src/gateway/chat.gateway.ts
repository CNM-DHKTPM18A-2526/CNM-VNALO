import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  OnGatewayConnection, OnGatewayDisconnect, MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { MessageService } from '../message/message.service';
import { SendMessageDto } from '../dto/send-message.dto';
import { WsJwtGuard } from '../auth/ws-jwt.guard';
import { ConversationService } from '../conversation/conversation.service';

const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? 'http://localhost:3000,http://localhost:5173')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

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
  cors: {
    origin: allowedOrigins,
    credentials: true,
  },
  namespace: '/chat',
  transports: ['websocket'],
})
@UseGuards(WsJwtGuard)
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  /** Maps userId -> Set of socketIds for multi-device support */
  private readonly userSockets = new Map<string, Set<string>>();

  private getRoomSize(room: string): number {
    const namespaceAdapter = (this.server as any)?.adapter;
    const roomClients = namespaceAdapter?.rooms?.get(room);
    return roomClients?.size ?? 0;
  }

  constructor(
    private readonly jwtService: JwtService,
    private readonly messageService: MessageService,
    private readonly conversationService: ConversationService,
  ) { }

  // ─── Call Signaling ───────────────────────────────────────

  @SubscribeMessage('call.offer')
  async handleCallOffer(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      sdp?: Record<string, unknown>;
      audioOnly?: boolean;
    },
  ) {
    return this.forwardCallSignal(client, 'offer', data);
  }

  @SubscribeMessage('call.answer')
  async handleCallAnswer(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      sdp?: Record<string, unknown>;
    },
  ) {
    return this.forwardCallSignal(client, 'answer', data);
  }

  @SubscribeMessage('call.ice-candidate')
  async handleCallIceCandidate(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      candidate?: Record<string, unknown>;
    },
  ) {
    return this.forwardCallSignal(client, 'ice-candidate', data);
  }

  @SubscribeMessage('call.end')
  async handleCallEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      reason?: string;
    },
  ) {
    return this.forwardCallSignal(client, 'end', data);
  }

  // ─── Connection Lifecycle ─────────────────────────────────

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake?.auth?.token || client.handshake?.query?.token;
      if (!token) {
        this.logger.warn(`[Gateway.conn] Connection rejected: no token`);
        client.disconnect();
        return;
      }

      this.logger.log(`[Gateway.conn] Token present, length: ${(token as string).length}`);
      const payload = this.jwtService.verify(token as string);
      const userId = payload.sub;
      client.data.user = {
        userId,
        phone: payload.phone,
        loginAtEpochSec: payload.iat,
        clientPlatform: payload.clientPlatform ?? 'WEB',
        trustLevel: payload.trustLevel ?? 'UNKNOWN',
        sessionType: payload.sessionType ?? 'PASSWORD',
        restrictedWebMode: false,
        deviceId: payload.deviceId ?? null,
      };

      // Track socket for this user
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(client.id);

      this.logger.log(`[Gateway.conn] ✅ Connected: client=${client.id} user=${userId} restrictedWebMode=${payload.restrictedWebMode} (effective=false override)`);

      // Broadcast presence
      this.server.emit('presence.changed', { userId, status: 'online' });
    } catch (err) {
      this.logger.warn(`[Gateway.conn] Connection rejected: ${err.message}`);
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
    const userId = client.data.user.userId;
    const conversationId = data?.conversationId;

    this.logger.log(
      `[Gateway.join] Entry: userId=${userId} clientId=${client.id} convId=${conversationId}`,
    );

    if (!conversationId) {
      this.logger.error(`[Gateway.join] ❌ Invalid: Missing conversationId`);
      return { event: 'conversation.error', data: { error: 'Missing conversationId' } };
    }

    try {
      this.logger.log(`[Gateway.join] Verifying user is member of conversation...`);
      await this.conversationService.assertMember(conversationId, userId);

      const room = this.getConversationRoom(conversationId);
      this.logger.log(`[Gateway.join] Joining room='${room}'...`);
      
      await client.join(room);
      
      const roomSize = this.getRoomSize(room);
      
      this.logger.log(
        `[Gateway.join] ✅ Successfully joined: room='${room}' now has ${roomSize} client(s)`,
      );
      
      return { event: 'conversation.joined', data: { conversationId } };
    } catch (err) {
      this.logger.error(
        `[Gateway.join] ❌ Failed: ${err.message}`,
      );
      return { event: 'conversation.error', data: { error: err.message } };
    }
  }

  /** Leave a conversation room. */
  @SubscribeMessage('conversation.leave')
  async handleLeaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const room = this.getConversationRoom(data.conversationId);
    await client.leave(room);
  }

  private async forwardCallSignal(
    client: Socket,
    type: 'offer' | 'answer' | 'ice-candidate' | 'end',
    data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      sdp?: Record<string, unknown>;
      candidate?: Record<string, unknown>;
      reason?: string;
      audioOnly?: boolean;
    },
  ) {
    const senderUserId = client.data?.user?.userId as string | undefined;
    const conversationId = data?.conversationId;
    const callId = data?.callId;
    const targetUserId = data?.targetUserId;

    if (!senderUserId) {
      this.logger.warn(`[Gateway.call.${type}] Missing sender identity`);
      return { event: 'call.error', data: { error: 'Unauthenticated socket' } };
    }

    if (!conversationId || !callId || !targetUserId) {
      this.logger.warn(
        `[Gateway.call.${type}] Invalid payload sender=${senderUserId} conversationId=${conversationId} callId=${callId} target=${targetUserId}`,
      );
      return {
        event: 'call.error',
        data: { error: 'conversationId, callId and targetUserId are required' },
      };
    }

    try {
      await this.conversationService.assertMember(conversationId, senderUserId);
      await this.conversationService.assertMember(conversationId, targetUserId);
    } catch (err) {
      this.logger.warn(
        `[Gateway.call.${type}] Membership check failed sender=${senderUserId} target=${targetUserId} conv=${conversationId}: ${err.message}`,
      );
      return { event: 'call.error', data: { error: err.message } };
    }

    const payload: Record<string, unknown> = {
      type,
      conversationId,
      callId,
      senderUserId,
      targetUserId,
    };

    if (data?.sdp != null) {
      payload.sdp = data.sdp;
    }
    if (data?.candidate != null) {
      payload.candidate = data.candidate;
    }
    if (data?.reason != null && data.reason.trim().length > 0) {
      payload.reason = data.reason.trim();
    }
    if (type == 'offer' && data?.audioOnly != null) {
      payload.audioOnly = data.audioOnly;
    }

    this.logger.log(
      `[Gateway.call.${type}] sender=${senderUserId} target=${targetUserId} conv=${conversationId} callId=${callId}`,
    );

    this.emitToUser(targetUserId, `call.${type}`, payload);

    return {
      event: `call.${type}.sent`,
      data: { conversationId, callId, targetUserId },
    };
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
    const access = {
      clientPlatform: client.data.user.clientPlatform ?? 'WEB',
      restrictedWebMode: Boolean(client.data.user.restrictedWebMode),
      loginAtEpochSec: client.data.user.loginAtEpochSec,
    };

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 1: LOG ENTRY (verify handler is called)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    this.logger.log(
      `[Gateway.send] ✅ ENTRY: user=${userId} convId=${dto?.conversationId ?? 'missing'} clientMsgId=${dto?.clientMessageId ?? 'missing'} len=${dto?.content?.length ?? 0} restricted=${access.restrictedWebMode}`,
    );
    this.logger.debug(`[Gateway.send] Full payload:`, JSON.stringify(dto, null, 2));

    // Validate DTO
    if (!dto?.conversationId) {
      this.logger.error(`[Gateway.send] ❌ INVALID: Missing conversationId`);
      return { event: 'message.error', data: { error: 'Missing conversationId' } };
    }
    if (!dto?.content) {
      this.logger.error(`[Gateway.send] ❌ INVALID: Missing content`);
      return { event: 'message.error', data: { error: 'Missing content' } };
    }

    try {
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 2: SAVE TO DATABASE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      this.logger.log(`[Gateway.send] Step 2: Calling messageService.sendMessage...`);
      const message = await this.messageService.sendMessage(userId, dto, access);
      
      if (!message) {
        this.logger.error(`[Gateway.send] ❌ FAILED: messageService returned null`);
        return { event: 'message.error', data: { error: 'Message save returned null' } };
      }

      this.logger.log(
        `[Gateway.send] ✅ Message persisted: id=${message.id} serverSeq=${message.serverSeq} convId=${message.conversationId}`,
      );

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 3: EMIT TO CONVERSATION ROOM (BOTH SENDER AND RECEIVER)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      const room = this.getConversationRoom(message.conversationId);
      const roomSize = this.getRoomSize(room);
      
      this.logger.log(
        `[Gateway.send] Step 3: EMITTING to room='${room}' (${roomSize} clients online) event='message.received'`,
      );
      
      // Use this.server.to() NOT client.to() - this includes the sender!
      this.server.to(room).emit('message.received', message);
      this.logger.log(`[Gateway.send] ✅ Emit to room completed, all ${roomSize} clients should receive message`);

      // Explicit sender confirmation event (in addition to Socket.IO ack callback)
      client.emit('message.sent', message);
      this.logger.log(`[Gateway.send] ✅ Emitted sender confirmation event='message.sent' mid=${message.id}`);
      
      if (roomSize === 0) {
        this.logger.warn(`[Gateway.send] ⚠️  WARNING: Room has 0 clients! Message won't be seen immediately.`)
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 4: EMIT TO INDIVIDUAL MEMBERS (for inbox updates)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      try {
        this.logger.log(`[Gateway.send] Step 4: Fetching conversation members...`);
        const conversation = await this.conversationService.getConversation(message.conversationId, userId);
        
        if (conversation && conversation.members && conversation.members.length > 0) {
          this.logger.log(
            `[Gateway.send] ✅ Found ${conversation.members.length} members, broadcasting individ events...`,
          );
          
          for (const member of conversation.members) {
            const memberSocketIds = this.userSockets.get(member.userId);
            const socketCount = memberSocketIds?.size ?? 0;
            this.logger.log(
              `[Gateway.send]   → Member ${member.userId} has ${socketCount} socket(s)`,
            );
            this.emitToUser(member.userId, 'message.received', message);
          }
          
          this.logger.log(`[Gateway.send] ✅ Individual member broadcasts completed`);
        } else {
          this.logger.warn(`[Gateway.send] ⚠️  Conversation has no members or not found`);
        }
      } catch (err) {
        this.logger.error(
          `[Gateway.send] ⚠️  Failed to broadcast to individual members: ${err.message}`,
        );
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 5: SEND ACK BACK TO CLIENT
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      this.logger.log(
        `[Gateway.send] Step 5: SENDING ACK back to client with event='message.sent' mid=${message.id}`,
      );
      
      const ackResponse = { event: 'message.sent', data: message };
      this.logger.log(
        `[Gateway.send] ✅ SUCCESS: Handler returning ACK: ${JSON.stringify({ event: ackResponse.event, messageId: message.id })}`,
      );
      
      return ackResponse;
    } catch (err) {
      this.logger.error(
        `[Gateway.send] ❌ EXCEPTION in handler: ${err.message} ${err.stack}`,
      );
      
      const errorResponse = { event: 'message.error', data: { error: err.message } };
      this.logger.log(
        `[Gateway.send] Returning error ACK: ${JSON.stringify(errorResponse)}`,
      );
      
      return errorResponse;
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

      // Broadcast recall event to all clients in the room (including sender)
      const room = this.getConversationRoom(recalled.conversationId);
      this.server.to(room).emit('message.recalled', {
        messageId: recalled.id,
        conversationId: recalled.conversationId,
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
    const userId = client.data.user.userId;
    this.conversationService.assertMember(data.conversationId, userId)
      .then(() => {
        const room = this.getConversationRoom(data.conversationId);
        // For typing, use client.to() to exclude the sender
        client.to(room).emit('message.typing', {
          userId,
          conversationId: data.conversationId,
          isTyping: data.isTyping,
        });
      })
      .catch((err) => {
        this.logger.warn(`Typing ignored for non-member user=${userId}: ${err.message}`);
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

      // Broadcast read receipt to conversation (use client.to() to exclude sender)
      const room = this.getConversationRoom(data.conversationId);
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

  /** Get the standard room name for a conversation. */
  private getConversationRoom(conversationId: string): string {
    return `conversation:${conversationId}`;
  }

  /** Check if a user is currently online (has at least one active socket). */
  isUserOnline(userId: string): boolean {
    return this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0;
  }

  /** Emit an event to a specific user's sockets. */
  emitToUser(userId: string, event: string, data: any) {
    const sockets = this.userSockets.get(userId);
    
    if (!sockets || sockets.size === 0) {
      this.logger.warn(
        `[Gateway.emitToUser] ⚠️  User ${userId} has no active sockets, event='${event}' will not be sent`,
      );
      return;
    }

    this.logger.log(
      `[Gateway.emitToUser] Emitting to ${sockets.size} socket(s) of user=${userId} event='${event}'`,
    );

    for (const socketId of sockets) {
      this.logger.log(
        `[Gateway.emitToUser]   → socketId=${socketId} event='${event}'`,
      );
      this.server.to(socketId).emit(event, data);
    }
    
    this.logger.log(`[Gateway.emitToUser] ✅ Emission to user=${userId} completed`);
  }
}
