import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { MessageService } from '../message/message.service';
import { SendMessageDto } from '../dto/send-message.dto';
import { WsJwtGuard } from '../auth/ws-jwt.guard';
import { ConversationService } from '../conversation/conversation.service';
import { PresenceService } from './presence.service';

const allowedOrigins = (
  process.env.CORS_ALLOWED_ORIGINS ??
  'http://localhost:3000,http://localhost:5173'
)
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
  transports: ['websocket', 'polling'],
  // Explicit ping/pong timeouts — prevents load-balancer/proxy from closing idle connections.
  pingTimeout: 60000,   // 60s — server waits 60s for client pong before marking dead
  pingInterval: 25000,  // 25s — server sends ping every 25s
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
    private readonly presenceService: PresenceService,
  ) {}

  // ─── Call Signaling ───────────────────────────────────────
  //
  // FIX BUG #1+2+3: Register handlers for BOTH colon (call:offer) and
  // dot (call.offer) notations. The Web client emits on 4 event names
  // (call:offer, call.offer, call.signal, call:signal) but the server only
  // had handlers for the dot notation. This caused all colon-notation and
  // generic-signal ICE candidates to be silently ignored.
  //

  // ── Dot notation (original) ──
  @SubscribeMessage('call.offer')
  async handleCallOffer(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
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
    @MessageBody()
    data: {
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
    @MessageBody()
    data: {
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
    @MessageBody()
    data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      reason?: string;
    },
  ) {
    return this.forwardCallSignal(client, 'end', data);
  }

  // ── Colon notation (web client also emits these) ──
  @SubscribeMessage('call:offer')
  async handleCallOfferColon(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
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

  @SubscribeMessage('call:answer')
  async handleCallAnswerColon(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      sdp?: Record<string, unknown>;
    },
  ) {
    return this.forwardCallSignal(client, 'answer', data);
  }

  @SubscribeMessage('call:ice-candidate')
  async handleCallIceCandidateColon(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId?: string;
      callId?: string;
      targetUserId?: string;
      senderUserId?: string;
      candidate?: Record<string, unknown>;
    },
  ) {
    return this.forwardCallSignal(client, 'ice-candidate', data);
  }

  @SubscribeMessage('call:end')
  async handleCallEndColon(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
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
      const token =
        client.handshake?.auth?.token || client.handshake?.query?.token;
      if (!token) {
        this.logger.warn(`[Gateway.conn] Connection rejected: no token`);
        client.disconnect();
        return;
      }

      this.logger.log(
        `[Gateway.conn] Token present, length: ${(token as string).length}`,
      );
      const payload = this.jwtService.verify(token as string);
      const userId = payload.sub;
      client.data.user = {
        userId,
        phone: payload.phone,
        loginAtEpochSec: payload.iat,
        clientPlatform: payload.clientPlatform ?? 'WEB',
        trustLevel: payload.trustLevel ?? 'UNKNOWN',
        sessionType: payload.sessionType ?? 'PASSWORD',
        // G-006: read restrictedWebMode from JWT payload (not hardcoded false)
        restrictedWebMode: Boolean(payload.restrictedWebMode ?? false),
        deviceId: payload.deviceId ?? null,
      };

      // Track socket for this user
      if (!this.userSockets.has(userId)) {
        this.userSockets.set(userId, new Set());
      }
      this.userSockets.get(userId)!.add(client.id);

      this.logger.log(
        `[Gateway.conn] ✅ Connected: client=${client.id} user=${userId} restrictedWebMode=${client.data.user.restrictedWebMode}`,
      );

      // Join Redis-backed user room so emitToUser works cross-node (via Redis adapter)
      await client.join(`user:${userId}`);

      // Save presence to Redis (shared with realtime-gateway)
      await this.presenceService.setOnline(userId, client.id);

      // Broadcast presence to all connected clients
      this.server.emit('presence.changed', { userId, status: 'online', isOnline: true });
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
        // Save to Redis first (shared with realtime-gateway)
        this.presenceService.setOffline(userId).catch((err) =>
          this.logger.warn(`Failed to save offline presence for ${userId}: ${err.message}`),
        );
        this.server.emit('presence.changed', { userId, status: 'offline', isOnline: false });
      }
      // Leave Redis-backed user room (Redis adapter cleans socket from room on disconnect automatically,
      // but explicit leave ensures consistency)
      client.leave(`user:${userId}`);
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
      return {
        event: 'conversation.error',
        data: { error: 'Missing conversationId' },
      };
    }

    try {
      this.logger.log(
        `[Gateway.join] Verifying user is member of conversation...`,
      );
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
      this.logger.error(`[Gateway.join] ❌ Failed: ${err.message}`);
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

  /**
   * Disband a group conversation.
   * G-005: emits group.disbanded to all current members before hard-delete.
   * Only the ADMIN (group owner) can trigger this.
   */
  @SubscribeMessage('group.disband')
  async handleDisbandGroup(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string },
  ) {
    const userId = client.data.user.userId;
    const { conversationId } = data ?? {};

    if (!conversationId) {
      return {
        event: 'conversation.error',
        data: { error: 'Missing conversationId' },
      };
    }

    try {
      // Collect member IDs BEFORE deletion so we can notify them
      const members = await this.conversationService.getMembers(
        conversationId,
        userId,
      );
      const memberUserIds = members.map((m: any) => m.userId);

      // Perform hard-delete cascade (will throw if caller is not ADMIN)
      const result = await this.conversationService.disbandGroup(
        conversationId,
        userId,
      );

      // Notify all ex-members (including disbanding admin)
      const disbandPayload = { conversationId, disbandedBy: userId };
      const room = this.getConversationRoom(conversationId);
      // Emit to the room first (for online members in the room)
      this.server.to(room).emit('group.disbanded', disbandPayload);
      // Also emit per-user for offline members
      for (const memberId of memberUserIds) {
        this.emitToUser(memberId, 'group.disbanded', disbandPayload);
      }

      this.logger.log(
        `[Gateway.disband] Group ${conversationId} disbanded by ${userId}. Notified ${memberUserIds.length} members.`,
      );

      return { event: 'group.disbanded', data: result };
    } catch (err) {
      this.logger.error(`[Gateway.disband] Failed: ${err.message}`);
      return { event: 'conversation.error', data: { error: err.message } };
    }
  }

  /**
   * G-010: Emit group.memberAdded after adding members via WS.
   * Wraps conversationService.addMembers and broadcasts to the room.
   */
  @SubscribeMessage('group.addMembers')
  async handleGroupAddMembers(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string; memberIds: string[] },
  ) {
    const userId = client.data.user.userId;
    const { conversationId, memberIds } = data ?? {};
    if (!conversationId || !memberIds?.length) {
      return { event: 'conversation.error', data: { error: 'Missing conversationId or memberIds' } };
    }
    try {
      const result = await this.conversationService.addMembers(conversationId, userId, memberIds);
      const room = this.getConversationRoom(conversationId);
      const payload = { conversationId, addedBy: userId, memberIds, members: result.members };
      this.server.to(room).emit('group.memberAdded', payload);
      // Notify newly added members individually in case they're not in the room yet
      for (const memberId of memberIds) {
        this.emitToUser(memberId, 'group.memberAdded', payload);
      }
      // G-009: create system message in chat history
      const sysMsg = await this.messageService.createSystemMessage(
        conversationId,
        `${userId} added ${memberIds.length} member(s) to the group`,
      );
      this.server.to(room).emit('message.received', sysMsg);
      return { event: 'group.memberAdded', data: payload };
    } catch (err) {
      return { event: 'conversation.error', data: { error: err.message } };
    }
  }

  /**
   * G-011: Emit group.memberRemoved or group.memberLeft after removing a member via WS.
   */
  @SubscribeMessage('group.removeMember')
  async handleGroupRemoveMember(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string; targetUserId: string },
  ) {
    const userId = client.data.user.userId;
    const { conversationId, targetUserId } = data ?? {};
    if (!conversationId || !targetUserId) {
      return { event: 'conversation.error', data: { error: 'Missing conversationId or targetUserId' } };
    }
    try {
      await this.conversationService.removeMember(conversationId, userId, targetUserId);
      const isSelf = userId === targetUserId;
      const eventName = isSelf ? 'group.memberLeft' : 'group.memberRemoved';
      const room = this.getConversationRoom(conversationId);
      const payload = { conversationId, userId: targetUserId, removedBy: isSelf ? null : userId };
      // Emit with dot notation (Flutter listens on 'group.memberRemoved')
      this.server.to(room).emit(eventName, payload);
      this.emitToUser(targetUserId, eventName, payload);
      // G-009: create system message in chat history
      const sysContent = isSelf
        ? `${targetUserId} left the group`
        : `${targetUserId} was removed from the group by ${userId}`;
      const sysMsg = await this.messageService.createSystemMessage(conversationId, sysContent);
      this.server.to(room).emit('message.received', sysMsg);
      return { event: eventName, data: payload };
    } catch (err) {
      return { event: 'conversation.error', data: { error: err.message } };
    }
  }

  /**
   * G-012: Emit group.roleChanged or group.adminTransferred after updating member role via WS.
   */
  @SubscribeMessage('group.updateMember')
  async handleGroupUpdateMember(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { conversationId: string; targetUserId: string; role?: string; nickname?: string },
  ) {
    const userId = client.data.user.userId;
    const { conversationId, targetUserId, role, nickname } = data ?? {};
    if (!conversationId || !targetUserId) {
      return { event: 'conversation.error', data: { error: 'Missing conversationId or targetUserId' } };
    }
    try {
      const updated = await this.conversationService.updateMember(conversationId, userId, targetUserId, { role, nickname });
      const room = this.getConversationRoom(conversationId);
      if (role) {
        const eventName = role === 'ADMIN' ? 'group.adminTransferred' : 'group.roleChanged';
        const payload = { conversationId, targetUserId, newRole: role, changedBy: userId, member: updated };
        // Emit to full room
        this.server.to(room).emit(eventName, payload);
        // B-02: Also emit individually to target user (they may be offline from room)
        this.emitToUser(targetUserId, eventName, payload);
        return { event: eventName, data: payload };
      }
      // Nickname-only change — no event broadcast needed (local UI update)
      return { event: 'group.memberUpdated', data: { conversationId, targetUserId, member: updated } };
    } catch (err) {
      return { event: 'conversation.error', data: { error: err.message } };
    }
  }

  /**
   * G-016: Update group settings and emit group.settingsChanged to all room members.
   * Allows ADMIN/DEPUTY to update: title, avatar, joinMode, memberLimit,
   * allowMemberInvite, allowMemberPin, allowMemberEditInfo.
   * Only ADMIN can update: onlyAdminCanPost (handled inside updateGroup).
   */
  @SubscribeMessage('group.updateSettings')
  async handleGroupUpdateSettings(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      title?: string;
      avatarUrl?: string;
      description?: string;
      joinMode?: string;
      memberLimit?: number;
      allowMemberInvite?: boolean;
      allowMemberPin?: boolean;
      allowMemberEditInfo?: boolean;
      onlyAdminCanPost?: boolean;
    },
  ) {
    const userId = client.data.user.userId;
    const { conversationId, ...dto } = data ?? {};

    if (!conversationId) {
      return {
        event: 'conversation.error',
        data: { error: 'Missing conversationId' },
      };
    }

    try {
      const updated = await this.conversationService.updateGroup(
        conversationId,
        userId,
        dto as any,
      );

      const room = this.getConversationRoom(conversationId);
      const payload = {
        conversationId,
        updatedBy: userId,
        changes: dto,
        conversation: updated,
      };

      this.server.to(room).emit('group.settingsChanged', payload);
      this.logger.log(
        `[Gateway.updateSettings] Group ${conversationId} settings updated by ${userId}`,
      );

      return { event: 'group.settingsChanged', data: payload };
    } catch (err) {
      this.logger.error(
        `[Gateway.updateSettings] Failed: ${err.message}`,
      );
      return { event: 'conversation.error', data: { error: err.message } };
    }
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
      duration?: number;
      outcome?: string;
      startedAt?: number | null;
      direction?: string;
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
    // FIX BUG #4: Forward audioOnly for ALL call types (not just offer).
    // The callee needs to know call type for ICE candidate and answer events too.
    if (data?.audioOnly != null) {
      payload.audioOnly = data.audioOnly;
    }
    // FIX BUG #5: Forward duration/outcome/startedAt/direction from Flutter endCall.
    // Mobile's endCall sends these fields; ensure they're relayed to the target.
    if (data?.duration != null) {
      payload.duration = data.duration;
    }
    if (data?.outcome != null) {
      payload.outcome = data.outcome;
    }
    if (data?.startedAt != null) {
      payload.startedAt = data.startedAt;
    }
    if (data?.direction != null) {
      payload.direction = data.direction;
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
    this.logger.debug(
      `[Gateway.send] Full payload:`,
      JSON.stringify(dto, null, 2),
    );

    // Validate DTO
    if (!dto?.conversationId) {
      this.logger.error(`[Gateway.send] ❌ INVALID: Missing conversationId`);
      return {
        event: 'message.error',
        data: { error: 'Missing conversationId' },
      };
    }
    if (!dto?.content) {
      this.logger.error(`[Gateway.send] ❌ INVALID: Missing content`);
      return { event: 'message.error', data: { error: 'Missing content' } };
    }

    try {
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 1.5: G-008 — ENFORCE onlyAdminCanPost GUARD
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      await this.conversationService.assertCanSendMessage(dto.conversationId, userId);

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 2: SAVE TO DATABASE
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      this.logger.log(
        `[Gateway.send] Step 2: Calling messageService.sendMessage...`,
      );
      const message = await this.messageService.sendMessage(
        userId,
        dto,
        access,
      );

      if (!message) {
        this.logger.error(
          `[Gateway.send] ❌ FAILED: messageService returned null`,
        );
        return {
          event: 'message.error',
          data: { error: 'Message save returned null' },
        };
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
      this.logger.log(
        `[Gateway.send] ✅ Emit to room completed, all ${roomSize} clients should receive message`,
      );

      // Explicit sender confirmation event (in addition to Socket.IO ack callback)
      client.emit('message.sent', message);
      this.logger.log(
        `[Gateway.send] ✅ Emitted sender confirmation event='message.sent' mid=${message.id}`,
      );

      if (roomSize === 0) {
        this.logger.warn(
          `[Gateway.send] ⚠️  WARNING: Room has 0 clients! Message won't be seen immediately.`,
        );
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // STEP 4: EMIT TO INDIVIDUAL MEMBERS (for inbox updates)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      try {
        this.logger.log(
          `[Gateway.send] Step 4: Fetching conversation members...`,
        );
        const conversation = await this.conversationService.getConversation(
          message.conversationId,
          userId,
        );

        if (
          conversation &&
          conversation.members &&
          conversation.members.length > 0
        ) {
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

          this.logger.log(
            `[Gateway.send] ✅ Individual member broadcasts completed`,
          );
        } else {
          this.logger.warn(
            `[Gateway.send] ⚠️  Conversation has no members or not found`,
          );
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

      const errorResponse = {
        event: 'message.error',
        data: { error: err.message },
      };
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
      const recalled = await this.messageService.recallMessage(
        userId,
        data.messageId,
      );

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
    this.conversationService
      .assertMember(data.conversationId, userId)
      .then(() => {
        const room = this.getConversationRoom(data.conversationId);
        // For typing, use client.to() to exclude the sender
        client.to(room).emit('message.typing', {
          userId,
          conversationId: data.conversationId,
          isTyping: data.isTyping,
          clientPlatform: client.data.user.clientPlatform ?? 'WEB',
        });
      })
      .catch((err) => {
        this.logger.warn(
          `Typing ignored for non-member user=${userId}: ${err.message}`,
        );
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
      await this.messageService.markAsRead(
        userId,
        data.conversationId,
        data.lastReadSeq,
      );

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

  /** Pin a message and broadcast to conversation room. */
  @SubscribeMessage('message.pin')
  async handlePinMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { messageId: string; conversationId: string },
  ) {
    const userId = client.data.user.userId;
    this.logger.log(`[Gateway.pin] START: userId=${userId} messageId=${data.messageId} conversationId=${data.conversationId}`);

    try {
      const pin = await this.messageService.pinMessage(
        userId,
        data.conversationId,
        data.messageId,
      );
      this.logger.log(`[Gateway.pin] SUCCESS: pin=${JSON.stringify(pin)}`);

      // Broadcast pinned event
      const room = this.getConversationRoom(data.conversationId);
      this.server.to(room).emit('message.pinned', {
        pin,
        pinnedBy: userId,
      });

      return { event: 'message.pinned', data: pin };
    } catch (err) {
      this.logger.error(`[Gateway.pin] FAILED: ${err.message}`);
      return { event: 'message.error', data: { error: err.message } };
    }
  }

  /** Unpin a message and broadcast to conversation room. */
  @SubscribeMessage('message.unpin')
  async handleUnpinMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { messageId: string; conversationId: string },
  ) {
    const userId = client.data.user.userId;
    this.logger.log(`[Gateway.unpin] START: userId=${userId} messageId=${data.messageId} conversationId=${data.conversationId}`);

    try {
      await this.messageService.unpinMessage(
        userId,
        data.conversationId,
        data.messageId,
      );
      this.logger.log(`[Gateway.unpin] SUCCESS`);

      // Broadcast unpinned event
      const room = this.getConversationRoom(data.conversationId);
      this.server.to(room).emit('message.unpinned', {
        messageId: data.messageId,
        conversationId: data.conversationId,
        unpinnedBy: userId,
      });

      return { event: 'message.unpinned', data: { messageId: data.messageId } };
    } catch (err) {
      this.logger.error(`[Gateway.unpin] FAILED: ${err.message}`);
      return { event: 'message.error', data: { error: err.message } };
    }
  }

  // ─── Utility ──────────────────────────────────────────────

  /** Get the standard room name for a conversation. */
  private getConversationRoom(conversationId: string): string {
    return `conversation:${conversationId}`;
  }

  /** Check if a user is currently online (has at least one active socket). */
  isUserOnline(userId: string): boolean {
    return (
      this.userSockets.has(userId) && this.userSockets.get(userId)!.size > 0
    );
  }

  /** Emit an event to a specific user's sockets. Uses Redis-backed user:{userId} room for cross-node delivery. */
  emitToUser(userId: string, event: string, data: unknown) {
    // With RedisIoAdapter installed, server.to('user:${userId}') reaches ALL sockets of
    // that user across ALL nodes. This replaces the broken in-memory Map lookup.
    this.server.to(`user:${userId}`).emit(event, data);
    this.logger.log(
      `[Gateway.emitToUser] Emitted event='${event}' to user=${userId} via Redis-backed user room`,
    );
  }
  // ─── Group Call Signaling ────────────────────────────────────────────
  // Hoàn toàn tách biệt với 1-1 call (call.offer / call.answer / call.end).
  // Frontend kết nối tới namespace /chat → handlers phải ở đây.

  /**
   * Caller phát tín hiệu bắt đầu cuộc gọi nhóm.
   * Relay tới TẤT CẢ thành viên trong conversation room (trừ chính caller).
   */
  @SubscribeMessage('group-call:started')
  async handleGroupCallStarted(
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
    const userId = client.data?.user?.userId;
    const room = `conversation:${data.conversationId}`;
    this.logger.log(
      `[GroupCall] group-call:started from user=${userId} in room=${room} callId=${data.callId}`,
    );
    // Broadcast tới tất cả NGOẠI TRỪ người gửi
    client.to(room).emit('group-call:started', data);
  }

  /**
   * Thành viên tham gia cuộc gọi nhóm.
   * Relay group-call:user-joined tới tất cả người trong room để họ tạo offer.
   */
  @SubscribeMessage('group-call:join')
  async handleGroupCallJoin(
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
      `[GroupCall] group-call:join from user=${data.senderUserId} in room=${room}`,
    );
    // Thông báo tới mọi người khác trong room (trừ joiner)
    client.to(room).emit('group-call:user-joined', data);
  }

  /**
   * Relay WebRTC offer từ A → B (point-to-point).
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
   * Relay ICE candidate (point-to-point).
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
   * Relay group-call:user-left tới tất cả người trong room.
   */
  @SubscribeMessage('group-call:media-update')
  handleGroupCallMediaUpdate(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      callId: string;
      senderUserId: string;
      isMicOn?: boolean;
      isCameraOn?: boolean;
    },
  ) {
    const room = `conversation:${data.conversationId}`;
    client.to(room).emit('group-call:media-update', data);
  }

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
      `[GroupCall] group-call:leave from user=${data.senderUserId} in room=${room}`,
    );
    client.to(room).emit('group-call:user-left', data);
  }

  /**
   * Cuộc gọi đã kết thúc hoàn toàn (người cuối rời).
   * Relay tới toàn bộ room để dismiss banner cho những người chưa bắt máy.
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
      `[GroupCall] group-call:ended by user=${data.endedByUserId} in room=${room}`,
    );
    // Broadcast tới tất cả (kể cả chính người gửi — để đảm bảo không ai còn banner)
    this.server.to(room).emit('group-call:ended', data);
  }
}
