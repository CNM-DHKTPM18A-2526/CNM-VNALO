import { io, type Socket } from 'socket.io-client'
import type { RawMessage } from './chat.api'
import type { ChatMessageType, ReplyMetadata } from './chat.types'

import { WS_BASE_URL as SOCKET_URL } from '../../api.client'

export type SocketMessagePayload = {
  conversationId: string
  content: string
  messageType?: Uppercase<ChatMessageType>
  mediaUrl?: string | null
  mediaThumbnailUrl?: string | null
  mediaMimeType?: string | null
  mediaSizeBytes?: number | null
  clientMessageId?: string
  attachments?: Array<{
    url: string
    name?: string | null
    mimeType?: string | null
    sizeBytes?: number | null
    thumbnailUrl?: string | null
  }>
  replyTo?: ReplyMetadata | null
}

export type SendMessageAck = {
  event?: 'message.sent' | string
  data?: RawMessage
  message?: string
}

export type RecallMessagePayload = {
  messageId: string
  conversationId: string
}

export type RecallMessageAck = {
  event?: 'message.recalled' | string
  data?: RawMessage
  message?: string
}

const SEND_ACK_TIMEOUT_MS = 3000 // TÄƒng tá»‘c Ä‘á»™ timeout Ä‘á»ƒ bÃ¡o lá»—i nhanh hÆ¡n

export type MessageReadPayload = {
  conversationId: string
  lastReadSeq?: number
}

