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

const SEND_ACK_TIMEOUT_MS = 3000 // Tăng tốc độ timeout để báo lỗi nhanh hơn

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
// SOCKET SINGLETON
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
let globalSocketManager: any = null
let globalSocketToken: string | null = null

let globalChatSocket: Socket | null = null
let globalRootSocket: Socket | null = null

// Registry to notify services when connection is lost
const onDisconnectCallbacks = new Set<() => void>()

export function getOrCreateSocketManager(token: string): { chat: Socket; root: Socket } {
  const incomingToken = token.trim()

  if (globalSocketManager && globalSocketToken && globalSocketToken !== incomingToken) {
    console.log('[SocketManager] Token changed, recreating connection')
    globalChatSocket?.disconnect()
    globalChatSocket = null
    globalSocketManager = null
  }

  if (globalChatSocket && globalSocketToken === incomingToken) {
    return { chat: globalChatSocket, root: globalChatSocket }
  }

  if (!globalSocketManager) {
    console.log('[SocketManager] Initializing connection to:', SOCKET_URL)
    globalSocketToken = incomingToken

    const options = {
      transports: ['websocket'], //Ưu tiên websocket để giảm độ trễ
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
      console.log('[Socket.CHAT] ✅ Connected ID:', globalChatSocket?.id)
    })

    globalChatSocket?.on('disconnect', (reason) => {
      console.warn('[Socket.CHAT] ⚪ Disconnected:', reason)
      // Notify all services to clear their room cache
      onDisconnectCallbacks.forEach(cb => cb())
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

  constructor() {
    // Auto-register to clear cache on disconnect
    onDisconnectCallbacks.add(() => this.clearJoinedConversations())
  }

  connect(token: string): Socket {
    this.socket = getOrCreateSocket(token)
    return this.socket
  }

  getRootSocket(token: string): Socket { return getOrCreateRootSocket(token) }

  disconnect() {
    disconnectSocket()
    this.socket = null
    this.clearJoinedConversations()
  }

  clearJoinedConversations() {
    this.joinedConversations.clear()
    console.log('[ChatSocketService] 🧹 Cache cleared due to disconnect/reset')
  }

  isConnected(): boolean { return Boolean(this.socket?.connected) }
  getSocket(): Socket | null { return this.socket }

  async emitSendMessage(payload: SocketMessagePayload): Promise<SendMessageAck | null> {
    const socket = this.socket || globalChatSocket;
    if (!socket?.connected) {
      return { event: 'message.error', message: 'Socket not connected' }
    }

    if (!this.joinedConversations.has(payload.conversationId)) {
      console.log('[SEND] ⚡ Auto-joining room before send:', payload.conversationId)
      socket.emit('conversation.join', { conversationId: payload.conversationId })
      this.joinedConversations.add(payload.conversationId)
    }

    return new Promise((resolve) => {
      let settled = false
      const timeoutId = window.setTimeout(() => {
        if (settled) return
        settled = true
        console.warn('[SEND] ⚠️ Socket stalling, switching to REST API...')
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
    if (!socket) return false

    if (this.joinedConversations.has(conversationId)) return true

    if (!socket.connected) {
      const connected = await waitForSocketConnect(3000)
      if (!connected) return false
    }

    console.log('[JOIN] 🚀 Joining:', conversationId)
    socket.emit('conversation.join', { conversationId })
    this.joinedConversations.add(conversationId)
    return true
  }

  markAsRead(payload: MessageReadPayload): boolean {
    const socket = this.socket || globalChatSocket;
    if (!socket?.connected) return false
    socket.emit('message.read', payload)
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
