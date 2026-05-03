import React from 'react'

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
  const hasConnectedRef = React.useRef(false)

  const onConnectedRef = React.useRef<UseChatSocketOptions['onConnected']>(onConnected)
  const onDisconnectedRef = React.useRef<UseChatSocketOptions['onDisconnected']>(onDisconnected)
  const onMessageReceivedRef = React.useRef<UseChatSocketOptions['onMessageReceived']>(onMessageReceived)
  const onMessageRecalledRef = React.useRef<UseChatSocketOptions['onMessageRecalled']>(onMessageRecalled)
  const onMessageReadRef = React.useRef<UseChatSocketOptions['onMessageRead']>(onMessageRead)
  const onPresenceChangedRef = React.useRef<UseChatSocketOptions['onPresenceChanged']>(onPresenceChanged)
  const onMessagePinnedRef = React.useRef<UseChatSocketOptions['onMessagePinned']>(options.onMessagePinned)
  const onMessageUnpinnedRef = React.useRef<UseChatSocketOptions['onMessageUnpinned']>(options.onMessageUnpinned)
  const onReactionAddedRef = React.useRef<UseChatSocketOptions['onReactionAdded']>(options.onReactionAdded)
  const onReactionRemovedRef = React.useRef<UseChatSocketOptions['onReactionRemoved']>(options.onReactionRemoved)
  const onGroupMemberAddedRef = React.useRef<UseChatSocketOptions['onGroupMemberAdded']>(options.onGroupMemberAdded)
  const onGroupMemberRemovedRef = React.useRef<UseChatSocketOptions['onGroupMemberRemoved']>(options.onGroupMemberRemoved)
  const onGroupMemberLeftRef = React.useRef<UseChatSocketOptions['onGroupMemberLeft']>(options.onGroupMemberLeft)
  const onGroupRoleChangedRef = React.useRef<UseChatSocketOptions['onGroupRoleChanged']>(options.onGroupRoleChanged)
  const onGroupDisbandedRef = React.useRef<UseChatSocketOptions['onGroupDisbanded']>(options.onGroupDisbanded)
  const onGroupUpdatedRef = React.useRef<UseChatSocketOptions['onGroupUpdated']>(options.onGroupUpdated)

  const onFriendshipUpdatedRef = React.useRef<UseChatSocketOptions['onFriendshipUpdated']>(options.onFriendshipUpdated)
  const onMessageErrorRef = React.useRef<UseChatSocketOptions['onMessageError']>(options.onMessageError)
  const onConversationErrorRef = React.useRef<UseChatSocketOptions['onConversationError']>(options.onConversationError)

  // Keep refs in sync with latest callback props (runs synchronously each render)
  React.useEffect(() => {
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

  const stableHandleConnect = React.useRef(() => {
    console.log('[useChatSocket] ✅ CONNECTED')
    onConnectedRef.current?.()
  })
  const stableHandleDisconnect = React.useRef(() => {
    console.log('[useChatSocket] ⚪ DISCONNECTED')
    getOrCreateChatService().clearJoinedConversations()
    onDisconnectedRef.current?.()
  })
  const stableHandleMessageReceived = React.useRef((payload: RawMessage) => {
    onMessageReceivedRef.current?.(payload)
  })
  const stableHandleMessageRecalled = React.useRef((payload: { messageId: string; conversationId: string; recalledBy: string }) => {
    onMessageRecalledRef.current?.(payload)
  })
  const stableHandleMessageRead = React.useRef((payload: { userId: string; conversationId: string; lastReadSeq: number }) => {
    onMessageReadRef.current?.(payload)
  })
  const stableHandlePresenceChanged = React.useRef((payload: PresenceChangedPayload) => {
    onPresenceChangedRef.current?.(payload)
  })
  const stableHandleMessagePinned = React.useRef((payload: any) => onMessagePinnedRef.current?.(payload))
  const stableHandleMessageUnpinned = React.useRef((payload: any) => onMessageUnpinnedRef.current?.(payload))
  const stableHandleReactionAdded = React.useRef((payload: any) => onReactionAddedRef.current?.(payload))
  const stableHandleReactionRemoved = React.useRef((payload: any) => onReactionRemovedRef.current?.(payload))
  const stableHandleGroupMemberAdded = React.useRef((payload: any) => onGroupMemberAddedRef.current?.(payload))
  const stableHandleGroupMemberRemoved = React.useRef((payload: any) => onGroupMemberRemovedRef.current?.(payload))
  const stableHandleGroupMemberLeft = React.useRef((payload: any) => onGroupMemberLeftRef.current?.(payload))
  const stableHandleGroupRoleChanged = React.useRef((payload: any) => onGroupRoleChangedRef.current?.(payload))
  const stableHandleGroupDisbanded = React.useRef((payload: any) => onGroupDisbandedRef.current?.(payload))
  const stableHandleGroupUpdated = React.useRef((payload: any) => onGroupUpdatedRef.current?.(payload))
  const stableHandleFriendshipUpdated = React.useRef((payload: any) => onFriendshipUpdatedRef.current?.(payload))


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // REGISTER EVENT HANDLERS ON GLOBAL SERVICE (idempotent)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  React.useEffect(() => {
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
    // IMPORTANT: This must run in the connect effect (next), not here, because socket might not exist yet
  }, [])

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CONNECT WHEN TOKEN PROVIDED
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  React.useEffect(() => {
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

    // NOW attach listeners when socket is guaranteed to exist
    if (!globalListenersAttached) {
      globalListenersAttached = true
      console.log('[useChatSocket] 🎯 Attaching listeners to socket (one-time, post-connect)')
      service.attachEventListeners()

      // Reset flag on disconnect so listeners are re-attached on reconnect
      socket.on('disconnect', () => {
        console.log('[useChatSocket] Reset listener flag on disconnect for next reconnect')
        globalListenersAttached = false
      })
    }

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

  React.useEffect(() => {
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

  const connect = React.useCallback(() => {
    if (!token) {
      return false
    }

    getOrCreateChatService().connect(token)
    return true
  }, [token])

  const disconnect = React.useCallback(() => {
    getOrCreateChatService().disconnect()
  }, [])

  const emitSendMessage = React.useCallback(async (payload: SocketMessagePayload): Promise<SendMessageAck | null> => {
    return getOrCreateChatService().emitSendMessage(payload) ?? null
  }, [])

  const emitRecallMessage = React.useCallback(async (payload: { messageId: string; conversationId: string }) => {
    return getOrCreateChatService().emitRecallMessage(payload) ?? null
  }, [])

  const joinConversation = React.useCallback(async (conversationId: string): Promise<boolean> => {
    return getOrCreateChatService().joinConversation(conversationId) ?? false
  }, [])

  const joinMultipleConversations = React.useCallback(async (conversationIds: string[]): Promise<void> => {
    return getOrCreateChatService().joinMultipleConversations(conversationIds)
  }, [])

  const markAsRead = React.useCallback((payload: MessageReadPayload): boolean => {
    return getOrCreateChatService().markAsRead(payload) ?? false
  }, [])

  const isConnected = React.useCallback((): boolean => {
    return getOrCreateChatService().isConnected() ?? false
  }, [])

  const getSocket = React.useCallback(() => {
    return getOrCreateChatService().getSocket()
  }, [])

  const getRootSocket = React.useCallback(() => {
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