export type PresenceChangedPayload = {
  userId: string
  status: 'online' | 'offline' | string
  lastSeen?: string | null
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
// SOCKET SINGLETON
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
let globalSocketManager: any = null
let globalSocketToken: string | null = null

let globalChatSocket: Socket | null = null
let globalRootSocket: Socket | null = null

// Track joined rooms for auto-rejoin on reconnect (like mobile)
const joinedRooms = new Set<string>()
const pendingRoomJoins = new Set<string>()

// Registry to notify services when connection is lost
const onDisconnectCallbacks = new Set<() => void>()

export function getOrCreateSocketManager(token: string): { chat: Socket; root: Socket } {
  const incomingToken = token.trim()

  if (globalSocketManager && globalSocketToken && globalSocketToken !== incomingToken) {
    console.log('[SocketManager] Token changed, recreating connection')
    globalChatSocket?.disconnect()
    globalChatSocket = null
    globalSocketManager = null
    
    // Clear room tracking on token change (logout/re-login)
    joinedRooms.clear()
    pendingRoomJoins.clear()
    console.log('[SocketManager] ðŸ§¹ Cleared all joined rooms on token change')
  }

  if (globalChatSocket && globalSocketToken === incomingToken) {
    return { chat: globalChatSocket, root: globalChatSocket }
  }

  if (!globalSocketManager) {
    console.log('[SocketManager] Initializing connection to:', SOCKET_URL)
    globalSocketToken = incomingToken

    const options = {
      transports: ['websocket'], //Æ¯u tiÃªn websocket Ä‘á»ƒ giáº£m Ä‘á»™ trá»…
      auth: { token },
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      path: '/socket.io/',
    }

    globalSocketManager = io(`${SOCKET_URL}/chat`, options)
    globalChatSocket = globalSocketManager
    globalRootSocket = globalSocketManager

    globalChatSocket?.on('connect', () => {
      console.log('[Socket.CHAT] âœ… Connected ID:', globalChatSocket?.id)
      
      // AUTO-REJOIN all rooms after reconnect (like mobile)
      console.log('[Socket.CHAT] ðŸ”„ Auto-rejoin started - rejoining', joinedRooms.size, 'rooms')
      for (const room of joinedRooms) {
        console.log('[Socket.CHAT]   â†’ Auto-rejoin room:', room)
        globalChatSocket?.emit('conversation.join', { conversationId: room })
      }
      
      // Process pending room joins
      if (pendingRoomJoins.size > 0) {
        console.log('[Socket.CHAT] ðŸ”„ Processing', pendingRoomJoins.size, 'pending room joins')
        for (const room of pendingRoomJoins) {
          if (!joinedRooms.has(room)) {
            console.log('[Socket.CHAT]   â†’ Joining pending room:', room)
            globalChatSocket?.emit('conversation.join', { conversationId: room })
            joinedRooms.add(room)
          }
        }
        pendingRoomJoins.clear()
      }
    })

    globalChatSocket?.on('disconnect', (reason) => {
      console.warn('[Socket.CHAT] âšª Disconnected:', reason)
      // Keep joinedRooms for auto-rejoin on reconnect
      // Notify all services to clear their room cache
      onDisconnectCallbacks.forEach(cb => cb())
    })

    globalChatSocket?.on('message.error', (payload: any) => {
      console.error('[Socket.CHAT] âŒ message.error:', payload)
      window.dispatchEvent(new CustomEvent('vnalo:socket:message-error', { detail: payload }))
    })

    globalChatSocket?.on('conversation.error', (payload: any) => {
      console.error('[Socket.CHAT] âŒ conversation.error:', payload)
      window.dispatchEvent(new CustomEvent('vnalo:socket:conversation-error', { detail: payload }))
    })
  }

  return { chat: globalChatSocket!, root: globalRootSocket! }
}

export function getOrCreateRootSocket(token: string): Socket { return getOrCreateSocketManager(token).root }
export function getOrCreateSocket(token: string): Socket { return getOrCreateSocketManager(token).chat }

export function disconnectSocket() {
  globalChatSocket?.disconnect()
  globalChatSocket = null
  globalSocketManager = null
  globalSocketToken = null
  
  // Clear all room tracking on full disconnect (logout)
  joinedRooms.clear()
  pendingRoomJoins.clear()
  console.log('[Socket] ðŸ§¹ Cleared all joined rooms on disconnect')
  
  onDisconnectCallbacks.forEach(cb => cb())
}

export function waitForSocketConnect(timeoutMs: number = 5000): Promise<boolean> {
  return new Promise((resolve) => {
    if (!globalChatSocket) return resolve(false)
    if (globalChatSocket.connected) return resolve(true)
    const timer = setTimeout(() => resolve(false), timeoutMs)
    globalChatSocket.once('connect', () => {
      clearTimeout(timer)
      resolve(true)
    })
  })
}

export class ChatSocketService {
  private socket: Socket | null = null
  private joinedConversations = new Set<string>()
  
  // Event handlers (to be called with latest state)
  private eventHandlers: {
    onConnected?: () => void
    onDisconnected?: () => void
    onMessageReceived?: (message: RawMessage) => void
    onMessageRecalled?: (payload: any) => void
    onMessageRead?: (payload: any) => void
    onPresenceChanged?: (payload: any) => void
    onMessagePinned?: (payload: any) => void
    onMessageUnpinned?: (payload: any) => void
    onReactionAdded?: (payload: any) => void
    onReactionRemoved?: (payload: any) => void
    onGroupMemberAdded?: (payload: any) => void
    onGroupMemberRemoved?: (payload: any) => void
    onGroupMemberLeft?: (payload: any) => void
    onGroupRoleChanged?: (payload: any) => void
    onGroupDisbanded?: (payload: any) => void
    onGroupUpdated?: (payload: any) => void
    onFriendshipUpdated?: (payload: any) => void
  } = {}

  private listenersAttached = false

  constructor() {
    // Auto-register to clear cache on disconnect
    onDisconnectCallbacks.add(() => this.clearJoinedConversations())
  }

  /**
   * Register event handler callbacks
   * Called once per component mount to inject latest callback refs
   */
  registerEventHandlers(handlers: typeof this.eventHandlers) {
    Object.assign(this.eventHandlers, handlers)
    console.log('[ChatSocketService] Event handlers registered')
  }

  /**
   * Attach listeners to socket (ONE-TIME)
   * Prevents listener re-attachment race conditions
   */
  attachEventListeners() {
    if (!this.socket || this.listenersAttached) {
      console.warn('[ChatSocketService] Socket not ready or listeners already attached')
      return
    }

    this.listenersAttached = true

    // Wrapper functions that call registered handlers
    const handleConnect = () => {
      console.log('[Socket] âœ… Connected')
      this.eventHandlers.onConnected?.()
    }

    const handleDisconnect = () => {
      console.log('[Socket] âšª Disconnected')
      this.listenersAttached = false // Reset flag on disconnect
      this.eventHandlers.onDisconnected?.()
    }

    const handleMessageReceived = (payload: RawMessage) => {
      console.log('[Socket] ðŸ“¨ message.received:', payload.id)
      this.eventHandlers.onMessageReceived?.(payload)
    }

    const handleMessageSent = (payload: RawMessage) => {
      console.log('[Socket] ðŸ“¨ message.sent:', payload.id)
      // Treat 'message.sent' same as 'message.received' for redundancy
      this.eventHandlers.onMessageReceived?.(payload)
    }

    const handleMessageRecalled = (payload: any) => {
      console.log('[ChatSocketService] message.recalled socket event received:', { messageId: payload?.messageId, conversationId: payload?.conversationId })
      console.log('[Socket] ðŸ”„ message.recalled:', payload.messageId)
      this.eventHandlers.onMessageRecalled?.(payload)
    }

    const handleMessageRead = (payload: any) => {
      console.log('[Socket] âœ“ message.read from', payload.userId)
      this.eventHandlers.onMessageRead?.(payload)
    }

    const handleMessagePinned = (payload: any) => {
      console.log('[Socket] ðŸ“Œ message.pinned:', payload.messageId)
      this.eventHandlers.onMessagePinned?.(payload)
    }

    const handleMessageUnpinned = (payload: any) => {
      console.log('[Socket] ðŸ“ message.unpinned:', payload.messageId)
      this.eventHandlers.onMessageUnpinned?.(payload)
    }

    const handleReactionAdded = (payload: any) => {
      console.log('[Socket] ðŸ˜€ reaction.added:', payload.emoji)
      this.eventHandlers.onReactionAdded?.(payload)
    }

    const handleReactionRemoved = (payload: any) => {
      console.log('[Socket] âŒ reaction.removed:', payload.emoji)
      this.eventHandlers.onReactionRemoved?.(payload)
    }

    const handlePresenceChanged = (payload: any) => {
      console.log('[Socket] ðŸ‘¤ presence.changed:', payload.userId, payload.status)
      this.eventHandlers.onPresenceChanged?.(payload)
    }

    const handleGroupMemberAdded = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.memberAdded')
      this.eventHandlers.onGroupMemberAdded?.(payload)
    }

    const handleGroupMemberRemoved = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.memberRemoved')
      this.eventHandlers.onGroupMemberRemoved?.(payload)
    }

    const handleGroupMemberLeft = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.memberLeft')
      this.eventHandlers.onGroupMemberLeft?.(payload)
    }

    const handleGroupRoleChanged = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.roleChanged')
      this.eventHandlers.onGroupRoleChanged?.(payload)
    }

    const handleGroupDisbanded = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.disbanded')
      this.eventHandlers.onGroupDisbanded?.(payload)
    }

    const handleGroupUpdated = (payload: any) => {
      console.log('[Socket] ðŸ‘¥ group.updated')
      this.eventHandlers.onGroupUpdated?.(payload)
    }

    const handleFriendshipUpdated = (payload: any) => {
      console.log('[Socket] ðŸ¤ friendship.updated:', payload.friendId)
      this.eventHandlers.onFriendshipUpdated?.(payload)
    }

    // Attach all listeners
    this.socket.on('connect', handleConnect)
    this.socket.on('disconnect', handleDisconnect)
    this.socket.on('message.received', handleMessageReceived)
    this.socket.on('message.sent', handleMessageSent)
    this.socket.on('message.recalled', handleMessageRecalled)
    this.socket.on('message.read', handleMessageRead)
    this.socket.on('message.pinned', handleMessagePinned)
    this.socket.on('message.unpinned', handleMessageUnpinned)
    this.socket.on('message.reaction.added', handleReactionAdded)
    this.socket.on('message.reaction.removed', handleReactionRemoved)
    this.socket.on('presence.changed', handlePresenceChanged)
    this.socket.on('group.memberAdded', handleGroupMemberAdded)
    this.socket.on('group.memberRemoved', handleGroupMemberRemoved)
    this.socket.on('group.memberLeft', handleGroupMemberLeft)
    this.socket.on('group.roleChanged', handleGroupRoleChanged)
    this.socket.on('group.disbanded', handleGroupDisbanded)
    this.socket.on('group.updated', handleGroupUpdated)
    this.socket.on('friendship.updated', handleFriendshipUpdated)

    console.log('[ChatSocketService] âœ… All event listeners attached')
  }

  connect(token: string): Socket {
    this.socket = getOrCreateSocket(token)
    return this.socket
  }

  getRootSocket(token: string): Socket { return getOrCreateRootSocket(token) }

  disconnect() {
    this.listenersAttached = false
    disconnectSocket()
    this.socket = null
    this.clearJoinedConversations()
  }

  clearJoinedConversations() {
    this.joinedConversations.clear()
    console.log('[ChatSocketService] ðŸ§¹ Cache cleared due to disconnect/reset')
  }

  isConnected(): boolean { return Boolean(this.socket?.connected) }
  getSocket(): Socket | null { return this.socket }

  async emitSendMessage(payload: SocketMessagePayload): Promise<SendMessageAck | null> {
    const socket = this.socket || globalChatSocket;
    if (!socket?.connected) {
      return { event: 'message.error', message: 'Socket not connected' }
    }

    // Ensure we're in the room BEFORE sending message (wait for server ack)
    if (!joinedRooms.has(payload.conversationId)) {
      console.log('[SEND] âš¡ Ensuring room join before send:', payload.conversationId)
      const joined = await this.joinConversation(payload.conversationId)
      if (!joined) {
        console.warn('[SEND] âŒ Failed to join room, cannot send')
        return { event: 'message.error', message: 'Failed to join conversation' }
      }
    }

    return new Promise((resolve) => {
      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) return
        settled = true
        console.warn('[SEND] âš ï¸ Socket stalling, switching to REST API...')
        resolve({ event: 'message.error', message: 'Timeout' })
      }, 1000)

      socket.emit('message.send', payload, (ack: unknown) => {
        if (settled) return
        settled = true
        window.clearTimeout(timeoutId)
        resolve((ack as SendMessageAck | null) ?? null)
      })
    })
  }

  async emitRecallMessage(payload: RecallMessagePayload): Promise<RecallMessageAck | null> {
    const socket = this.socket || globalChatSocket;
    if (!socket?.connected) return { event: 'message.error', message: 'Disconnected' }

    return new Promise((resolve) => {
      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) return
        settled = true
        resolve({ event: 'message.error', message: 'Timeout' })
      }, SEND_ACK_TIMEOUT_MS)

      socket.emit('message.recall', payload, (ack: unknown) => {
        if (settled) return
        settled = true
        window.clearTimeout(timeoutId)
        resolve((ack as RecallMessageAck | null) ?? null)
      })
    })
  }

  async joinConversation(conversationId: string): Promise<boolean> {
    const socket = this.socket || globalChatSocket;
    if (!socket) {
      console.warn('[JOIN] âŒ Socket is null, cannot join')
      return false
    }

    // Check if already joined (globally tracked)
    if (joinedRooms.has(conversationId)) {
      console.log('[JOIN] â„¹ï¸ Already in room:', conversationId)
      return true
    }

    // If socket not connected, queue for later
    if (!socket.connected) {
      console.log('[JOIN] âš ï¸ Socket not connected, queuing join:', conversationId)
      pendingRoomJoins.add(conversationId)
      return false
    }

    console.log('[JOIN] ðŸš€ Joining:', conversationId)
    
    // Wait for server ACK before marking as joined
    return new Promise((resolve) => {
      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) return
        settled = true
        console.warn('[JOIN] âš ï¸ Join timeout, fallback to optimistic join')
        joinedRooms.add(conversationId)
        this.joinedConversations.add(conversationId)
        resolve(true)
      }, 3000)

      socket.emit('conversation.join', { conversationId }, (ack: unknown) => {
        if (settled) return
        settled = true
        window.clearTimeout(timeoutId)
        
        const response = ack as {
          success?: boolean
          joined?: boolean
          event?: string
          data?: { conversationId?: string }
        } | null
        const success =
          response?.success === true ||
          response?.joined === true ||
          response?.event === 'conversation.joined' ||
          response?.data?.conversationId === conversationId
        
        if (success) {
          console.log('[JOIN] âœ… Server confirmed join:', conversationId)
          joinedRooms.add(conversationId)
          this.joinedConversations.add(conversationId)
          resolve(true)
        } else {
          console.warn('[JOIN] âŒ Server rejected join:', conversationId)
          resolve(false)
        }
      })
    })
  }

  /**
   * Join multiple conversations in batch (reduces latency)
   * Waits for all joins to be confirmed before returning
   */
  async joinMultipleConversations(conversationIds: string[]): Promise<void> {
    const socket = this.socket || globalChatSocket;
    if (!socket) return

    if (!socket.connected) {
      const connected = await waitForSocketConnect(3000)
      if (!connected) return
    }

    const toJoin = conversationIds.filter(id => !this.joinedConversations.has(id))
    if (toJoin.length === 0) return

    console.log('[JOIN] ðŸš€ Batch joining', toJoin.length, 'conversations with acks')
    
    // Join all conversations in parallel and wait for all to complete
    const joinPromises = toJoin.map(conversationId => this.joinConversation(conversationId))
    const results = await Promise.all(joinPromises)
    
    const successCount = results.filter(r => r).length
    console.log(`[JOIN] âœ… Successfully joined ${successCount}/${toJoin.length} conversations`)
  }

  markAsRead(payload: MessageReadPayload): boolean {
    const socket = this.socket || globalChatSocket;
    if (!socket?.connected) return false
    socket.emit('message.read', {
      ...payload,
      conversation_id: payload.conversationId,
      last_read_seq: payload.lastReadSeq,
    })
    return true
  }

  on<T = unknown>(event: string, handler: (payload: T) => void) {
    const socket = this.socket || globalChatSocket;
    if (!socket) return
    socket.off(event, handler)
    socket.on(event, handler)
  }

  off(event: string, handler?: (...args: unknown[]) => void) {
    const socket = this.socket || globalChatSocket;
    socket?.off(event, handler)
  }
}

export function createChatSocket(token: string): Socket {
  const service = new ChatSocketService()
  return service.connect(token)
}

export function emitSendMessage(socket: Socket, payload: SocketMessagePayload): Promise<SendMessageAck | null> {
  return new Promise((resolve) => {
    let settled = false
    const timeoutId = window.setTimeout(() => {
      if (settled) return
      settled = true
      resolve({ event: 'message.error', message: 'Timeout' })
    }, SEND_ACK_TIMEOUT_MS)

    socket.emit('message.send', payload, (ack: unknown) => {
      if (settled) return
      settled = true
      window.clearTimeout(timeoutId)
      resolve((ack as SendMessageAck | null) ?? null)
    })
  })
}

