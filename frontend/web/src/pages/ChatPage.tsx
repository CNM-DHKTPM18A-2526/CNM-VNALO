import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { getSyncPolicy } from '../features/auth/auth.api'
import { ChatList } from '../features/chat/components/ChatList'
import { ConversationInfo } from '../features/chat/components/ConversationInfo'
import { SearchMessagesPanel } from '../features/chat/components/SearchMessagesPanel'
import { SearchGlobalPanel } from '../features/chat/components/SearchGlobalPanel'
import { MessageShareModal } from '../features/chat/components/MessageShareModal'
import { ChatWindow } from '../features/chat/components/ChatWindow'
import { UserProfileModal } from '../features/chat/components/UserProfileModal'
import { CallModal } from '../features/chat/components/CallModal'
import { GroupCallModal, IncomingGroupCallBanner, useGroupCall } from '../features/chat/components/GroupCallModal'
import type { MessageContextMenuAction } from '../features/chat/components/MessageContextMenu'
import {
  addMessageReaction,
  createGroupConversation,           // ← NEW
  deleteMessageForMe,
  fetchMessageReactions,
  fetchInbox,
  fetchMessages,
  fetchPinnedMessages,
  getOrCreateDirectConversation,
  mapRawMessage,
  markConversationRead,
  pinMessage,
  recallMessage,
  removeMessageReaction,
  searchConversationMessages,
  sendMessage as sendMessageViaRest,
  unpinMessage,
  updateMessage,
  uploadChatMedia,
  fetchConversation,
  addMembersToConversation,
  leaveConversation,
  removeMember,
  updateMemberRole,
  updateGroupAvatar,
  updateConversation,
  disbandConversation,
  renameGroupConversation,
  setConversationNickname,
} from '../features/chat/chat.api';
import type { RawMessage } from '../features/chat/chat.api'
import { REACTION_OPTIONS } from '../features/chat/chat.constants'
import type { MessageReactionState, ReactionKey } from '../features/chat/chat.types'
import { useChatSocket } from '../features/chat/useChatSocket'
import type {
  ChatComposePayload,
  ChatMessage,
  ChatMessageType,
  ConversationSummary,
  MessageDeliveryState,
  MessageReactionMap,
} from '../features/chat/chat.types'
import { getFriends, getUserById, searchUsers } from '../features/friends/friends.api'
import { refreshNotificationBadges } from '../features/notifications/NotificationContext'
import { getUserByPhone } from '../features/friends/friends.api'
import type { Friend, UserLookupResult } from '../features/friends/friends.types'
import { useAuth } from '../features/auth/useAuth'
import { WebRtcCallService } from '../features/chat/webrtcCallService'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { Card } from '../shared/components/ui/Card'
import { Modal } from '../shared/components/ui/Modal'
import { useLanguage } from '../shared/i18n/LanguageContext'
import {
  initializeSearchIndex,
  updateSearchIndexConversations,
  addMessagesToSearchIndex,
  updateSearchIndexUsers,
  type CachedMessage,
  type CachedUser,
} from '../features/chat/searchIndex'
import { CreateGroupModal } from '../features/chat/components/CreateGroupModal'
import { EditConversationNameModal } from '../features/chat/components/EditConversationNameModal'
import { formatMessage, renderSystemMessage, formatMessagePreview, formatMessageTimestamp, normalizeMessage } from '../features/chat/utils/messageUtils'
import { UserStoreProvider, useUserStore } from '../features/chat/context/UserStoreContext'
import type { SystemMessagePayload } from '../features/chat/chat.types'

// Fallback toast object to prevent crashes if toast library is missing
const toast = {
  success: (msg: string) => console.log('SUCCESS:', msg),
  error: (msg: string) => console.error('ERROR:', msg),
}

function sortMessages(messages: ChatMessage[]): ChatMessage[] {
  return [...messages].sort((left, right) => {
    const leftSeq = left.serverSeq ?? -1
    const rightSeq = right.serverSeq ?? -1

    if (leftSeq !== rightSeq) {
      return leftSeq - rightSeq
    }

    return left.id.localeCompare(right.id)
  })
}

function mergeMessage(existing: ChatMessage, incoming: ChatMessage): ChatMessage {
  const mergedDeliveryState = resolveDeliveryState(existing.deliveryState, incoming.deliveryState)
  const hasExistingMedia = Boolean(existing.mediaUrl || existing.attachments?.length)
  const hasIncomingMedia = Boolean(incoming.mediaUrl || incoming.attachments?.length)
  const shouldPreserveExistingType =
    existing.type !== 'text' &&
    incoming.type === 'text' &&
    hasExistingMedia &&
    !hasIncomingMedia

  return {
    ...existing,
    ...incoming,
    type: shouldPreserveExistingType ? existing.type : incoming.type,
    clientMessageId: incoming.clientMessageId ?? existing.clientMessageId,
    mediaUrl: incoming.mediaUrl ?? existing.mediaUrl,
    mediaThumbnailUrl: incoming.mediaThumbnailUrl ?? existing.mediaThumbnailUrl,
    mediaMimeType: incoming.mediaMimeType ?? existing.mediaMimeType,
    mediaSizeBytes: incoming.mediaSizeBytes ?? existing.mediaSizeBytes,
    attachments: incoming.attachments?.length ? incoming.attachments : existing.attachments,
    deliveryState: mergedDeliveryState,
  }
}

function dedupeMessages(messages: ChatMessage[]): ChatMessage[] {
  const deduped: ChatMessage[] = []

  for (const message of messages) {
    const existingIndex = deduped.findIndex(
      (item) =>
        (Boolean(message.clientMessageId) && item.clientMessageId === message.clientMessageId) ||
        item.id === message.id,
    )

    if (existingIndex === -1) {
      deduped.push(message)
      continue
    }

    deduped[existingIndex] = mergeMessage(deduped[existingIndex], message)
  }

  return deduped
}

function upsertMessage(messages: ChatMessage[], incoming: ChatMessage): ChatMessage[] {
  const index = messages.findIndex(
    (message) =>
      (Boolean(incoming.clientMessageId) && message.clientMessageId === incoming.clientMessageId) ||
      message.id === incoming.id,
  )

  if (index === -1) {
    return sortMessages(dedupeMessages([...messages, incoming]))
  }

  const next = [...messages]
  next[index] = mergeMessage(next[index], incoming)
  return sortMessages(dedupeMessages(next))
}

function resolveDeliveryState(
  current: MessageDeliveryState | undefined,
  incoming: MessageDeliveryState | undefined,
): MessageDeliveryState | undefined {
  // Once a message is marked failed, never regress back to sending for that same local id.
  if (current === 'failed' || incoming === 'failed') {
    return 'failed'
  }

  const rank: Record<MessageDeliveryState, number> = {
    failed: 0,
    sending: 1,
    sent: 2,
    read: 3,
  }

  if (!current) {
    return incoming
  }

  if (!incoming) {
    return current
  }

  return rank[incoming] >= rank[current] ? incoming : current
}
// Moved to messageUtils.ts

function markLocalMessageFailed(messages: ChatMessage[], clientMessageId: string): ChatMessage[] {
  return messages.map((message) => {
    const isTarget = message.clientMessageId === clientMessageId || message.id === clientMessageId
    if (!isTarget) {
      return message
    }

    return {
      ...message,
      deliveryState: 'failed' as const,
    }
  })
}

function toSocketMessageType(type: ChatMessageType): Uppercase<ChatMessageType> {
  return type.toUpperCase() as Uppercase<ChatMessageType>
}


// Removed local normalizeMessage, now imported from ../features/chat/utils/messageUtils

function getConversationPreview(
  message: ChatMessage,
  currentUserId: string,
  getDisplayName: (id: string) => string,
): string {
  return formatMessage(message, currentUserId, getDisplayName)
}




function formatConversationPreview(
  senderName: string | null | undefined,
  message: ChatMessage | string,
  currentUserId: string,
  getDisplayName: (id: string) => string,
): string {
  if (typeof message !== 'string' && message.type === 'system') {
    return getConversationPreview(message, currentUserId, getDisplayName)
  }

  const isMe = typeof message !== 'string' && message.senderId === currentUserId;
  const type = typeof message !== 'string' ? message.type : undefined;
  const attachments = typeof message !== 'string' ? message.attachments : undefined;
  let text = typeof message === 'string' ? message : message.text;

  // Handle poll preview specifically since type='poll' messages might have empty text
  if (typeof message !== 'string' && message.type === 'poll' && message.pollData) {
    text = `{"type":"poll","question":"${message.pollData.question}"}`;
  }

  // Preserve complex system formatting if content is JSON
  if (text.startsWith('{"action":')) {
    text = renderSystemMessage(text, currentUserId, getDisplayName);
  }

  return formatMessagePreview(text, isMe, type, senderName || undefined, attachments);
}

function getDraftMessageType(payload: ChatComposePayload): ChatMessageType {
  if (payload.sticker) {
    return 'sticker'
  }

  const files = [payload.file, ...(payload.files ?? [])].filter((f): f is File => !!f)
  if (files.length > 0) {
    // If all files are images, type is image. Otherwise it's file.
    const allImages = files.every(f => f.type.startsWith('image/'))
    return allImages ? 'image' : 'file'
  }

  return 'text'
}

function getDraftContent(payload: ChatComposePayload): string {
  return payload.text.trim()
}

function getFileNameFromUrl(url?: string | null): string {
  if (!url) {
    return ''
  }

  const normalized = url.trim()
  if (!normalized) {
    return ''
  }

  try {
    const parsed = new URL(normalized)
    const fileName = parsed.pathname.split('/').filter(Boolean).pop() ?? ''
    return decodeURIComponent(fileName).toLowerCase()
  } catch {
    const safeUrl = normalized.split('?')[0]
    const fileName = safeUrl.split('/').filter(Boolean).pop() ?? ''
    return decodeURIComponent(fileName).toLowerCase()
  }
}

const EMOJI_TO_REACTION_KEY = REACTION_OPTIONS.reduce<Record<string, ReactionKey>>((acc, item) => {
  acc[item.emoji] = item.key
  return acc
}, {})

const RESTRICTED_TEXT = 'Noi dung duoc an tren web do chinh sach dong bo.'
const DELETE_FOR_ME_STORAGE_PREFIX = 'vnalo:chat:deleted-for-me:'

function buildDeleteForMeStorageKey(userId?: string | null): string | null {
  const normalized = String(userId ?? '').trim()
  if (!normalized) {
    return null
  }
  return `${DELETE_FOR_ME_STORAGE_PREFIX}${normalized}`
}

function loadDeletedMessageIds(userId?: string | null): Record<string, true> {
  const key = buildDeleteForMeStorageKey(userId)
  if (!key) {
    return {}
  }

  try {
    const raw = window.localStorage.getItem(key)
    if (!raw) {
      return {}
    }

    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) {
      return {}
    }

    return parsed.reduce<Record<string, true>>((acc, id) => {
      if (typeof id === 'string' && id.trim()) {
        acc[id] = true
      }
      return acc
    }, {})
  } catch {
    return {}
  }
}

function persistDeletedMessageIds(userId: string, deletedMap: Record<string, true>): void {
  const key = buildDeleteForMeStorageKey(userId)
  if (!key) {
    return
  }

  try {
    window.localStorage.setItem(key, JSON.stringify(Object.keys(deletedMap)))
  } catch {
    // Ignore storage errors and keep in-memory fallback behavior.
  }
}

function fallbackUserDisplayName(_userId: string): string {
  return 'Người dùng'
}

function applyRestrictedMessage(message: ChatMessage, restricted: boolean): ChatMessage {
  if (!restricted) {
    return message
  }

  return {
    ...message,
    text: message.sender === 'me' ? message.text : RESTRICTED_TEXT,
  }
}

function applyRestrictedConversationPreview(conversation: ConversationSummary, restricted: boolean): ConversationSummary {
  if (!restricted) {
    return conversation
  }

  return {
    ...conversation,
    lastMessage: RESTRICTED_TEXT,
  }
}

function parseJwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split('.')
  if (parts.length < 2) {
    return null
  }

  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=')

  try {
    const decoded = atob(padded)
    return JSON.parse(decoded) as Record<string, unknown>
  } catch {
    return null
  }
}

function parseBooleanClaim(value: unknown): boolean {
  if (typeof value === 'boolean') {
    return value
  }

  if (typeof value === 'number') {
    return value !== 0
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase()
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no' || normalized === '') {
      return false
    }
  }

  return false
}

function isRestrictedWebToken(token: string): boolean {
  const payload = parseJwtPayload(token)
  if (!payload) {
    return false
  }

  const restrictedWebMode = parseBooleanClaim(payload.restrictedWebMode)
  const platform = String(payload.clientPlatform ?? 'WEB').trim().toLowerCase()
  return restrictedWebMode && platform === 'web'
}

function isUUID(str: string): boolean {
  if (typeof str !== 'string') return false
  const simpleUuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  return simpleUuidRegex.test(str)
}

function generateUUID(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID()
  }
  // Fallback for non-HTTPS or older browsers
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

