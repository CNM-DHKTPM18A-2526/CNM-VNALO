import { io, type Socket } from 'socket.io-client'
import type { RawMessage } from './chat.api'
import type { ChatMessageType, ReplyMetadata } from './chat.types'

const fallbackProtocol = typeof window !== 'undefined' ? window.location.protocol.replace(':', '') : 'http'
const fallbackHost = typeof window !== 'undefined' ? window.location.hostname : 'localhost'
const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? `${fallbackProtocol}://${fallbackHost}:3000/api/v1`
// All services route through Nginx gateway at 13.250.2.132; Socket.io connects via /socket.io/ path
const SOCKET_URL =
  import.meta.env.VITE_SOCKET_URL ?? MESSAGE_API_URL.replace(/\/api\/v1\/?$/, '')

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

const SEND_ACK_TIMEOUT_MS = 4000

export type MessageReadPayload = {
  conversationId: string
  lastReadSeq?: number
}

export type PresenceChangedPayload = {
  userId: string
  status: 'online' | 'offline' | string
  lastSeen?: string | null
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SOCKET SINGLETON (prevents React StrictMode re-renders from creating new instances)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
let globalSocketManager: any = null
let globalSocketToken: string | null = null

let globalChatSocket: Socket | null = null
let globalRootSocket: Socket | null = null

export function getOrCreateSocketManager(token: string): { chat: Socket; root: Socket } {
  const incomingToken = token.trim()

  if (globalSocketManager && globalSocketToken && globalSocketToken !== incomingToken) {
    console.log('[SocketManager] Token changed, recreating connection')
    globalChatSocket?.disconnect()
    globalRootSocket?.disconnect()
    globalChatSocket = null
    globalRootSocket = null
    globalSocketManager = null
  }

  if (globalChatSocket && globalRootSocket && globalSocketToken === incomingToken) {
    return { chat: globalChatSocket, root: globalRootSocket }
  }

  if (!globalSocketManager) {
    console.log('[SocketManager] Initializing Manager connection to:', SOCKET_URL)
    globalSocketToken = incomingToken

    // Create sockets for both namespaces sharing the same connection
    const options = {
      transports: ['websocket'],
      auth: { token },
      reconnection: true,
      // Required when connecting through Nginx reverse proxy (EC2 port 80).
      // Socket.io client defaults to /<namespace>/socket.io/ which breaks Nginx routing.
      path: '/socket.io/',
    }

    // Use only the /chat namespace as the primary connection, matching Mobile.
    // We point everything to this one instance to avoid identity fragmentation.
    globalSocketManager = io(`${SOCKET_URL}/chat`, options)
    globalChatSocket = globalSocketManager
    globalRootSocket = globalSocketManager // Shadow reference for backward compatibility

    if (globalChatSocket) {
      globalChatSocket.on('connect', () => {
        console.log('[Socket.CHAT] ✅ Connected Unified Socket:', globalChatSocket?.id)
      })

      // Listen to everything for heavy debugging
      globalChatSocket.onAny((event, ...args) => {
        if (typeof event === 'string' && event.startsWith('call.')) {
          console.log(`[Socket.CHAT][SIGNAL] ${event} received:`, args)
        }
      })
    }
  }

  return { chat: globalChatSocket!, root: globalRootSocket! }
}

export function getOrCreateRootSocket(token: string): Socket {
  return getOrCreateSocketManager(token).root
}

export function getOrCreateSocket(token: string): Socket {
  return getOrCreateSocketManager(token).chat
}

export function disconnectSocket() {
  if (globalChatSocket) {
    globalChatSocket.disconnect()
    globalChatSocket = null
  }
  if (globalRootSocket) {
    globalRootSocket.disconnect()
    globalRootSocket = null
  }
  globalSocketManager = null
  globalSocketToken = null
}

export function waitForSocketConnect(timeoutMs: number = 5000): Promise<boolean> {
  return new Promise((resolve) => {
    if (!globalChatSocket) {
      console.warn('[Socket.waitForConnect] No global chat socket')
      return resolve(false)
    }

    if (globalChatSocket.connected) {
      console.log('[Socket.waitForConnect] Socket already connected, ID:', globalChatSocket.id)
      return resolve(true)
    }

    const timer = setTimeout(() => {
      console.error('[Socket.waitForConnect] Timeout waiting for connection')
      resolve(false)
    }, timeoutMs)

    globalChatSocket.once('connect', () => {
      clearTimeout(timer)
      console.log('[Socket.waitForConnect] Socket connected successfully, ID:', globalChatSocket?.id)
      resolve(true)
    })
  })
}

export class ChatSocketService {
  private socket: Socket | null = null
  private joinedConversations = new Set<string>()

  connect(token: string): Socket {
    this.socket = getOrCreateSocket(token)
    console.log('[ChatSocketService.connect] Socket obtained, ID:', this.socket.id)
    return this.socket
  }

  getRootSocket(token: string): Socket {
    return getOrCreateRootSocket(token)
  }

  disconnect() {
    // Do NOT disconnect in hook cleanup (causes issues in Strict Mode)
    // Only disconnect when explicitly called by logout/unmount
    if (!this.socket) {
      return
    }
    console.log('[ChatSocketService.disconnect] Explicit disconnect requested')
    disconnectSocket()
    this.socket = null
    this.joinedConversations.clear()
  }

  clearJoinedConversations() {
    if (!this.joinedConversations) {
      this.joinedConversations = new Set<string>()
      return
    }

    this.joinedConversations.clear()
  }

  isConnected(): boolean {
    return Boolean(this.socket?.connected)
  }

  getSocket(): Socket | null {
    return this.socket
  }

  async emitSendMessage(payload: SocketMessagePayload): Promise<SendMessageAck | null> {
    if (!this.joinedConversations) {
      this.joinedConversations = new Set<string>()
    }

    if (!this.socket?.connected) {
      console.error('[SEND] ❌ Socket not connected', {
        socket: Boolean(this.socket),
        connected: this.socket?.connected,
        socketId: this.socket?.id,
      })
      return {
        event: 'message.error',
        message: 'Socket is not connected',
      }
    }

    if (!this.joinedConversations.has(payload.conversationId)) {
      console.error('[SEND] ❌ Conversation NOT joined before send', {
        conversationId: payload.conversationId,
        joinedCount: this.joinedConversations.size,
        joined: Array.from(this.joinedConversations),
      })
      return {
        event: 'message.error',
        message: `Conversation ${payload.conversationId} not joined`,
      }
    }

    console.log('[SEND] ✅ Conditions met:', {
      socketConnected: true,
      conversationJoined: true,
      conversationId: payload.conversationId,
      socketId: this.socket.id,
      contentLength: payload.content.length,
    })

    return new Promise((resolve) => {
      if (!this.socket) {
        return resolve({
          event: 'message.error',
          message: 'Socket instance unavailable',
        })
      }

      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) {
          return
        }
        settled = true
        console.error('[SEND] ❌ ACK timeout from backend')
        resolve({
          event: 'message.error',
          message: 'ACK timeout from backend',
        })
      }, SEND_ACK_TIMEOUT_MS)

      console.log('[SEND] Emitting message.send to backend...')
      this.socket.emit('message.send', payload, (ack: unknown) => {
        if (settled) {
          return
        }
        settled = true
        window.clearTimeout(timeoutId)
        console.log('[SEND] ✅ Received ACK from backend:', ack)
        resolve((ack as SendMessageAck | null) ?? null)
      })
    })
  }

  async emitRecallMessage(payload: RecallMessagePayload): Promise<RecallMessageAck | null> {
    if (!this.joinedConversations) {
      this.joinedConversations = new Set<string>()
    }

    if (!this.socket?.connected) {
      return {
        event: 'message.error',
        message: 'Socket is not connected',
      }
    }

    if (!this.joinedConversations.has(payload.conversationId)) {
      return {
        event: 'message.error',
        message: `Conversation ${payload.conversationId} not joined`,
      }
    }

    return new Promise((resolve) => {
      if (!this.socket) {
        return resolve({
          event: 'message.error',
          message: 'Socket instance unavailable',
        })
      }

      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) {
          return
        }
        settled = true
        resolve({
          event: 'message.error',
          message: 'ACK timeout from backend',
        })
      }, SEND_ACK_TIMEOUT_MS)

      this.socket.emit('message.recall', payload, (ack: unknown) => {
        if (settled) {
          return
        }
        settled = true
        window.clearTimeout(timeoutId)
        resolve((ack as RecallMessageAck | null) ?? null)
      })
    })
  }

  async joinConversation(conversationId: string): Promise<boolean> {
    if (!this.socket) {
      console.error('[JOIN] ❌ No socket instance')
      return false
    }

    if (!this.joinedConversations) {
      this.joinedConversations = new Set<string>()
    }

    if (this.joinedConversations.has(conversationId)) {
      // Already joined, skip to avoid infinite loop
      return true
    }

    if (!this.socket.connected) {
      console.log('[JOIN] ⏳ Socket not connected yet, waiting for connect event...')
      const connected = await waitForSocketConnect(5000)
      if (!connected) {
        console.error('[JOIN] ❌ Socket never connected, giving up')
        return false
      }
    }

    console.log('[JOIN] 🚀 Emitting join for:', conversationId, '| Socket ID:', this.socket.id)
    this.socket.emit('conversation.join', { conversationId })

    // Also join on root socket for signaling if it exists. 
    // Do NOT check for .connected, Socket.io will buffer the emit if needed.
    if (globalRootSocket) {
      console.log('[JOIN.ROOT] Emitting join for:', conversationId)
      globalRootSocket.emit('conversation.join', { conversationId })
    }

    this.joinedConversations.add(conversationId)
    console.log('[JOIN] ✅ Join emitted for conversation:', conversationId)

    return true
  }

  markAsRead(payload: MessageReadPayload): boolean {
    if (!this.socket?.connected) {
      return false
    }

    if (payload.lastReadSeq === undefined) {
      this.socket.emit('message.read', { conversationId: payload.conversationId })
      return true
    }

    this.socket.emit('message.read', payload)
    return true
  }

  on<T = unknown>(event: string, handler: (payload: T) => void) {
    if (!this.socket) {
      console.warn('[Socket.on] Socket not initialized for event:', event)
      return
    }
    // Remove old listener before adding new one (prevent duplicates in Strict Mode)
    this.socket.off(event, handler)
    this.socket.on(event, handler)
  }

  off(event: string, handler?: (...args: unknown[]) => void) {
    this.socket?.off(event, handler)
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
      if (settled) {
        return
      }
      settled = true
      resolve({
        event: 'message.error',
        message: 'ACK timeout from backend',
      })
    }, SEND_ACK_TIMEOUT_MS)

    socket.emit('message.send', payload, (ack: unknown) => {
      if (settled) {
        return
      }
      settled = true
      window.clearTimeout(timeoutId)
      resolve((ack as SendMessageAck | null) ?? null)
    })
  })
}
