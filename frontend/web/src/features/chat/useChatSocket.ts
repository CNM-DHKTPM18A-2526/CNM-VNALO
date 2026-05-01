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
  onMessagePinned?: (payload: { pin: any; pinnedBy: string }) => void
  onMessageUnpinned?: (payload: { messageId: string; conversationId: string; unpinnedBy: string }) => void
  onReactionAdded?: (payload: { messageId: string; userId: string; emoji: string }) => void
  onReactionRemoved?: (payload: { messageId: string; userId: string; emoji: string }) => void
  onGroupMemberAdded?: (payload: { conversationId: string; targetMemberIds: string[]; actorId: string }) => void
  onGroupMemberRemoved?: (payload: { conversationId: string; targetMemberIds: string[]; actorId: string }) => void
  onGroupMemberLeft?: (payload: { conversationId: string; actorId: string }) => void
  onGroupRoleChanged?: (payload: { conversationId: string; targetUserId: string; role: string; actorId: string }) => void
  onGroupDisbanded?: (payload: { conversationId: string }) => void
  onGroupUpdated?: (payload: { conversationId: string; metadata: any }) => void
  onFriendshipUpdated?: (payload: { friendId: string }) => void
  onMessageError?: (payload: { code: string; message: string; clientMessageId?: string; conversationId?: string }) => void
  onConversationError?: (payload: { code: string; message: string; conversationId?: string }) => void
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SINGLETON SERVICE (prevents multiple instances)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
let globalChatService: ChatSocketService | null = null
let globalListenersAttached = false

function getOrCreateChatService(): ChatSocketService {
  if (!globalChatService) {
    console.log('[useChatSocket] Creating singleton ChatSocketService')
    globalChatService = new ChatSocketService()
  }
  return globalChatService
}

function resetGlobalState() {
  globalListenersAttached = false
}

