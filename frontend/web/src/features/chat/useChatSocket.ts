import { useCallback, useEffect, useRef } from 'react'

import type { RawMessage } from './chat.api'
import {
  ChatSocketService,
  type MessageReadPayload,
  type PresenceChangedPayload,
  type SendMessageAck,
  type SocketMessagePayload,
  waitForSocketConnect,
} from './chat.socket'

type UseChatSocketOptions = {
  token: string | null | undefined
  onConnected?: () => void
  onDisconnected?: () => void
  onMessageReceived?: (message: RawMessage) => void
  onMessageRecalled?: (payload: { messageId: string; conversationId: string; recalledBy: string }) => void
  onMessageRead?: (payload: { userId: string; conversationId: string; lastReadSeq: number }) => void
  onPresenceChanged?: (payload: PresenceChangedPayload) => void
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SINGLETON SERVICE (prevents multiple instances)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
let globalChatService: ChatSocketService | null = null

function getOrCreateChatService(): ChatSocketService {
  if (!globalChatService) {
    console.log('[useChatSocket] Creating singleton ChatSocketService')
    globalChatService = new ChatSocketService()
  }
  return globalChatService
}

export function useChatSocket({
  token,
  onConnected,
  onDisconnected,
  onMessageReceived,
  onMessageRecalled,
  onMessageRead,
  onPresenceChanged,
}: UseChatSocketOptions) {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SINGLE INITIALIZATION (prevents React Strict Mode double-connect)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  const hasConnectedRef = useRef(false)

  const onConnectedRef = useRef<UseChatSocketOptions['onConnected']>(onConnected)
  const onDisconnectedRef = useRef<UseChatSocketOptions['onDisconnected']>(onDisconnected)
  const onMessageReceivedRef = useRef<UseChatSocketOptions['onMessageReceived']>(onMessageReceived)
  const onMessageRecalledRef = useRef<UseChatSocketOptions['onMessageRecalled']>(onMessageRecalled)
  const onMessageReadRef = useRef<UseChatSocketOptions['onMessageRead']>(onMessageRead)
  const onPresenceChangedRef = useRef<UseChatSocketOptions['onPresenceChanged']>(onPresenceChanged)

  useEffect(() => {
    onConnectedRef.current = onConnected
    onDisconnectedRef.current = onDisconnected
    onMessageReceivedRef.current = onMessageReceived
    onMessageRecalledRef.current = onMessageRecalled
    onMessageReadRef.current = onMessageRead
    onPresenceChangedRef.current = onPresenceChanged
  }, [onConnected, onDisconnected, onMessageRead, onMessageReceived, onMessageRecalled, onPresenceChanged])

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CONNECT ONLY ONCE (even with Strict Mode)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  useEffect(() => {
    if (!token) {
      console.log('[useChatSocket.effect] Skipping: no token provided')
      hasConnectedRef.current = false
      getOrCreateChatService().disconnect()
      return
    }

    const service = getOrCreateChatService()

    // Connect only once, but always re-attach listeners on remount.
    let socket = service.getSocket()
    if (!hasConnectedRef.current) {
      hasConnectedRef.current = true
      console.log('[useChatSocket.effect] ✅ Initializing socket connection with token')
      socket = service.connect(token)
    } else {
      console.log('[useChatSocket.effect] Reusing existing socket connection, re-attaching listeners')
      socket = service.connect(token)
    }

    if (!socket) {
      console.warn('[useChatSocket.effect] Socket unavailable, skipping listener registration')
      return
    }

    console.log('[useChatSocket.effect] Socket obtained, ID:', socket.id, 'Connected:', socket.connected)

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SET UP LISTENERS (remove before adding to prevent duplicates)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    const handleConnect = () => {
      console.log('[useChatSocket.listener] ✅ CONNECTED event received, socket.id:', socket.id)
      onConnectedRef.current?.()
    }

    const handleDisconnect = () => {
      console.log('[useChatSocket.listener] ⚪ DISCONNECTED event received')
      getOrCreateChatService().clearJoinedConversations()
      onDisconnectedRef.current?.()
    }

    const handleMessageReceived = (payload: RawMessage) => {
      console.log('[useChatSocket.listener] 📨 message.received event:', {
        messageId: payload.id,
        conversationId: payload.conversationId,
        from: payload.senderId,
      })
      onMessageReceivedRef.current?.(payload)
    }

    const handleMessageRecalled = (payload: { messageId: string; conversationId: string; recalledBy: string }) => {
      console.log('[useChatSocket.listener] ↩️ message.recalled event', payload)
      onMessageRecalledRef.current?.(payload)
    }

    const handleMessageRead = (payload: { userId: string; conversationId: string; lastReadSeq: number }) => {
      console.log('[useChatSocket.listener] ✓ message.read event')
      onMessageReadRef.current?.(payload)
    }

    const handlePresenceChanged = (payload: PresenceChangedPayload) => {
      console.log('[useChatSocket.listener] 👤 presence.changed event', payload)
      onPresenceChangedRef.current?.(payload)
    }

    // Remove old listeners first to prevent duplicates in Strict Mode
    socket.off('connect', handleConnect)
    socket.off('disconnect', handleDisconnect)
    socket.off('message.received', handleMessageReceived)
    socket.off('message.recalled', handleMessageRecalled)
    socket.off('message.read', handleMessageRead)
    socket.off('presence.changed', handlePresenceChanged)

    // Add listeners
    socket.on('connect', handleConnect)
    socket.on('disconnect', handleDisconnect)
    socket.on('message.received', handleMessageReceived)
    socket.on('message.recalled', handleMessageRecalled)
    socket.on('message.read', handleMessageRead)
    socket.on('presence.changed', handlePresenceChanged)

    socket.onAny((event, ...args) => {
      // Log all events to help debug WebRTC signaling
      console.log('[useChatSocket.onAny] Received socket event:', event, 'Payload:', args)
    })

    if (socket.connected && socket.id) {
      queueMicrotask(() => {
        console.log('[useChatSocket.effect] Socket already connected, replaying onConnected, socket.id:', socket.id)
        onConnectedRef.current?.()
      })
    }

    return () => {
      // DO NOT DISCONNECT on cleanup in Strict Mode
      // This would cause immediate reconnect cycles
      // Only remove listeners to prevent leaks when switching tokens
      console.log('[useChatSocket.cleanup] Removing listeners (NOT disconnecting socket)')
      socket.off('connect', handleConnect)
      socket.off('disconnect', handleDisconnect)
      socket.off('message.received', handleMessageReceived)
      socket.off('message.recalled', handleMessageRecalled)
      socket.off('message.read', handleMessageRead)
      socket.off('presence.changed', handlePresenceChanged)
      socket.offAny()
    }
  }, [token])

  useEffect(() => {
    const handleAuthLogout = () => {
      hasConnectedRef.current = false
      getOrCreateChatService().disconnect()
    }

    window.addEventListener('vnalo:auth-logout', handleAuthLogout)
    return () => {
      window.removeEventListener('vnalo:auth-logout', handleAuthLogout)
    }
  }, [])

  const connect = useCallback(() => {
    if (!token) {
      return false
    }

    getOrCreateChatService().connect(token)
    return true
  }, [token])

  const disconnect = useCallback(() => {
    getOrCreateChatService().disconnect()
  }, [])

  const emitSendMessage = useCallback(async (payload: SocketMessagePayload): Promise<SendMessageAck | null> => {
    return getOrCreateChatService().emitSendMessage(payload) ?? null
  }, [])

  const emitRecallMessage = useCallback(async (payload: { messageId: string; conversationId: string }) => {
    return getOrCreateChatService().emitRecallMessage(payload) ?? null
  }, [])

  const joinConversation = useCallback(async (conversationId: string): Promise<boolean> => {
    return getOrCreateChatService().joinConversation(conversationId) ?? false
  }, [])

  const markAsRead = useCallback((payload: MessageReadPayload): boolean => {
    return getOrCreateChatService().markAsRead(payload) ?? false
  }, [])

  const isConnected = useCallback((): boolean => {
    return getOrCreateChatService().isConnected() ?? false
  }, [])

  const getSocket = useCallback(() => {
    return getOrCreateChatService().getSocket()
  }, [])

  const getRootSocket = useCallback(() => {
    if (!token) return null
    return getOrCreateChatService().getRootSocket(token)
  }, [token])

  return {
    connect,
    disconnect,
    emitSendMessage,
    emitRecallMessage,
    joinConversation,
    markAsRead,
    isConnected,
    getSocket,
    getRootSocket,
    waitForConnect: waitForSocketConnect,
  }
}