export default function ChatPage() {
  const { userMap, upsertUser, ensureUser } = useUserStore()
  const { isBootstrapping, accessToken, user } = useAuth()
  const currentUserId = user?.id || ''
  const { t } = useLanguage()
  const navigate = useNavigate()
  const { conversationId: conversationIdFromUrl } = useParams<{ conversationId?: string }>()
  const routedConversationId = conversationIdFromUrl ?? ''
  const [conversations, setConversations] = useState<ConversationSummary[]>([])
  const [messagesByConversation, setMessagesByConversation] = useState<Record<string, ChatMessage[]>>({})
  const [selectedConversationId, setSelectedConversationId] = useState('')
  const [isLoadingConversations, setIsLoadingConversations] = useState(false)
  const [isLoadingMessages, setIsLoadingMessages] = useState(false)
  const [isRestrictedMode, setIsRestrictedMode] = useState(false)
  const [peerLastReadByConversation, setPeerLastReadByConversation] = useState<Record<string, number>>({})
  const [reactionStatesByMessage, setReactionStatesByMessage] = useState<Record<string, MessageReactionState>>({})
  const [friendResults, setFriendResults] = useState<UserLookupResult[]>([])
  const [friendsDirectory, setFriendsDirectory] = useState<Friend[]>([])
  const [isSocketConnected, setIsSocketConnected] = useState(false)
  const [isSocketInitialized, setIsSocketInitialized] = useState(false)
  const [rightSidebarContent, setRightSidebarContent] = useState<'info' | 'search' | 'global-search' | null>(() => {
    const saved = localStorage.getItem('vnalo_chat_sidebar_content')
    if (!saved || saved === 'null' || saved === 'none') return null
    if (['info', 'search', 'global-search'].includes(saved)) return saved as any
    return null
  })

  useEffect(() => {
    localStorage.setItem('vnalo_chat_sidebar_content', rightSidebarContent || 'none')
  }, [rightSidebarContent])

  const [jumpToMessageId, setJumpToMessageId] = useState<string | null>(null)
  const [pinnedMessageIds, setPinnedMessageIds] = useState<Record<string, string[]>>({})
  const [pinnedMessages, setPinnedMessages] = useState<Record<string, ChatMessage[]>>({})
  const [starredMessageIds, setStarredMessageIds] = useState<Record<string, true>>({})
  const [recalledMessageIds, setRecalledMessageIds] = useState<Record<string, true>>({})
  const [deletedMessageIds, setDeletedMessageIds] = useState<Record<string, true>>({})
  const [selectedMessageIds, setSelectedMessageIds] = useState<string[]>([])
  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false)

  const [shareModalMessage, setShareModalMessage] = useState<ChatMessage | null>(null)
  const [isShareSubmitting, setIsShareSubmitting] = useState(false)
  const [deletedTimestamps, setDeletedTimestamps] = useState<Record<string, number>>({})
  const [pinnedConversationIds, setPinnedConversationIds] = useState<Record<string, boolean>>({})
  const [confirmDeleteHistoryId, setConfirmDeleteHistoryId] = useState<string | null>(null)
  const [confirmLeaveGroupOpen, setConfirmLeaveGroupOpen] = useState(false)
  const [selectedProfileUserId, setSelectedProfileUserId] = useState<string | null>(null)
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false)

  // CALL STATE
  const [callState, setCallState] = useState<{
    isOpen: boolean
    type: 'audio' | 'video'
    direction: 'outgoing' | 'incoming'
    status: 'connecting' | 'connected' | 'failed'
    peerId?: string
    conversationId?: string
    startedAt?: number
    callId?: string
    localStream?: MediaStream | null
    remoteStream?: MediaStream | null
    isMicOn?: boolean
    isCameraOn?: boolean
    hasRemoteDescription?: boolean
    error?: string | null
  }>({
    isOpen: false,
    type: 'audio',
    direction: 'outgoing',
    status: 'connecting',
    isMicOn: true,
    isCameraOn: true,
  })

  // WEBRTC SERVICE REF
  const callServiceRef = useRef<WebRtcCallService | null>(null)

  // SYNC CALL STATE TO REF FOR LISTENERS
  const callStateRef = useRef(callState)
  const currentCallIdRef = useRef<string | null>(null) // Immediate sync ref for signal routing
  useEffect(() => {
    callStateRef.current = callState
    currentCallIdRef.current = callState.callId || null
  }, [callState])

  // Initialize call service with state syncing
  if (!callServiceRef.current) {
    callServiceRef.current = new WebRtcCallService((serviceState) => {
      setCallState((prev) => {
        let status: 'connecting' | 'connected' | 'failed' = 'connecting'
        if (serviceState.isConnected) status = 'connected'
        else if (serviceState.error) status = 'failed'
        else if (prev.status === 'failed') status = 'failed' // Maintain failure state

        return {
          ...prev,
          status,
          startedAt: serviceState.startedAt,
          localStream: serviceState.localStream,
          remoteStream: serviceState.remoteStream,
          isMicOn: serviceState.isMicOn,
          isCameraOn: serviceState.isCameraOn,
          hasRemoteDescription: serviceState.hasRemoteDescription,
          error: serviceState.error,
        }
      })

      if (serviceState.isEnded && callState.isOpen) {
        // We'll handle termination in the component logic or here
      }
    })
  }


  const routedConversationIdRef = useRef('')
  const selectedConversationIdRef = useRef('')
  const selectedMessagesRef = useRef<ChatMessage[]>([])
  const conversationsRef = useRef<ConversationSummary[]>([])
  const friendIdSetRef = useRef<Set<string>>(new Set())
  const lastLoadedMessagesKeyRef = useRef('')
  const userMapRef = useRef<Record<string, { displayName: string; avatarUrl: string | null }>>({})

  // Hard guards for pinned messages
  const loadingPinnedRef = useRef<Record<string, boolean>>({})
  const lastConvRef = useRef<string | null>(null)

  // WebRTC Signal Deduplication (prevents double-triggering from specific + generic events)
  const processedSignalsRef = useRef<Set<string>>(new Set())

  useEffect(() => {
    userMapRef.current = userMap
  }, [userMap])
  const messageLoadRequestSeqRef = useRef(0)
  const pendingMetadataFetches = useRef<Map<string, Promise<void>>> (new Map())
  const processedMessageIds = useRef<Set<string>>(new Set())

  // Load deleted timestamps & pinned conversations from localStorage on mount
  useEffect(() => {
    const savedDeleted = localStorage.getItem('vnalo_deleted_timestamps')
    if (savedDeleted) {
      try {
        setDeletedTimestamps(JSON.parse(savedDeleted))
      } catch (e) {
        console.warn('Failed to parse deleted timestamps', e)
      }
    }

    const savedPinned = localStorage.getItem('vnalo_pinned_conversations')
    if (savedPinned) {
      try {
        setPinnedConversationIds(JSON.parse(savedPinned))
      } catch (e) {
        console.warn('Failed to parse pinned conversations', e)
      }
    }
  }, [])

  const handleDeleteHistory = (conversationId: string) => {
    const timestamp = Date.now()
    const newTimestamps = { ...deletedTimestamps, [conversationId]: timestamp }
    setDeletedTimestamps(newTimestamps)
    localStorage.setItem('vnalo_deleted_timestamps', JSON.stringify(newTimestamps))
    setConfirmDeleteHistoryId(null)
  }

  const handleTogglePinConversation = useCallback((conversationId: string) => {
    setPinnedConversationIds((prev) => {
      const isCurrentlyPinned = !!prev[conversationId]
      const next = { ...prev }
      if (isCurrentlyPinned) {
        delete next[conversationId]
      } else {
        next[conversationId] = true
      }
      localStorage.setItem('vnalo_pinned_conversations', JSON.stringify(next))
      return next
    })
  }, [])

  const [isCreateGroupOpen, setIsCreateGroupOpen] = useState(false);
  const [isCreatingGroup, setIsCreatingGroup] = useState(false);
  const [isAddMembersOpen, setIsAddMembersOpen] = useState(false);
  const [isAddingMembers, setIsAddingMembers] = useState(false);
  const [preselectedMemberIds, setPreselectedMemberIds] = useState<string[]>([]);

  const [isEditConversationNameOpen, setIsEditConversationNameOpen] = useState(false);
  const [editConversationNameMode, setEditConversationNameMode] = useState<'group' | 'nickname'>('group');

  useEffect(() => {
    routedConversationIdRef.current = routedConversationId
  }, [routedConversationId])

  useEffect(() => {
    selectedConversationIdRef.current = routedConversationId || selectedConversationId
  }, [routedConversationId, selectedConversationId])

  useEffect(() => {
    conversationsRef.current = conversations
  }, [conversations])


  const selectedConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === (routedConversationId || selectedConversationId)),
    [conversations, routedConversationId, selectedConversationId],
  )

  const selectedMessages = useMemo(() => {
    const resolvedConversationId = routedConversationId || selectedConversationId
    if (!resolvedConversationId) {
      return []
    }

    const allMsgs = messagesByConversation[resolvedConversationId] ?? []
    const deleteTime = deletedTimestamps[resolvedConversationId]

    if (!deleteTime) return allMsgs

    // Zalo style: Filter out messages sent BEFORE the delete moment
    return allMsgs.filter(m => {
      const msgTime = m.createdAt ? new Date(m.createdAt).getTime() : 0
      return msgTime > deleteTime
    })
  }, [messagesByConversation, routedConversationId, selectedConversationId, deletedTimestamps])

  useEffect(() => {
    selectedMessagesRef.current = selectedMessages
  }, [selectedMessages])

  useEffect(() => {
    setIsMultiSelectMode(false)
    setSelectedMessageIds([])
  }, [routedConversationId, selectedConversationId])

  useEffect(() => {
    setDeletedMessageIds(loadDeletedMessageIds(user?.id))
  }, [user?.id])

  useEffect(() => {
    if (!user?.id) {
      return
    }

    persistDeletedMessageIds(user.id, deletedMessageIds)
  }, [deletedMessageIds, user?.id])

  // Initialize search index on mount
  useEffect(() => {
    initializeSearchIndex()
  }, [])

  // Update search index when conversations are loaded
  useEffect(() => {
    if (conversations.length > 0) {
      updateSearchIndexConversations(conversations)
    }
  }, [conversations])

  // Update search index when messages are loaded
  useEffect(() => {
    const allMessages: CachedMessage[] = []
    Object.entries(messagesByConversation).forEach(([conversationId, messages]) => {
      const conversation = conversations.find((c) => c.id === conversationId)
      messages.forEach((msg) => {
        allMessages.push({
          id: msg.id,
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          content: msg.text,
          createdAt: msg.createdAt ?? undefined,
          messageType: msg.type,
          conversationName: conversation?.name,
        })
      })
    })
    if (allMessages.length > 0) {
      addMessagesToSearchIndex(allMessages)
    }
  }, [messagesByConversation, conversations])

  // Update search index when friends are loaded
  useEffect(() => {
    if (friendResults.length > 0) {
      const cachedUsers: CachedUser[] = friendResults.map((u) => ({
        id: u.id,
        phone: u.phone ?? undefined,
        email: u.email ?? undefined,
        displayName: u.displayName ?? undefined,
        avatarUrl: u.avatarUrl ?? undefined,
        bio: u.bio ?? undefined,
      }))
      updateSearchIndexUsers(cachedUsers)
    }
  }, [friendResults])

  const updateConversationAfterMessage = useCallback(
    (conversationId: string, message: ChatMessage, markAsReadNow: boolean) => {
      const senderName =
        message.senderId === user?.id
          ? user?.name?.trim() || fallbackUserDisplayName(message.senderId)
          : userMapRef.current[message.senderId]?.displayName || fallbackUserDisplayName(message.senderId)
      const getName = (id: string) => {
        if (id === user?.id) return 'Bạn'
        return userMapRef.current[id]?.displayName || 'Người dùng'
      }
      const formattedPreview = formatConversationPreview(senderName, message, user?.id || '', getName)

      setConversations((prev) => {
        const index = prev.findIndex((conversation) => conversation.id === conversationId)
        if (index === -1) {
          return prev
        }

        const next = [...prev]
        const current = next[index]

        let finalPreview = formattedPreview;

        // Inspect last few messages for grouping in sidebar
        const conversationMsgs = messagesByConversation[conversationId] || [];
        if (conversationMsgs.length > 0 && (message.type === 'image' || message.type === 'file')) {
          const lastFew = [...conversationMsgs, message].slice(-5);
          let count = 0;
          const groupType = message.type;

          for (let i = lastFew.length - 1; i >= 0; i--) {
            const m = lastFew[i];
            const prevM = i > 0 ? lastFew[i - 1] : null;

            const getMs = (msg: ChatMessage) => msg.createdAt ? Date.parse(msg.createdAt) : Date.parse(msg.timestamp);
            const withinTime = !prevM || Math.abs(getMs(m) - getMs(prevM)) <= 60000;
            const sameSender = !prevM || prevM.senderId === m.senderId;

            if (m.type === groupType && withinTime && sameSender) {
              count++;
            } else {
              break;
            }
          }

          if (count > 1) {
            const icon = groupType === 'image' ? '📷' : '📎';
            const label = groupType === 'image' ? 'hình ảnh' : 'tệp tin';
            const prefix = message.senderId === user?.id ? 'Bạn: ' : (senderName ? `${senderName}: ` : '');
            finalPreview = `${prefix}${icon} ${count} ${label}`;
          }
        }

        next[index] = {
          ...current,
          lastMessage: finalPreview,
          lastMessageAt: message.type === 'system' ? current.lastMessageAt : new Date().toISOString(),
          lastMessageSeq: message.serverSeq ?? current.lastMessageSeq,
          unreadCount: markAsReadNow ? 0 : current.unreadCount + (message.sender === 'me' ? 0 : 1),
        }

        return next
      })
    },
    [user?.id, user?.name],
  )

  const toReactionState = useCallback(
    (rows: Array<{ userId: string; emoji: string }>): MessageReactionState => {
      const reactions = {} as MessageReactionMap

      for (const row of rows) {
        let reactionKey = EMOJI_TO_REACTION_KEY[row.emoji]

        // Handle poll votes (vote:prefix)
        if (!reactionKey && row.emoji.startsWith('vote:')) {
          reactionKey = row.emoji as ReactionKey
        }

        if (!reactionKey) {
          continue
        }

        const current = reactions[reactionKey] ?? { count: 0, myCount: 0 }
        reactions[reactionKey] = {
          count: current.count + 1,
          myCount: current.myCount + (row.userId === user?.id ? 1 : 0),
        }
      }

      const myReaction = (Object.keys(reactions) as ReactionKey[]).find(
        (key) => (reactions[key]?.myCount ?? 0) > 0,
      )

      return {
        reactions,
        lastUsedReaction: myReaction,
      }
    },
    [user?.id],
  )

  const syncMessageReaction = useCallback(
    async (messageId: string): Promise<void> => {
      if (!accessToken || !messageId || !isUUID(messageId)) {
        return
      }

      try {
        const rows = await fetchMessageReactions(accessToken, messageId)
        const nextState = toReactionState(rows)

        setReactionStatesByMessage((prev) => {
          if (Object.keys(nextState.reactions).length === 0) {
            if (!prev[messageId]) {
              return prev
            }
            const next = { ...prev }
            delete next[messageId]
            return next
          }

          return {
            ...prev,
            [messageId]: nextState,
          }
        })
      } catch (error) {
        console.warn('[ChatPage.syncMessageReaction] Failed to sync reaction', { messageId, error })
      }
    },
    [accessToken, toReactionState],
  )

  const syncConversationReactions = useCallback(async () => {
    if (!selectedConversationIdRef.current || !accessToken) return

    // Limit to only 10 latest messages for initial sync to avoid network flood
    const messageIds = selectedMessagesRef.current
      .map((message) => message.id)
      .filter((id) => isUUID(id))
      .slice(-10)

    if (messageIds.length === 0) return

    // Execute in sequence or small batches rather than all-at-once Promise.all
    for (const id of messageIds) {
      await syncMessageReaction(id)
    }
  }, [accessToken, syncMessageReaction])

  const loadPinnedMessages = useCallback(
    async (conversationId: string) => {
      if (!accessToken || !conversationId) return

      // Hard guard: avoid double/simultaneous calls for same conversation
      if (loadingPinnedRef.current[conversationId]) return
      loadingPinnedRef.current[conversationId] = true

      try {
        const pins = await fetchPinnedMessages(accessToken, conversationId)
        const ids = pins.map(p => p.messageId).filter(Boolean) as string[]

        setPinnedMessageIds((prev) => ({
          ...prev,
          [conversationId]: ids,
        }))
      } catch (error) {
        console.warn('[ChatPage.loadPinnedMessages] Failed to fetch pinned messages', { conversationId, error })
      } finally {
        loadingPinnedRef.current[conversationId] = false
      }
    },
    [accessToken],
  )

  const syncPinnedMessages = loadPinnedMessages

  const { emitSendMessage, emitRecallMessage, joinConversation, markAsRead, getSocket } = useChatSocket({
    token: accessToken,
    onConnected: async () => {
      console.log('[ChatPage] 🟢 Socket connected event received');
      setIsSocketConnected(true)
      setIsSocketInitialized(true)
      void syncConversationReactions()
      void syncPinnedMessages(selectedConversationIdRef.current)
    },
    onDisconnected: () => {
      setIsSocketConnected(false)
    },
    onFriendshipUpdated: async (payload) => {
      if (!user || !accessToken || !payload.friendId) return;
      console.log('[ChatPage] 🤝 Friendship updated via socket for friendId:', payload.friendId);

      try {
        // 1. Ensure conversation is created in message-service
        const cid = await getOrCreateDirectConversation(accessToken, payload.friendId);
        if (!cid) return;

        // 2. Refresh inbox to get latest state
        await loadInbox(accessToken, cid);

        // 3. (Optional) If it's not already at the top, it will be after loadInbox 
        // because loadInbox updates the conversations state.
      } catch (error) {
        console.warn('[ChatPage] Failed to handle friendship update:', error);
      }
    },
    onMessageReceived: async (raw: RawMessage) => {
      if (!user || !accessToken) return;

      const mapped = applyRestrictedMessage(normalizeMessage(mapRawMessage(raw, user.id)), isRestrictedMode);
      if (!mapped.conversationId) return;

      // ── 0. SYSTEM MESSAGES (CRITICAL SIGNALS) ──
      // Handle both SYSTEM messages and TEXT messages that contain JSON signals (like poll sync)
      if (mapped.type === 'system' || (mapped.type === 'text' && mapped.text.startsWith('{"action":'))) {
        try {
          let sys: any = null;
          try {
            sys = JSON.parse(mapped.text);
          } catch (e) {
            // Handle plain text or malformed JSON
            if (mapped.text === 'FRIEND_ACCEPTED' || mapped.text.includes('FRIEND_ACCEPTED')) {
              sys = { action: 'FRIEND_ACCEPTED' };
            }
          }

          if (!sys || !sys.action) {
            // Fallback detection
            if (mapped.text.includes('"action":"FRIEND_ACCEPTED"')) sys = { action: 'FRIEND_ACCEPTED' };
          }

          if (sys && sys.action) {
            const cid = mapped.conversationId;

            if (sys.action === 'DISBAND_GROUP') {
              setConversations(prev => prev.filter(c => c.id !== cid));
              if (selectedConversationIdRef.current === cid) navigate('/chat');
              return;
            }
            if (sys.action === 'LEAVE_GROUP' && sys.actorId === user.id) {
              setConversations(prev => prev.filter(c => c.id !== cid));
              if (selectedConversationIdRef.current === cid) navigate('/chat');
              return;
            }

            // PIN/UNPIN Sync
            if (sys.action === 'PIN_MESSAGE') {
              console.log('[ChatPage] 📌 Handling PIN_MESSAGE event');
              setPinnedMessageIds(prev => ({
                ...prev,
                [cid]: [...(prev[cid] || []), sys.messageId].filter((v, i, a) => a.indexOf(v) === i)
              }));
              void syncPinnedMessages(cid);
            }
            if (sys.action === 'UNPIN_MESSAGE') {
              console.log('[ChatPage] 📍 Handling UNPIN_MESSAGE event');
              setPinnedMessageIds(prev => ({
                ...prev,
                [cid]: (prev[cid] || []).filter(id => id !== sys.messageId)
              }));
              void syncPinnedMessages(cid);
            }

            // Group Info Sync
            if (sys.action === 'UPDATE_GROUP_INFO') {
              setConversations(prev => prev.map(c => {
                if (c.id !== cid) return c;
                return { ...c, ...sys.metadata };
              }));
            }

            // Reaction Sync (Poll Voting)
            if (sys.action === 'UPDATE_MESSAGE_REACTIONS') {
              console.log('[ChatPage] 🔄 Handling UPDATE_MESSAGE_REACTIONS signal for poll sync');
              if (sys.messageId) {
                void syncMessageReaction(sys.messageId);
              }
            }

            // FRIEND_ACCEPTED Sync: Proactively fetch and show the new conversation
            if (sys.action === 'FRIEND_ACCEPTED' || mapped.text.includes('FRIEND_ACCEPTED')) {
              console.log('[ChatPage] 🤝 Handling FRIEND_ACCEPTED signal');
              void loadInbox();
            }
          }
        } catch (err) {
          console.warn('[ChatPage] Error processing system signal:', err);
        }
      }

      // ── 1. DEDUPLICATION (PREVENT DOUBLE RENDERING) ──
      if (mapped.id && processedMessageIds.current.has(mapped.id)) {
        console.log('[ChatPage] ⏭️ Skipping duplicate message:', mapped.id);
        return;
      }
      if (mapped.id) processedMessageIds.current.add(mapped.id);

      console.log('[ChatPage] 📩 Processing new message:', { id: mapped.id, type: mapped.type, conversationId: mapped.conversationId });

      // ── 2. INSTANT UI UPDATE (FAST PATH) ──
      const senderId = mapped.senderId;
      const senderProfile = userMapRef.current[senderId];
      const senderDisplayName = senderId === user.id ? 'Bạn' : (senderProfile?.displayName || 'Người dùng');

      const preview = formatConversationPreview(
        senderDisplayName,
        mapped,
        user.id,
        (id) => userMapRef.current[id]?.displayName || 'Người dùng'
      );

      // Fast message update
      setMessagesByConversation(prev => ({
        ...prev,
        [mapped.conversationId]: upsertMessage(prev[mapped.conversationId] ?? [], mapped)
      }));

      // Fast conversation update (Blind Discovery)
      const exists = conversationsRef.current.some(c => c.id === mapped.conversationId);
      const isActive = selectedConversationIdRef.current === mapped.conversationId;

      setConversations(prev => {
        const idx = prev.findIndex(c => c.id === mapped.conversationId);
        const now = new Date().toISOString();

        if (idx === -1) {
          const placeholder: ConversationSummary = {
            id: mapped.conversationId,
            name: senderDisplayName,
            avatarUrl: senderProfile?.avatarUrl || null,
            lastMessage: preview,
            lastMessageAt: now,
            unreadCount: mapped.senderId === user.id ? 0 : 1,
            isStranger: !friendIdSetRef.current.has(senderId),
            participantUserIds: [senderId],
            lastMessageSeq: mapped.serverSeq
          };
          return [placeholder, ...prev];
        }

        const next = [...prev];
        next[idx] = {
          ...next[idx],
          lastMessage: preview,
          lastMessageAt: now,
          lastMessageSeq: mapped.serverSeq ?? next[idx].lastMessageSeq,
          unreadCount: (isActive || mapped.senderId === user.id) ? 0 : (next[idx].unreadCount + 1)
        };
        const [target] = next.splice(idx, 1);
        return [target, ...next];
      });

      // ── 3. BACKGROUND SYNC ──
      if (isActive && mapped.serverSeq !== undefined) {
        markAsRead({ conversationId: mapped.conversationId, lastReadSeq: mapped.serverSeq });
        refreshNotificationBadges();
      }

      void (async () => {
        try {
          if (!exists) {
            void joinConversation(mapped.conversationId);
            if (!pendingMetadataFetches.current.has(mapped.conversationId)) {
              pendingMetadataFetches.current.add(mapped.conversationId);
              const data = await fetchConversation(accessToken, mapped.conversationId);
              if (data) {
                const inner = (data as any).conversation || data;
                setConversations(prev => prev.map(c => c.id === mapped.conversationId ? {
                  ...c,
                  name: inner.title || inner.name || c.name,
                  avatarUrl: inner.avatarUrl || c.avatarUrl,
                  isGroup: inner.type === 'GROUP'
                } : c));
              }
              pendingMetadataFetches.current.delete(mapped.conversationId);
            }
          }
          if (!senderProfile && senderId !== user.id) void ensureUser(accessToken, senderId);
          void syncMessageReaction(mapped.id);
        } catch (err) { /* silent bg error */ }
      })();
    },
    onMessageRecalled: (payload) => {
      if (!payload.messageId || !payload.conversationId) {
        return
      }

      setRecalledMessageIds((prev) => ({
        ...prev,
        [payload.messageId]: true,
      }))

      setMessagesByConversation((prev) => {
        const current = prev[payload.conversationId] ?? []
        if (current.length === 0) {
          return prev
        }

        return {
          ...prev,
          [payload.conversationId]: current.map((message) =>
            message.id === payload.messageId
              ? {
                ...message,
                text: '',
                mediaUrl: null,
                mediaThumbnailUrl: null,
                mediaMimeType: null,
                mediaSizeBytes: null,
              }
              : message,
          ),
        }
      })

      setPinnedMessageIds((prev) => {
        if (!prev[payload.messageId]) {
          return prev
        }

        const next = { ...prev }
        delete next[payload.messageId]
        return next
      })

      void syncMessageReaction(payload.messageId)
    },
    onMessageRead: (payload) => {
      if (!user || payload.userId === user.id) {
        return
      }

      setPeerLastReadByConversation((prev) => {
        const current = prev[payload.conversationId] ?? 0
        if (payload.lastReadSeq <= current) {
          return prev
        }

        return {
          ...prev,
          [payload.conversationId]: payload.lastReadSeq,
        }
      })

      setMessagesByConversation((prev) => {
        const conversationMessages = prev[payload.conversationId] ?? []
        if (conversationMessages.length === 0) {
          return prev
        }

        const nextMessages = conversationMessages.map((message) => {
          if (
            message.sender !== 'me' ||
            message.serverSeq === undefined ||
            message.serverSeq > payload.lastReadSeq
          ) {
            return message
          }

          return {
            ...message,
            deliveryState: 'read' as const,
          }
        })

        return {
          ...prev,
          [payload.conversationId]: nextMessages,
        }
      })
    },
    onPresenceChanged: (payload) => {
      if (!user) {
        return
      }

      console.log('Đã nhận sự kiện presence:', payload)
      console.log('Đang tìm userId:', payload.userId, 'trong danh sách conversations...')
      console.log('Danh sách ID hiện có:', conversations.map((conv) => conv.userId))

      setConversations((prev) => {
        let changed = false
        const next = prev.map((conv) => {
          const isMatch = String(conv.userId ?? '').trim() === String(payload.userId ?? '').trim()

          if (!isMatch) {
            return conv
          }

          const nextOnline = payload.status === 'online'
          const nextLastSeen = payload.status === 'offline' ? new Date().toISOString() : null
          if (conv.online === nextOnline && conv.isOnline === nextOnline && conv.lastSeenTime === nextLastSeen) {
            return conv
          }

          changed = true

          return {
            ...conv,
            online: nextOnline,
            isOnline: nextOnline,
            lastSeenTime: nextLastSeen,
          }
        })

        return changed ? next : prev
      })
    },
    onReactionAdded: (payload: any) => {
      console.log('[ChatPage.socket] Reaction added:', payload);
      if (payload.messageId) {
        void syncMessageReaction(payload.messageId);
      }
    },
    onReactionRemoved: (payload: any) => {
      console.log('[ChatPage.socket] Reaction removed:', payload);
      if (payload.messageId) {
        void syncMessageReaction(payload.messageId);
      }
    },
    onGroupUpdated: (payload: any) => {
      console.log('[ChatPage.socket] Group updated:', payload);
      setConversations(prev => prev.map(c => {
        if (c.id !== payload.conversationId) return c;
        return { ...c, ...payload.metadata };
      }));
    },
    onGroupDisbanded: (payload) => {
      console.log('Group disbanded', payload.conversationId)
      setConversations((prev) => prev.filter((c) => c.id !== payload.conversationId))
      if (selectedConversationIdRef.current === payload.conversationId) {
        navigate('/chat')
      }
    },
    onGroupMemberAdded: (payload) => {
      setConversations(prev => prev.map(c => {
        if (c.id === payload.conversationId) {
          const newMemberIds = payload.targetMemberIds.filter(id => !c.participantUserIds?.includes(id));
          return {
            ...c,
            participantUserIds: [...(c.participantUserIds || []), ...newMemberIds],
            memberCount: (c.memberCount || 0) + newMemberIds.length,
            members: [
              ...(c.members || []),
              ...newMemberIds.map(id => ({ userId: id, role: 'MEMBER' }))
            ]
          }
        }
        return c;
      }))
    },
    onGroupMemberRemoved: (payload) => {
      setConversations(prev => prev.map(c => {
        if (c.id === payload.conversationId) {
          return {
            ...c,
            participantUserIds: c.participantUserIds?.filter(id => !payload.targetMemberIds.includes(id)),
            memberCount: Math.max(0, (c.memberCount || 1) - payload.targetMemberIds.length),
            members: c.members?.filter(m => !payload.targetMemberIds.includes(m.userId))
          }
        }
        return c;
      }))

      // If we are removed
      if (user?.id && payload.targetMemberIds.includes(user.id) && selectedConversationIdRef.current === payload.conversationId) {
        navigate('/chat');
      }
    },
    onGroupMemberLeft: (payload) => {
      setConversations(prev => prev.map(c => {
        if (c.id === payload.conversationId) {
          return {
            ...c,
            participantUserIds: c.participantUserIds?.filter(id => id !== payload.actorId),
            memberCount: Math.max(0, (c.memberCount || 1) - 1),
            members: c.members?.filter(m => m.userId !== payload.actorId)
          }
        }
        return c;
      }))
    },
    onGroupRoleChanged: (payload) => {
      setConversations(prev => prev.map(c => {
        if (c.id === payload.conversationId) {
          return {
            ...c,
            members: c.members?.map(m => m.userId === payload.targetUserId ? { ...m, role: payload.role } : m)
          }
        }
        return c;
      }))
    }
  })

  // ─── GROUP CALL (SEPARATE LAYER - does not touch single call) ────
  const {
    snapshot: groupCallSnapshot,
    incomingCall: incomingGroupCall,
    elapsedSeconds: groupCallElapsed,
    startGroupCall,
    joinGroupCall,
    declineGroupCall,
    leaveGroupCall,
    toggleMic: groupToggleMic,
    toggleCamera: groupToggleCamera,
    isInGroupCall,
  } = useGroupCall({
    socket: getSocket(),
    currentUserId,
    currentUserName: user?.name ?? 'Bạn',
    currentUserAvatar: user?.avatarUrl ?? '',
  })

  // Caller: bắt đầu cuộc gọi nhóm (chỉ broadcast, không tạo peer trước)
  const handleStartGroupCall = useCallback(
    async (audioOnly = false) => {
      if (!selectedConversationId) return
      const callId = `gc-${Date.now()}`
      const conv = conversations.find((c) => c.id === selectedConversationId)
      await startGroupCall({
        conversationId: selectedConversationId,
        conversationName: conv?.name ?? 'Cuộc gọi nhóm',
        callId,
        audioOnly,
      })
    },
    [selectedConversationId, conversations, startGroupCall]
  )

  // Rời cuộc gọi nhóm + tạo call log message
  const handleLeaveGroupCall = useCallback(async () => {
    const snap = groupCallSnapshot
    const convId = snap?.conversationId
    if (!convId) {
      leaveGroupCall()
      return
    }

    const callId = snap?.callId ?? ''
    const duration = groupCallElapsed
    // Số peers còn lại trước khi rời (không tính bản thân)
    const remainingPeers = snap?.peers.length ?? 0

    // 1. Stop WebRTC (luôn làm, bất kể có phải người cuối không)
    leaveGroupCall()

    // ⚠️ CHỈ tạo call log nếu không còn ai khác trong cuộc gọi.
    // Nếu vẫn còn người khác → họ sẽ là người tạo log khi rời sau cùng.
    if (remainingPeers > 0) {
      console.log(`[GROUP_CALL_LOG] Skipping log — ${remainingPeers} peer(s) still in call`)
      return
    }

    // 2. Broadcast group-call:ended để dismiss banner của những người chưa bắt máy
    console.log(`[GROUP_CALL_LOG] Last person leaving — broadcasting group-call:ended`)
    getSocket()?.emit('group-call:ended', {
      conversationId: convId,
      callId,
      endedByUserId: currentUserId,
    })

    // 3. Tạo CALL_LOG message (chỉ người cuối cùng rời)
    console.log(`[GROUP_CALL_LOG] Creating call log. duration=${duration}s`)
    const logData = {
      v: 1,
      callId,
      conversationId: convId,
      callerId: currentUserId,
      calleeId: 'group',
      mediaType: snap?.audioOnly ? 'voice' : 'video',
      outcome: duration > 0 ? 'completed' : 'canceled',
      durationSeconds: duration,
      participantCount: (snap?.peers.length ?? 0) + 1,
      isGroup: true,
      createdAt: new Date().toISOString(),
    }
    const logText = `CALL_LOG::${JSON.stringify(logData)}`
    const clientMessageId = crypto.randomUUID()

    // 3. Optimistic UI
    const optimisticLog: ChatMessage = {
      id: clientMessageId,
      clientMessageId,
      conversationId: convId,
      sender: 'me',
      senderId: currentUserId,
      type: 'call',
      text: logText,
      timestamp: formatMessageTimestamp(),
      createdAt: new Date().toISOString(),
      deliveryState: 'sending',
      isLocal: true,
    }
    setMessagesByConversation((prev) => ({
      ...prev,
      [convId]: upsertMessage(prev[convId] ?? [], optimisticLog),
    }))
    updateConversationAfterMessage(convId, optimisticLog, true)

      // 4. Lưu qua Socket với fallback REST
      ; (async () => {
        let success = false
        for (let attempt = 1; attempt <= 2; attempt++) {
          try {
            const ack = await Promise.race([
              emitSendMessage({ conversationId: convId, content: logText, messageType: 'TEXT', clientMessageId }),
              new Promise<null>((_, reject) => setTimeout(() => reject(new Error('TIMEOUT')), 4000)),
            ])
            if (ack?.event === 'message.sent' && ack?.data) {
              const serverMsg = {
                ...normalizeMessage(mapRawMessage(ack.data, currentUserId)),
                clientMessageId,
                deliveryState: 'sent' as const,
              }
              setMessagesByConversation((prev) => ({
                ...prev,
                [convId]: upsertMessage(prev[convId] ?? [], serverMsg),
              }))
              updateConversationAfterMessage(convId, serverMsg, true)
              success = true
              break
            }
          } catch { }
        }
        if (!success) {
          try {
            const restRes = await sendMessageViaRest(accessToken || '', {
              conversationId: convId,
              content: logText,
              messageType: 'TEXT',
              clientMessageId,
            })
            if (restRes?.id) {
              const serverMsg = {
                ...normalizeMessage(mapRawMessage(restRes, currentUserId)),
                clientMessageId,
                deliveryState: 'sent' as const,
              }
              setMessagesByConversation((prev) => ({
                ...prev,
                [convId]: upsertMessage(prev[convId] ?? [], serverMsg),
              }))
              updateConversationAfterMessage(convId, serverMsg, true)
              success = true
            }
          } catch { }
        }
        if (!success) {
          setMessagesByConversation((prev) => ({
            ...prev,
            [convId]: markLocalMessageFailed(prev[convId] ?? [], clientMessageId),
          }))
        }
      })()
  }, [
    groupCallSnapshot,
    groupCallElapsed,
    selectedConversationId,
    currentUserId,
    leaveGroupCall,
    emitSendMessage,
    accessToken,
    updateConversationAfterMessage,
  ])

  const handleAddReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken || !selectedConversationId) {
        return
      }

      let emoji = REACTION_OPTIONS.find((item) => item.key === reactionKey)?.emoji
      if (!emoji) {
        if (typeof reactionKey === 'string' && (reactionKey.startsWith('vote:') || reactionKey.startsWith('v:'))) {
          emoji = reactionKey
        } else {
          return
        }
      }

      try {
        // Optimistic UI Update for Polls
        if (reactionKey.startsWith('vote:') || reactionKey.startsWith('v:')) {
          setReactionStatesByMessage(prev => {
            const current = prev[messageId] || { reactions: {} };
            const nextReactions = { ...current.reactions };

            // In poll voting, remove any other poll-related reactions (vote: or v:) from this user
            Object.keys(nextReactions).forEach(key => {
              if ((key.startsWith('vote:') || key.startsWith('v:')) && nextReactions[key as ReactionKey]?.myCount > 0) {
                nextReactions[key as ReactionKey] = {
                  count: Math.max(0, nextReactions[key as ReactionKey].count - 1),
                  myCount: 0
                };
              }
            });

            nextReactions[reactionKey as ReactionKey] = {
              count: (nextReactions[reactionKey as ReactionKey]?.count || 0) + 1,
              myCount: 1
            };

            return {
              ...prev,
              [messageId]: {
                ...current,
                reactions: nextReactions,
                lastUsedReaction: reactionKey as ReactionKey
              }
            };
          });
        }

        await addMessageReaction(accessToken, messageId, emoji)
        await syncMessageReaction(messageId)

        // Emit signal to sync other clients
        void emitSendMessage({
          conversationId: selectedConversationId,
          content: JSON.stringify({
            action: 'UPDATE_MESSAGE_REACTIONS',
            messageId,
            conversationId: selectedConversationId,
            actorId: user?.id,
            type: 'ADD',
            emoji: emoji
          }),
          messageType: 'SYSTEM',
          clientMessageId: crypto.randomUUID()
        });
      } catch (error) {
        console.error('[ChatPage.handleAddReaction] Failed to add reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, selectedConversationId, user?.id, emitSendMessage, syncMessageReaction],
  )

  const handleRemoveReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken || !selectedConversationId) {
        return
      }

      const emoji = REACTION_OPTIONS.find((item) => item.key === reactionKey)?.emoji
      if (!emoji) {
        if (typeof reactionKey === 'string' && reactionKey.startsWith('vote:')) {
          emoji = reactionKey
        } else {
          return
        }
      }

      const current = reactionStatesByMessage[messageId]?.reactions[reactionKey]
      if (!current || current.myCount <= 0) {
        return
      }

      try {
        await removeMessageReaction(accessToken, messageId)
        await syncMessageReaction(messageId)

        // Emit signal to sync other clients
        void emitSendMessage({
          conversationId: selectedConversationId,
          content: JSON.stringify({
            action: 'UPDATE_MESSAGE_REACTIONS',
            messageId,
            conversationId: selectedConversationId,
            actorId: user?.id,
            type: 'REMOVE',
            emoji: emoji
          }),
          messageType: 'SYSTEM',
          clientMessageId: crypto.randomUUID()
        });
      } catch (error) {
        console.error('[ChatPage.handleRemoveReaction] Failed to remove reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, selectedConversationId, user?.id, emitSendMessage, reactionStatesByMessage, syncMessageReaction],
  )

  const handleDeleteForMe = useCallback(
    async (messageId: string) => {
      if (!accessToken || !messageId) {
        return
      }

      try {
        await deleteMessageForMe(accessToken, messageId)
        setDeletedMessageIds((prev) => ({
          ...prev,
          [messageId]: true,
        }))
      } catch (error) {
        console.error('[ChatPage.handleDeleteForMe] Failed to delete message for me', { messageId, error })
      }
    },
    [accessToken],
  )

  const handleRecallMessage = useCallback(
    async (messageId: string, conversationId: string) => {
      if (!accessToken) {
        return
      }

      try {
        await joinConversation(conversationId)

        const ack = await emitRecallMessage({ messageId, conversationId })
        if (ack?.event !== 'message.recalled') {
          await recallMessage(accessToken, messageId)
        }

        setRecalledMessageIds((prev) => ({
          ...prev,
          [messageId]: true,
        }))
        await Promise.all([
          syncMessageReaction(messageId),
          syncPinnedMessages(conversationId),
        ])
      } catch (error) {
        console.error('[ChatPage.handleRecallMessage] Failed to recall message', { messageId, conversationId, error })
      }
    },
    [accessToken, emitRecallMessage, joinConversation, syncMessageReaction, syncPinnedMessages],
  )

  const handleTogglePinMessage = useCallback(
    async (messageId: string, conversationId: string) => {
      if (!accessToken || !user) {
        return
      }

      const currentPins = pinnedMessageIds[conversationId] || []
      const isPinned = currentPins.includes(messageId)

      // Permission check for group pinning
      const currentConv = conversations.find(c => c.id === conversationId)
      if (currentConv?.isGroup) {
        const myMember = currentConv.members?.find(m => m.userId === user.id)
        const isModerator = myMember?.role === 'ADMIN' || myMember?.role === 'DEPUTY'
        const canPin = isModerator || currentConv.allowMemberPin

        if (!canPin) {
          toast.error('Bạn không có quyền ghim tin nhắn trong nhóm này')
          return
        }
      }

      const previousPins = [...currentPins]

      try {
        if (isPinned) {
          // Optimistic UI update
          setPinnedMessageIds((prev) => ({
            ...prev,
            [conversationId]: currentPins.filter((id) => id !== messageId),
          }))

          await unpinMessage(accessToken, conversationId, messageId)

          // Emit signal for other clients
          void emitSendMessage({
            conversationId,
            content: JSON.stringify({
              action: 'UNPIN_MESSAGE',
              messageId,
              conversationId,
              actorId: user.id
            }),
            messageType: 'SYSTEM',
            clientMessageId: crypto.randomUUID()
          });
          return
        }

        if (currentPins.length >= 3) {
          toast.error('Chỉ được ghim tối đa 3 tin nhắn')
          return
        }

        // Optimistic UI update
        setPinnedMessageIds((prev) => ({
          ...prev,
          [conversationId]: [...currentPins, messageId],
        }))

        await pinMessage(accessToken, conversationId, messageId)

        // Emit signal for other clients
        void emitSendMessage({
          conversationId,
          content: JSON.stringify({
            action: 'PIN_MESSAGE',
            messageId,
            conversationId,
            actorId: user.id
          }),
          messageType: 'SYSTEM',
          clientMessageId: crypto.randomUUID()
        });
      } catch (error) {
        // Rollback on error
        setPinnedMessageIds((prev) => ({
          ...prev,
          [conversationId]: previousPins,
        }))
        const action = isPinned ? 'bỏ ghim' : 'ghim'
        console.error(`[ChatPage.handleTogglePinMessage] Failed to ${action} message`, error)
        toast.error(`Không thể ${action} tin nhắn. Vui lòng thử lại sau.`)
      }
    },
    [accessToken, pinnedMessageIds, user, emitSendMessage],
  )

  const toggleMessageIdInList = useCallback((messageId: string) => {
    setSelectedMessageIds((prev) => {
      if (prev.includes(messageId)) {
        return prev.filter((item) => item !== messageId)
      }

      return [...prev, messageId]
    })
  }, [])

  const handleClearMultiSelectMode = useCallback(() => {
    setIsMultiSelectMode(false)
    setSelectedMessageIds([])
  }, [])

  const handleMessageContextMenuAction = useCallback(
    (messageId: string, action: MessageContextMenuAction, message: ChatMessage, groupMessages?: ChatMessage[]) => {
      if (!messageId) {
        return
      }

      switch (action) {
        case 'pin':
          void handleTogglePinMessage(messageId, message.conversationId)
          return
        case 'star':
          setStarredMessageIds((prev) => {
            const next = { ...prev }
            if (next[messageId]) {
              delete next[messageId]
            } else {
              next[messageId] = true
            }
            return next
          })
          return
        case 'multiSelect':
          setIsMultiSelectMode(true)
          toggleMessageIdInList(messageId)
          return
        case 'recall':
          void handleRecallMessage(messageId, message.conversationId)
          return
        case 'deleteSelf':
          void handleDeleteForMe(messageId)
          setSelectedMessageIds((prev) => prev.filter((item) => item !== messageId))
          return
        case 'share':
          setShareModalMessage(message)
          return
        case 'recallGroup':
          if (groupMessages && groupMessages.length > 0) {
            groupMessages.forEach((msg) => {
              void handleRecallMessage(msg.id, msg.conversationId)
            })
          }
          return
        case 'deleteGroupSelf':
          if (groupMessages && groupMessages.length > 0) {
            groupMessages.forEach((msg) => {
              void handleDeleteForMe(msg.id)
            })
          }
          return
        default:
          return
      }
    },
    [handleDeleteForMe, handleRecallMessage, handleTogglePinMessage, toggleMessageIdInList],
  )

  const handleShareMessage = useCallback(
    async (targetUserIds: string[], note: string) => {
      if (!accessToken || !shareModalMessage || targetUserIds.length === 0) {
        return
      }

      setIsShareSubmitting(true)
      const trimmedNote = note.trim()
      const attachments = shareModalMessage.attachments || []

      try {
        for (const userId of targetUserIds) {
          const conversationId = await getOrCreateDirectConversation(accessToken, userId)
          await joinConversation(conversationId)

          // 1. Send Note first
          if (trimmedNote) {
            const noteClientId = crypto.randomUUID();
            const noteAck = await emitSendMessage({
              conversationId,
              content: trimmedNote,
              messageType: 'TEXT',
              clientMessageId: noteClientId,
            })

            if (noteAck?.event !== 'message.sent') {
              await sendMessageViaRest(accessToken, {
                conversationId,
                content: trimmedNote,
                messageType: 'TEXT',
                clientMessageId: noteClientId,
              })
            }
          }

          // 2. Determine and Send Message Content
          // If the original message has multiple attachments, we must split them
          if (attachments.length > 1) {
            for (const att of attachments) {
              const attClientId = crypto.randomUUID();
              const payload = {
                conversationId,
                content: att.name || '',
                messageType: toSocketMessageType(shareModalMessage.type),
                mediaUrl: att.url,
                mediaThumbnailUrl: att.thumbnailUrl,
                mediaMimeType: att.mimeType,
                mediaSizeBytes: att.sizeBytes,
                clientMessageId: attClientId,
              }

              const ack = await emitSendMessage(payload)
              if (ack?.event !== 'message.sent') {
                await sendMessageViaRest(accessToken, {
                  ...payload,
                  messageType: (shareModalMessage.type === 'image' ? 'IMAGE' : 'FILE') as any
                })
              }
            }
          } else {
            // Singular message (text, sticker, or single image/file)
            const mediaUrl = shareModalMessage.mediaUrl ?? attachments[0]?.url ?? null
            const mediaThumbnailUrl = shareModalMessage.mediaThumbnailUrl ?? attachments[0]?.thumbnailUrl ?? null
            const mediaMimeType = shareModalMessage.mediaMimeType ?? attachments[0]?.mimeType ?? null
            const mediaSizeBytes = shareModalMessage.mediaSizeBytes ?? attachments[0]?.sizeBytes ?? null

            const payloadContent = (shareModalMessage.text ?? '').trim().length > 0
              ? shareModalMessage.text
              : ""

            const singularClientId = crypto.randomUUID();
            const payload = {
              conversationId,
              content: payloadContent,
              messageType: toSocketMessageType(shareModalMessage.type),
              mediaUrl,
              mediaThumbnailUrl,
              mediaMimeType,
              mediaSizeBytes,
              clientMessageId: singularClientId,
            }

            const ack = await emitSendMessage(payload)
            if (ack?.event !== 'message.sent') {
              await sendMessageViaRest(accessToken, {
                ...payload,
                messageType: (shareModalMessage.type === 'image' ? 'IMAGE' : (shareModalMessage.type === 'file' ? 'FILE' : (shareModalMessage.type === 'sticker' ? 'STICKER' : 'TEXT'))) as any
              })
            }
          }
        }

        setShareModalMessage(null)
      } catch (error) {
        console.error('[ChatPage.handleShareMessage] Failed to share message', {
          error,
          messageId: shareModalMessage.id,
          targetUserIds,
        })
      } finally {
        setIsShareSubmitting(false)
      }
    },
    [accessToken, emitSendMessage, joinConversation, shareModalMessage],
  )

  const handleInitiateCall = useCallback(async (type: 'audio' | 'video') => {
    if (!selectedConversationId) return;

    // ✅ GROUP CALL routing — delegate to separate group call layer
    if (selectedConversation?.isGroup) {
      await handleStartGroupCall(type === 'audio')
      return;
    }

    // ─── Single call (1-1) — DO NOT MODIFY ────────────────────────
    const callId = `call_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const socket = getSocket();
    if (!socket) return;

    const peerUserId = selectedConversation?.userId || selectedConversationId;
    console.log('[CALL][INITIATE]', { type, conversationId: selectedConversationId, peerUserId });

    setCallState({
      isOpen: true,
      type,
      direction: 'outgoing',
      status: 'connecting',
      peerId: peerUserId,
      conversationId: selectedConversationId,
      callId,
      isMicOn: true,
      isCameraOn: type === 'video',
    });

    await callServiceRef.current?.initialize({
      socket,
      conversationId: selectedConversationId,
      callId,
      currentUserId,
      peerUserId: peerUserId,
      audioOnly: type === 'audio',
      isCaller: true,
    });
  }, [selectedConversationId, selectedConversation, currentUserId, getSocket, handleStartGroupCall]);


  const handleEndCall = useCallback(async (reasonArg: any = 'hangup') => {
    const reason = typeof reasonArg === 'string' ? reasonArg : 'hangup';
    const currentCall = callStateRef.current;
    if (!currentCall.isOpen || !currentCall.conversationId) return;

    const { type, direction, startedAt, callId, peerId } = currentCall;
    const duration = startedAt ? Math.floor((Date.now() - startedAt) / 1000) : 0;

    let outcome: 'completed' | 'canceled' | 'missed' = 'completed';
    if (!startedAt) {
      outcome = direction === 'outgoing' ? 'canceled' : 'missed';
    }

    console.log(`[CALL_LOG] Ending call. Reason: ${reason}, Outcome: ${outcome}, Duration: ${duration}s`);

    // Stop WebRTC service
    const shouldNotify = reason !== 'remote-ended';
    callServiceRef.current?.endCall(reason, shouldNotify);

    const targetConvId = currentCall.conversationId;
    const peerUserId = peerId || selectedConversation?.userId || targetConvId;

    // Reset UI State immediately
    setCallState({
      isOpen: false,
      type: 'audio',
      direction: 'outgoing',
      status: 'connecting',
    });

    if (callId) {
      const keysToDelete = Array.from(processedSignalsRef.current).filter(k => k.startsWith(callId));
      keysToDelete.forEach(k => processedSignalsRef.current.delete(k));
    }

    // 1. Construct final log data
    const logData = {
      v: 1,
      callId: String(callId || ''),
      conversationId: String(targetConvId),
      callerId: direction === 'outgoing' ? currentUserId : peerUserId,
      calleeId: direction === 'outgoing' ? peerUserId : currentUserId,
      mediaType: type === 'video' ? 'video' : 'voice',
      outcome,
      durationSeconds: duration,
      createdAt: new Date().toISOString(),
    };

    const logText = `CALL_LOG::${JSON.stringify(logData)}`;
    // 3. Robust Send Pipeline (Shadow Process)
    // ONLY the Caller (outgoing) or receiver of a missed call is responsible for saving & showing optimistic log
    if (direction === 'outgoing' || (outcome !== 'completed' && direction === 'incoming')) {
      // 2. OPTIMISTIC UI: Add to chat immediately for caller
      const clientMessageId = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`;

      const optimisticLog: ChatMessage = {
        id: clientMessageId,
        clientMessageId,
        conversationId: targetConvId,
        sender: 'me',
        senderId: currentUserId,
        type: 'call',
        text: logText,
        timestamp: formatMessageTimestamp(),
        createdAt: new Date().toISOString(),
        deliveryState: 'sending',
        isLocal: true
      };

      console.log('[CALL_LOG] Adding optimistic message to UI', clientMessageId);
      setMessagesByConversation(prev => ({
        ...prev,
        [targetConvId]: upsertMessage(prev[targetConvId] ?? [], optimisticLog)
      }));
      updateConversationAfterMessage(targetConvId, optimisticLog, true);

      (async () => {
        let success = false;
        const maxRetries = 2;
        // ... (existing pipeline logic)

        // --- SOCKET ATTEMPT (with Retry & Timeout) ---
        for (let attempt = 1; attempt <= maxRetries; attempt++) {
          console.log(`[CALL_LOG] Socket Attempt ${attempt}/${maxRetries}...`);
          try {
            // Wrap emit in a timeout promise
            const ack = await Promise.race([
              emitSendMessage({
                conversationId: targetConvId,
                content: logText,
                messageType: 'TEXT', // BYPASS Restricted Mode using TEXT type
                clientMessageId
              }),
              new Promise<null>((_, reject) => setTimeout(() => reject(new Error('TIMEOUT')), 4000))
            ]);

            if (ack?.event === 'message.sent' && ack?.data) {
              console.log('[CALL_LOG] Socket send SUCCESS', ack.data.id);
              const serverMsg = {
                ...normalizeMessage(mapRawMessage(ack.data, currentUserId)),
                clientMessageId,
                deliveryState: 'sent' as const
              };
              setMessagesByConversation(prev => ({
                ...prev,
                [targetConvId]: upsertMessage(prev[targetConvId] ?? [], serverMsg)
              }));
              updateConversationAfterMessage(targetConvId, serverMsg, true);
              success = true;
              break;
            } else {
              console.warn(`[CALL_LOG] Socket attempt ${attempt} failed: No ACK or wrong event`);
            }
          } catch (err) {
            console.warn(`[CALL_LOG] Socket attempt ${attempt} error:`, err instanceof Error ? err.message : err);
          }
        }

        // --- REST FALLBACK ---
        if (!success) {
          console.warn('[CALL_LOG] Socket failed after retries, falling back to REST API');
          try {
            const restRes = await sendMessageViaRest(accessToken || '', {
              conversationId: targetConvId,
              content: logText,
              messageType: 'TEXT', // BYPASS Restricted Mode
              clientMessageId
            });

            if (restRes?.id) {
              console.log('[CALL_LOG] REST fallback SUCCESS', restRes.id);
              const serverMsg = {
                ...normalizeMessage(mapRawMessage(restRes, currentUserId)),
                clientMessageId,
                deliveryState: 'sent' as const
              };
              setMessagesByConversation(prev => ({
                ...prev,
                [targetConvId]: upsertMessage(prev[targetConvId] ?? [], serverMsg)
              }));
              updateConversationAfterMessage(targetConvId, serverMsg, true);
              success = true;
            }
          } catch (restErr) {
            console.error('[CALL_LOG] REST fallback CRITICAL FAILURE', restErr);
          }
        }

        // --- FINAL ERROR STATE ---
        if (!success) {
          console.error('[CALL_LOG] Failed to save call log after all attempts.');
          setMessagesByConversation(prev => ({
            ...prev,
            [targetConvId]: markLocalMessageFailed(prev[targetConvId] ?? [], clientMessageId)
          }));
        }
      })();
    } else {
      console.log('[CALL_LOG] Skipping send pipeline (current user is the receiver)');
    }
  }, [selectedConversation, currentUserId, emitSendMessage, accessToken, updateConversationAfterMessage]);

  const isAnsweringRef = useRef(false);
  const handleAnswerCall = useCallback(async () => {
    if (!callServiceRef.current || !callStateRef.current.isOpen || isAnsweringRef.current) return;
    if (callStateRef.current.status === 'connected') return;

    isAnsweringRef.current = true;
    console.log('[ChatPage.handleAnswerCall] Answering call...');

    // Safety watchdog: If it takes more than 15s to answer, fail the call to unstick UI
    const watchdog = setTimeout(() => {
      if (isAnsweringRef.current && callStateRef.current.status !== 'connected') {
        console.warn('[ChatPage.handleAnswerCall] Watchdog triggered: Answer taking too long, resetting.');
        handleEndCall('handshake-timeout');
        isAnsweringRef.current = false;
      }
    }, 15000);

    try {
      setCallState(prev => ({ ...prev, status: 'connecting' }));
      await callServiceRef.current.acceptCall();
      // Status will be updated to 'connected' by WebRTC event listeners
    } catch (error) {
      console.error('[ChatPage.handleAnswerCall] Failed to answer call:', error);
      handleEndCall('media-failed');
    } finally {
      clearTimeout(watchdog);
      isAnsweringRef.current = false;
    }
  }, [handleEndCall]);

  const handleToggleMic = useCallback(() => {
    callServiceRef.current?.toggleMic();
  }, []);

  const handleToggleCamera = useCallback(() => {
    callServiceRef.current?.toggleCamera();
  }, []);

  const handleCallAnswer = async (data: any) => {
    const signalData = Array.isArray(data) ? data[0] : data;
    const callId = signalData.callId;
    if (!callId) return;

    const sigKey = `${callId}_answer`;
    if (processedSignalsRef.current.has(sigKey)) return;
    processedSignalsRef.current.add(sigKey);

    console.log('[CALL][RECEIVE ANSWER]', signalData);
    if (callId === callStateRef.current.callId) {
      await callServiceRef.current?.handleAnswer(signalData.sdp || signalData.answer?.sdp);
    }
  };

  const handleCallIce = async (data: any) => {
    const signalData = Array.isArray(data) ? data[0] : data;
    const callId = signalData.callId;
    const candidate = signalData.candidate?.candidate || signalData.candidate;
    if (!callId || !candidate) return;

    const sigKey = `${callId}_ice_${candidate}`;
    if (processedSignalsRef.current.has(sigKey)) return;
    processedSignalsRef.current.add(sigKey);

    console.log('[CALL][RECEIVE ICE]', { callId, candidate: Boolean(candidate) });
    // Use currentCallIdRef for immediate matching to avoid state sync race conditions
    if (callId === currentCallIdRef.current) {
      await callServiceRef.current?.handleIceCandidate(signalData.candidate);
    } else {
      console.warn('[CALL][ICE IGNORED] Call ID mismatch or call not initialized yet', { incoming: callId, current: currentCallIdRef.current });
    }
  };

  const handleCallEnd = useCallback(async (data: any) => {
    const signalData = Array.isArray(data) ? data[0] : data;
    console.log('[CALL][RECEIVE END]', signalData);
    if (signalData.callId === callStateRef.current.callId) {
      handleEndCall(signalData.reason || 'remote-ended');
    }
  }, [handleEndCall]);

  const handleCallOffer = async (data: any) => {
    // Robust unwrap: Support direct object, socket.io array-wrapping, or nested 'data'/'offer'
    let signalData = Array.isArray(data) ? data[0] : data;
    if (signalData && signalData.data) signalData = signalData.data;
    if (signalData && signalData.offer && !signalData.sdp) signalData = signalData.offer;

    const callId = signalData?.callId;
    if (!callId || !getSocket()) return;

    const sigKey = `${callId}_offer`;
    if (processedSignalsRef.current.has(sigKey)) return;
    processedSignalsRef.current.add(sigKey);

    console.log('[CALL][RECEIVE OFFER] Hardened parsing:', signalData);

    // Support aliased keys from mobile clients at root or in nested object
    const peerUserId = signalData.senderUserId || signalData.callerId || signalData.fromUserId;
    const conversationId = signalData.conversationId || signalData.roomId;

    // Atomic Lock: Update currentCallIdRef immediately before any async work
    currentCallIdRef.current = callId;

    if (callStateRef.current.isOpen) {
      console.warn('[ChatPage] Already in a call, ignoring offer');
      return;
    }

    setCallState({
      isOpen: true,
      type: signalData.audioOnly ? 'audio' : 'video',
      direction: 'incoming',
      status: 'connecting',
      peerId: peerUserId,
      conversationId: conversationId,
      callId: callId,
      isMicOn: true,
      isCameraOn: !signalData.audioOnly,
    });

    if (peerUserId && accessToken) {
      void ensureUser(accessToken, peerUserId);
    }

    await callServiceRef.current?.initialize({
      socket: getSocket()!,
      conversationId: conversationId,
      callId: callId,
      currentUserId,
      peerUserId: peerUserId,
      audioOnly: signalData.audioOnly,
      isCaller: false,
      initialSdp: signalData.sdp || signalData.offer?.sdp || signalData.data?.sdp,
    });
  };

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STABLE SIGNALING HANDLERS (using Refs to prevent listener churn)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  const handleEndCallRef = useRef(handleEndCall);
  useEffect(() => { handleEndCallRef.current = handleEndCall; }, [handleEndCall]);

  const signalHandlersRef = useRef({
    handleCallOffer,
    handleCallAnswer,
    handleCallIce,
    handleCallEnd
  });

  useEffect(() => {
    signalHandlersRef.current = {
      handleCallOffer,
      handleCallAnswer,
      handleCallIce,
      handleCallEnd
    };
  }, [handleCallOffer, handleCallAnswer, handleCallIce, handleCallEnd]);

  useEffect(() => {
    const socket = getSocket();
    if (!socket || !currentUserId) return;

    console.log('[ChatPage.signaling] Registering stable listeners');

    const onOffer = (data: any) => signalHandlersRef.current.handleCallOffer(data);
    const onAnswer = (data: any) => signalHandlersRef.current.handleCallAnswer(data);
    const onIce = (data: any) => signalHandlersRef.current.handleCallIce(data);
    const onEnd = (data: any) => signalHandlersRef.current.handleCallEnd(data);

    // Colon notation
    socket.on('call:offer', onOffer);
    socket.on('call:answer', onAnswer);
    socket.on('call:ice-candidate', onIce);
    socket.on('call:end', onEnd);

    // Dot notation (fallback)
    socket.on('call.offer', onOffer);
    socket.on('call.answer', onAnswer);
    socket.on('call.ice-candidate', onIce);
    socket.on('call.end', onEnd);

    // Generic signal (fallback)
    const onGenericSignal = (data: any) => {
      // Robust unwrapping: check for direct payload or nested 'data', 'offer', 'answer', 'candidate' keys
      const signalData = data.data || data.offer || data.answer || data.candidate || (Array.isArray(data) ? data[0] : data);
      const type = data.type || signalData?.type;

      console.log('[CALL][RECEIVE GENERIC SIGNAL]', { type, signalData });

      if (type === 'offer') signalHandlersRef.current.handleCallOffer(signalData);
      else if (type === 'answer') signalHandlersRef.current.handleCallAnswer(signalData);
      else if (type === 'ice-candidate') signalHandlersRef.current.handleCallIce(signalData);
      else if (type === 'end') signalHandlersRef.current.handleCallEnd(signalData);
    };
    socket.on('call:signal', onGenericSignal);
    socket.on('call.signal', onGenericSignal);

    return () => {
      console.log('[ChatPage.signaling] Cleaning up listeners');
      socket.off('call:offer', onOffer);
      socket.off('call:answer', onAnswer);
      socket.off('call:ice-candidate', onIce);
      socket.off('call:end', onEnd);
      socket.off('call.offer', onOffer);
      socket.off('call.answer', onAnswer);
      socket.off('call.ice-candidate', onIce);
      socket.off('call.end', onEnd);
      socket.off('call:signal', onGenericSignal);
      socket.off('call.signal', onGenericSignal);
    };
  }, [getSocket, currentUserId]);



  // Sync effect: Fetch profile for all group members when a conversation is opened
  useEffect(() => {
    if (!accessToken || !selectedConversationId) return;
    const selected = conversations.find(c => c.id === selectedConversationId);
    if (selected?.participantUserIds) {
      selected.participantUserIds.forEach(id => void ensureUser(accessToken, id));
    }
  }, [accessToken, selectedConversationId, conversations, ensureUser]);

  const loadInbox = useCallback(
    async (token: string, preferredConversationId?: string) => {
      setIsLoadingConversations(true)

      try {
        const [itemsResult, policy, friends] = await Promise.all([
          fetchInbox(token, user?.id),
          getSyncPolicy(token).catch(() => null),
          getFriends(token).catch(() => []),
        ])
        let items = itemsResult as any[];

        const targetId = preferredConversationId || routedConversationIdRef.current;

        // Collect IDs to proactively fetch
        const proactiveIds = new Set<string>();
        if (targetId) proactiveIds.add(targetId);

        try {
          const storedPending = localStorage.getItem(`vnalo_pending_groups_${user?.id}`);
          const pendingIds: string[] = storedPending ? JSON.parse(storedPending) : [];
          pendingIds.forEach(id => proactiveIds.add(id));
        } catch (e) {
          console.warn("Failed to load pending group IDs:", e);
        }

        const missingIds = Array.from(proactiveIds).filter(id => !items.some(it => it.id === id));

        if (missingIds.length > 0) {
          console.log("🔍 [ChatPage] Proactively fetching missing conversations:", missingIds);
          const fetchedResults = await Promise.all(
            missingIds.map(id => fetchConversation(token, id).catch(() => null))
          );

          const myId = String(user?.id ?? '').trim();
          fetchedResults.forEach(rawConvo => {
            if (rawConvo) {
              const c = rawConvo as any;
              const inner = c.conversation || c;
              const members = inner.members || [];
              const participantIds = members
                .map((m: any) => String(m.userId ?? '').trim())
                .filter((id: string) => id && id !== myId);

              const isGroup = (inner.type || c.type) === 'GROUP';
              const freshConvo: ConversationSummary = {
                id: inner.id || c.id,
                isGroup,
                name: inner.title || c.title || (isGroup ? "Nhóm mới" : "Người dùng mới"),
                avatarUrl: inner.avatarUrl || c.avatarUrl || null,
                lastMessage: isGroup ? "Nhóm mới được tạo" : "[Thiệp] Gửi lời chào",
                unreadCount: 0,
                participantUserIds: participantIds,
                memberCount: members.length,
                lastMessageAt: inner.updatedAt || c.updatedAt || new Date().toISOString(),
                updatedAt: inner.updatedAt || c.updatedAt || new Date().toISOString(),
              };

              // Only add if not already present (double check for safety)
              if (!items.some(it => it.id === freshConvo.id)) {
                items = [freshConvo, ...items];
              }
            }
          });

          // Cleanup: if an ID is now in items, it's either fetched or already in inbox
          try {
            const storedPending = localStorage.getItem(`vnalo_pending_groups_${user?.id}`);
            const pendingIds: string[] = storedPending ? JSON.parse(storedPending) : [];
            // Cleanup logic would go here if we wanted to remove IDs that are now in items
            console.log("Still missing group IDs:", pendingIds.filter(id => !items.some(it => it.id === id)));
          } catch (e) {
            console.warn("Failed to cleanup pending groups:", e);
          }
        }

        const restrictedByToken = isRestrictedWebToken(token)
        const restrictedByPolicy = Boolean(policy?.webRestrictedMode) || policy?.syncEnabled === false
        const restrictionSignalsPresent = restrictedByToken || restrictedByPolicy
        const friendNameById = new Map(
          friends
            .filter((friend) => Boolean(friend.friendId))
            .map((friend) => [friend.friendId, friend.nickname?.trim() || friend.displayName?.trim() || null]),
        )
        const friendAvatarById = new Map(
          friends
            .filter((friend) => Boolean(friend.friendId))
            .map((friend) => [friend.friendId, friend.avatarUrl ?? null]),
        )
        const friendIdSet = new Set(
          friends
            .map((friend) => String(friend.friendId ?? '').trim())
            .filter((friendId): friendId is string => Boolean(friendId)),
        )
        friendIdSetRef.current = friendIdSet
        setFriendsDirectory(friends)

        const previewNameById = new Map(friendNameById)
        if (user?.id) {
          previewNameById.set(user.id, user.name?.trim() || fallbackUserDisplayName(user.id))
        }

        friends.forEach((friend) => {
          if (friend.friendId) {
            upsertUser(friend.friendId, {
              displayName: friend.nickname?.trim() || friend.displayName?.trim() || fallbackUserDisplayName(friend.friendId),
              avatarUrl: friend.avatarUrl ?? null,
            })
          }
        })

        const unresolvedPeerIds = [
          ...new Set(
            items
              .flatMap((item) => (item as any).participantUserIds ?? [])
              .filter((peerId): peerId is string => typeof peerId === 'string' && peerId !== user?.id && !friendNameById.has(peerId)),
          ),
        ]

        const fallbackProfiles = await Promise.all(
          unresolvedPeerIds.map(async (peerId) => {
            const profile = await getUserById(token, peerId).catch(() => null)
            return {
              peerId,
              name: profile?.displayName?.trim() || profile?.phone || profile?.email || null,
              avatarUrl: profile?.avatarUrl ?? null,
            }
          }),
        )

        for (const fallback of fallbackProfiles) {
          if (fallback.name) {
            friendNameById.set(fallback.peerId, fallback.name)
          }
          if (fallback.avatarUrl) {
            friendAvatarById.set(fallback.peerId, fallback.avatarUrl)
          }
        }

        // Seed cache with members of all group conversations in inbox only if real name exists
        items.forEach((it: any) => {
          if (it.conversation?.members) {
            it.conversation.members.forEach((m: any) => {
              const mid = String(m.userId ?? '').trim()
              const realName = (m.nickname || m.displayName || m.name || '').trim();
              if (mid && realName && realName !== 'Người dùng' && realName !== (mid === user?.id ? 'Bạn' : 'Người dùng')) {
                upsertUser(mid, {
                  displayName: realName,
                  avatarUrl: m.avatarUrl || null
                })
              } else if (mid) {
                // Background fetch for missing names
                void ensureUser(token, mid);
              }
            })
          }
        })

        const mappedItems = items.map((item: any) => {
          const peerId = (item.participantUserIds ?? []).find((participantId: string) => participantId !== user?.id)
          const isGroup = item.isGroup;
          const resolvedPeerName = !isGroup && peerId ? friendNameById.get(peerId) : null
          const resolvedPeerAvatar = !isGroup && peerId ? (friendAvatarById.get(peerId) ?? null) : null
          const resolvedLastMessageSenderName = item.lastMessageSenderId
            ? (previewNameById.get(item.lastMessageSenderId) ?? null)
            : null
          const getName = (id: string) => {
            if (id === user?.id) return 'Bạn'
            return userMapRef.current[id]?.displayName || previewNameById.get(id) || 'Người dùng'
          }
          const formattedLastMessage = formatConversationPreview(
            resolvedLastMessageSenderName,
            item.lastMessagePreview ?? item.lastMessage ?? '',
            user?.id || '',
            getName,
          )
          const isStranger = !isGroup && peerId ? !friendIdSet.has(peerId) : false

          const withName = (!isGroup && resolvedPeerName)
            ? {
              ...item,
              name: resolvedPeerName,
              avatarUrl: resolvedPeerAvatar,
              lastMessage: formattedLastMessage,
              isStranger,
            }
            : {
              ...item,
              lastMessage: formattedLastMessage,
              isStranger,
            }

          return applyRestrictedConversationPreview(withName, false)
        })

        // Keep diagnostics but do not lock web composer from policy flags.
        if (restrictionSignalsPresent) {
          console.warn('[ChatPage.inbox] Restriction signal detected but ignored by client override', {
            restrictedByToken,
            restrictedByPolicy,
          })
        }
        setIsRestrictedMode(false)
        console.log('🚀 [DEBUG] Inbox items from API:', mappedItems);

        const deduplicateById = (items: ConversationSummary[]): ConversationSummary[] => {
          const seen = new Set<string>()
          const seenPeers = new Set<string>()
          return items.filter((item) => {
            if (seen.has(item.id)) return false

            if (!item.isGroup && !item.isCloud) {
              const peerId = (item.participantUserIds ?? []).find(id => id !== user?.id)
              if (peerId) {
                if (seenPeers.has(peerId)) return false
                seenPeers.add(peerId)
              }
            }

            seen.add(item.id)
            return true
          })
        }

        setConversations((prev) => {
          if (!targetId) return mappedItems;

          // Try to find it in the freshly fetched items first
          const targetInFetched = mappedItems.find(item => item.id === targetId);
          if (targetInFetched) {
            return [targetInFetched, ...mappedItems.filter(item => item.id !== targetId)];
          }

          // Fallback: try to find it in previous state
          const targetInPrev = prev.find(item => item.id === targetId);
          if (targetInPrev) {
            return [targetInPrev, ...mappedItems.filter(item => item.id !== targetId)];
          }

          return mappedItems;
        })
        setSelectedConversationId((prev) => {
          if (preferredConversationId) {
            return preferredConversationId
          }
          if (routedConversationIdRef.current && mappedItems.some((item) => item.id === routedConversationIdRef.current)) {
            return routedConversationIdRef.current
          }
          if (prev && mappedItems.some((item) => item.id === prev)) {
            return prev
          }
          return ''
        })
      } catch (error) {
        console.error('Failed to fetch inbox', error)
        setConversations([])
        setSelectedConversationId('')
      } finally {
        setIsLoadingConversations(false)
      }
    },
    [user?.id, user?.name, upsertUser],
  )

  const handleCreateGroup = useCallback(
    async (groupName: string, avatarUrl: string | null, memberIds: string[]) => {
      if (!accessToken || !user) {
        toast.error("Vui lòng đăng nhập lại");
        return;
      }

      setIsCreatingGroup(true);
      try {
        let finalAvatarUrl = avatarUrl;
        if (avatarUrl && avatarUrl.startsWith('blob:')) {
          try {
            const blob = await fetch(avatarUrl).then(r => r.blob());
            const file = new File([blob], 'avatar.png', { type: blob.type });
            const uploadRes = await uploadChatMedia(accessToken, file);
            finalAvatarUrl = uploadRes.url ?? null;
          } catch (e) {
            console.warn("Failed to upload avatar:", e);
          }
        }
        const groupId = await createGroupConversation(accessToken, {
          title: groupName,
          memberUserIds: memberIds,
          avatarUrl: finalAvatarUrl,
        });

        console.log("🚀 [DEBUG] Created Group ID:", groupId);

        // 2. Local Sync: Proactively fetch profiles for all selected members
        memberIds.forEach(id => void ensureUser(accessToken, id));

        // Manually construct and append the new group to local state for immediate UI update
        const newGroupEntry: ConversationSummary = {
          id: groupId,
          name: groupName,
          isGroup: true,
          avatarUrl: finalAvatarUrl,
          lastMessage: "Bạn đã tạo nhóm",
          unreadCount: 0,
          participantUserIds: memberIds,
          memberCount: memberIds.length + 1,
          members: [
            { userId: user.id, role: 'ADMIN' },
            ...memberIds.map(id => ({ userId: id, role: 'MEMBER' }))
          ],
          lastMessageAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        setConversations(prev => [newGroupEntry, ...prev.filter(c => c.id !== groupId)]);
        setSelectedConversationId(groupId);

        // Seed cache for myself too
        upsertUser(user.id, {
          displayName: user.name || "Bạn",
          avatarUrl: user.avatarUrl || null
        });

        // Seed cache for others (best effort using what we might already know from friendsDirectory)
        memberIds.forEach(id => {
          const friend = friendsDirectory.find(f => f.friendId === id);
          if (friend) {
            upsertUser(id, {
              displayName: friend.nickname || friend.displayName || fallbackUserDisplayName(id),
              avatarUrl: friend.avatarUrl || null
            });
          } else {
            // Force fetch if unknown
            void ensureUser(accessToken, id);
          }
        });

        // Remember this group ID locally to ensure it shows up even if it has no messages
        try {
          const storedPending = localStorage.getItem(`vnalo_pending_groups_${user?.id}`);
          const pendingIds: string[] = storedPending ? JSON.parse(storedPending) : [];
          if (!pendingIds.includes(groupId)) {
            pendingIds.push(groupId);
            localStorage.setItem(`vnalo_pending_groups_${user?.id}`, JSON.stringify(pendingIds));
          }
        } catch (e) {
          console.warn("Failed to save pending group ID:", e);
        }

        // Emit structured SYSTEM message via socket
        const systemPayload = JSON.stringify({
          action: 'CREATE_GROUP',
          actorId: user.id
        });

        // Join the conversation room first to ensuring receiving messages and broadcasts
        await joinConversation(groupId);

        // Emit structured SYSTEM message via socket
        void emitSendMessage({
          conversationId: groupId,
          content: systemPayload,
          messageType: 'SYSTEM',
          clientMessageId: crypto.randomUUID()
        });

        // Refresh conversation list to sync with backend
        await loadInbox(accessToken, groupId);


        navigate(`/chat/${groupId}`);
        setIsCreateGroupOpen(false);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : "Không thể tạo nhóm. Vui lòng thử lại.";
        console.error("❌ [CREATE GROUP] Lỗi:", error);
        toast.error(errorMessage);
      } finally {
        setIsCreatingGroup(false);
      }
    },
    [accessToken, user, navigate, loadInbox, emitSendMessage, joinConversation]
  );



  useEffect(() => {
    if (!accessToken) {
      setConversations([])
      setMessagesByConversation({})
      setSelectedConversationId('')
      setFriendResults([])
      setFriendsDirectory([])
      setShareModalMessage(null)
      lastLoadedMessagesKeyRef.current = ''
      return
    }

    // SINGLE ENTRY for loadInbox
    void loadInbox(accessToken)

    // Reset restricted mode locally
    setIsRestrictedMode(false)
  }, [accessToken, loadInbox])

  useEffect(() => {
    if (!routedConversationId) {
      return
    }

    setSelectedConversationId(routedConversationId)
  }, [routedConversationId])

  const handleSearchFriends = useCallback(
    async (keyword: string) => {
      if (!accessToken) {
        setFriendResults([])
        return
      }

      const normalizedKeyword = keyword.trim()
      if (!normalizedKeyword) {
        setFriendResults([])
        return
      }

      const normalizedPhone = normalizedKeyword.replace(/\D/g, '')
      let phoneSearchTerm = normalizedKeyword
      if (normalizedKeyword.startsWith('0') && normalizedPhone.length >= 9) {
        phoneSearchTerm = '+84' + normalizedKeyword.substring(1)
      }

      try {
        if (normalizedPhone.length >= 2 && normalizedPhone.length >= Math.max(2, normalizedKeyword.length - 2)) {
          const user = await getUserByPhone(accessToken, phoneSearchTerm)
          if (user) {
            setFriendResults([user])
            return
          }
        }

        const users = await searchUsers(accessToken, normalizedKeyword)
        setFriendResults(users)
      } catch (error) {
        console.error('Failed to search users', error)
        setFriendResults([])
      }
    },
    [accessToken],
  )

  const handleSelectConversation = useCallback(
    async (conversationId: string) => {
      setSelectedConversationId(conversationId)
      navigate('/chat/' + conversationId)

      // Proactively refresh metadata for the selected conversation
      if (accessToken && conversationId && !conversationId.startsWith('vnalo_cloud_')) {
        try {
          const detailRaw = await fetchConversation(accessToken, conversationId).catch(() => null);
          if (detailRaw) {
            const c = detailRaw as any;
            const inner = c.conversation || c;
            const members = inner.members || [];
            const myId = String(user?.id ?? '').trim();
            const participantIds = members
              .map((m: any) => String(m.userId ?? '').trim())
              .filter((id: string) => id && id !== myId);

            setConversations(prev => prev.map(conv => {
              if (conv.id !== conversationId) return conv;
              const isGroup = conv.isGroup;
              return {
                ...conv,
                memberCount: members.length || conv.memberCount,
                members: members.map((m: any) => ({
                  userId: String(m.userId ?? '').trim(),
                  role: String(m.role ?? 'MEMBER').toUpperCase(),
                })),
                participantUserIds: participantIds,
                avatarUrl: isGroup ? (inner.avatarUrl || conv.avatarUrl) : (inner.avatarUrl || conv.avatarUrl),
                name: isGroup ? (inner.title || conv.name) : (inner.title || conv.name),
                onlyAdminCanPost: Boolean(inner.onlyAdminCanPost ?? inner.only_admin_can_post ?? conv.onlyAdminCanPost),
                allowMemberPin: Boolean(inner.allowMemberPin ?? inner.allow_member_pin ?? conv.allowMemberPin),
                allowMemberEditInfo: Boolean(inner.allowMemberEditInfo ?? inner.allow_member_edit_info ?? conv.allowMemberEditInfo),
              };
            }));

            // Fetch missing profiles for members
            const missingProfiles = participantIds.filter((id: string) => !userMapRef.current[id]);
            if (missingProfiles.length > 0) {
              const fetched = await Promise.all(
                missingProfiles.map((id: string) => getUserById(accessToken, id).catch(() => null))
              );
              fetched.forEach((p, idx) => {
                const pid = missingProfiles[idx];
                if (p && pid) {
                  upsertUser(pid, {
                    displayName: p.displayName?.trim() || p.phone || p.email || fallbackUserDisplayName(pid),
                    avatarUrl: p.avatarUrl ?? null,
                  });
                }
              });
            }
          }
        } catch (e) {
          console.warn('[ChatPage] metadata refresh failed:', e);
        }
      }
    },
    [accessToken, navigate, user?.id, upsertUser],
  )

  const handleOpenCreateGroupModal = useCallback(() => {
    setPreselectedMemberIds([]);
    setIsCreateGroupOpen(true)
  }, [])

  const handleCreateGroupFromDirect = useCallback(() => {
    if (selectedConversation && !selectedConversation.isGroup) {
      const peerId = (selectedConversation.participantUserIds ?? [])[0];
      if (peerId) {
        setPreselectedMemberIds([peerId]);
      } else {
        setPreselectedMemberIds([]);
      }
    } else {
      setPreselectedMemberIds([]);
    }
    setIsCreateGroupOpen(true);
  }, [selectedConversation]);

  // Handlers for global search panel
  const handleGlobalSearchSelectMessage = useCallback(
    (messageId: string, conversationId: string) => {
      setSelectedConversationId(conversationId)
      navigate(`/chat/${conversationId}`)
      setJumpToMessageId(messageId)
      setRightSidebarContent(null)
    },
    [navigate],
  )

  const handleGlobalSearchSelectConversation = useCallback(
    (conversationId: string) => {
      setSelectedConversationId(conversationId)
      navigate(`/chat/${conversationId}`)
      setRightSidebarContent(null)
    },
    [navigate],
  )

  const handleGlobalSearchSelectUser = useCallback(
    async (userId: string) => {
      if (!accessToken || !user) {
        return
      }

      try {
        const conversationId = await getOrCreateDirectConversation(accessToken, userId)
        handleGlobalSearchSelectConversation(conversationId)
      } catch (error) {
        console.error('[ChatPage] Failed to create direct conversation:', error)
      }
    },
    [accessToken, user, handleGlobalSearchSelectConversation],
  )

  const handleOpenUserProfile = useCallback((userId: string) => {
    setSelectedProfileUserId(userId)
    setIsProfileModalOpen(true)
  }, [])



  const handleLoadConversationMessages = useCallback((conversationId: string) => {
    if (!accessToken || !conversationId || !user) {
      return
    }

    const loadKey = `${conversationId}:${isRestrictedMode ? 'restricted' : 'full'}`
    if (lastLoadedMessagesKeyRef.current === loadKey) {
      return
    }
    lastLoadedMessagesKeyRef.current = loadKey
    const requestSeq = ++messageLoadRequestSeqRef.current

    setIsLoadingMessages(true)

    void (async () => {
      try {
        // Proactively refresh metadata to ensure member count etc is updated
        if (accessToken && !conversationId.startsWith('vnalo_cloud_')) {
          void (async () => {
            try {
              const detailRaw = await fetchConversation(accessToken, conversationId).catch(() => null);
              if (detailRaw) {
                const c = detailRaw as any;
                const inner = c.conversation || c;
                const members = inner.members || [];
                const myId = String(user?.id ?? '').trim();
                const participantIds = members
                  .map((m: any) => String(m.userId ?? '').trim())
                  .filter((id: string) => id && id !== myId);

                setConversations(prev => prev.map(conv => {
                  if (conv.id !== conversationId) return conv;
                  const isGroup = conv.isGroup;
                  return {
                    ...conv,
                    memberCount: members.length || conv.memberCount,
                    members: members.map((m: any) => ({
                      userId: String(m.userId ?? '').trim(),
                      role: String(m.role ?? 'MEMBER').toUpperCase(),
                    })),
                    participantUserIds: participantIds,
                    avatarUrl: isGroup ? (inner.avatarUrl || conv.avatarUrl) : (inner.avatarUrl || conv.avatarUrl),
                    name: isGroup ? (inner.title || conv.name) : (inner.title || conv.name),
                    onlyAdminCanPost: Boolean(inner.onlyAdminCanPost ?? inner.only_admin_can_post ?? conv.onlyAdminCanPost),
                    allowMemberPin: Boolean(inner.allowMemberPin ?? inner.allow_member_pin ?? conv.allowMemberPin),
                    allowMemberEditInfo: Boolean(inner.allowMemberEditInfo ?? inner.allow_member_edit_info ?? conv.allowMemberEditInfo),
                  };
                }));

                // Fetch missing profiles
                const missingProfiles = participantIds.filter((id: string) => !userMapRef.current[id]);
                if (missingProfiles.length > 0) {
                  const fetched = await Promise.all(
                    missingProfiles.map((id: string) => getUserById(accessToken, id).catch(() => null))
                  );
                  fetched.forEach((p, idx) => {
                    const pid = missingProfiles[idx];
                    if (p && pid) {
                      upsertUser(pid, {
                        displayName: p.displayName?.trim() || p.phone || p.email || fallbackUserDisplayName(pid),
                        avatarUrl: p.avatarUrl ?? null,
                      });
                    }
                  });
                }
              }
            } catch (e) {
              console.warn('[ChatPage] metadata refresh failed:', e);
            }
          })();
        }

        const isVirtualCloud = conversationId === `vnalo_cloud_${user.id}`
        const rawMessages = isVirtualCloud ? [] : await fetchMessages(accessToken, conversationId)
        console.log('Dữ liệu tin nhắn nhận được:', rawMessages)
        const mapped = sortMessages(
          rawMessages
            .map((message) => applyRestrictedMessage(normalizeMessage(mapRawMessage(message, user.id)), isRestrictedMode))
            .filter((message) => !deletedMessageIds[message.id]),
        )

        // Capture all recalled messages from the fetched data
        const loadTimeRecalledIds: Record<string, true> = {};
        mapped.forEach(m => {
          if (m.isRecalled) loadTimeRecalledIds[m.id] = true;
        });
        if (Object.keys(loadTimeRecalledIds).length > 0) {
          setRecalledMessageIds(prev => ({ ...prev, ...loadTimeRecalledIds }));
        }

        setMessagesByConversation((prev) => ({
          ...prev,
          [conversationId]: mapped,
        }))
        void syncPinnedMessages(conversationId)
        void syncConversationReactions()

        const newestSeq = mapped[mapped.length - 1]?.serverSeq
        if (newestSeq !== undefined) {
          void markConversationRead(accessToken, conversationId, newestSeq).catch(() => undefined)
          setConversations((prev) =>
            prev.map((conversation) =>
              conversation.id === conversationId
                ? {
                  ...conversation,
                  unreadCount: 0,
                }
                : conversation,
            ),
          )
        }
      } catch (error: unknown) {
        console.error('Failed to fetch messages', error)
        lastLoadedMessagesKeyRef.current = ''
      } finally {
        if (messageLoadRequestSeqRef.current === requestSeq) {
          setIsLoadingMessages(false)
        }
      }
    })()
  }, [accessToken, deletedMessageIds, isRestrictedMode, syncConversationReactions, syncPinnedMessages, user, upsertUser])



  useEffect(() => {
    if (!isSocketConnected || !selectedConversationId || !accessToken) {
      return
    }

    // REMOVED REACTION POLLING: It was causing O(N) requests every 2.5s, 
    // which flooded the network and caused Socket ACK timeouts (the 4-5s delay).
    // Reactions are now handled via real-time socket events instead.
    void syncConversationReactions()
  }, [accessToken, isSocketConnected, selectedConversationId, syncConversationReactions])

  useEffect(() => {
    console.log('Danh sách ID sau khi sửa mapping:', conversations.map((conv) => conv.userId))
  }, [conversations])

  const conversationIdsSignature = useMemo(
    () => conversations.map((conversation) => conversation.id).sort().join(','),
    [conversations],
  )

  const joinAllConversations = useCallback(async (list: ConversationSummary[]) => {
    const conversationIds = list.map((conversation) => conversation.id)

    if (conversationIds.length === 0) {
      return
    }

    console.log('--- ĐANG THỰC HIỆN JOIN ROOM CHO', list.length, 'HỘI THOẠI ---')
    console.log('Đã tự động Join vào các room:', conversationIds)

    for (const conversationId of conversationIds) {
      const joined = await joinConversation(conversationId)
      if (!joined) {
        console.warn('[ChatPage.joinAllConversations] Failed to join conversation:', conversationId)
      }
    }
  }, [joinConversation])

  const previousSocketConnectedRef = useRef(false)

  useEffect(() => {
    const socket = getSocket()
    const currentConnected = Boolean(socket?.connected)

    if (!previousSocketConnectedRef.current && currentConnected && conversations.length > 0) {
      console.log('[ChatPage.retryJoin] Socket vừa chuyển false -> true, join lại rooms')
      void joinAllConversations(conversations)
    }

    previousSocketConnectedRef.current = currentConnected
  }, [conversations, getSocket, joinAllConversations])

  const handleOpenFriendChat = useCallback(
    async (friend: UserLookupResult) => {
      if (!accessToken) {
        return
      }

      try {
        const conversationId = await getOrCreateDirectConversation(accessToken, friend.id)
        const friendName = friend.displayName?.trim() || friend.phone || friend.email || t('contacts.common.unknownUser')

        setConversations((prev) => {
          if (prev.some((conversation) => conversation.id === conversationId)) {
            return prev
          }

          return [
            {
              id: conversationId,
              name: friendName,
              avatarUrl: friend.avatarUrl ?? null,
              isStranger: false,
              lastMessage: '',
              unreadCount: 0,
              online: false,
              lastMessageSeq: 0,
              participantUserIds: [friend.id],
            },
            ...prev,
          ]
        })

        setSelectedConversationId(conversationId)
        navigate(`/chat/${conversationId}`)
        await joinConversation(conversationId)
        console.log('[ChatPage.openDirectConversation] ✅ Joined conversation:', conversationId)
        await loadInbox(accessToken, conversationId)
      } catch (error) {
        console.error('Failed to open direct conversation', error)
      }
    },
    [accessToken, joinConversation, loadInbox, navigate, t],
  )

  useEffect(() => {
    // Only redirect if we are at the root /chat path AND we have a previously selected ID
    // but we ARE NOT already on that routed path.
    if (!routedConversationId && selectedConversationId) {
      navigate(`/chat/${selectedConversationId}`, { replace: true });
    }
  }, [navigate, routedConversationId, selectedConversationId])

  // Save selection to localStorage whenever it changes
  useEffect(() => {
    if (selectedConversationId) {
      localStorage.setItem('vnalo_last_conv_id', selectedConversationId);
    }
  }, [selectedConversationId])

  // Load last selection on mount if we are at the root
  useEffect(() => {
    if (!routedConversationId) {
      const lastId = localStorage.getItem('vnalo_last_conv_id');
      if (lastId && conversations.some(c => c.id === lastId)) {
        setSelectedConversationId(lastId);
      }
    }
  }, [conversations, routedConversationId])

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SMART JOIN ROOMS (Only join once per session/reconnect)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  const joinedIdsRef = useRef<Set<string>>(new Set())
  const lastJoinedSocketIdRef = useRef<string | null>(null)

  useEffect(() => {
    // Hard check every time conversations or connection state changes
    const socket = getSocket();
    const actualConnected = Boolean(socket?.connected);
    const currentSocketId = socket?.id || null;

    // If socket ID changed (reconnect), we MUST clear the joined cache
    // because server-side room membership is lost on reconnect.
    if (currentSocketId !== lastJoinedSocketIdRef.current) {
      console.log(`[ChatPage.join] 🔄 Socket ID changed from ${lastJoinedSocketIdRef.current} to ${currentSocketId}, clearing joined cache`);
      joinedIdsRef.current.clear();
      lastJoinedSocketIdRef.current = currentSocketId;
    }

    if (actualConnected && !isSocketConnected) {
      console.log('[ChatPage.join] ⚡ Fixing connection state (out of sync)');
      setIsSocketConnected(true);
      return;
    }

    if (!actualConnected || !isSocketConnected) {
      if (joinedIdsRef.current.size > 0) {
        console.log('[ChatPage.join] ⚪ Socket disconnected, clearing joined cache');
        joinedIdsRef.current.clear();
      }
      return;
    }

    const currentIds = conversations.map((c) => c.id);
    const newIds = currentIds.filter((id) => id && !joinedIdsRef.current.has(id));

    if (newIds.length > 0) {
      console.log(`[ChatPage.join] 🚀 Joining ${newIds.length} new rooms for socket ${currentSocketId}`);
      newIds.forEach((id) => {
        joinedIdsRef.current.add(id);
        void joinConversation(id);
      });
    }
  }, [conversations, isSocketConnected, joinConversation, getSocket]);

  // 1. Mark as read on conversation change or new messages (with guard)
  const lastEmittedReadRef = useRef<Record<string, number>>({})

  useEffect(() => {
    if (!selectedConversationId) {
      return
    }

    const convMessages = messagesByConversation[selectedConversationId] || []
    const latestSeq = convMessages.at(-1)?.serverSeq

    if (latestSeq === undefined) {
      return
    }

    // GUARD: Only emit if sequence has actually increased OR conversation changed to prevent infinite loop
    if (latestSeq > (lastEmittedReadRef.current[selectedConversationId] ?? 0)) {
      console.log('[ChatPage.effect] auto-markAsRead:', { selectedConversationId, latestSeq })
      lastEmittedReadRef.current[selectedConversationId] = latestSeq
      markAsRead({ conversationId: selectedConversationId, lastReadSeq: latestSeq })
      refreshNotificationBadges()
    }
  }, [markAsRead, messagesByConversation, selectedConversationId])

  useEffect(() => {
    if (!accessToken || !selectedConversationId) {
      return
    }

    void syncPinnedMessages(selectedConversationId)
  }, [accessToken, selectedConversationId, syncPinnedMessages])

  // Auto-update presence status every 60 seconds to refresh time-based text
  useEffect(() => {
    const interval = setInterval(() => {
      setConversations((prev) => [...prev])
    }, 60000)

    return () => clearInterval(interval)
  }, [])

  const handleSend = useCallback(
    async (draft: ChatComposePayload) => {
      const conversationId = selectedConversationIdRef.current || selectedConversationId || routedConversationId

      if (!conversationId || !user || !accessToken) {
        console.warn('[ChatPage.send] Precondition failed:', {
          conversationId: !!conversationId,
          user: !!user,
          token: !!accessToken,
        })
        return
      }

      const content = getDraftContent(draft)
      const messageType = getDraftMessageType(draft)
      let replyTo = draft.replyTo

      // Resolve better senderName if possible
      if (replyTo && replyTo.senderId && userMap[replyTo.senderId]) {
        replyTo = {
          ...replyTo,
          senderName: userMap[replyTo.senderId].displayName || replyTo.senderName
        };
      }

      console.log('[ChatPage.send] Draft replyTo:', replyTo)

      // Fallback resolve virtual "My Documents" to real conversation if needed
      let targetConversationId = conversationId;
      if (conversationId === `vnalo_cloud_${user.id}`) {
        try {
          const realId = await getOrCreateDirectConversation(accessToken, user.id);
          targetConversationId = realId;
          setConversations(prev => prev.map(c => c.id === conversationId ? { ...c, id: realId } : c));
          setSelectedConversationId(realId);
        } catch (err) {
          console.error('[ChatPage.send] Final attempt to resolve cloud chat failed', err);
          return;
        }
      }

      const clientMessageId = generateUUID()

      // 1. Collect all files to upload
      const allFiles = (draft.files && draft.files.length > 0
        ? draft.files
        : (draft.file ? [draft.file] : [])).filter((f): f is File => !!f);
      const isMultiFile = allFiles.length > 0;

      // 2. Handle Optimistic UI for files/images (Initial local preview)
      const localPreviewUrls: string[] = [];
      if (isMultiFile) {
        const optimisticAttachments = allFiles.map(file => {
          const isImg = file.type.startsWith('image/');
          const previewUrl = isImg ? URL.createObjectURL(file) : '';
          if (previewUrl) localPreviewUrls.push(previewUrl);

          return {
            url: previewUrl || '',
            name: file.name,
            mimeType: file.type,
            sizeBytes: file.size,
          };
        });

        // If it's a single file, we can show it optimistically as one bubble initially.
        // But for consistency with the new "individual message" flow, if multi-file, we can skip this single bubble 
        // and just let the loop below handle optimistic bubbles.
        if (allFiles.length === 1) {
          const optimisticMessage: ChatMessage = {
            id: clientMessageId,
            clientMessageId,
            conversationId: targetConversationId,
            sender: 'me',
            senderId: user.id,
            type: messageType,
            isLocal: true,
            text: content,
            attachments: optimisticAttachments,
            mediaUrl: optimisticAttachments[0]?.url || null,
            timestamp: formatMessageTimestamp(),
            deliveryState: 'sending',
          };
          setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], optimisticMessage) }));
        }
      }

      // 3. Upload all files concurrently
      let uploadResults: Array<{ url: string, mimeType: string | null, sizeBytes: number | null, thumbnailUrl: string | null }> = [];
      try {
        if (isMultiFile) {
          const uploadPromises = allFiles.map(file => uploadChatMedia(accessToken, file));
          const rawResults = await Promise.all(uploadPromises);
          uploadResults = rawResults.map(res => ({
            url: res.url ?? '',
            mimeType: res.mimeType ?? null,
            sizeBytes: res.sizeBytes ?? null,
            thumbnailUrl: res.thumbnailUrl ?? null
          }));

          // Cleanup blob URLs
          queueMicrotask(() => {
            localPreviewUrls.forEach(url => URL.revokeObjectURL(url));
          });
        }
      } catch (uploadError) {
        console.error('[ChatPage.send] Multi-upload failed', uploadError);
        // Mark the optimistic message as failed so it doesn't hang in "Sending..."
        setMessagesByConversation(prev => ({
          ...prev,
          [targetConversationId]: markLocalMessageFailed(prev[targetConversationId] ?? [], clientMessageId)
        }));
        return;
      }

      // 4. Handle sticker case (override first media if needed)
      if (draft.sticker && uploadResults.length === 0) {
        const sUrl = draft.sticker.url || `sticker://${encodeURIComponent(draft.sticker.id)}`;
        const isUrlSticker = Boolean(draft.sticker.url);

        uploadResults = [{
          url: sUrl,
          mimeType: isUrlSticker ? 'image/webp' : 'application/x-chat-sticker',
          sizeBytes: 0,
          thumbnailUrl: null
        }];
      }

      // 5. Send logic
      // Case A: Text only (no files, no sticker)
      if (uploadResults.length === 0) {
        const payload: any = {
          conversationId: targetConversationId,
          content: content,
          clientMessageId,
          messageType: toSocketMessageType('text'),
        };

        if (replyTo) {
          payload.replyToMessageId = replyTo.id;
        }

        const optimisticTextMessage: ChatMessage = {
          id: clientMessageId,
          clientMessageId,
          conversationId: targetConversationId,
          sender: 'me',
          senderId: user.id,
          type: 'text',
          isLocal: false,
          text: content,
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sending',
          replyTo: replyTo,
        };
        console.log('[ChatPage.send] Optimistic message replyTo:', optimisticTextMessage.replyTo)
        setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], optimisticTextMessage) }));
        updateConversationAfterMessage(targetConversationId, optimisticTextMessage, true);

        const ack = await emitSendMessage(payload);
        if (ack?.event === 'message.sent' && ack?.data) {
          const serverMessage = { ...mapRawMessage(ack.data, user.id), clientMessageId, deliveryState: 'sent' as const, replyTo: replyTo };
          setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], serverMessage) }));
          updateConversationAfterMessage(targetConversationId, serverMessage, true);
        } else {
          try {
            const restMessage = await sendMessageViaRest(accessToken, {
              ...payload,
              messageType: payload.messageType
            });
            if (restMessage?.id) {
              const mapped = { ...mapRawMessage(restMessage, user.id), clientMessageId, deliveryState: 'sent' as const, replyTo: replyTo };
              setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], mapped) }));
              updateConversationAfterMessage(targetConversationId, mapped, true);
            }
          } catch (e) {
            setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: markLocalMessageFailed(prev[targetConversationId] ?? [], clientMessageId) }));
          }
        }
        return;
      }

      // Case B: Files/Images/Stickers (Loop for each)
      // The backend explicitly rejects "attachments" property (Error 400), 
      // so we MUST send each file as an individual message.

      for (let i = 0; i < uploadResults.length; i++) {
        const res = uploadResults[i];
        const resClientMessageId = i === 0 ? clientMessageId : generateUUID();

        const file = allFiles[i];
        const actualExt = file ? file.name.split('.').pop()?.toLowerCase() || '' : '';
        const isDoc = ['docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt', 'pdf'].includes(actualExt);
        const isVideo = res.mimeType?.startsWith('video/') || ['mp4', 'mov', 'webm', 'm4v', '3gp', 'mkv'].includes(actualExt);
        const resTypeStr = isDoc ? 'file' : (res.mimeType?.startsWith('image/') ? 'image' : (isVideo ? 'video' : (res.mimeType === 'application/x-chat-sticker' ? 'sticker' : 'file')));

        // Use original filename as content for 'file' or 'image' type messages if no other text is provided.
        const resContent = (i === 0 && content.trim().length > 0) ? content : (file ? file.name : "");

        const payload: any = {
          conversationId: targetConversationId,
          content: resContent,
          clientMessageId: resClientMessageId,
          messageType: toSocketMessageType(resTypeStr as any),
          mediaUrl: res.url,
          mediaThumbnailUrl: res.thumbnailUrl,
          mediaMimeType: isDoc ? (allFiles[i].type || 'application/octet-stream') : res.mimeType,
          mediaSizeBytes: res.sizeBytes,
        };

        if (replyTo && i === 0) {
          payload.replyToMessageId = replyTo.id;
        }

        const optimisticMessage: ChatMessage = {
          id: resClientMessageId,
          clientMessageId: resClientMessageId,
          conversationId: targetConversationId,
          sender: 'me',
          senderId: user.id,
          type: resTypeStr as any,
          isLocal: false,
          text: resContent,
          mediaUrl: res.url,
          mediaThumbnailUrl: res.thumbnailUrl,
          mediaMimeType: res.mimeType,
          mediaSizeBytes: res.sizeBytes,
          createdAt: new Date().toISOString(),
          // We keep attachments in local state only for the UI to potentially group them
          attachments: [{
            url: res.url,
            name: allFiles[i]?.name || "Tệp",
            mimeType: res.mimeType,
            sizeBytes: res.sizeBytes,
            thumbnailUrl: res.thumbnailUrl
          }],
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sending',
          replyTo: i === 0 ? replyTo : null,
        };

        setMessagesByConversation(prev => ({
          ...prev,
          [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], optimisticMessage)
        }));
        updateConversationAfterMessage(targetConversationId, optimisticMessage, true);

        // Send a message using socket, then fallback to REST if needed
        const ack = await emitSendMessage(payload);
        if (ack?.event === 'message.sent' && ack?.data) {
          const serverMessage = {
            ...mapRawMessage(ack.data, user.id),
            clientMessageId: resClientMessageId,
            deliveryState: 'sent' as const,
            replyTo: i === 0 ? replyTo : null
          };
          setMessagesByConversation(prev => ({
            ...prev,
            [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], serverMessage)
          }));
          updateConversationAfterMessage(targetConversationId, serverMessage, true);
        } else {
          try {
            const restMessage = await sendMessageViaRest(accessToken, {
              ...payload,
              messageType: payload.messageType as any
            });
            if (restMessage?.id) {
              const mapped = {
                ...mapRawMessage(restMessage, user.id),
                clientMessageId: resClientMessageId,
                deliveryState: 'sent' as const,
                replyTo: i === 0 ? replyTo : null
              };
              setMessagesByConversation(prev => ({
                ...prev,
                [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], mapped)
              }));
              updateConversationAfterMessage(targetConversationId, mapped, true);
            }
          } catch (e) {
            setMessagesByConversation(prev => ({
              ...prev,
              [targetConversationId]: markLocalMessageFailed(prev[targetConversationId] ?? [], resClientMessageId)
            }));
          }
        }
      }
    },
    [accessToken, emitSendMessage, isRestrictedMode, routedConversationId, selectedConversationId, updateConversationAfterMessage, user],
  )

  const handleSendPoll = useCallback(
    async (poll: PollMetadata) => {
      const conversationId = selectedConversationIdRef.current || selectedConversationId || routedConversationId
      if (!conversationId || !user || !accessToken) return

      const clientMessageId = generateUUID()
      const optimisticMessage: ChatMessage = {
        id: clientMessageId,
        clientMessageId,
        conversationId,
        sender: 'me',
        senderId: user.id,
        type: 'poll',
        isLocal: false,
        text: `📊 Bình chọn: ${poll.question}`,
        pollData: poll,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sending',
      }

      setMessagesByConversation(prev => ({
        ...prev,
        [conversationId]: upsertMessage(prev[conversationId] ?? [], optimisticMessage)
      }))
      updateConversationAfterMessage(conversationId, optimisticMessage, true)

      const pollPayload = {
        type: 'poll',
        question: poll.question,
        options: poll.options.map(opt => ({
          id: opt.id,
          label: opt.label,
          votes: []
        })),
        allowMultiple: poll.allowMultiple ?? false,
        allowAddOption: poll.allowAddOption ?? false,
        isAnonymous: poll.isAnonymous ?? false,
        expiresAt: poll.expiresAt,
        totalVotes: 0
      }

      const payload = {
        conversationId,
        messageType: 'TEXT',
        content: JSON.stringify(pollPayload),
        clientMessageId,
      }

      const ack = await emitSendMessage(payload as any)
      if (ack?.event === 'message.sent' && ack?.data) {
        // ... (existing logic)
        const serverMessage = { ...mapRawMessage(ack.data, user.id), clientMessageId, deliveryState: 'sent' as const }
        setMessagesByConversation(prev => ({ ...prev, [conversationId]: upsertMessage(prev[conversationId] ?? [], serverMessage) }))
      } else {
        // Fallback to REST 
        try {
          const restMessage = await sendMessageViaRest(accessToken, payload as any)
          if (restMessage?.id) {
            const mapped = { ...mapRawMessage(restMessage, user.id), clientMessageId, deliveryState: 'sent' as const }
            setMessagesByConversation(prev => ({ ...prev, [conversationId]: upsertMessage(prev[conversationId] ?? [], mapped) }))
          }
        } catch (err) {
          console.error('[ChatPage.handleSendPoll] Failed to send poll via REST fallback', err)
          setMessagesByConversation(prev => ({ ...prev, [conversationId]: markLocalMessageFailed(prev[conversationId] ?? [], clientMessageId) }))
        }
      }
    },
    [accessToken, emitSendMessage, routedConversationId, selectedConversationId, updateConversationAfterMessage, upsertMessage, user]
  )

  const handleVotePoll = useCallback(
    async (messageId: string, optionId: string) => {
      const conversationId = selectedConversationIdRef.current || selectedConversationId || routedConversationId
      if (!conversationId || !user || !accessToken) return

      const emoji = (optionId.startsWith('vote:') || optionId.startsWith('v:')) 
        ? optionId 
        : `vote:${optionId}`

      try {
        // Use existing addReaction logic
        await handleAddReaction(messageId, emoji as any)
      } catch (err) {
        console.error('[ChatPage.handleVotePoll] Failed to sync vote via reaction', err)
      }
    },
    [accessToken, handleAddReaction, routedConversationId, selectedConversationId, user]
  )

  const handleSearchConversation = useCallback(
    async (conversationId: string, keyword: string) => {
      if (!accessToken || !user) {
        return { messages: [] as ChatMessage[], files: [] as ChatMessage[] }
      }

      const normalizedKeyword = keyword.trim().toLowerCase()
      const localConversationMessages = messagesByConversation[conversationId] ?? []

      const localMessages = localConversationMessages.filter((message) => {
        if (message.type === 'file') {
          return false
        }

        if (!normalizedKeyword) {
          return true
        }

        return (
          message.text.toLowerCase().includes(normalizedKeyword) ||
          getFileNameFromUrl(message.mediaUrl ?? message.attachments?.[0]?.url).includes(normalizedKeyword)
        )
      })

      const localFiles = localConversationMessages.filter((message) => {
        if (message.type !== 'file') {
          return false
        }

        if (!normalizedKeyword) {
          return true
        }

        const messageText = message.text.toLowerCase()
        const fileName = getFileNameFromUrl(message.mediaUrl ?? message.attachments?.[0]?.url)
        return messageText.includes(normalizedKeyword) || fileName.includes(normalizedKeyword)
      })

      const [messageResult, fileResult] = await Promise.all([
        searchConversationMessages(accessToken, conversationId, {
          keyword: normalizedKeyword.length > 0 ? normalizedKeyword : undefined,
          limit: 40,
          offset: 0,
        }),
        searchConversationMessages(accessToken, conversationId, {
          messageType: 'FILE',
          limit: 60,
          offset: 0,
        }),
      ])

      const mappedMessages = messageResult.items
        .map((raw) => mapRawMessage(raw, user.id))
        .filter((message) => message.type !== 'file')

      const mappedFiles = fileResult.items
        .map((raw) => mapRawMessage(raw, user.id))
        .filter((message) => message.type === 'file')
        .filter((message) => {
          if (!normalizedKeyword) {
            return true
          }

          const messageText = message.text.toLowerCase()
          const fileName = getFileNameFromUrl(message.mediaUrl ?? message.attachments?.[0]?.url)
          return messageText.includes(normalizedKeyword) || fileName.includes(normalizedKeyword)
        })

      const mergedMessages = [...localMessages, ...mappedMessages]
      const mergedFiles = [...localFiles, ...mappedFiles]
      const dedupeById = (items: ChatMessage[]) => {
        const seen = new Set<string>()
        return items.filter((item) => {
          if (seen.has(item.id)) {
            return false
          }
          seen.add(item.id)
          return true
        })
      }

      return {
        messages: dedupeById(mergedMessages),
        files: dedupeById(mergedFiles),
      }
    },
    [accessToken, messagesByConversation, user],
  )

  const handleToggleSearchSidebar = useCallback(() => {
    // If there's a selected conversation, toggle in-conversation search
    // Otherwise, toggle global search
    if (selectedConversationIdRef.current) {
      setRightSidebarContent((prev) => (prev === 'search' ? null : 'search'))
    } else {
      setRightSidebarContent((prev) => (prev === 'global-search' ? null : 'global-search'))
    }
  }, [])

  const handleToggleInfoSidebar = useCallback(() => {
    setRightSidebarContent((prev) => (prev === 'info' ? null : 'info'))
  }, [])

  // Add keyboard shortcut Cmd/Ctrl+K for global search
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault()
        setRightSidebarContent((prev) => (prev === 'global-search' ? null : 'global-search'))
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  const handleEditGroupName = async (newName: string) => {
    if (!selectedConversationId || !accessToken) return

    // Permission check for group renaming
    if (selectedConversation?.isGroup) {
      const myMember = selectedConversation.members?.find(m => m.userId === user?.id)
      const role = String(myMember?.role || '').toUpperCase()
      const isModerator = role === 'ADMIN' || role === 'DEPUTY'
      if (!isModerator && !selectedConversation.allowMemberEditInfo) {
        toast.error('Bạn không có quyền thay đổi tên nhóm')
        return
      }
    }
    try {
      await renameGroupConversation(accessToken, selectedConversationId, newName)
      setConversations((prev) =>
        prev.map((c) =>
          c.id === selectedConversationId ? { ...c, name: newName } : c
        )
      )
      toast.success('Đổi tên nhóm thành công')

      const systemPayload = JSON.stringify({
        action: 'UPDATE_GROUP_INFO',
        actorId: user?.id,
        metadata: { newName }
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function' ? crypto.randomUUID() : String(Date.now()),
      })
    } catch (err) {
      toast.error('Có lỗi xảy ra khi đổi tên nhóm')
      console.error(err)
    }
  }

  const handleUpdateGroupAvatar = async (file: File) => {
    if (!selectedConversationId || !accessToken) return;

    try {
      // 0. Permission check
      const currentConv = conversations.find(c => c.id === selectedConversationId)
      if (currentConv?.isGroup) {
        const myMember = currentConv.members?.find(m => m.userId === user?.id)
        const role = String(myMember?.role || '').toUpperCase()
        const isModerator = role === 'ADMIN' || role === 'DEPUTY'
        if (!isModerator && !currentConv.allowMemberEditInfo) {
          toast.error('Bạn không có quyền thay đổi ảnh nhóm')
          return
        }
      }

      // 1. Upload new avatar
      const uploadRes = await uploadChatMedia(accessToken, file);
      const newAvatarUrl = uploadRes.url;

      // 2. Update conversation via API
      await updateGroupAvatar(accessToken, selectedConversationId, newAvatarUrl ?? '');

      // 3. Update local state
      setConversations((prev) =>
        prev.map((c) =>
          c.id === selectedConversationId ? { ...c, avatarUrl: newAvatarUrl } : c
        )
      );

      // 4. Emit SYSTEM notification
      const systemPayload = JSON.stringify({
        action: 'CHANGE_GROUP_AVATAR',
        actorId: user?.id,
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID(),
      });

      // 5. Success - Silent per user request
    } catch (err: any) {
      console.error('Failed to update group avatar:', err);
      toast.error(err.message || 'Cập nhật ảnh đại diện thất bại');
    }
  };

  const handleEditNickname = async (newNickname: string) => {
    if (!selectedConversationId || !accessToken) return
    const targetUserId = selectedConversation?.userId || selectedConversation?.participantUserIds?.[0]
    if (!targetUserId) {
      toast.error('Không tìm thấy người dùng để cập nhật tên gợi nhớ')
      return;
    }
    try {
      await setConversationNickname(accessToken, selectedConversationId, targetUserId, newNickname)
      setConversations((prev) =>
        prev.map((c) =>
          c.id === selectedConversationId ? { ...c, name: newNickname } : c
        )
      )
      toast.success('Cập nhật tên gợi nhớ thành công')
    } catch (err) {
      toast.error('Có lỗi xảy ra khi cập nhật tên gợi nhớ')
      console.error(err)
    }
  }

  const handleAddMembers = async (
    _groupName: string,
    _avatarUrl: string | null,
    selectedMemberIds: string[]
  ) => {
    if (!selectedConversationId || !user || !accessToken) return;
    setIsAddingMembers(true);
    try {
      await addMembersToConversation(accessToken, selectedConversationId, selectedMemberIds);

      // Emit structured SYSTEM message via socket to notify all members (real-time sync)
      const systemPayload = JSON.stringify({
        action: 'ADD_MEMBERS',
        actorId: user.id,
        targetMemberIds: selectedMemberIds
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID()
      });

      setIsAddMembersOpen(false);
    } catch (error) {
      console.error('Failed to add members:', error);
      toast.error('Thêm thành viên thất bại');
    } finally {
      setIsAddingMembers(false);
    }
  };

  const handleLeaveGroupClick = () => {
    if (!selectedConversationId || !user || !accessToken) return;
    setConfirmLeaveGroupOpen(true);
  };

  const doLeaveGroup = async () => {
    if (!selectedConversationId || !user || !accessToken) return;
    setConfirmLeaveGroupOpen(false);

    try {
      // Emit structured SYSTEM message via socket FIRST while we still have permissions
      const systemPayload = JSON.stringify({
        action: 'LEAVE_GROUP',
        actorId: user.id
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID()
      });

      // Then actually leave via API
      await leaveConversation(accessToken, selectedConversationId);

      setConversations((prev) => prev.filter(c => c.id !== selectedConversationId));
      navigate('/chat');
    } catch (error: any) {
      console.error('Failed to leave group:', error);
      if (error.message === 'Bạn cần chuyển quyền trước khi rời nhóm') {
        toast.error('Bạn cần chuyển quyền trước khi rời nhóm');
      } else {
        toast.error('Rời nhóm thất bại');
      }
    }
  };

  const handleUpdateGroupSettings = async (settings: Partial<any>) => {
    if (!selectedConversationId || !accessToken) return;
    try {
      await updateConversation(accessToken, selectedConversationId, settings);

      // Update local state
      setConversations(prev => prev.map(conv => {
        if (conv.id !== selectedConversationId) return conv;
        return { ...conv, ...settings };
      }));
      // Emit SYSTEM notification for realtime sync
      const systemPayload = JSON.stringify({
        action: 'UPDATE_GROUP_INFO',
        actorId: user?.id,
        metadata: settings
      });

      emitSendMessage({
        conversationId: selectedConversationId,
        messageType: 'system',
        content: systemPayload
      });
    } catch (error) {
      console.error('Failed to update group settings', error);
      toast.error('Không thể cập nhật cài đặt nhóm');
    }
  };

  const handleDisbandGroup = async () => {
    if (!selectedConversationId || !accessToken || !user) return;
    try {
      // Emit real-time signal via socket to all members
      const systemPayload = JSON.stringify({
        action: 'DISBAND_GROUP',
        actorId: user.id
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID()
      });

      // Add a small delay to ensure socket broadcast finishes before backend deletes the group
      await new Promise(resolve => setTimeout(resolve, 300));

      // Then call API
      await disbandConversation(accessToken, selectedConversationId);

      // Update local state
      setConversations(prev => prev.filter(conv => conv.id !== selectedConversationId));
      setSelectedConversationId('');
      setRightSidebarContent(null);
      navigate('/chat');
    } catch (err) {
      console.error('Không thể giải tán nhóm', err);
    }
  };

  const handleRemoveMember = async (targetUserId: string, _block?: boolean) => {
    if (!selectedConversationId || !user || !accessToken) return;

    try {
      const selectedConv = conversations.find(c => c.id === selectedConversationId);
      if (!selectedConv) return;

      const targetDisplayName = userMap[targetUserId]?.displayName || 'Thành viên';

      // Emit SYSTEM message for UI
      const systemPayload = JSON.stringify({
        action: 'REMOVE_MEMBER',
        actorId: user.id,
        targetMemberIds: [targetUserId]
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID()
      });

      // API Call
      await removeMember(accessToken, selectedConversationId, targetUserId);

      // Local State Update
      setConversations(prev => prev.map(c => {
        if (c.id === selectedConversationId) {
          return {
            ...c,
            memberCount: (c.memberCount || 1) - 1,
            participantUserIds: c.participantUserIds?.filter(id => id !== targetUserId),
            members: c.members?.filter(m => m.userId !== targetUserId)
          };
        }
        return c;
      }));

      toast.success(`Đã xóa ${targetDisplayName} khỏi nhóm`);
    } catch (error) {
      console.error('Failed to remove member:', error);
      toast.error('Không thể xóa thành viên');
    }
  };

  const handleUpdateMemberRole = async (targetUserId: string, role: string) => {
    if (!selectedConversationId || !accessToken) return;

    try {
      await updateMemberRole(accessToken, selectedConversationId, targetUserId, role);

      // Emit SYSTEM message if promoting
      if (role === 'DEPUTY') {
        const systemPayload = JSON.stringify({
          action: 'PROMOTE_ADMIN',
          actorId: user?.id,
          targetMemberIds: [targetUserId]
        });

        void emitSendMessage({
          conversationId: selectedConversationId,
          content: systemPayload,
          messageType: 'SYSTEM',
          clientMessageId: crypto.randomUUID()
        });
      }

      setConversations(prev => prev.map(c => {
        if (c.id === selectedConversationId) {
          return {
            ...c,
            members: c.members?.map(m => m.userId === targetUserId ? { ...m, role } : m)
          };
        }
        return c;
      }));

      const roleDisplay = role === 'DEPUTY' ? 'phó nhóm' : 'thành viên';
      toast.success(`Đã cập nhật vai trò thành ${roleDisplay}`);
    } catch (error) {
      console.error('Failed to update member role:', error);
      toast.error('Cập nhật vai trò thất bại');
    }
  };

  const handleTransferAndLeave = async (newOwnerId: string) => {
    if (!selectedConversationId || !accessToken || !user) return;

    try {
      // 1. Promote new owner
      await updateMemberRole(accessToken, selectedConversationId, newOwnerId, 'ADMIN');

      // 2. Emit TRANSFER_OWNERSHIP system message
      const transferPayload = JSON.stringify({
        action: 'TRANSFER_OWNERSHIP',
        actorId: user.id,
        targetMemberIds: [newOwnerId]
      });

      void emitSendMessage({
        conversationId: selectedConversationId,
        content: transferPayload,
        messageType: 'SYSTEM',
        clientMessageId: crypto.randomUUID()
      });

      // 3. Perform standard leave group logic
      await doLeaveGroup();
    } catch (error) {
      console.error('Failed to transfer ownership and leave:', error);
      toast.error('Chuyển quyền và rời nhóm thất bại');
    }
  };

  const sortedConversations = useMemo(() => {
    return [...conversations].map(conv => {
      const deleteTime = deletedTimestamps[conv.id];
      if (!deleteTime) return conv;

      const lastMsgTime = new Date(conv.lastMessageAt || conv.updatedAt || 0).getTime();

      // If the last message is OLDER than the deletion moment, hide it in the preview
      if (lastMsgTime <= deleteTime) {
        return {
          ...conv,
          lastMessage: t('chat.historyDeletedPreview') || 'Bạn đã xóa lịch sử trò chuyện',
          unreadCount: 0 // Hide unread count for deleted history conversations
        };
      }
      return conv;
    }).sort((a, b) => {
      // 1. PINNED SORTING
      const isPinnedA = !!pinnedConversationIds[a.id]
      const isPinnedB = !!pinnedConversationIds[b.id]
      if (isPinnedA && !isPinnedB) return -1
      if (!isPinnedA && isPinnedB) return 1

      // 2. RECENCY SORTING
      const timeA = new Date(a.lastMessageAt || a.updatedAt || 0).getTime()
      const timeB = new Date(b.lastMessageAt || b.updatedAt || 0).getTime()
      return timeB - timeA
    })
  }, [conversations, deletedTimestamps, pinnedConversationIds, t])

  const visibleConversations = useMemo(() => {
    return sortedConversations.map(conv => ({
      ...conv,
      isPinned: !!pinnedConversationIds[conv.id]
    })).filter((conv) => {
      const deletedAt = deletedTimestamps[conv.id];
      if (!deletedAt) return true;

      // ONLY use lastMessageAt (real message timestamp)
      if (!conv.lastMessageAt) return false;

      const lastMessageTime = new Date(conv.lastMessageAt).getTime();

      return lastMessageTime > deletedAt;
    });
  }, [sortedConversations, deletedTimestamps, pinnedConversationIds]);

  if (isBootstrapping || isLoadingConversations) {
    return (
      <div className={rightSidebarContent ? 'chat-layout' : 'chat-layout chat-layout-sidebar-closed'}>
        <section className='chat-list-panel chat-list-panel-skeleton'>
          <div className='panel-header'>
            <Skeleton className='skeleton-line skeleton-line-title' />
            <Skeleton className='skeleton-line' />
          </div>
          <div className='chat-list chat-list-skeleton'>
            {Array.from({ length: 6 }).map((_, index) => (
              <div className='chat-item-skeleton' key={`chat-skeleton-${index}`}>
                <Skeleton className='chat-item-avatar-skeleton' />
                <div className='chat-item-skeleton-copy'>
                  <Skeleton className='skeleton-line skeleton-line-title' />
                  <Skeleton className='skeleton-line' />
                </div>
              </div>
            ))}
          </div>
        </section>
        <section className='chat-window'>
          <div className='chat-window-header'>
            <Skeleton className='skeleton-line skeleton-line-title' />
          </div>
          <div className='chat-window-messages'>
            <Skeleton className='chat-message-skeleton me' />
            <Skeleton className='chat-message-skeleton' />
            <Skeleton className='chat-message-skeleton me' />
          </div>
        </section>
        {rightSidebarContent ? (
          <aside className='chat-side-panel'>
            <Skeleton className='skeleton-line skeleton-line-title' />
            <Skeleton className='skeleton-line' />
            <Card className='chat-side-card'>
              <Skeleton className='skeleton-line' />
              <Skeleton className='skeleton-line skeleton-line-short' />
            </Card>
          </aside>
        ) : null}
      </div>
    )
  }

  const isSidebarOpen = rightSidebarContent && (selectedConversation || rightSidebarContent === 'global-search')

  return (
    <div className={isSidebarOpen ? 'chat-layout' : 'chat-layout chat-layout-sidebar-closed'}>
      <ChatList
        conversations={visibleConversations}
        friendResults={friendResults}
        activeConversationId={routedConversationId || selectedConversationId}
        onSearchFriends={handleSearchFriends}
        onOpenFriendChat={handleOpenFriendChat}
        onSelectConversation={handleSelectConversation}
        onCreateGroupClick={handleOpenCreateGroupModal}
      />
      <ChatWindow
        conversation={selectedConversation}
        messages={selectedMessages}
        isLoadingMessages={isLoadingMessages}
        onLoadConversationMessages={handleLoadConversationMessages}
        onSend={handleSend}
        onToggleSearchSidebar={handleToggleSearchSidebar}
        onToggleInfoSidebar={handleToggleInfoSidebar}
        rightSidebarContent={rightSidebarContent}
        jumpToMessageId={jumpToMessageId}
        onJumpToMessageHandled={() => setJumpToMessageId(null)}
        onOpenUserProfile={handleOpenUserProfile}
        isRestrictedMode={isRestrictedMode}
        peerLastReadSeq={(routedConversationId || selectedConversationId)
          ? peerLastReadByConversation[routedConversationId || selectedConversationId]
          : undefined}
        reactionStatesByMessage={reactionStatesByMessage}
        onAddReaction={handleAddReaction}
        onRemoveReaction={handleRemoveReaction}
        pinnedMessages={selectedConversationId ? pinnedMessages[selectedConversationId] : []}
        onUnpinMessage={(id) => handleTogglePinMessage(id, selectedConversationId!)}
        starredMessageIds={starredMessageIds}
        recalledMessageIds={recalledMessageIds}
        deletedMessageIds={deletedMessageIds}
        currentUserId={user?.id}
        selectedMessageIds={selectedMessageIds}
        isMultiSelectMode={isMultiSelectMode}
        onToggleMessageSelection={toggleMessageIdInList}
        onClearMultiSelectMode={handleClearMultiSelectMode}
        onMessageContextMenuAction={handleMessageContextMenuAction}
        onVotePoll={handleVotePoll}
        onInitiateCall={handleInitiateCall}
        members={selectedConversation?.members || []}
      />

      <CreateGroupModal
        isOpen={isCreateGroupOpen}
        friends={friendsDirectory}
        isSubmitting={isCreatingGroup}
        onClose={() => setIsCreateGroupOpen(false)}
        onCreate={handleCreateGroup}
        initialMemberIds={preselectedMemberIds}
      />

      <CreateGroupModal
        isOpen={isAddMembersOpen}
        friends={friendsDirectory}
        mode="add-members"
        isSubmitting={isAddingMembers}
        onClose={() => setIsAddMembersOpen(false)}
        onCreate={handleAddMembers}
        initialMemberIds={selectedConversation?.participantUserIds ?? []}
        existingMemberIds={selectedConversation?.participantUserIds ?? []}
      />

      {rightSidebarContent && (selectedConversation || rightSidebarContent === 'global-search') ? (
        <aside className='chat-side-panel'>
          {rightSidebarContent === 'search' && selectedConversation ? (
            <SearchMessagesPanel
              conversation={selectedConversation}
              onSearchConversation={handleSearchConversation}
              onSelectMessage={(messageId) => setJumpToMessageId(messageId)}
            />
          ) : null}

          {rightSidebarContent === 'global-search' ? (
            <SearchGlobalPanel
              accessToken={accessToken ?? undefined}
              onSelectMessage={handleGlobalSearchSelectMessage}
              onSelectConversation={handleGlobalSearchSelectConversation}
              onSelectUser={handleGlobalSearchSelectUser}
              onClose={() => setRightSidebarContent(null)}
            />
          ) : null}

          {rightSidebarContent === 'info' && selectedConversation ? (
            <>
              <ConversationInfo
                  conversation={selectedConversation}
                  messages={selectedMessages}
                  onAddMembersClick={() => setIsAddMembersOpen(true)}
                  onDeleteHistoryClick={() => setConfirmDeleteHistoryId(selectedConversationId || routedConversationId)}
                  onLeaveGroupClick={handleLeaveGroupClick}
                  onCreateGroupClick={handleCreateGroupFromDirect}
                  onEditGroupName={() => {
                    setEditConversationNameMode('group')
                    setIsEditConversationNameOpen(true)
                  }}
                  onEditNickname={() => {
                    setEditConversationNameMode('nickname')
                    setIsEditConversationNameOpen(true)
                  }}
                  onTogglePinConversation={() => handleTogglePinConversation(selectedConversation.id)}
                  onRemoveMember={handleRemoveMember}
                  onUpdateMemberRole={handleUpdateMemberRole}
                  onTransferOwnerAndLeave={handleTransferAndLeave}
                  onUpdateGroupAvatar={handleUpdateGroupAvatar}
                  onUpdateGroupSettings={handleUpdateGroupSettings}
                  onDisbandGroup={handleDisbandGroup}
                  onJumpToMessage={setJumpToMessageId}
                  onSendPoll={handleSendPoll}
                  friends={friendsDirectory}
                  currentUserId={user?.id}
                />
            </>
          ) : null}
        </aside>
      ) : null}

      <MessageShareModal
        isOpen={Boolean(shareModalMessage)}
        message={shareModalMessage}
        friends={friendsDirectory}
        isSubmitting={isShareSubmitting}
        onClose={() => {
          if (!isShareSubmitting) {
            setShareModalMessage(null)
          }
        }}
        onShare={handleShareMessage}
      />

      <EditConversationNameModal
        isOpen={isEditConversationNameOpen}
        mode={editConversationNameMode}
        defaultValue={selectedConversation?.name || ''}
        avatarUrl={selectedConversation?.avatarUrl}
        conversationName={selectedConversation?.name}
        onClose={() => setIsEditConversationNameOpen(false)}
        onSubmit={editConversationNameMode === 'group' ? handleEditGroupName : handleEditNickname}
      />

      <Modal
        isOpen={!!confirmDeleteHistoryId}
        onClose={() => setConfirmDeleteHistoryId(null)}
        title={t('chat.confirmDeleteHistoryTitle')}
        variant="confirm"
        footer={
          <div className="flex gap-3 justify-end w-full">
            <button className="btn-zalo-secondary" onClick={() => setConfirmDeleteHistoryId(null)}>
              {t('common.no')}
            </button>
            <button className="btn-zalo-danger" onClick={() => confirmDeleteHistoryId && handleDeleteHistory(confirmDeleteHistoryId)}>
              {t('common.delete')}
            </button>
          </div>
        }
      >
        {t('chat.confirmDeleteHistoryContent')}
      </Modal>

      <Modal
        isOpen={confirmLeaveGroupOpen}
        onClose={() => setConfirmLeaveGroupOpen(false)}
        title="Xác nhận"
        variant="confirm"
        footer={
          <div className="flex gap-3 justify-end w-full">
            <button className="btn-zalo-secondary" onClick={() => setConfirmLeaveGroupOpen(false)}>
              Không
            </button>
            <button className="btn-zalo-danger" onClick={doLeaveGroup}>
              Rời nhóm
            </button>
          </div>
        }
      >
        Bạn có chắc chắn muốn rời khỏi nhóm này không?
      </Modal>

      <UserProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        userId={selectedProfileUserId}
        accessToken={accessToken}
        initialUser={selectedProfileUserId ? userMap[selectedProfileUserId] : undefined}
        onMessage={handleOpenFriendChat}
      />

      <CallModal
        isOpen={callState.isOpen}
        type={callState.type}
        status={callState.status}
        peerName={callState.peerId ? (userMap[callState.peerId]?.displayName || 'Người dùng') : (selectedConversation?.name || 'Người dùng')}
        peerAvatar={callState.peerId ? userMap[callState.peerId]?.avatarUrl : selectedConversation?.avatarUrl}
        localStream={callState.localStream}
        remoteStream={callState.remoteStream}
        isMicOn={callState.isMicOn}
        isCameraOn={callState.isCameraOn}
        isRemoteCameraOn={callState.isRemoteCameraOn}
        hasRemoteDescription={callState.hasRemoteDescription}
        onEnd={handleEndCall}
        onAnswer={handleAnswerCall}
        onToggleMic={handleToggleMic}
        onToggleCamera={handleToggleCamera}
      />

      {/* INCOMING GROUP CALL NOTIFICATION — shown to non-callers */}
      {incomingGroupCall && !isInGroupCall && (
        <IncomingGroupCallBanner
          info={incomingGroupCall}
          onJoin={() => joinGroupCall(incomingGroupCall)}
          onDecline={declineGroupCall}
        />
      )}

      {/* GROUP CALL MODAL — independent of 1-1 CallModal */}
      {isInGroupCall && groupCallSnapshot && (
        <GroupCallModal
          isOpen={isInGroupCall}
          snapshot={groupCallSnapshot}
          localUserName={user?.name ?? 'Bạn'}
          localUserAvatar={user?.avatarUrl ?? undefined}
          onLeave={handleLeaveGroupCall}
          onToggleMic={groupToggleMic}
          onToggleCamera={groupToggleCamera}
          elapsedSeconds={groupCallElapsed}
        />
      )}

      {/* Pinned Messages Logic Hooks */}
      <PinnedLogicHooks
        accessToken={accessToken}
        isBootstrapping={isBootstrapping}
        selectedConversationId={selectedConversationId}
        loadPinnedMessages={loadPinnedMessages}
        pinnedMessageIds={pinnedMessageIds}
        setPinnedMessageIds={setPinnedMessageIds}
        messagesByConversation={messagesByConversation}
        setPinnedMessages={setPinnedMessages}
        lastConvRef={lastConvRef}
      />
    </div>
  )
}