export function useChatSocket(options: UseChatSocketOptions) {
  const { token, onConnected, onDisconnected, onMessageReceived, onMessageRecalled, onMessageRead, onPresenceChanged } = options;
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CALLBACK REFS — Updated on every render so handlers always have
  // fresh closures without being recreated themselves.
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  const hasConnectedRef = useRef(false)

  const onConnectedRef = useRef<UseChatSocketOptions['onConnected']>(onConnected)
  const onDisconnectedRef = useRef<UseChatSocketOptions['onDisconnected']>(onDisconnected)
  const onMessageReceivedRef = useRef<UseChatSocketOptions['onMessageReceived']>(onMessageReceived)
  const onMessageRecalledRef = useRef<UseChatSocketOptions['onMessageRecalled']>(onMessageRecalled)
  const onMessageReadRef = useRef<UseChatSocketOptions['onMessageRead']>(onMessageRead)
  const onPresenceChangedRef = useRef<UseChatSocketOptions['onPresenceChanged']>(onPresenceChanged)
  const onMessagePinnedRef = useRef<UseChatSocketOptions['onMessagePinned']>(options.onMessagePinned)
  const onMessageUnpinnedRef = useRef<UseChatSocketOptions['onMessageUnpinned']>(options.onMessageUnpinned)
  const onReactionAddedRef = useRef<UseChatSocketOptions['onReactionAdded']>(options.onReactionAdded)
  const onReactionRemovedRef = useRef<UseChatSocketOptions['onReactionRemoved']>(options.onReactionRemoved)
  const onGroupMemberAddedRef = useRef<UseChatSocketOptions['onGroupMemberAdded']>(options.onGroupMemberAdded)
  const onGroupMemberRemovedRef = useRef<UseChatSocketOptions['onGroupMemberRemoved']>(options.onGroupMemberRemoved)
  const onGroupMemberLeftRef = useRef<UseChatSocketOptions['onGroupMemberLeft']>(options.onGroupMemberLeft)
  const onGroupRoleChangedRef = useRef<UseChatSocketOptions['onGroupRoleChanged']>(options.onGroupRoleChanged)
  const onGroupDisbandedRef = useRef<UseChatSocketOptions['onGroupDisbanded']>(options.onGroupDisbanded)
  const onGroupUpdatedRef = useRef<UseChatSocketOptions['onGroupUpdated']>(options.onGroupUpdated)

  const onFriendshipUpdatedRef = useRef<UseChatSocketOptions['onFriendshipUpdated']>(options.onFriendshipUpdated)
  const onMessageErrorRef = useRef<UseChatSocketOptions['onMessageError']>(options.onMessageError)
  const onConversationErrorRef = useRef<UseChatSocketOptions['onConversationError']>(options.onConversationError)

  // Keep refs in sync with latest callback props (runs synchronously each render)
  useEffect(() => {
    onConnectedRef.current = options.onConnected
    onDisconnectedRef.current = options.onDisconnected
    onMessageReceivedRef.current = options.onMessageReceived
    onMessageRecalledRef.current = options.onMessageRecalled
    onMessageReadRef.current = options.onMessageRead
    onPresenceChangedRef.current = options.onPresenceChanged
    onMessagePinnedRef.current = options.onMessagePinned
    onMessageUnpinnedRef.current = options.onMessageUnpinned
    onReactionAddedRef.current = options.onReactionAdded
    onReactionRemovedRef.current = options.onReactionRemoved
    onGroupMemberAddedRef.current = options.onGroupMemberAdded
    onGroupMemberRemovedRef.current = options.onGroupMemberRemoved
    onGroupMemberLeftRef.current = options.onGroupMemberLeft
    onGroupRoleChangedRef.current = options.onGroupRoleChanged
    onGroupDisbandedRef.current = options.onGroupDisbanded
    onGroupUpdatedRef.current = options.onGroupUpdated
    onFriendshipUpdatedRef.current = options.onFriendshipUpdated
    onMessageErrorRef.current = options.onMessageError
    onConversationErrorRef.current = options.onConversationError
  }, [options])

  const stableHandleConnect = useRef(() => {
    console.log('[useChatSocket] ✅ CONNECTED')
    onConnectedRef.current?.()
  })
  const stableHandleDisconnect = useRef(() => {
    console.log('[useChatSocket] ⚪ DISCONNECTED')
    getOrCreateChatService().clearJoinedConversations()
    onDisconnectedRef.current?.()
  })
  const stableHandleMessageReceived = useRef((payload: RawMessage) => {
    onMessageReceivedRef.current?.(payload)
  })
  const stableHandleMessageRecalled = useRef((payload: { messageId: string; conversationId: string; recalledBy: string }) => {
    onMessageRecalledRef.current?.(payload)
  })
  const stableHandleMessageRead = useRef((payload: { userId: string; conversationId: string; lastReadSeq: number }) => {
    onMessageReadRef.current?.(payload)
  })
  const stableHandlePresenceChanged = useRef((payload: PresenceChangedPayload) => {
    onPresenceChangedRef.current?.(payload)
  })
  const stableHandleMessagePinned = useRef((payload: any) => onMessagePinnedRef.current?.(payload))
  const stableHandleMessageUnpinned = useRef((payload: any) => onMessageUnpinnedRef.current?.(payload))
  const stableHandleReactionAdded = useRef((payload: any) => onReactionAddedRef.current?.(payload))
  const stableHandleReactionRemoved = useRef((payload: any) => onReactionRemovedRef.current?.(payload))
  const stableHandleGroupMemberAdded = useRef((payload: any) => onGroupMemberAddedRef.current?.(payload))
  const stableHandleGroupMemberRemoved = useRef((payload: any) => onGroupMemberRemovedRef.current?.(payload))
  const stableHandleGroupMemberLeft = useRef((payload: any) => onGroupMemberLeftRef.current?.(payload))
  const stableHandleGroupRoleChanged = useRef((payload: any) => onGroupRoleChangedRef.current?.(payload))
  const stableHandleGroupDisbanded = useRef((payload: any) => onGroupDisbandedRef.current?.(payload))
  const stableHandleGroupUpdated = useRef((payload: any) => onGroupUpdatedRef.current?.(payload))
  const stableHandleFriendshipUpdated = useRef((payload: any) => onFriendshipUpdatedRef.current?.(payload))


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // REGISTER EVENT HANDLERS ON GLOBAL SERVICE (idempotent)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  useEffect(() => {
    const service = getOrCreateChatService()
    
    // Register handlers on service (NOT socket directly to avoid listener lifecycle issues)
    service.registerEventHandlers({
      onConnected: stableHandleConnect.current,
      onDisconnected: stableHandleDisconnect.current,
      onMessageReceived: stableHandleMessageReceived.current,
      onMessageRecalled: stableHandleMessageRecalled.current,
      onMessageRead: stableHandleMessageRead.current,
      onPresenceChanged: stableHandlePresenceChanged.current,
      onMessagePinned: stableHandleMessagePinned.current,
      onMessageUnpinned: stableHandleMessageUnpinned.current,
      onReactionAdded: stableHandleReactionAdded.current,
      onReactionRemoved: stableHandleReactionRemoved.current,
      onGroupMemberAdded: stableHandleGroupMemberAdded.current,
      onGroupMemberRemoved: stableHandleGroupMemberRemoved.current,
      onGroupMemberLeft: stableHandleGroupMemberLeft.current,
      onGroupRoleChanged: stableHandleGroupRoleChanged.current,
      onGroupDisbanded: stableHandleGroupDisbanded.current,
      onGroupUpdated: stableHandleGroupUpdated.current,
      onFriendshipUpdated: stableHandleFriendshipUpdated.current,
    })

    // Only attach listeners ONCE to socket to prevent race conditions
    const socket = service.getSocket()
    if (!globalListenersAttached && socket) {
      globalListenersAttached = true
      console.log('[useChatSocket] 🎯 Attaching listeners to socket (one-time)')
      service.attachEventListeners()

      // Reset flag on disconnect so listeners are re-attached on reconnect
      socket.on('disconnect', () => {
        console.log('[useChatSocket] Reset listener flag on disconnect for next reconnect')
        globalListenersAttached = false
      })
    }
  }, [])

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CONNECT WHEN TOKEN PROVIDED
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  useEffect(() => {
    if (!token) {
      console.log('[useChatSocket.effect] Skipping: no token provided')
      hasConnectedRef.current = false
      resetGlobalState()
      getOrCreateChatService().disconnect()
      return
    }

    const service = getOrCreateChatService()

    if (!hasConnectedRef.current) {
      hasConnectedRef.current = true
      console.log('[useChatSocket.effect] ✅ Initializing socket connection with token')
    }

    const socket = service.connect(token)
    if (!socket) {
      console.warn('[useChatSocket.effect] Socket unavailable')
      return
    }

    console.log('[useChatSocket.effect] Socket obtained, ID:', socket.id, 'Connected:', socket.connected)

    // If already connected, replay onConnected callback
    if (socket.connected && socket.id) {
      queueMicrotask(() => {
        onConnectedRef.current?.()
      })
    }

    // Cleanup on token change or unmount
    return () => {
      // Don't disconnect here - let disconnect be called explicitly
    }
  }, [token])

  useEffect(() => {
    const handleAuthLogout = () => {
      hasConnectedRef.current = false
      getOrCreateChatService().disconnect()
    }

    window.addEventListener('vnalo:auth-logout', handleAuthLogout)

    const handleMessageError = (e: any) => {
      onMessageErrorRef.current?.(e.detail)
    }
    const handleConversationError = (e: any) => {
      onConversationErrorRef.current?.(e.detail)
    }

    window.addEventListener('vnalo:socket:message-error', handleMessageError)
    window.addEventListener('vnalo:socket:conversation-error', handleConversationError)

    return () => {
      window.removeEventListener('vnalo:auth-logout', handleAuthLogout)
      window.removeEventListener('vnalo:socket:message-error', handleMessageError)
      window.removeEventListener('vnalo:socket:conversation-error', handleConversationError)
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

  const joinMultipleConversations = useCallback(async (conversationIds: string[]): Promise<void> => {
    return getOrCreateChatService().joinMultipleConversations(conversationIds)
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
    joinMultipleConversations,
    markAsRead,
    isConnected,
    getSocket,
    getRootSocket,
    waitForConnect: waitForSocketConnect,
  }
}
