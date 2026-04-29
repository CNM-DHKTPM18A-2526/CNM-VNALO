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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CONNECT + REGISTER LISTENERS (only when token changes)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  useEffect(() => {
    if (!token) {
      console.log('[useChatSocket.effect] Skipping: no token provided')
      hasConnectedRef.current = false
      getOrCreateChatService().disconnect()
      return
    }

    const service = getOrCreateChatService()

    // Connect only once per token, but always sync listeners
    if (!hasConnectedRef.current) {
      hasConnectedRef.current = true
      console.log('[useChatSocket.effect] ✅ Initializing socket connection')
    } else {
      console.log('[useChatSocket.effect] Re-attaching listeners to existing socket')
    }

    const socket = service.connect(token)
    if (!socket) {
      console.warn('[useChatSocket.effect] Socket unavailable, skipping listener registration')
      return
    }

    console.log('[useChatSocket.effect] Socket obtained, ID:', socket.id, 'Connected:', socket.connected)

    // Remove listeners first
    socket.off('connect', stableHandleConnect.current)
    socket.off('disconnect', stableHandleDisconnect.current)
    socket.off('message.sent', stableHandleMessageReceived.current)
    socket.off('message.received', stableHandleMessageReceived.current)
    socket.off('message.recalled', stableHandleMessageRecalled.current)
    socket.off('message.read', stableHandleMessageRead.current)
    socket.off('message.pinned', stableHandleMessagePinned.current)
    socket.off('message.unpinned', stableHandleMessageUnpinned.current)
    socket.off('message.reaction.added', stableHandleReactionAdded.current)
    socket.off('message.reaction.removed', stableHandleReactionRemoved.current)
    socket.off('presence.changed', stableHandlePresenceChanged.current)
    socket.off('group.memberAdded', stableHandleGroupMemberAdded.current)
    socket.off('group.memberRemoved', stableHandleGroupMemberRemoved.current)
    socket.off('group.memberLeft', stableHandleGroupMemberLeft.current)
    socket.off('group.roleChanged', stableHandleGroupRoleChanged.current)
    socket.off('group.disbanded', stableHandleGroupDisbanded.current)
    socket.off('group.updated', stableHandleGroupUpdated.current)

    // Re-add listeners
    socket.on('connect', stableHandleConnect.current)
    socket.on('disconnect', stableHandleDisconnect.current)
    socket.on('message.sent', stableHandleMessageReceived.current)
    socket.on('message.received', stableHandleMessageReceived.current)
    socket.on('message.recalled', stableHandleMessageRecalled.current)
    socket.on('message.read', stableHandleMessageRead.current)
    socket.on('message.pinned', stableHandleMessagePinned.current)
    socket.on('message.unpinned', stableHandleMessageUnpinned.current)
    socket.on('message.reaction.added', stableHandleReactionAdded.current)
    socket.on('message.reaction.removed', stableHandleReactionRemoved.current)
    socket.on('presence.changed', stableHandlePresenceChanged.current)
    socket.on('group.memberAdded', stableHandleGroupMemberAdded.current)
    socket.on('group.memberRemoved', stableHandleGroupMemberRemoved.current)
    socket.on('group.memberLeft', stableHandleGroupMemberLeft.current)
    socket.on('group.roleChanged', stableHandleGroupRoleChanged.current)
    socket.on('group.disbanded', stableHandleGroupDisbanded.current)
    socket.on('group.updated', stableHandleGroupUpdated.current)

    // If already connected, replay onConnected callback
    if (socket.connected && socket.id) {
      queueMicrotask(() => {
        onConnectedRef.current?.()
      })
    }

    return () => {
      socket.off('connect', stableHandleConnect.current)
      socket.off('disconnect', stableHandleDisconnect.current)
      socket.off('message.sent', stableHandleMessageReceived.current)
      socket.off('message.received', stableHandleMessageReceived.current)
      socket.off('message.recalled', stableHandleMessageRecalled.current)
      socket.off('message.read', stableHandleMessageRead.current)
      socket.off('message.pinned', stableHandleMessagePinned.current)
      socket.off('message.unpinned', stableHandleMessageUnpinned.current)
      socket.off('message.reaction.added', stableHandleReactionAdded.current)
      socket.off('message.reaction.removed', stableHandleReactionRemoved.current)
      socket.off('presence.changed', stableHandlePresenceChanged.current)
      socket.off('group.memberAdded', stableHandleGroupMemberAdded.current)
      socket.off('group.memberRemoved', stableHandleGroupMemberRemoved.current)
      socket.off('group.memberLeft', stableHandleGroupMemberLeft.current)
      socket.off('group.roleChanged', stableHandleGroupRoleChanged.current)
      socket.off('group.disbanded', stableHandleGroupDisbanded.current)
      socket.off('group.updated', stableHandleGroupUpdated.current)
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