/**
 * Extracted hooks to avoid cluttering main component and ensure they are after declarations.
 */
function PinnedLogicHooks({
  accessToken, isBootstrapping, selectedConversationId, loadPinnedMessages,
  pinnedMessageIds, setPinnedMessageIds, messagesByConversation, setPinnedMessages,
  lastConvRef
}: any) {
  // ISOLATED PINNED FETCH (NO loadInbox call)
  useEffect(() => {
    if (!accessToken || isBootstrapping || !selectedConversationId) return

    // Avoid re-fetching same conversation (Double Guard)
    if (lastConvRef.current === selectedConversationId) return
    lastConvRef.current = selectedConversationId

    void loadPinnedMessages(selectedConversationId)
  }, [accessToken, isBootstrapping, selectedConversationId, loadPinnedMessages, lastConvRef])

  // Mapping Pinned IDs -> Message Objects (with placeholder support)
  useEffect(() => {
    if (!selectedConversationId) return

    const ids = pinnedMessageIds[selectedConversationId] || []
    const convMessages = messagesByConversation[selectedConversationId] || []

    const mapped = ids.map((id: string) => {
      const found = convMessages.find((m: any) => m.id === id)
      if (found) return found

      // Return placeholder for unloaded messages
      return {
        id,
        conversationId: selectedConversationId,
        content: 'Tin nhắn đã ghim',
        text: 'Tin nhắn đã ghim',
        type: 'text' as any,
        sender: 'system' as any,
        senderId: 'system',
        timestamp: '',
        deliveryState: 'sent' as any,
        isPlaceholder: true, // Custom flag for UI
      }
    })

    setPinnedMessages((prev: any) => ({
      ...prev,
      [selectedConversationId]: mapped,
    }))
  }, [messagesByConversation, pinnedMessageIds, selectedConversationId, setPinnedMessages])

  // Auto clean pinned IDs when messages are recalled
  useEffect(() => {
    if (!selectedConversationId) return
    const ids = pinnedMessageIds[selectedConversationId] || []
    const convMessages = messagesByConversation[selectedConversationId] || []

    const validIds = ids.filter((id: string) => {
      const msg = convMessages.find((m: any) => m.id === id)
      return msg ? !msg.isRecalled : true
    })

    if (validIds.length !== ids.length) {
      setPinnedMessageIds((prev: any) => ({
        ...prev,
        [selectedConversationId]: validIds,
      }))
    }
  }, [messagesByConversation, selectedConversationId, pinnedMessageIds, setPinnedMessageIds])

  return null;
}


