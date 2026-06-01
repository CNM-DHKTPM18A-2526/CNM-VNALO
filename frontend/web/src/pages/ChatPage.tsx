import { useEffect, useRef, useCallback, useState, useMemo } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { getSyncPolicy } from '../features/auth/auth.api'
import { ChatList } from '../features/chat/components/ChatList'
import { ConversationInfo } from '../features/chat/components/ConversationInfo'
import { SearchMessagesPanel } from '../features/chat/components/SearchMessagesPanel'
import { SearchGlobalPanel } from '../features/chat/components/SearchGlobalPanel'
import { MessageShareModal } from '../features/chat/components/MessageShareModal'
import { ChatWindow } from '../features/chat/components/ChatWindow'
import { UserProfileModal } from '../features/chat/components/UserProfileModal'
import { useGroupCall } from '../features/chat/components/GroupCallModal'
import { IncomingCallBanner } from '../features/chat/components/PremiumCallUI'
import type { MessageContextMenuAction } from '../features/chat/components/MessageContextMenu'
import {
  addMessageReaction,
  createGroupConversation,           // NEW
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
import type { WebRTCCallState } from '../features/chat/webrtcCallService'
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
import { formatMessage, renderSystemMessage, formatMessagePreview, formatMessageTimestamp, normalizeMessage, formatReactionSyncPreview, buildReactionSyncContent } from '../features/chat/utils/messageUtils'
import { useUserStore } from '../features/chat/context/UserStoreContext'

// Fallback toast object to prevent crashes if toast library is missing
const AI_PENDING_PROMPT_KEY = 'vnalo_ai_web_pending_prompt'
const AI_ASSISTANT_USER_ID = '__vnalo_ai__'

const toast = {
  success: (msg: string) => console.log('SUCCESS:', msg),
  error: (msg: string) => console.error('ERROR:', msg),
}

function sortMessages(messages: ChatMessage[]): ChatMessage[] {
  return [...messages].sort((left, right) => {
    // If serverSeq is missing (optimistic message), treat it as a very large number 
    // so it appears at the bottom of the list.
    const leftSeq = left.serverSeq ?? Number.MAX_SAFE_INTEGER
    const rightSeq = right.serverSeq ?? Number.MAX_SAFE_INTEGER

    if (leftSeq !== rightSeq) {
      return leftSeq - rightSeq
    }

    // Fallback to timestamp comparison if available
    const leftTime = new Date(left.timestamp).getTime()
    const rightTime = new Date(right.timestamp).getTime()
    if (leftTime !== rightTime) {
      return leftTime - rightTime
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
  _isModerator?: boolean
): string {
  return formatMessage(message, currentUserId, getDisplayName)
}




function formatConversationPreview(
  senderName: string | null | undefined,
  message: ChatMessage | string,
  currentUserId: string,
  getDisplayName: (id: string) => string,
  isModerator?: boolean
): string {
  if (typeof message !== 'string') {
    const txt = (message.text || '').trim();
    if (message.type === 'system' || (txt.startsWith('{') && txt.includes('"action":'))) {
      const reactionSyncPreview = formatReactionSyncPreview(txt, senderName)
      if (reactionSyncPreview) {
        return reactionSyncPreview
      }

      return getConversationPreview(message, currentUserId, getDisplayName, isModerator)
    }
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
  const trimmedText = text.trim();
  if (trimmedText.startsWith('{') && trimmedText.includes('"action":')) {
    const reactionSyncPreview = formatReactionSyncPreview(trimmedText, senderName)
    if (reactionSyncPreview) {
      return reactionSyncPreview
    }

    return renderSystemMessage(trimmedText, currentUserId, getDisplayName);
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
  if (!restricted || message.type === 'system') {
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

const isGenericDirectName = (value: string | undefined | null) => {
  const normalized = String(value ?? '').trim()
  const isGenericLabel = !normalized || normalized === 'Người dùng' || /^Người dùng\s+[0-9a-f]{6,}$/i.test(normalized)
  const isRawId = /^[0-9a-f]{24}$/i.test(normalized) // Common MongoDB ID format
  return isGenericLabel || isRawId
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
  const messagesByConversationRef = useRef<Record<string, ChatMessage[]>>(messagesByConversation)
  const [selectedConversationId, setSelectedConversationId] = useState('')
  const [isLoadingConversations, setIsLoadingConversations] = useState(false)
  const [isLoadingMessages, setIsLoadingMessages] = useState(false)
  const [isRestrictedMode, setIsRestrictedMode] = useState(false)
  const [peerLastReadByConversation, setPeerLastReadByConversation] = useState<Record<string, number>>({})
  const [reactionStatesByMessage, setReactionStatesByMessage] = useState<Record<string, MessageReactionState>>({})
  const [friendResults, setFriendResults] = useState<UserLookupResult[]>([])
  const [friendsDirectory, setFriendsDirectory] = useState<Friend[]>([])
  const [isSocketConnected, setIsSocketConnected] = useState(false)
  const [, setIsSocketInitialized] = useState(false)
  const [rightSidebarContent, setRightSidebarContent] = useState<'info' | 'search' | 'global-search' | null>(() => {
    const saved = localStorage.getItem('vnalo_chat_sidebar_content')
    if (!saved || saved === 'null' || saved === 'none') return null
    if (['info', 'search', 'global-search'].includes(saved)) return saved as any
    return null
  })

  useEffect(() => {
    messagesByConversationRef.current = messagesByConversation
  }, [messagesByConversation])

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
  const [leaveGroupSilently, setLeaveGroupSilently] = useState(false)
  const [selectedProfileUserId, setSelectedProfileUserId] = useState<string | null>(null)
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false)

  // CALL STATE
  const [callState, setCallState] = useState<WebRTCCallState & { isOpen: boolean, type: 'audio' | 'video', direction: 'outgoing' | 'incoming', status: 'connecting' | 'connected' | 'failed', peerId?: string, conversationId?: string, callId?: string }>({
    pc: null,
    localStream: null,
    remoteStream: null,
    isConnected: false,
    isEnded: false,
    isMicOn: true,
    isCameraOn: true,
    isRemoteMicOn: true,
    isRemoteCameraOn: true,
    pendingCandidates: [],
    hasRemoteDescription: false,
    error: null,
    isOpen: false,
    type: 'audio',
    direction: 'outgoing',
    status: 'connecting',
  })

  // WEBRTC SERVICE REF


  // SYNC CALL STATE TO REF FOR LISTENERS
  const callStateRef = useRef(callState)
  const currentCallIdRef = useRef<string | null>(null) // Immediate sync ref for signal routing
  useEffect(() => {
    callStateRef.current = callState
    currentCallIdRef.current = callState.callId || null
  }, [callState])

  // Initialize call service with state syncing


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
  const pendingMetadataFetches = useRef<Set<string>>(new Set())
  const processedMessageIds = useRef<Set<string>>(new Set())
  const lastPinnedSyncTimeRef = useRef<Record<string, number>>({})

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

  const myDocumentsConversation = useMemo<ConversationSummary>(() => {
    // Try to get last message from local storage for preview
    let lastMsgText = 'Lưu và đồng bộ dữ liệu giữa các thiết bị';
    let lastTime = new Date().toISOString();

    if (user?.id) {
      try {
        const key = `vnalo_cloud_msgs_${user.id}`;
        const saved = localStorage.getItem(key);
        if (saved) {
          const msgs = JSON.parse(saved);
          if (Array.isArray(msgs) && msgs.length > 0) {
            // In handleSend we save newest at index 0
            const last = msgs[0];
            lastMsgText = last.text || (last.type === 'image' ? '[Hình ảnh]' : last.type === 'file' ? '[Tệp tin]' : lastMsgText);
            lastTime = last.createdAt || last.timestamp || lastTime;
          }
        }
      } catch (e) {
        console.warn('Failed to load cloud messages for preview', e);
      }
    }

    return {
      id: 'my-documents',
      isGroup: false,
      isCloud: true,
      name: 'My Documents',
      avatarUrl: null,
      lastMessage: lastMsgText,
      unreadCount: 0,
      participantUserIds: [],
      memberCount: 0,
      lastMessageAt: lastTime,
      updatedAt: lastTime,
    };
  }, [user?.id, messagesByConversation['my-documents']]); // Re-run when messages change

  const selectedConversation = useMemo(
    () => {
      const targetId = routedConversationId || selectedConversationId;
      if (targetId === 'my-documents') return myDocumentsConversation;
      return conversations.find((conversation) => conversation.id === targetId);
    },
    [conversations, routedConversationId, selectedConversationId, myDocumentsConversation],
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
  }, [(user ? user.id : "")])

  useEffect(() => {
    if (!user?.id) {
      return
    }

    persistDeletedMessageIds(user.id, deletedMessageIds)
  }, [deletedMessageIds, (user ? user.id : "")])

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
    (
      conversationId: string,
      message: ChatMessage,
      markAsReadNow: boolean,
      conversationMsgsOverride?: ChatMessage[],
      conversationSeed?: Partial<ConversationSummary>,
    ) => {
      const senderName =
        message.senderId === user?.id
          ? user?.name?.trim() || fallbackUserDisplayName(message.senderId)
          : userMapRef.current[message.senderId]?.displayName || fallbackUserDisplayName(message.senderId)
      const getName = (id: string) => {
        if (id === user?.id) return 'Bạn'
        return userMapRef.current[id]?.displayName || 'Người dùng'
      }

      const formattedPreview = formatConversationPreview(senderName, message, user?.id || '', getName)
      // Defensive: ensure formatted preview is never empty if original message has content

      setConversations((prev) => {
        const index = prev.findIndex((conversation) => conversation.id === conversationId)
        const next = [...prev]
        const currentTimestamp = message.createdAt || message.timestamp || new Date().toISOString()
        const current =
          index === -1
            ? {
              id: conversationId,
              isCloud: conversationId === 'my-documents' || conversationSeed?.isCloud,
              name: conversationId === 'my-documents' ? 'My Documents' : (conversationSeed?.name || senderName || fallbackUserDisplayName(message.senderId)),
              avatarUrl: conversationId === 'my-documents' ? null : (conversationSeed?.avatarUrl ?? null),
              isGroup: conversationSeed?.isGroup,
              isStranger: conversationSeed?.isStranger,
              participantUserIds: conversationSeed?.participantUserIds ?? [message.senderId],
              unreadCount: 0,
              lastMessage: '',
              lastMessagePreview: '',
              updatedAt: currentTimestamp,
              lastMessageAt: currentTimestamp,
              lastMessageSeq: message.serverSeq,
            }
            : {
              ...next[index],
              ...(conversationSeed || {})
            };

        // If this is a NEW conversation entry (index === -1), 
        // verify it's not a "Kicked" system message for ourselves.
        // If it is, we don't want to re-add the conversation we just removed.
        if (index === -1 && message.type === 'system' && message.text) {
          try {
            const sys = JSON.parse(message.text);
            const isMeKicked = sys.action === 'REMOVE_MEMBER' &&
              sys.targetMemberIds?.some((id: any) => String(id) === String(user?.id));
            if (isMeKicked) {
              console.log('[ChatPage.updateConversationAfterMessage] Blocking re-add of kicked group');
              return prev;
            }
          } catch (e) { /* ignore */ }
        }

        let finalPreview = formattedPreview;

        // Defensive: if formatted preview is empty or looks suspicious, use direct formatting
        if (!finalPreview || finalPreview.trim() === '' || (finalPreview.startsWith('{') && finalPreview.includes('"action":'))) {
          console.log('[ChatPage.updateConversationAfterMessage] Defensive formatting applied for message:', message.id);
          finalPreview = formatMessagePreview(message.text || '', message.senderId === user?.id, message.type, senderName || undefined, message.attachments);
        }

        // Inspect last few messages for grouping in sidebar
        const conversationMsgs = conversationMsgsOverride ?? messagesByConversationRef.current[conversationId] ?? [];
        if (message.text && message.text.includes('UPDATE_MESSAGE_REACTIONS')) {
          const reactionPreview = formatReactionSyncPreview(
            message.text,
            message.senderId === user?.id ? 'Bạn' : senderName,
          )
          if (reactionPreview) {
            finalPreview = reactionPreview
          } else {
            try {
              const signal = JSON.parse(message.text)
              const reactedMessageId = String(signal.messageId ?? signal.message_id ?? '').trim()
              const reactedMessage = conversationMsgs.find((item) => item.id === reactedMessageId)
              if (reactedMessage?.type === 'poll' || signal.isPollVote === true || signal.pollVote === true) {
                const actorName = message.senderId === user?.id ? 'Bạn' : senderName
                finalPreview = `${actorName}: ${signal.type === 'REMOVE' ? 'Đã cập nhật bình chọn' : 'Đã bình chọn'}`
              }
            } catch {
              /* ignore malformed reaction sync payload */
            }
          }
        }

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
            const icon = groupType === 'image' ? '🖼️' : '📎';
            const label = groupType === 'image' ? 'hình ảnh' : 'tập tin';
            const prefix = message.senderId === user?.id ? 'Bạn: ' : (senderName ? `${senderName}: ` : '');
            finalPreview = `${prefix}${icon} ${count} ${label}`;
          }
        }

        const updatedConversation: ConversationSummary = {
          ...current,
          lastMessage: finalPreview,
          lastMessagePreview: finalPreview,
          lastMessageSenderId: message.senderId,
          lastMessageAt: currentTimestamp,
          updatedAt: currentTimestamp,
          lastMessageSeq: message.serverSeq ?? current.lastMessageSeq,
          unreadCount: markAsReadNow ? 0 : current.unreadCount + (message.senderId === user?.id ? 0 : 1),
        }

        if (index === -1) {
          return [updatedConversation, ...next]
        }

        next[index] = updatedConversation
        const [target] = next.splice(index, 1)
        return [target, ...next]
      })
    },
    [user ? user.id : '', user ? user.name : ''],
  )

  // PERIODIC SYNC (POLLING FALLBACK)
  const SYNC_INTERVAL_MS = 2000
  const lastSyncTimeRef = useRef<Record<string, number>>({})
  const pollingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Setup polling interval that runs on a timer
  const syncLatestMessages = useCallback(async (targetId?: string) => {
    const conversationId = targetId || selectedConversationIdRef.current
    if (!conversationId || !accessToken) return

    // Don't poll for conversations that are no longer in our list (ghost groups)
    if (!targetId && !conversationsRef.current.some(c => c.id === conversationId)) {
      return;
    }

    const now = Date.now()
    const lastSync = lastSyncTimeRef.current[conversationId] ?? 0
    if (!targetId && now - lastSync < SYNC_INTERVAL_MS) return
    lastSyncTimeRef.current[conversationId] = now

    try {
      console.log('[ChatPage.syncLatestMessages] fetching messages for', conversationId);
      const latest = await fetchMessages(accessToken, conversationId, true)
      if (!latest || latest.length === 0) return
      console.log('[ChatPage.syncLatestMessages] fetched', latest.length, 'messages, syncing pinned list too');
      // Refresh pinned messages after fetching new messages
      void syncPinnedMessages(conversationId);
      const newMessages: ChatMessage[] = []
      const recalledFromSync: Record<string, true> = {}
      let latestMessageForPreview: ChatMessage | null = null
      let hasServerChanges = false

      setMessagesByConversation((prev) => {
        const current = prev[conversationId] ?? []
        const result = [...current]
        const indexById = new Map(result.map((m, idx) => [m.id, idx]))

        for (const rawMsg of latest) {
          const mapped = applyRestrictedMessage(normalizeMessage(mapRawMessage(rawMsg, user?.id || '')), isRestrictedMode)
          if (mapped.isRecalled) {
            recalledFromSync[mapped.id] = true
          }

          const existingIndex = indexById.get(mapped.id)
          if (existingIndex === undefined) {
            processedMessageIds.current.add(mapped.id)
            result.push(mapped)
            newMessages.push(mapped)
            indexById.set(mapped.id, result.length - 1)
            hasServerChanges = true
            continue
          }

          const existing = result[existingIndex]
          const merged = {
            ...existing,
            ...mapped,
            // keep client-side id if server payload does not carry it
            clientMessageId: mapped.clientMessageId ?? existing.clientMessageId,
          }

          const isChanged =
            existing.text !== merged.text ||
            existing.type !== merged.type ||
            existing.isRecalled !== merged.isRecalled ||
            existing.mediaUrl !== merged.mediaUrl ||
            existing.mediaThumbnailUrl !== merged.mediaThumbnailUrl ||
            existing.mediaMimeType !== merged.mediaMimeType ||
            existing.mediaSizeBytes !== merged.mediaSizeBytes ||
            (existing.attachments?.length ?? 0) !== (merged.attachments?.length ?? 0)

          if (isChanged) {
            result[existingIndex] = merged
            hasServerChanges = true
          }
        }

        if (!hasServerChanges) {
          return prev
        }

        const sorted = sortMessages(dedupeMessages(result))
        latestMessageForPreview = sorted.at(-1) ?? null
        return { ...prev, [conversationId]: sorted }
      })

      if (Object.keys(recalledFromSync).length > 0) {
        setRecalledMessageIds((prev) => ({
          ...prev,
          ...recalledFromSync,
        }))
      }

      const previewMessage = latestMessageForPreview ?? newMessages[newMessages.length - 1] ?? null
      if (previewMessage) {
        updateConversationAfterMessage(conversationId, previewMessage, true)
      }
    } catch (error) {
      console.warn("[ChatPage] Polling sync failed:", error)
    }
  }, [accessToken, isRestrictedMode, updateConversationAfterMessage, (user ? user.id : "")])

  useEffect(() => {
    if (!isSocketConnected || !accessToken) {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
        pollingIntervalRef.current = null
      }
      return
    }
    void syncLatestMessages()
    pollingIntervalRef.current = setInterval(() => syncLatestMessages(), SYNC_INTERVAL_MS)
    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
        pollingIntervalRef.current = null
      }
    }
  }, [isSocketConnected, accessToken, syncLatestMessages])
  const toReactionState = useCallback(
    (rows: Array<{ userId: string; emoji: string }>): MessageReactionState => {
      const reactions = {} as MessageReactionMap

      for (const row of rows) {
        let reactionKey = EMOJI_TO_REACTION_KEY[row.emoji]

        // Handle poll votes (vote:/v: prefixes)
        if (!reactionKey && (row.emoji.startsWith('vote:') || row.emoji.startsWith('v:'))) {
          reactionKey = row.emoji as ReactionKey
        }

        if (!reactionKey) {
          continue
        }

        const current = reactions[reactionKey] ?? { count: 0, myCount: 0, userIds: [] }
        reactions[reactionKey] = {
          count: current.count + 1,
          myCount: current.myCount + (row.userId === user?.id ? 1 : 0),
          userIds: [...current.userIds, row.userId],
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
    [(user ? user.id : "")],
  )

  const syncMessageReaction = useCallback(
    async (messageId: string): Promise<void> => {
      // Relaxed validation: ensure we have a token and an ID, but don't strictly enforce UUID 
      // if it might be a temporary or cross-platform ID format that still maps to the server.
      if (!accessToken || !messageId) {
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

  const applyReactionSocketEvent = useCallback(
    (messageId: string, emoji: string | undefined, actorId: string | undefined, kind: 'added' | 'removed') => {
      const normalizedEmoji = String(emoji ?? '').trim()
      const normalizedActorId = String(actorId ?? '').trim()

      if (!messageId || !normalizedEmoji || !normalizedActorId) {
        return
      }

      let reactionKey = EMOJI_TO_REACTION_KEY[normalizedEmoji]
      if (!reactionKey && (normalizedEmoji.startsWith('vote:') || normalizedEmoji.startsWith('v:'))) {
        reactionKey = normalizedEmoji as ReactionKey
      }

      if (!reactionKey) {
        return
      }

      setReactionStatesByMessage((prev) => {
        const current = prev[messageId] ?? { reactions: {} as MessageReactionMap }
        const currentReaction = current.reactions[reactionKey] ?? { count: 0, myCount: 0, userIds: [] }
        const hasUser = currentReaction.userIds.includes(normalizedActorId)

        const nextReactions = { ...current.reactions }
        let nextReaction = { ...currentReaction }

        if (kind === 'added') {
          if (!hasUser) {
            nextReaction = {
              ...nextReaction,
              count: nextReaction.count + 1,
              userIds: [...nextReaction.userIds, normalizedActorId],
            }
          }

          if (normalizedActorId === user?.id) {
            nextReaction = {
              ...nextReaction,
              myCount: 1,
            }
          }
        } else if (hasUser) {
          nextReaction = {
            ...nextReaction,
            count: Math.max(0, nextReaction.count - 1),
            myCount: normalizedActorId === user?.id ? 0 : nextReaction.myCount,
            userIds: nextReaction.userIds.filter((id) => id !== normalizedActorId),
          }
        }

        if (nextReaction.count <= 0 && nextReaction.myCount <= 0 && nextReaction.userIds.length === 0) {
          delete nextReactions[reactionKey]
        } else {
          nextReactions[reactionKey] = nextReaction
        }

        return {
          ...prev,
          [messageId]: {
            ...current,
            reactions: nextReactions,
            lastUsedReaction: normalizedActorId === user?.id ? reactionKey : current.lastUsedReaction,
          },
        }
      })

      window.setTimeout(() => {
        void syncMessageReaction(messageId)
      }, 250)
    },
    [syncMessageReaction, (user ? user.id : "")],
  )

  const resolveReactionActorId = useCallback((payload: any): string | undefined => {
    return String(
      payload?.actorId ??
      payload?.userId ??
      payload?.user_id ??
      payload?.senderId ??
      payload?.sender_id ??
      ''
    ).trim() || undefined
  }, [])

  const resolveReactionEmoji = useCallback((payload: any): string | undefined => {
    return String(
      payload?.emoji ??
      payload?.reaction ??
      payload?.reactionKey ??
      payload?.reaction_key ??
      ''
    ).trim() || undefined
  }, [])

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
        console.log('[ChatPage.loadPinnedMessages] fetching pinned messages for', conversationId, 'accessToken present:', !!accessToken)
        const pins = await fetchPinnedMessages(accessToken, conversationId)
        console.log('[ChatPage.loadPinnedMessages] fetched pins response:', pins);
        const ids = pins.map(p => p.messageId).filter(Boolean) as string[]
        console.log('[ChatPage.loadPinnedMessages] fetched pins:', { conversationId, count: ids.length, ids })

        // Update pinned id list first
        setPinnedMessageIds((prev) => ({
          ...prev,
          [conversationId]: ids,
        }))

        // Try to resolve message objects from current cache
        let resolved: ChatMessage[] = (messagesByConversationRef.current[conversationId] ?? []).filter(m => ids.includes(m.id))
        const missingIds = ids.filter(id => !resolved.find(m => m.id === id))

        if (missingIds.length > 0) {
          console.log('[ChatPage.loadPinnedMessages] missing pinned message objects, will fetch conversation messages', { conversationId, missingIds })
          try {
            const rawMessages = await fetchMessages(accessToken, conversationId, true)
            const mapped = rawMessages.map(r => applyRestrictedMessage(normalizeMessage(mapRawMessage(r, user?.id || '')), isRestrictedMode))

            // Merge into messagesByConversation cache
            setMessagesByConversation((prev) => {
              const current = prev[conversationId] ?? []
              const next = [...current]
              for (const m of mapped) {
                const idx = next.findIndex(x => (x.id && x.id === m.id) || (m.clientMessageId && x.clientMessageId === m.clientMessageId))
                if (idx === -1) {
                  next.push(m)
                } else {
                  next[idx] = mergeMessage(next[idx], m)
                }
              }
              return { ...prev, [conversationId]: sortMessages(dedupeMessages(next)) }
            })

            // Re-resolve from freshly fetched 'mapped' list (don't rely on ref synchronization)
            resolved = mapped.filter(m => ids.includes(m.id))
            console.log('[ChatPage.loadPinnedMessages] after fetch resolved pinned objects count:', resolved.length)
          } catch (err) {
            console.warn('[ChatPage.loadPinnedMessages] Failed to fetch conversation messages for pinned resolution', { conversationId, err })
          }
        }

        // Populate pinnedMessages map with message objects we have
        setPinnedMessages((prev) => ({
          ...prev,
          [conversationId]: ids.map(id => (resolved.find(m => m.id === id) as ChatMessage | undefined)).filter(Boolean) as ChatMessage[],
        }))

      } catch (error) {
        console.warn('[ChatPage.loadPinnedMessages] Failed to fetch pinned messages', { conversationId, error })
      } finally {
        loadingPinnedRef.current[conversationId] = false
      }
    },
    [accessToken, isRestrictedMode, user?.id],
  )



  const syncPinnedMessages = loadPinnedMessages

  const syncConversationMetadata = useCallback(async (conversationId: string) => {
    if (!accessToken) return;
    try {
      const data = await fetchConversation(accessToken, conversationId) as any;
      if (!data) return;

      setConversations(prev => prev.map(c => {
        if (c.id !== conversationId) return c;
        // Merge settings from various possible backend field names
        const settings = {
          name: data.isGroup || data.type === 'GROUP' ? (data.title || data.name || c.name) : c.name,
          avatarUrl: data.avatarUrl || data.avatar_url || c.avatarUrl,
          onlyAdminCanPost: Boolean(data.onlyAdminCanPost ?? data.only_admin_can_post ?? c.onlyAdminCanPost),
          allowMemberPin: Boolean(data.allowMemberPin ?? data.allow_member_pin ?? c.allowMemberPin),
          allowMemberEditInfo: Boolean(data.allowMemberEditInfo ?? data.allow_member_edit_info ?? c.allowMemberEditInfo),
          members: data.members || c.members,
          memberCount: (data.members || []).length || c.memberCount,
          updatedAt: new Date().toISOString(),
          _syncVersion: Date.now()
        };
        return { ...c, ...settings };
      }));
      console.log('[ChatPage] 🔄 Metadata refreshed for', conversationId);
    } catch (e: any) {
      // If 404 (Deleted) or 403 (Kicked/Forbidden)
      if (e.response?.status === 404 || e.response?.status === 403) {
        console.log('[ChatPage] 🚪 Access lost (Kicked or Deleted), cleaning up:', conversationId);
        setConversations(prev => prev.filter(c => c.id !== conversationId));
        if (selectedConversationIdRef.current === conversationId) {
          navigate('/chat');
        }
      } else {
        console.warn('[ChatPage] Metadata sync failed', e);
      }
    }
  }, [accessToken]);

  // Fail-Safe Heartbeat: Ensure active conversation settings are always fresh
  useEffect(() => {
    if (!accessToken || !selectedConversationId || !isSocketConnected) return;

    // Only poll if the conversation exists in our list to avoid 404 noise
    // (Wait for inbox to load first)
    if (conversations.length === 0) return;
    const exists = conversations.some(c => c.id === selectedConversationId);
    if (!exists) return;

    // Fast poll for settings while in active chat (fallback if socket fails)
    const timer = setInterval(() => {
      void syncConversationMetadata(selectedConversationId);
    }, 3500);

    return () => clearInterval(timer);
  }, [accessToken, selectedConversationId, isSocketConnected, syncConversationMetadata, conversations]);

  const { emitSendMessage, emitRecallMessage, joinConversation, joinMultipleConversations, markAsRead, getSocket } = useChatSocket({
    token: accessToken,
    onConnected: async () => {
      console.log('[ChatPage] Socket connected event received');
      setIsSocketConnected(true)
      setIsSocketInitialized(true)

      // AUTO-JOIN ALL CONVERSATIONS ON CONNECT
      if (conversationsRef.current.length > 0) {
        const conversationIds = conversationsRef.current.map(c => c.id);
        console.log('[ChatPage] Auto-joining', conversationIds.length, 'conversations on connect');
        void joinMultipleConversations(conversationIds);
      }

      void syncConversationReactions()
      void syncPinnedMessages(selectedConversationIdRef.current)
    },
    onDisconnected: () => {
      setIsSocketConnected(false)
    },
    onFriendshipUpdated: async (payload) => {
      if (!user || !accessToken || !payload.friendId) return;
      console.log('[ChatPage] Friendship updated via socket for friendId:', payload.friendId);

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

      // NOTE: We DON'T join here - should already be in room from onConnected auto-join
      // If somehow we still receive a message we're not in room for, it means:
      // - Server auto-joined us, OR
      // - This is a message from our own send

      // 0. SYSTEM MESSAGES (CRITICAL SIGNALS)
      // Handle both SYSTEM messages and TEXT messages that contain JSON signals (like poll sync)
      if (mapped.type === 'system' || (mapped.text && (mapped.text.includes('"action":') || mapped.text.startsWith('{')))) {
        try {
          let sys: any = null;
          const content = mapped.text.trim();

          try {
            if (content.startsWith('{')) {
              sys = JSON.parse(content);
            } else {
              // Fallback for signals that might be embedded in other text
              const jsonStart = content.indexOf('{"action":');
              if (jsonStart >= 0) {
                const potentialJson = content.substring(jsonStart);
                sys = JSON.parse(potentialJson);
              }
            }
          } catch (e) {
            // Handle plain text or specific recognized keywords
            if (content.includes('FRIEND_ACCEPTED')) {
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
            const isMeKicked = sys.action === 'REMOVE_MEMBER' &&
              sys.targetMemberIds?.some((id: any) => String(id) === String(user?.id));
            if (isMeKicked) {
              console.log('[ChatPage.onMessageReceived] 🚪 Kicked from group! Removing conversation:', cid);
              setConversations(prev => prev.filter(c => c.id !== cid));
              if (selectedConversationIdRef.current === cid) navigate('/chat');
              return;
            }

            // PIN/UNPIN Sync
            if (sys.action === 'PIN_MESSAGE') {
              console.log('[ChatPage] Handling PIN_MESSAGE event -> sys:', sys, 'cid:', cid);
              setPinnedMessageIds(prev => {
                const next = ({ ...prev, [cid]: [...(prev[cid] || []), sys.messageId].filter((v, i, a) => a.indexOf(v) === i) });
                console.log('[ChatPage] setPinnedMessageIds updated (PIN):', { cid, nextIds: next[cid] });
                return next;
              });
              // Ensure pinned message objects are loaded for remote clients
              console.log('[ChatPage] syncPinnedMessages requested for', cid);
              void syncPinnedMessages(cid);
            }
            if (sys.action === 'UNPIN_MESSAGE') {
              console.log('[ChatPage] Handling UNPIN_MESSAGE event -> sys:', sys, 'cid:', cid);
              setPinnedMessageIds(prev => {
                const next = ({ ...prev, [cid]: (prev[cid] || []).filter(id => id !== sys.messageId) });
                console.log('[ChatPage] setPinnedMessageIds updated (UNPIN):', { cid, nextIds: next[cid] });
                return next;
              });
              // Refresh pinned list from server to keep state consistent
              console.log('[ChatPage] syncPinnedMessages requested for', cid);
              void syncPinnedMessages(cid);
            }

            // Group Info Sync: Essential for permissions/settings
            if (sys.action === 'UPDATE_GROUP_INFO') {
              console.log('[ChatPage] Realtime Group Update Signal Received:', mapped.conversationId, sys.metadata);

              // 1. Optimistic update from payload
              setConversations(prev => prev.map(c => {
                if (c.id !== mapped.conversationId) return c;
                return { ...c, ...sys.metadata, updatedAt: new Date().toISOString() };
              }));

              // 2. Proactive Sync: Trigger a refresh of the whole inbox summary
              // to ensure we have the most authoritative state for ALL groups
              if (accessToken) void loadInbox(accessToken);

              // 3. Fallback: Specific metadata refresh
              void syncConversationMetadata(mapped.conversationId);

              // 4. UI Hint
              if (sys.metadata && Object.keys(sys.metadata).length > 0) {
                toast.success('Cài đặt nhóm đã được cập nhật');
              }

              // 5. Silent Update: If it's just settings (no rename), don't show a bubble in chat
              if (!sys.metadata?.newName && !sys.newName) {
                return;
              }
            }

            // Reaction Sync (Poll Voting)
            if (sys.action === 'UPDATE_MESSAGE_REACTIONS') {
              console.log('[ChatPage] Handling UPDATE_MESSAGE_REACTIONS signal for poll sync');
              if (sys.messageId) {
                applyReactionSocketEvent(
                  sys.messageId,
                  typeof sys.emoji === 'string' ? sys.emoji : undefined,
                  typeof sys.actorId === 'string' ? sys.actorId : undefined,
                  sys.type === 'REMOVE' ? 'removed' : 'added',
                );
              }
            }

            // FRIEND_ACCEPTED Sync: Proactively fetch and show the new conversation
            if (sys.action === 'FRIEND_ACCEPTED' || mapped.text.includes('FRIEND_ACCEPTED')) {
              console.log('[ChatPage] Handling FRIEND_ACCEPTED signal');
              void loadInbox(accessToken);
            }
          }

          // Fallback: sometimes system payloads are delivered as TEXT that our JSON parse missed.
          // If the raw text contains PIN_MESSAGE / UNPIN_MESSAGE, trigger a pinned sync.
          try {
            const raw = mapped.text || '';
            if (typeof raw === 'string' && (raw.includes('PIN_MESSAGE') || raw.includes('UNPIN_MESSAGE'))) {
              console.log('[ChatPage] Fallback detected PIN/UNPIN inside text, syncing pinned messages for', mapped.conversationId)
              void syncPinnedMessages(mapped.conversationId)
            }
          } catch (e) {
            /* ignore fallback errors */
          }
        } catch (err) {
          console.warn('[ChatPage] Error processing system signal:', err);
        }
      }

      // 1. DEDUPLICATION (PREVENT DOUBLE RENDERING)
      if (mapped.id && processedMessageIds.current.has(mapped.id)) {
        console.log('[ChatPage] Skipping duplicate message:', mapped.id);
        return;
      }
      if (mapped.id) processedMessageIds.current.add(mapped.id);

      console.log('[ChatPage] Processing new message:', { id: mapped.id, type: mapped.type, conversationId: mapped.conversationId });

      // 2. INSTANT UI UPDATE (FAST PATH)
      const senderId = mapped.senderId;
      const senderProfile = userMapRef.current[senderId];
      const senderDisplayName = senderId === user.id ? 'Bạn' : (senderProfile?.displayName || 'Người dùng');

      // Fast conversation update (Blind Discovery)
      const exists = conversationsRef.current.some(c => c.id === mapped.conversationId);
      const isActive = selectedConversationIdRef.current === mapped.conversationId;

      // Fast message update
      setMessagesByConversation(prev => ({
        ...prev,
        [mapped.conversationId]: upsertMessage(prev[mapped.conversationId] ?? [], mapped)
      }));

      // Prepare seed for conversation update
      let conversationSeed: Partial<ConversationSummary> = {
        name: senderDisplayName,
        avatarUrl: senderProfile?.avatarUrl || null,
        isStranger: !friendIdSetRef.current.has(senderId),
        participantUserIds: [senderId],
      };

      // If it's a system message with metadata, override seed values
      if (mapped.type === 'system' && mapped.text.includes('"action":')) {
        try {
          const sys = JSON.parse(mapped.text);
          if (sys.action === 'UPDATE_GROUP_INFO') {
            conversationSeed = {
              ...conversationSeed,
              name: sys.metadata?.newName,
              avatarUrl: sys.metadata?.newAvatarUrl || sys.metadata?.avatarUrl,
              ...sys.metadata
            };
          }
        } catch (e) { /* ignore */ }
      }

      updateConversationAfterMessage(
        mapped.conversationId,
        mapped,
        isActive || mapped.senderId === user.id,
        undefined,
        conversationSeed,
      );

      // 3. BACKGROUND SYNC
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
          if (!senderProfile && senderId !== user.id) {
            const resolvedSender = await ensureUser(accessToken, senderId);
            setConversations(prev => prev.map(conversation => {
              if (conversation.id !== mapped.conversationId || conversation.lastMessageSenderId !== senderId) {
                return conversation;
              }

              const conversationMessages = messagesByConversationRef.current[mapped.conversationId] ?? [];
              const latestMessage = conversationMessages[conversationMessages.length - 1];
              if (!latestMessage) {
                return {
                  ...conversation,
                  name: conversation.name || resolvedSender.displayName,
                  avatarUrl: conversation.avatarUrl ?? resolvedSender.avatarUrl,
                };
              }

              const refreshedPreview = formatConversationPreview(
                resolvedSender.displayName,
                latestMessage,
                user.id,
                (id) => {
                  if (id === senderId) return resolvedSender.displayName;
                  return userMapRef.current[id]?.displayName || fallbackUserDisplayName(id);
                },
              );

              return {
                ...conversation,
                name: conversation.name || resolvedSender.displayName,
                avatarUrl: conversation.avatarUrl ?? resolvedSender.avatarUrl,
                lastMessage: refreshedPreview,
                lastMessagePreview: refreshedPreview,
              };
            }));
          }
          void syncMessageReaction(mapped.id);
        } catch (err) { /* silent bg error */ }
      })();

      // FALLBACK: Always refresh pinned list when any message arrives
      // This ensures pinned list updates even if PIN_MESSAGE event is not delivered by gateway
      // Debounce: only sync pinned messages once every 3 seconds per conversation
      const now = Date.now();
      const lastSync = lastPinnedSyncTimeRef.current[mapped.conversationId] ?? 0;
      if (now - lastSync >= 3000) {
        lastPinnedSyncTimeRef.current[mapped.conversationId] = now;
        console.log('[ChatPage.onMessageReceived] fallback: refreshing pinned messages due to new message for', mapped.conversationId);
        void syncPinnedMessages(mapped.conversationId);
      }
    },
    onMessageRecalled: (payload) => {
      console.log('[ChatPage.onMessageRecalled] Recall event received:', { messageId: payload?.messageId, conversationId: payload?.conversationId })
      if (!payload.messageId || !payload.conversationId) {
        return
      }

      setRecalledMessageIds((prev) => ({
        ...prev,
        [payload.messageId]: true,
      }))

      // 1. Update message list
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
                isRecalled: true,
                mediaUrl: null,
                mediaThumbnailUrl: null,
                mediaMimeType: null,
                mediaSizeBytes: null,
              }
              : message,
          ),
        }
      })

      // 2. Update Sidebar preview immediately
      setConversations((prev) =>
        prev.map((c) => {
          if (c.id === payload.conversationId) {
            // Check if this recalled message was the one showing in preview
            // We can't easily check messageId against preview text perfectly,
            // but if it's the current selected chat or recently updated, it's likely.
            // Server will eventually sync this, but for realtime we force update.
            return { ...c, lastMessage: 'Tin nhắn đã được thu hồi' }
          }
          return c
        })
      )

      setPinnedMessageIds((prev) => ({
        ...prev,
        [payload.conversationId]: (prev[payload.conversationId] || []).filter((id) => id !== payload.messageId),
      }))

      void syncMessageReaction(payload.messageId)
    },
    onMessageRead: (payload: any) => {
      const safePayload = payload as any;
      const readByUserId = String(safePayload?.userId ?? safePayload?.user_id ?? '').trim()
      const conversationId = String(safePayload?.conversationId ?? safePayload?.conversation_id ?? '').trim()
      const rawLastReadSeq = safePayload?.lastReadSeq ?? safePayload?.last_read_seq ?? safePayload?.seq ?? safePayload?.serverSeq ?? safePayload?.server_seq
      const lastReadSeq = typeof rawLastReadSeq === 'string' ? Number(rawLastReadSeq) : rawLastReadSeq

      if (!user || !readByUserId || readByUserId === user.id || !conversationId || !Number.isFinite(lastReadSeq)) {
        return
      }

      setPeerLastReadByConversation((prev) => {
        const current = prev[conversationId] ?? 0
        if (lastReadSeq <= current) {
          return prev
        }

        return {
          ...prev,
          [conversationId]: lastReadSeq,
        }
      })

      setMessagesByConversation((prev) => {
        const conversationMessages = prev[conversationId] ?? []
        if (conversationMessages.length === 0) {
          return prev
        }

        const nextMessages = conversationMessages.map((message) => {
          if (
            message.sender !== 'me' ||
            message.serverSeq === undefined ||
            message.serverSeq > lastReadSeq
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
          [conversationId]: nextMessages,
        }
      })
    },
    onPresenceChanged: (payload) => {
      if (!user) {
        return
      }

      console.log('Nhận sự kiện presence:', payload)
      console.log('Đang tìm userId:', payload.userId, 'trong danh sách conversations...')
      console.log('[ChatPage.onPresenceChanged] Presence updated:', payload)
      console.log('[ChatPage.onPresenceChanged] Looking for userId:', payload.userId, 'in conversations...')
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
        applyReactionSocketEvent(payload.messageId, resolveReactionEmoji(payload), resolveReactionActorId(payload), 'added');
      }
    },
    onReactionRemoved: (payload: any) => {
      console.log('[ChatPage.socket] Reaction removed:', payload);
      if (payload.messageId) {
        applyReactionSocketEvent(payload.messageId, resolveReactionEmoji(payload), resolveReactionActorId(payload), 'removed');
      }
    },
    onMessagePinned: (payload: any) => {
      const conversationId = String(payload?.conversationId ?? payload?.pin?.conversationId ?? payload?.pin?.conversation_id ?? '').trim()
      const messageId = String(payload?.messageId ?? payload?.pin?.messageId ?? payload?.pin?.message_id ?? '').trim()

      if (!conversationId || !messageId) {
        return
      }

      setPinnedMessageIds((prev) => ({
        ...prev,
        [conversationId]: [...(prev[conversationId] || []), messageId].filter((id, index, list) => list.indexOf(id) === index),
      }))
      // Also refresh pinned messages from server to ensure UI shows message objects
      void syncPinnedMessages(conversationId)
    },
    onMessageUnpinned: (payload: any) => {
      const conversationId = String(payload?.conversationId ?? payload?.pin?.conversationId ?? payload?.pin?.conversation_id ?? '').trim()
      const messageId = String(payload?.messageId ?? payload?.pin?.messageId ?? payload?.pin?.message_id ?? '').trim()

      if (!conversationId || !messageId) {
        return
      }

      setPinnedMessageIds((prev) => ({
        ...prev,
        [conversationId]: (prev[conversationId] || []).filter((id) => id !== messageId),
      }))
      void syncPinnedMessages(conversationId)
    },
    onGroupUpdated: (payload: any) => {
      console.log('[ChatPage.socket] Group Updated (Socket):', payload);
      const conversationId = payload.conversationId || payload.conversation_id;
      if (!conversationId) return;

      // Trigger full refresh to ensure all settings are synced correctly
      void syncConversationMetadata(conversationId);
      if (accessToken) void loadInbox(accessToken);
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
      console.log('[ChatPage.onGroupMemberRemoved] Event:', payload);
      const isMeRemoved = user?.id && payload.targetMemberIds.some(id => String(id) === String(user.id));
      if (isMeRemoved) {
        console.log('[ChatPage.onGroupMemberRemoved] 🚪 Current user removed from group. Cleaning up UI.');
        setConversations(prev => prev.filter(c => c.id !== payload.conversationId));
        if (selectedConversationIdRef.current === payload.conversationId) {
          navigate('/chat');
        }
      } else {
        setConversations(prev => prev.map(c => {
          if (c.id === payload.conversationId) {
            const targetIds = (payload.targetMemberIds || []).map(id => String(id));
            return {
              ...c,
              participantUserIds: c.participantUserIds?.filter(id => !targetIds.includes(String(id))),
              memberCount: Math.max(0, (c.memberCount || 1) - targetIds.length),
              members: c.members?.filter(m => !targetIds.includes(String(m.userId)))
            }
          }
          return c;
        }))
      }
    },
    onGroupMemberLeft: (payload) => {
      if (user?.id && String(payload.actorId) === String(user.id)) {
        setConversations(prev => prev.filter(c => c.id !== payload.conversationId));
        if (selectedConversationIdRef.current === payload.conversationId) {
          navigate('/chat');
        }
        return;
      }

      setConversations(prev => prev.map(c => {
        if (c.id === payload.conversationId) {
          return {
            ...c,
            participantUserIds: c.participantUserIds?.filter(id => String(id) !== String(payload.actorId)),
            memberCount: Math.max(0, (c.memberCount || 1) - 1),
            members: c.members?.filter(m => String(m.userId) !== String(payload.actorId))
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
    },
    onMessageError: (payload) => {
      console.error('[ChatPage] Message error:', payload);
      if (payload.code === 'AUTH_DENIED' && payload.clientMessageId) {
        setMessagesByConversation(prev => {
          const cid = payload.conversationId || selectedConversationIdRef.current;
          if (!cid || !prev[cid]) return prev;
          return {
            ...prev,
            [cid]: markLocalMessageFailed(prev[cid], payload.clientMessageId!)
          };
        });
        toast.error('Bạn không có quyền gửi tin nhắn này.');
      } else {
        toast.error(payload.message || 'Lỗi gửi tin nhắn.');
      }
    },
    onConversationError: (payload) => {
      console.error('[ChatPage] Conversation error:', payload);
      if (payload.code === 'FORBIDDEN' || payload.code === 'NOT_MEMBER' || payload.code === 'CONVERSATION_NOT_FOUND') {
        if (payload.conversationId) {
          setConversations(prev => prev.filter(c => c.id !== payload.conversationId));
          if (selectedConversationIdRef.current === payload.conversationId) {
            navigate('/chat');
          }
        }
        toast.error('Bạn không có quyền thực hiện hành động này hoặc cuộc trò chuyện không tồn tại.');
      } else {
        toast.error(payload.message || 'Lỗi cuộc trò chuyện.');
      }
    }
  })

  // Ensure we join conversation rooms after conversations are loaded
  useEffect(() => {
    if (!accessToken) return
    if (!isSocketConnected) return
    if (!conversations || conversations.length === 0) return

    const ids = conversations.map(c => c.id)
    console.log('[ChatPage] Auto-joining conversations after inbox load:', ids.length)
    void joinMultipleConversations(ids)
  }, [accessToken, isSocketConnected, conversations, joinMultipleConversations])

  // GROUP CALL (SEPARATE LAYER - does not touch single call)
  const {

    incomingCall: incomingGroupCall,



    declineGroupCall,



    isInGroupCall,
  } = useGroupCall({
    socket: getSocket(),
    currentUserId,
    currentUserName: user?.name ?? 'Bạn',
    currentUserAvatar: user?.avatarUrl ?? '',
    userMap,
    conversations, // Added conversations here
  })

  const handleAddReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken || !selectedConversationId || !user) {
        return
      }

      const message = (messagesByConversationRef.current[selectedConversationId] ?? []).find(
        (item) => item.id === messageId,
      )
      const isPollMultipleChoice = Boolean(message?.type === 'poll' && message.pollData?.allowMultiple)

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

            if (!isPollMultipleChoice) {
              // Single-choice poll: remove any other poll-related reactions from this user
              Object.keys(nextReactions).forEach(key => {
                const r = nextReactions[key as ReactionKey];
                if ((key.startsWith('vote:') || key.startsWith('v:')) && r?.myCount > 0) {
                  nextReactions[key as ReactionKey] = {
                    count: Math.max(0, r.count - 1),
                    myCount: 0,
                    userIds: r.userIds.filter(id => id !== user.id)
                  };
                }
              });
            }

            const currentCount = nextReactions[reactionKey as ReactionKey]?.count || 0;
            const currentUserIds = nextReactions[reactionKey as ReactionKey]?.userIds || [];

            nextReactions[reactionKey as ReactionKey] = {
              count: currentCount + 1,
              myCount: 1,
              userIds: [...currentUserIds, user.id]
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

        // Optimistic local update for normal reactions so sender sees change immediately
        setReactionStatesByMessage(prev => {
          const current = prev[messageId] || { reactions: {} };
          const nextReactions = { ...current.reactions } as MessageReactionMap
          const key = (Object.keys(nextReactions) as ReactionKey[]).find(k => REACTION_OPTIONS.find(o => o.key === k)?.emoji === emoji) || EMOJI_TO_REACTION_KEY[emoji] || undefined

          if (key) {
            const cur = nextReactions[key] ?? { count: 0, myCount: 0, userIds: [] }
            if (!cur.userIds.includes(user?.id || '')) {
              nextReactions[key] = {
                count: cur.count + 1,
                myCount: (cur.myCount || 0) + 1,
                userIds: [...cur.userIds, user?.id || '']
              }
            }
          }

          return {
            ...prev,
            [messageId]: {
              ...current,
              reactions: nextReactions,
              lastUsedReaction: key ?? current.lastUsedReaction,
            }
          }
        })

        await syncMessageReaction(messageId)

        // Emit both a system signal (already used by mobile) and a socket reaction event
        if (user?.id) {
          const reactionContent = buildReactionSyncContent({
            messageId,
            conversationId: selectedConversationId,
            actorId: user.id,
            type: 'ADD',
            emoji,
            isPollVote: message?.type === 'poll',
          })

          // Ensure we're in the room before emitting low-level socket event and system signal
          try {
            console.log('[ChatPage.emit] join before reaction.added', { conversationId: selectedConversationId, messageId, actorId: user.id, emoji })
            await joinConversation(selectedConversationId)
            const socket = getSocket()
            console.log('[ChatPage.emit] join done for reaction.added', { connected: socket?.connected, socketId: socket?.id, conversationId: selectedConversationId })
            try {
              console.log('[ChatPage.emit] sending reaction via socket primary (ADD)', { messageId, emoji, isPollVote: message?.type === 'poll' })
              if (socket?.connected) {
                try {
                  const ack = await emitSendMessage({
                    conversationId: selectedConversationId,
                    content: reactionContent,
                    messageType: 'TEXT',
                    clientMessageId: crypto.randomUUID(),
                  })
                  console.log('[ChatPage.emit] send ACK (ADD):', ack)
                  if (!ack || ack.event === 'message.error') {
                    console.warn('[ChatPage.emit] message.send ack error, falling back to REST', ack)
                    void sendMessageViaRest(accessToken, {
                      conversationId: selectedConversationId,
                      content: reactionContent,
                      messageType: 'SYSTEM',
                      clientMessageId: crypto.randomUUID(),
                    })
                  }
                } catch (innerErr) {
                  console.warn('[ChatPage.emit] emitSendMessage threw, fallback to REST (ADD)', innerErr)
                  void sendMessageViaRest(accessToken, {
                    conversationId: selectedConversationId,
                    content: reactionContent,
                    messageType: 'SYSTEM',
                    clientMessageId: crypto.randomUUID(),
                  })
                }
              } else {
                console.warn('[ChatPage.emit] socket not connected, fallback to REST for ADD')
                void sendMessageViaRest(accessToken, {
                  conversationId: selectedConversationId,
                  content: reactionContent,
                  messageType: 'SYSTEM',
                  clientMessageId: crypto.randomUUID()
                })
              }
            } catch (e) {
              console.warn('[ChatPage.emit] failed to send reaction signal via socket', e)
            }

            // Also emit low-level socket event to encourage immediate broadcast
            console.log('[ChatPage.emit] emitting message.reaction.added', { messageId, conversationId: selectedConversationId, actorId: user.id, userId: user.id, emoji })
            socket?.emit && socket.emit('message.reaction.added', {
              messageId,
              message_id: messageId,
              conversationId: selectedConversationId,
              conversation_id: selectedConversationId,
              actorId: user.id,
              actor_id: user.id,
              userId: user.id,
              user_id: user.id,
              emoji,
            })
          } catch (e) {
            console.warn('[ChatPage.emit] failed to emit reaction.added', e)
          }
        }
      } catch (error) {
        console.error('[ChatPage.handleAddReaction] Failed to add reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, selectedConversationId, (user ? user.id : ""), emitSendMessage, syncMessageReaction, getSocket],
  )

  const handleRemoveReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken || !selectedConversationId) {
        return
      }

      let emoji = REACTION_OPTIONS.find((item) => item.key === reactionKey)?.emoji
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

        // Optimistic local update for removal
        setReactionStatesByMessage(prev => {
          const current = prev[messageId] || { reactions: {} };
          const nextReactions = { ...current.reactions } as MessageReactionMap
          const key = (Object.keys(nextReactions) as ReactionKey[]).find(k => REACTION_OPTIONS.find(o => o.key === k)?.emoji === emoji) || EMOJI_TO_REACTION_KEY[emoji] || undefined

          if (key) {
            const cur = nextReactions[key]
            if (cur) {
              const nextUserIds = cur.userIds.filter(id => id !== user?.id)
              const nextCount = Math.max(0, cur.count - (cur.userIds.includes(user?.id || '') ? 1 : 0))
              const nextMyCount = user?.id && cur.myCount > 0 && cur.userIds.includes(user.id) ? Math.max(0, cur.myCount - 1) : cur.myCount

              if (nextCount <= 0 && nextMyCount <= 0 && nextUserIds.length === 0) {
                delete nextReactions[key]
              } else {
                nextReactions[key] = { count: nextCount, myCount: nextMyCount, userIds: nextUserIds }
              }
            }
          }

          return {
            ...prev,
            [messageId]: {
              ...current,
              reactions: nextReactions,
            }
          }
        })

        await syncMessageReaction(messageId)

        if (user?.id) {
          const reactedMessage = (messagesByConversationRef.current[selectedConversationId] ?? []).find(
            (item) => item.id === messageId,
          )
          const reactionContent = buildReactionSyncContent({
            messageId,
            conversationId: selectedConversationId,
            actorId: user.id,
            type: 'REMOVE',
            emoji,
            isPollVote: reactedMessage?.type === 'poll' || emoji.startsWith('vote:') || emoji.startsWith('v:'),
          })

          // Ensure we're in the room before emitting low-level socket event and system signal
          try {
            console.log('[ChatPage.emit] join before reaction.removed', { conversationId: selectedConversationId, messageId, actorId: user.id, emoji })
            await joinConversation(selectedConversationId)
            const socket = getSocket()
            console.log('[ChatPage.emit] join done for reaction.removed', { connected: socket?.connected, socketId: socket?.id, conversationId: selectedConversationId })
            try {
              console.log('[ChatPage.emit] sending reaction via socket primary (REMOVE)', { messageId, emoji })
              if (socket?.connected) {
                try {
                  const ack = await emitSendMessage({
                    conversationId: selectedConversationId,
                    content: reactionContent,
                    messageType: 'TEXT',
                    clientMessageId: crypto.randomUUID(),
                  })
                  console.log('[ChatPage.emit] send ACK (REMOVE):', ack)
                  if (!ack || ack.event === 'message.error') {
                    console.warn('[ChatPage.emit] message.send ack error, falling back to REST', ack)
                    void sendMessageViaRest(accessToken, {
                      conversationId: selectedConversationId,
                      content: reactionContent,
                      messageType: 'SYSTEM',
                      clientMessageId: crypto.randomUUID(),
                    })
                  }
                } catch (innerErr) {
                  console.warn('[ChatPage.emit] emitSendMessage threw, fallback to REST (REMOVE)', innerErr)
                  void sendMessageViaRest(accessToken, {
                    conversationId: selectedConversationId,
                    content: reactionContent,
                    messageType: 'SYSTEM',
                    clientMessageId: crypto.randomUUID(),
                  })
                }
              } else {
                console.warn('[ChatPage.emit] socket not connected, fallback to REST for REMOVE')
                void sendMessageViaRest(accessToken, {
                  conversationId: selectedConversationId,
                  content: reactionContent,
                  messageType: 'SYSTEM',
                  clientMessageId: crypto.randomUUID()
                })
              }
            } catch (e) {
              console.warn('[ChatPage.emit] failed to send reaction signal via socket', e)
            }

            console.log('[ChatPage.emit] emitting message.reaction.removed', { messageId, conversationId: selectedConversationId, actorId: user.id, userId: user.id, emoji })
            socket?.emit && socket.emit('message.reaction.removed', {
              messageId,
              message_id: messageId,
              conversationId: selectedConversationId,
              conversation_id: selectedConversationId,
              actorId: user.id,
              actor_id: user.id,
              userId: user.id,
              user_id: user.id,
              emoji,
            })
          } catch (e) {
            console.warn('[ChatPage.emit] failed to emit reaction.removed', e)
          }
        }
      } catch (error) {
        console.error('[ChatPage.handleRemoveReaction] Failed to remove reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, selectedConversationId, (user ? user.id : ""), emitSendMessage, reactionStatesByMessage, syncMessageReaction, getSocket],
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

        // Update local message list for sender
        setMessagesByConversation((prev) => {
          const current = prev[conversationId] ?? []
          return {
            ...prev,
            [conversationId]: current.map(m => m.id === messageId ? { ...m, isRecalled: true, text: '' } : m)
          }
        })

        // Update Sidebar preview for sender
        setConversations((prev) =>
          prev.map((c) => {
            if (c.id === conversationId) {
              return { ...c, lastMessage: 'Tin nhắn đã được thu hồi' }
            }
            return c
          })
        )
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

          const systemPayload = JSON.stringify({
            action: 'UNPIN_MESSAGE',
            messageId,
            conversationId,
            actorId: user.id
          });

          const clientMessageId = crypto.randomUUID();
          void (async () => {
            try {
              await sendMessageViaRest(accessToken, {
                conversationId,
                content: systemPayload,
                messageType: 'TEXT',
                clientMessageId,
              })

              // Also attempt to emit via socket so gateway broadcasts to other clients in realtime
              try {
                await joinConversation(conversationId)
                await emitSendMessage({ conversationId, content: systemPayload, messageType: 'TEXT', clientMessageId: crypto.randomUUID() })
              } catch (e) {
                // ignore socket errors; REST is source-of-truth
              }
            } catch (e) {
              // ignore REST errors here; handled by outer catch
            }
          })();

          // Optimistic UI Update
          const optimisticSystemMessage: ChatMessage = {
            id: clientMessageId,
            conversationId,
            senderId: user.id,
            sender: 'system',
            type: 'system',
            text: systemPayload,
            timestamp: formatMessageTimestamp(),
            deliveryState: 'sent',
            clientMessageId
          };
          setMessagesByConversation(prev => ({
            ...prev,
            [conversationId]: upsertMessage(prev[conversationId] ?? [], optimisticSystemMessage)
          }));
          return
        }

        if (currentPins.length >= 3) {
          toast.error('Chỉ được phép ghim tối đa 3 tin nhắn')
          return
        }

        // Optimistic UI update
        setPinnedMessageIds((prev) => ({
          ...prev,
          [conversationId]: [...currentPins, messageId],
        }))

        await pinMessage(accessToken, conversationId, messageId)

        const systemPayload = JSON.stringify({
          action: 'PIN_MESSAGE',
          messageId,
          conversationId,
          actorId: user.id
        });

        const clientMessageId = crypto.randomUUID();
        void (async () => {
          try {
            await sendMessageViaRest(accessToken, {
              conversationId,
              content: systemPayload,
              messageType: 'TEXT',
              clientMessageId,
            })

            // Also attempt to emit via socket so gateway broadcasts to other clients in realtime
            try {
              await joinConversation(conversationId)
              await emitSendMessage({ conversationId, content: systemPayload, messageType: 'TEXT', clientMessageId: crypto.randomUUID() })
            } catch (e) {
              // ignore socket errors; REST is source-of-truth
            }
          } catch (e) {
            // ignore REST errors here; handled by outer catch
          }
        })();

        // Optimistic UI Update
        const optimisticSystemMessage: ChatMessage = {
          id: clientMessageId,
          conversationId,
          senderId: user.id,
          sender: 'system',
          type: 'system',
          text: systemPayload,
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sent',
          clientMessageId
        };
        setMessagesByConversation(prev => ({
          ...prev,
          [conversationId]: upsertMessage(prev[conversationId] ?? [], optimisticSystemMessage)
        }));
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

  const processedCallEndsRef = useRef<Set<string>>(new Set())

  const handleInitiateCall = useCallback(async (type: 'audio' | 'video') => {
    if (!selectedConversationId) return;
    const isGroup = !!selectedConversation?.isGroup;
    const callId = `call_${Date.now()}`;
    const peerUserId = isGroup
      ? selectedConversationId
      : (
        selectedConversation?.userId ||
        selectedConversation?.members?.find(member => member.userId && member.userId !== user?.id)?.userId ||
        selectedConversation?.participantUserIds?.find(memberId => memberId !== user?.id)
      );
    if (!peerUserId) {
      console.error('[CALL][INITIATE] Missing direct peer user id', {
        conversationId: selectedConversationId,
        selectedConversation,
      });
      return;
    }
    const peerName = (peerUserId && userMap[peerUserId]?.displayName && userMap[peerUserId].displayName !== 'Người dùng')
      ? userMap[peerUserId].displayName
      : (selectedConversation?.name || "Người dùng");
    const peerAvatar = selectedConversation?.avatarUrl || "";
    const url = `/call/${callId}?type=${isGroup ? "group" : "direct"}&conversationId=${selectedConversationId}&peerId=${peerUserId}&audioOnly=${type === "audio"}&isCaller=true&peerName=${encodeURIComponent(peerName)}&peerAvatar=${encodeURIComponent(peerAvatar)}`;
    console.log("[CALL][INITIATE-POPUP]", { url });

    // FIX: Pre-fetch profiles for all group members BEFORE opening popup.
    // This ensures userMap has displayNames for all participants, preventing userId display in group call UI.
    if (isGroup && accessToken) {
      const memberIds = selectedConversation?.participantUserIds || [];
      await Promise.all(memberIds.map(id => ensureUser(accessToken!, id)));
    }

    // Store call metadata in callStateRef so handleEndCall can access callId
    // BEFORE opening the popup (needed for the early-return guard and message creation)
    callStateRef.current = {
      ...callStateRef.current,
      isOpen: false,
      callId,
      type,
      direction: 'outgoing' as const,
      conversationId: selectedConversationId,
      peerId: peerUserId,
      status: 'connecting',
    };

    const width = window.screen.availWidth;
    const height = window.screen.availHeight;
    window.open(url, "VnaloCall", `width=${width},height=${height},menubar=no,toolbar=no,location=no,status=no`);
    setCallState(prev => ({ ...prev, isOpen: false }));
  }, [selectedConversationId, selectedConversation, userMap, accessToken, user?.id]);


  const handleEndCall = useCallback(async (data: any = 'hangup') => {
    const signalData = typeof data === 'object' ? data : { reason: data };
    const reason = signalData.reason || 'hangup';

    console.log('[CALL_LOG] handleEndCall triggered:', { 
      reason, 
      signalDataCallId: signalData.callId,
      signalDataConvId: signalData.conversationId || signalData.roomId,
      stateCallId: callStateRef.current.callId 
    });

    // BUG FIX: Extract all fields from signalData FIRST (popup-passed data),
    // then fall back to callStateRef (which may be stale after popup took over).
    // The popup owns the call lifecycle once it opens, so its signalData is authoritative.
    const fromSignal = {
      callId: signalData.callId || signalData.callId,
      conversationId: signalData.conversationId || signalData.roomId,
      direction: signalData.direction || callStateRef.current.direction,
      type: signalData.type || callStateRef.current.type,
      startedAt: signalData.startedAt || callStateRef.current.startedAt,
      peerId: signalData.senderUserId || signalData.targetUserId
                || callStateRef.current.peerId
                || selectedConversation?.userId,
    };

    // Use callStateRef as secondary source only when signalData doesn't provide it
    const currentCall = callStateRef.current;
    const callId    = fromSignal.callId    || currentCall.callId;
    const targetConvId = fromSignal.conversationId || currentCall.conversationId;
    const direction  = fromSignal.direction  || currentCall.direction;
    const type       = fromSignal.type       || currentCall.type;
    const startedAt  = fromSignal.startedAt  || currentCall.startedAt;
    const peerId     = fromSignal.peerId     || currentCall.peerId;

    // FIX: Deduplicate call.end events using callId as key.
  // Popup sends call.end directly -> caller processes -> server relays to callee.
  // The caller receives call.end TWICE: once direct from popup, once from server relay.
  // Using only callId as key ensures both trigger only ONE call log creation.
  // Key edge cases:
  // - Caller popup -> direct: callId known, direction='outgoing' -> creates message.
  // - Caller server relay -> callId same -> SKIP (already created by direct path).
  // - Callee server relay -> callId known, direction='incoming' -> creates message.
  const dedupKey = callId ? `${callId}` : `${targetConvId}_${signalData.reason || 'hangup'}`;
  if (processedCallEndsRef.current.has(dedupKey)) {
    console.log('[CALL_LOG] Skipping duplicate call.end event', dedupKey);
    return;
  }
  processedCallEndsRef.current.add(dedupKey);
  // Clean up old entries to prevent memory leak (keep last 50)
  if (processedCallEndsRef.current.size > 50) {
    const entries = Array.from(processedCallEndsRef.current);
    entries.slice(0, entries.length - 50).forEach(k => processedCallEndsRef.current.delete(k));
  }

  // FIX: Determine the authoritative direction based on who triggered this event.
  // - Popup sends call.end with direction already set -> use it.
  // - Server relays call.end from the other party -> direction is opposite.
  // - Popup sends 'hangup' string directly (no signalData fields) -> use callStateRef.direction.
  // - If no direction known at all, infer from peer relationship.
  let finalDirection = direction;
  if (!finalDirection) {
    // Server relayed: the sender is the opposite of the call owner.
    // signalData.senderUserId tells us who sent this event.
    // If it's the current user -> we are the one ending, direction is 'outgoing'.
    // If it's NOT the current user -> peer ended the call, direction is 'incoming'.
    finalDirection = signalData.senderUserId === currentUserId ? 'outgoing' : 'incoming';
  }

  // FIX: Determine who the caller is. The caller is whoever initiated the call.
  // - For outgoing calls: callerId = currentUserId.
  // - For incoming calls: callerId = peerUserId.
  // - We can detect who the caller is from the direction:
  //   - 'outgoing': I called the peer -> callerId = currentUserId, calleeId = peerUserId.
  //   - 'incoming': Peer called me -> callerId = peerUserId, calleeId = currentUserId.
  // But when the server relays call.end to the callee, senderUserId = peerId (the caller).
  // When server relays to the caller, senderUserId = peerId (the callee).

  // For callee receiving server relay:
  // - senderUserId = peerId (the caller) -> callerId = peerId, calleeId = currentUserId
  // For caller receiving server relay:
  // - senderUserId = peerId (the callee) -> but this is a relay TO the caller

  // The most reliable way: if direction='outgoing', callerId=currentUserId.
  // If direction='incoming', callerId=peerUserId.
  // peerUserId is the other party in the conversation.
  const thePeerUserId = peerId || selectedConversation?.userId || targetConvId;
  const theCallerId = finalDirection === 'outgoing' ? currentUserId : thePeerUserId;
  const theCalleeId = finalDirection === 'outgoing' ? thePeerUserId : currentUserId;

  // FIX: Always create call log message regardless of direction.
  // Both outgoing and incoming calls should produce a visible call bubble.
  // The only case where we skip is when we cannot determine a valid conversation.
  if (!targetConvId) {
    console.warn('[CALL_LOG] No conversationId, skipping call log creation');
    return;
  }

  const externalDuration = signalData.duration;
  const externalOutcome  = signalData.outcome;
  const duration = externalDuration !== undefined
    ? externalDuration
    : (startedAt ? Math.floor((Date.now() - startedAt) / 1000) : 0);

  let outcome: 'completed' | 'canceled' | 'missed' = externalOutcome || 'completed';
  if (externalOutcome === undefined && !startedAt) {
    outcome = finalDirection === 'outgoing' ? 'canceled' : 'missed';
  }

  console.log(`[CALL_LOG] Ending call. Reason: ${reason}, Outcome: ${outcome}, Duration: ${duration}s, CallId: ${callId}, Direction: ${finalDirection}`);

  // Reset UI State immediately
  setCallState(prev => ({
    ...prev,
    isOpen: false,
    status: 'connecting',
    callId: undefined,
  }));

  if (callId) {
    const keysToDelete = Array.from(processedSignalsRef.current).filter(k => k.startsWith(callId));
    keysToDelete.forEach(k => processedSignalsRef.current.delete(k));
  }

  // Construct final log data using the authoritative direction and callerId
  const logData = {
    v: 1,
    callId: String(callId || ''),
    conversationId: String(targetConvId),
    callerId: theCallerId,
    calleeId: theCalleeId,
    mediaType: type === 'video' ? 'video' : 'voice',
    outcome,
    durationSeconds: duration,
    createdAt: new Date().toISOString(),
  };

  const logText = `CALL_LOG::${JSON.stringify(logData)}`;

  // FIX: Always create optimistic message for BOTH outgoing AND incoming calls.
  // The sender of the call.end event is the one who ended the call.
  // - For outgoing calls (caller ends): caller created the message.
  // - For incoming calls (callee receives server relay): the peer's ended call should
  //   appear as an incoming call bubble in the chat. We show it with sender='other'.
  const isThisUserTheCaller = finalDirection === 'outgoing';
  const optimisticLog: ChatMessage = {
    id: typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    clientMessageId: typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    conversationId: targetConvId,
    sender: isThisUserTheCaller ? 'me' : 'other',
    senderId: isThisUserTheCaller ? currentUserId : thePeerUserId,
    type: 'call',
    text: logText,
    timestamp: formatMessageTimestamp(),
    createdAt: new Date().toISOString(),
    deliveryState: isThisUserTheCaller ? 'sending' : 'sent',
  };

  console.log('[CALL_LOG] Adding optimistic message to UI', optimisticLog.id, 'sender:', optimisticLog.sender);

  // Add to local state immediately
  setMessagesByConversation(prev => ({
    ...prev,
    [targetConvId]: upsertMessage(prev[targetConvId] ?? [], optimisticLog)
  }));
  updateConversationAfterMessage(targetConvId, optimisticLog, true);

  // FIX: Only the caller (isThisUserTheCaller=true) sends the call log to the server.
  // The callee already receives the message via the caller's send (server relays it).
  // For the callee, we add an optimistic 'other' message locally.
  // For the caller, we send to the server (which will relay to the callee).
  if (isThisUserTheCaller) {
    (async () => {
      let success = false;
      const maxRetries = 2;
      const clientMessageId = optimisticLog.clientMessageId as string;

      // --- SOCKET ATTEMPT (with Retry & Timeout) ---
      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        console.log(`[CALL_LOG] Socket Attempt ${attempt}/${maxRetries}...`);
        try {
          const ack = await Promise.race([
            emitSendMessage({
              conversationId: targetConvId,
              content: logText,
              messageType: 'TEXT',
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
            messageType: 'TEXT',
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
  }
  // For incoming calls (callee side): the message was already added optimistically above.
  // The server doesn't relay call log messages to the callee separately - the callee
  // sees the call bubble based on the incoming call.end event they receive.
  // We do NOT need to send anything to the server for incoming calls.
  }, [selectedConversation, currentUserId, emitSendMessage, accessToken, updateConversationAfterMessage]);





  const handleCallEnd = useCallback(async (data: any) => {
    const signalData = Array.isArray(data) ? data[0] : data;
    console.log('[CALL][RECEIVE END]', signalData);
    handleEndCall(signalData);
  }, [handleEndCall]);

  const handleCallOffer = async (data: any) => {
    let signalData = Array.isArray(data) ? data[0] : data;
    if (signalData && signalData.data) signalData = signalData.data;
    if (signalData && signalData.offer && !signalData.sdp) signalData = signalData.offer;
    const callId = signalData?.callId;
    if (!callId || !getSocket()) return;
    const sigKey = `${callId}_offer`;
    if (processedSignalsRef.current.has(sigKey)) return;
    processedSignalsRef.current.add(sigKey);
    console.log("[CALL][RECEIVE OFFER-POPUP-READY]", signalData);
    const peerUserId = signalData.senderUserId || signalData.callerId || signalData.fromUserId;
    const conversationId = signalData.conversationId || signalData.roomId;

    // FIX BUG #12: Pass offer SDP directly in URL to avoid localStorage race condition.
    // Previously, the offer was stored in localStorage by ChatPage and the popup
    // tried to read it after opening. This created a race: if the popup opened
    // before setState completed, or if the popup was closed and reopened, the
    // offer would be lost. Now we encode the offer directly in the URL query param
    // so the popup has everything it needs immediately on load.
    const offerSdp = signalData.sdp || signalData.offer?.sdp || signalData.data?.sdp;
    if (offerSdp) {
      // FIX BUG #12: Store offer in sessionStorage (shared between parent ChatPage
      // and popup CallPage on the same origin). The popup reads this immediately
      // on load. This replaces the fragile localStorage approach that had a race
      // condition where the popup might read before the offer was stored.
      // We also store in localStorage as a fallback (in case sessionStorage isn't
      // ready yet in the popup's first render cycle).
      const encodedOffer = btoa(JSON.stringify(offerSdp));
      sessionStorage.setItem(`offer_${callId}`, encodedOffer);
      localStorage.setItem(`pending_offer_${callId}`, JSON.stringify(offerSdp));
    }

    currentCallIdRef.current = callId;
    if (callStateRef.current.isOpen) {
      console.warn("[ChatPage] Already in a call, ignoring offer");
      return;
    }
    setCallState(prev => ({
      ...prev,
      isOpen: true,
      type: signalData.audioOnly ? "audio" : "video",
      direction: "incoming",
      status: "connecting",
      peerId: peerUserId,
      conversationId: conversationId,
      callId: callId,
      isMicOn: true,
      isCameraOn: !signalData.audioOnly,
    }));
    if (peerUserId && accessToken) {
      void ensureUser(accessToken, peerUserId);
    }
  };

  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // STABLE SIGNALING HANDLERS (using Refs to prevent listener churn)
  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
  const handleCallAnswer = async (data: any) => {
    const signalData = Array.isArray(data) ? data[0] : data;
    if (signalData?.callId === callStateRef.current.callId) {
      setCallState(prev => ({ ...prev, isOpen: false }));
    }
  };
  const handleCallIce = async (_data: any) => {
    // Popup handles its own ICE
  };

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
    };
  }, [getSocket, currentUserId]);

  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // POPUP COMMUNICATION (Receive signals from CallPage popup)
  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.data?.type === 'call.end') {
        console.log('[ChatPage] Received call.end from popup', event.data.data);
        handleEndCall(event.data.data);
      }
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [handleEndCall]);

  // Sync effect: Fetch profile for all group members when a conversation is opened
  // Sync effect: Fetch profile for all visible conversation members when a conversation is opened
  useEffect(() => {
    const activeConversationId = routedConversationId || selectedConversationId
    if (!accessToken || !activeConversationId) return;

    const selected = conversations.find(c => c.id === activeConversationId);
    const memberIds = selected?.members?.map(member => member.userId).filter(Boolean)
      ?? selected?.participantUserIds
      ?? [];

    memberIds.forEach(id => void ensureUser(accessToken, id));
  }, [accessToken, routedConversationId, selectedConversationId, conversations, ensureUser]);

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
          console.log("âš¡ [ChatPage] Proactively fetching missing conversations:", missingIds);
          const fetchedResults = await Promise.all(
            missingIds.map(async (id) => {
              try {
                const result = await fetchConversation(token, id);
                return result;
              } catch (err: any) {
                const status = err.response?.status;
                // If it's a 404/403, cleanup localStorage so we don't keep trying forever
                if (status === 404 || status === 403) {
                  console.log(`[ChatPage] Purging ghost group ID: ${id}`);

                  // 1. Cleanup localStorage
                  const stored = localStorage.getItem(`vnalo_pending_groups_${user?.id}`);
                  if (stored) {
                    try {
                      const ids: string[] = JSON.parse(stored);
                      const filtered = ids.filter(pid => pid !== id);
                      localStorage.setItem(`vnalo_pending_groups_${user?.id}`, JSON.stringify(filtered));
                    } catch (e) { /* ignore */ }
                  }

                  // 2. If this is the active conversation in URL, it's dead. Redirect!
                  if (id === targetId) {
                    console.warn(`[ChatPage] âš ï¸ Current URL points to dead conversation ${id}. Redirecting to /chat.`);
                    navigate('/chat');
                  }
                }
                return null;
              }
            })
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
                lastMessage: isGroup ? "Nhóm mới được tạo" : "[Thông báo] Gửi lời chào",
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
              if (mid && realName && realName !== 'Người dùng mới' && realName !== (mid === user?.id ? 'Bạn' : 'Người dùng mới')) {
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
          const isCloud = !isGroup && !peerId; // My Documents flag
          const resolvedPeerName = !isGroup && peerId ? friendNameById.get(peerId) : null
          const resolvedPeerAvatar = !isGroup && peerId ? (friendAvatarById.get(peerId) ?? null) : null
          const resolvedLastMessageSenderName = item.lastMessageSenderId
            ? (previewNameById.get(item.lastMessageSenderId) ?? null)
            : null
          const getName = (id: string) => {
            if (id === user?.id) return 'Bạn'
            return userMapRef.current[id]?.displayName || previewNameById.get(id) || 'Người dùng mới'
          }
          const formattedLastMessage = formatConversationPreview(
            resolvedLastMessageSenderName,
            item.lastMessagePreview ?? item.lastMessage ?? '',
            user?.id || '',
            getName,
          )
          const isStranger = !isGroup && peerId ? !friendIdSet.has(peerId) : false

          let withName = item;
          if (isCloud) {
            withName = { ...item, name: 'My Documents', avatarUrl: null, isCloud: true, lastMessage: formattedLastMessage, isStranger: false };
          } else if (!isGroup && resolvedPeerName) {
            withName = { ...item, name: resolvedPeerName, avatarUrl: resolvedPeerAvatar, lastMessage: formattedLastMessage, isStranger };
          } else {
            withName = { ...item, lastMessage: formattedLastMessage, isStranger };
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
        console.log('âš¡ [DEBUG] Inbox items from API:', mappedItems);



        const finalMappedItems = [...mappedItems];
        if (!finalMappedItems.some(c => c.id === 'my-documents' || c.isCloud)) {
          finalMappedItems.push(myDocumentsConversation);
        }

        setConversations((prev) => {
          if (!targetId) return finalMappedItems;

          // Try to find it in the freshly fetched items first
          const targetInFetched = finalMappedItems.find(item => item.id === targetId);
          if (targetInFetched) {
            return [targetInFetched, ...finalMappedItems.filter(item => item.id !== targetId)];
          }

          // Fallback: try to find it in previous state
          const targetInPrev = prev.find(item => item.id === targetId);
          if (targetInPrev) {
            return [targetInPrev, ...finalMappedItems.filter(item => item.id !== targetId)];
          }

          return finalMappedItems;
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
    [(user ? user.id : ""), user?.name, upsertUser],
  )


  const inboxSummarySyncingRef = useRef(false)

  useEffect(() => {
    if (!accessToken || !user?.id || !isSocketConnected || conversations.length === 0) {
      return
    }

    let isCancelled = false
    const SYNC_INTERVAL_MS = 3000

    const syncInboxSummaries = async () => {
      if (inboxSummarySyncingRef.current) {
        return
      }

      inboxSummarySyncingRef.current = true

      try {
        const inboxItems = await fetchInbox(accessToken, user.id)
        if (isCancelled || inboxItems.length === 0) {
          return
        }

        setConversations((prev) => {
          const incomingById = new Map(inboxItems.map((item) => [item.id, item]))
          let changed = false

          const next = prev.map((conversation) => {
            const incoming = incomingById.get(conversation.id)
            if (!incoming) {
              return conversation
            }

            incomingById.delete(conversation.id)

            const peerId = !incoming.isGroup
              ? (incoming.participantUserIds ?? []).find((id) => id !== user?.id)
              : undefined
            const cachedPeer = peerId ? userMapRef.current[peerId] : null
            const incomingSeq = incoming.lastMessageSeq ?? -1
            const currentSeq = conversation.lastMessageSeq ?? -1
            const incomingTime = new Date(incoming.lastMessageAt || incoming.updatedAt || 0).getTime()
            const currentTime = new Date(conversation.lastMessageAt || conversation.updatedAt || 0).getTime()
            const resolvedIncomingName = !incoming.isGroup && cachedPeer?.displayName && isGenericDirectName(incoming.name)
              ? cachedPeer.displayName
              : incoming.name
            const resolvedIncomingAvatar = !incoming.isGroup
              ? (incoming.avatarUrl ?? cachedPeer?.avatarUrl ?? conversation.avatarUrl ?? null)
              : (incoming.avatarUrl ?? conversation.avatarUrl ?? null)
            const nextName = !incoming.isGroup && isGenericDirectName(resolvedIncomingName) && !isGenericDirectName(conversation.name)
              ? conversation.name
              : resolvedIncomingName
            const isStaleSummary = incomingTime < currentTime
            const hasNewerSummary = !isStaleSummary && (
              incomingSeq > currentSeq ||
              incomingTime > currentTime ||
              (incoming.unreadCount ?? 0) !== (conversation.unreadCount ?? 0)
            )

            // 1. If incoming summary is older than local, ignore it entirely
            if (isStaleSummary) {
              return conversation
            }

            // 2. If timestamps are exactly equal, trust the local state (prevents optimistic UI flickering)
            if (incomingTime === currentTime && incomingTime > 0) {
              // Only check for unread count if everything else is equal
              if ((incoming.unreadCount ?? 0) !== (conversation.unreadCount ?? 0)) {
                changed = true;
                return { ...conversation, unreadCount: incoming.unreadCount };
              }
              return conversation;
            }

            if (!hasNewerSummary) {
              const metadataChanged =
                nextName !== conversation.name ||
                resolvedIncomingAvatar !== (conversation.avatarUrl ?? null) ||
                (incoming.memberCount ?? 0) !== (conversation.memberCount ?? 0) ||
                Boolean(incoming.allowMemberPin) !== Boolean(conversation.allowMemberPin) ||
                Boolean(incoming.allowMemberEditInfo) !== Boolean(conversation.allowMemberEditInfo) ||
                Boolean(incoming.onlyAdminCanPost) !== Boolean(conversation.onlyAdminCanPost)

              if (!metadataChanged) {
                return conversation
              }
            } else {
              // Newer summary detected, trigger message sync (Mobile-like fallback)
              console.log('[ChatPage] Out-of-sync summary for:', conversation.id, 'Triggering message sync');
              void syncLatestMessages(conversation.id);
            }

            changed = true
            return {
              ...conversation,
              ...incoming,
              name: nextName,
              avatarUrl: resolvedIncomingAvatar,
              online: conversation.online,
              isOnline: conversation.isOnline,
              lastSeenTime: conversation.lastSeenTime,
            }
          })

          const extras = Array.from(incomingById.values()).map((incoming) => {
            const peerId = !incoming.isGroup
              ? (incoming.participantUserIds ?? []).find((id) => id !== user?.id)
              : undefined
            const cachedPeer = peerId ? userMapRef.current[peerId] : null
            const nextName = !incoming.isGroup && cachedPeer?.displayName && isGenericDirectName(incoming.name)
              ? cachedPeer.displayName
              : incoming.name
            const nextAvatarUrl = !incoming.isGroup
              ? (incoming.avatarUrl ?? cachedPeer?.avatarUrl ?? null)
              : (incoming.avatarUrl ?? null)

            if (peerId && !cachedPeer) {
              void ensureUser(accessToken, peerId)
            }

            return {
              ...incoming,
              name: nextName,
              avatarUrl: nextAvatarUrl,
            }
          })

          if (extras.length > 0) {
            changed = true
            return [...extras, ...next]
          }

          return changed ? next : prev
        })
      } catch (error) {
        console.warn('[ChatPage.inboxSummarySync] Failed to sync inbox summaries', error)
      } finally {
        inboxSummarySyncingRef.current = false
      }
    }

    void syncInboxSummaries()
    const interval = window.setInterval(() => {
      void syncInboxSummaries()
    }, SYNC_INTERVAL_MS)

    return () => {
      isCancelled = true
      window.clearInterval(interval)
    }
  }, [accessToken, conversations.length, isSocketConnected, (user ? user.id : "")])

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

        console.log("[DEBUG] Created Group ID:", groupId);

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
        console.error("[CREATE GROUP] Lỗi:", error);
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

  // Removed polling fallback: rely on socket + auto-join for realtime updates

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
      if (accessToken && conversationId && conversationId !== 'my-documents') {
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
    [accessToken, navigate, (user ? user.id : ""), upsertUser],
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
        if (accessToken && conversationId !== 'my-documents') {
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
                  const peerId = !isGroup ? (participantIds[0]) : undefined;
                  const cachedPeer = peerId ? userMapRef.current[peerId] : null;

                  const rawName = isGroup ? (inner.title || conv.name) : (inner.title || conv.name);
                  const resolvedName = !isGroup && (isGenericDirectName(rawName) || !rawName) && cachedPeer?.displayName
                    ? cachedPeer.displayName
                    : rawName;

                  return {
                    ...conv,
                    memberCount: members.length || conv.memberCount,
                    members: members.map((m: any) => ({
                      userId: String(m.userId ?? '').trim(),
                      role: String(m.role ?? 'MEMBER').toUpperCase(),
                      displayName: m.displayName || m.name || m.fullName,
                      avatarUrl: m.avatarUrl || m.avatar,
                    })),
                    participantUserIds: participantIds,
                    avatarUrl: isGroup ? (inner.avatarUrl || conv.avatarUrl) : (inner.avatarUrl || conv.avatarUrl),
                    name: resolvedName,
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

        const isVirtualCloud = conversationId === 'my-documents'
        let mapped: ChatMessage[] = []

        if (isVirtualCloud) {
          try {
            const key = `vnalo_cloud_msgs_${user.id}`;
            const saved = localStorage.getItem(key);
            if (saved) {
              const rawCloudMsgs = JSON.parse(saved);
              mapped = sortMessages(
                (Array.isArray(rawCloudMsgs) ? rawCloudMsgs : [])
                  .map((m) => normalizeMessage(m))
                  .filter((m) => !deletedMessageIds[m.id])
              );
            }
          } catch (e) {
            console.error('Failed to load local cloud messages', e);
          }
        } else {
          const rawMessages = await fetchMessages(accessToken, conversationId)
          console.log('Dữ liệu tin nhắn nhận được:', rawMessages)
          mapped = sortMessages(
            rawMessages
              .map((message) => applyRestrictedMessage(normalizeMessage(mapRawMessage(message, user.id)), isRestrictedMode))
              .filter((message) => !deletedMessageIds[message.id]),
          )
        }

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

    // Lightweight fallback polling for the active conversation only.
    // This keeps reactions in sync even when the gateway does not emit
    // message.reaction.* events for some sessions.
    void syncConversationReactions()

    const interval = window.setInterval(() => {
      void syncConversationReactions()
    }, 4000)

    return () => {
      window.clearInterval(interval)
    }
  }, [accessToken, isSocketConnected, selectedConversationId, syncConversationReactions])

  useEffect(() => {
    console.log('[ChatPage.onPresenceChanged] Conversation IDs:', conversations.map((conv) => conv.userId))
  }, [conversations])


  const joinAllConversations = useCallback(async (list: ConversationSummary[]) => {
    const conversationIds = list.map((conversation) => conversation.id)

    if (conversationIds.length === 0) {
      return
    }

    console.log('--- ĐANG THỰC HIỆN JOIN ROOM CHO', list.length, 'HỘI THOẠI ---')
    console.log('Tự động Join về các room:', conversationIds)

    await joinMultipleConversations(conversationIds)
  }, [joinMultipleConversations])

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
        console.log('[ChatPage.openDirectConversation] âš¡ Joined conversation:', conversationId)
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

  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // SMART JOIN ROOMS (Only join once per session/reconnect)
  // ------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
      console.log(`[ChatPage.join] âš¡ Socket ID changed from ${lastJoinedSocketIdRef.current} to ${currentSocketId}, clearing joined cache`);
      joinedIdsRef.current.clear();
      lastJoinedSocketIdRef.current = currentSocketId;
    }

    if (actualConnected && !isSocketConnected) {
      console.log('[ChatPage.join] âš¡ Fixing connection state (out of sync)');
      setIsSocketConnected(true);
      return;
    }

    if (!actualConnected || !isSocketConnected) {
      if (joinedIdsRef.current.size > 0) {
        console.log('[ChatPage.join] âš¡ Socket disconnected, clearing joined cache');
        joinedIdsRef.current.clear();
      }
      return;
    }

    const currentIds = conversations.map((c) => c.id);
    const newIds = currentIds.filter((id) => id && !joinedIdsRef.current.has(id));

    if (newIds.length > 0) {
      console.log(`[ChatPage.join] âš¡ Joining ${newIds.length} new rooms for socket ${currentSocketId}`);
      newIds.forEach((id) => {
        void (async () => {
          const joined = await joinConversation(id);
          if (joined) {
            joinedIdsRef.current.add(id);
          } else {
            console.warn('[ChatPage.join] Join failed, will retry on next effect run:', id);
          }
        })();
      });
    }
  }, [conversations, isSocketConnected, joinConversation, getSocket]);

  // 1. Mark as read on conversation change or new messages (with guard)
  // 1. Mark as read on conversation change or new messages (with guard)
  const lastEmittedReadRef = useRef<Record<string, number>>({})

  useEffect(() => {
    const activeConversationId = routedConversationId || selectedConversationId

    if (!accessToken || !activeConversationId) {
      return
    }

    const convMessages = messagesByConversation[activeConversationId] || []
    const latestSeq = convMessages.at(-1)?.serverSeq

    if (latestSeq === undefined) {
      return
    }

    // GUARD: Only emit if sequence has actually increased OR conversation changed to prevent infinite loop
    if (latestSeq > (lastEmittedReadRef.current[activeConversationId] ?? 0)) {
      console.log('[ChatPage.effect] auto-markAsRead:', { activeConversationId, latestSeq })
      lastEmittedReadRef.current[activeConversationId] = latestSeq
      markAsRead({ conversationId: activeConversationId, lastReadSeq: latestSeq })
      void markConversationRead(accessToken, activeConversationId, latestSeq).catch(() => undefined)
      refreshNotificationBadges()
    }
  }, [accessToken, markAsRead, messagesByConversation, routedConversationId, selectedConversationId])
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
      const mentionsAiAssistant = draft.mentions?.some((mention) => mention.userId === AI_ASSISTANT_USER_ID) || /(^|\s)@VNALO(\s|$)/i.test(draft.text ?? '')

      if (mentionsAiAssistant) {
        const cleanedPrompt = (draft.text ?? '')
          .replace(/\u200B@VNALO\|__vnalo_ai__\u200B/gi, '')
          .replace(/(^|\s)@VNALO(\s|$)/gi, ' ')
          .trim()
        const conversationName = selectedConversation?.name?.trim() || 'hội thoại hiện tại'
        const prompt = cleanedPrompt
          ? 'Trong ngữ cảnh "' + conversationName + '", ' + cleanedPrompt
          : 'Hỗ trợ tôi trong ngữ cảnh hội thoại "' + conversationName + '".'

        window.localStorage.setItem(AI_PENDING_PROMPT_KEY, prompt)
        navigate('/chat-ai')
        return
      }

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

      // Virtual "My Documents" uses local storage, no need to resolve to a real conversation
      let targetConversationId = conversationId;
      if (conversationId === 'my-documents') {
        targetConversationId = 'my-documents';
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
          isLocal: true,
          text: content,
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sending',
          replyTo: replyTo,
        };
        console.log('[ChatPage.send] Optimistic message replyTo:', optimisticTextMessage.replyTo)
        // Compute next messages immediately so preview uses the optimistic message
        const prevMsgs = messagesByConversationRef.current[targetConversationId] ?? []
        const nextMsgs = upsertMessage(prevMsgs, optimisticTextMessage)
        setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: nextMsgs }));
        updateConversationAfterMessage(targetConversationId, optimisticTextMessage, true, nextMsgs);

        // Virtual Cloud Chat: Bypass backend and save to localStorage
        if (targetConversationId === 'my-documents') {
          const sentMessage = { ...optimisticTextMessage, deliveryState: 'sent' as const, createdAt: new Date().toISOString() };
          setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], sentMessage) }));
          updateConversationAfterMessage(targetConversationId, sentMessage, true);

          const key = `vnalo_cloud_msgs_${user.id}`;
          const existingStr = localStorage.getItem(key);
          const existing = existingStr ? JSON.parse(existingStr) : [];
          localStorage.setItem(key, JSON.stringify([sentMessage, ...existing]));
          return;
        }

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
          isLocal: true,
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

        // Virtual Cloud Chat: Bypass backend and save to localStorage
        if (targetConversationId === 'my-documents') {
          const sentMessage = { ...optimisticMessage, deliveryState: 'sent' as const, createdAt: new Date().toISOString() };
          setMessagesByConversation(prev => ({ ...prev, [targetConversationId]: upsertMessage(prev[targetConversationId] ?? [], sentMessage) }));
          updateConversationAfterMessage(targetConversationId, sentMessage, true);

          const key = `vnalo_cloud_msgs_${user.id}`;
          const existingStr = localStorage.getItem(key);
          const existing = existingStr ? JSON.parse(existingStr) : [];
          localStorage.setItem(key, JSON.stringify([sentMessage, ...existing]));
          continue;
        }

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
    async (poll: any) => {
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
        isLocal: true,
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
        options: poll.options.map((opt: any) => ({
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
      toast.success('Cập nhật tên nhóm thành công')

      const systemPayload = JSON.stringify({
        action: 'UPDATE_GROUP_INFO',
        actorId: user?.id,
        metadata: { newName }
      });

      const clientMessageId = crypto.randomUUID();
      void emitSendMessage({
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'SYSTEM',
        clientMessageId
      });

      // Also persist it as a TEXT message for history
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Optimistic UI Update
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user?.id || '',
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId
      };
      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));
    } catch (err) {
      toast.error('Có lỗi xảy ra khi cập nhật tên nhóm')
      console.error(err)
    }
  }

  const handleUpdateGroupAvatar = async (file: File) => {
    if (!selectedConversationId || !accessToken) return;

    try {
      // 0. Permission check
      const currentConv = conversations.find(c => c.id === selectedConversationId)
      const isModerator = (currentConv?.members?.find(m => m.userId === user?.id)?.role || '').toUpperCase() === 'ADMIN' || (currentConv?.members?.find(m => m.userId === user?.id)?.role || '').toUpperCase() === 'DEPUTY'
      if (currentConv?.isGroup) {
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

      const clientMessageId = crypto.randomUUID();
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Optimistic UI Update
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user?.id || '',
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId
      };
      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));

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

      const clientMessageId = crypto.randomUUID();
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Optimistic UI Update
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user.id,
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId
      };
      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));

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
        actorId: user.id,
        silent: leaveGroupSilently
      });

      const clientMessageId = crypto.randomUUID();
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Optimistic UI Update
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user.id,
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId
      };
      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));

      // Then actually leave via API
      await leaveConversation(accessToken, selectedConversationId);

      setConversations((prev) => prev.filter(c => c.id !== selectedConversationId));
      navigate('/chat');
    } catch (error: any) {
      console.error('Failed to leave group:', error);
      if (error.message === 'Bạn chưa chuyển quyền trưởng nhóm khi rời nhóm') {
        toast.error('Bạn chưa chuyển quyền trưởng nhóm khi rời nhóm');
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
        return { ...conv, ...settings, updatedAt: new Date().toISOString() };
      }));
      // Emit SYSTEM notification for realtime sync
      const systemPayload = JSON.stringify({
        action: 'UPDATE_GROUP_INFO',
        actorId: user?.id,
        metadata: settings
      });

      // Emit as SYSTEM signal (using SYSTEM type for maximum priority)
      try {
        await emitSendMessage({
          conversationId: selectedConversationId,
          messageType: 'SYSTEM',
          content: systemPayload,
          clientMessageId: crypto.randomUUID()
        });
        console.log('[ChatPage] Group sync signal sent successfully');
      } catch (e) {
        console.warn('[ChatPage] âš ï¸ Failed to emit group sync signal');
      }
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

      const clientMessageId = crypto.randomUUID();
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Add a small delay to ensure socket broadcast finishes before backend deletes the group
      await new Promise(resolve => setTimeout(resolve, 300));

      // Then call API
      await disbandConversation(accessToken, selectedConversationId);
      toast.success('Giải tán nhóm thành công');

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

      const clientMessageId = crypto.randomUUID();
      // Send as 'TEXT' (uppercase) to satisfy backend validation.
      // The frontend mapping logic will automatically detect the system action and render it as a system message.
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId: clientMessageId
      });

      // Optimistic UI Update: Add system message to local list immediately
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user.id,
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId: clientMessageId
      };

      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));

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

        const clientMessageId = crypto.randomUUID();
        void sendMessageViaRest(accessToken, {
          conversationId: selectedConversationId,
          content: systemPayload,
          messageType: 'TEXT',
          clientMessageId
        });

        // Optimistic UI Update
        const optimisticSystemMessage: ChatMessage = {
          id: clientMessageId,
          conversationId: selectedConversationId,
          senderId: user?.id || '',
          sender: 'system',
          type: 'system',
          text: systemPayload,
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sent',
          clientMessageId
        };
        setMessagesByConversation(prev => ({
          ...prev,
          [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
        }));
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

      const systemPayload = JSON.stringify({
        action: 'TRANSFER_OWNERSHIP',
        actorId: user.id,
        targetMemberIds: [newOwnerId]
      });

      const clientMessageId = crypto.randomUUID();
      void sendMessageViaRest(accessToken, {
        conversationId: selectedConversationId,
        content: systemPayload,
        messageType: 'TEXT',
        clientMessageId
      });

      // Optimistic UI Update
      const optimisticSystemMessage: ChatMessage = {
        id: clientMessageId,
        conversationId: selectedConversationId,
        senderId: user.id,
        sender: 'system',
        type: 'system',
        text: systemPayload,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sent',
        clientMessageId
      };
      setMessagesByConversation(prev => ({
        ...prev,
        [selectedConversationId]: upsertMessage(prev[selectedConversationId] ?? [], optimisticSystemMessage)
      }));

      // 3. Perform standard leave group logic
      await doLeaveGroup();
    } catch (error) {
      console.error('Failed to transfer ownership and leave:', error);
      toast.error('Chuyển quyền và rời nhóm thất bại');
    }
  };

  const sortedConversations = useMemo(() => {
    const list = [...conversations];
    if (!list.some(c => c.id === 'my-documents' || c.isCloud)) {
      list.push(myDocumentsConversation);
    }

    return list.map(conv => {
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
      // Use lastMessageAt or updatedAt as fallback
      const effectiveTime = conv.lastMessageAt || conv.updatedAt;
      if (!effectiveTime) return true; // Don't hide if we have no time info at all

      const lastMessageTime = new Date(effectiveTime).getTime();
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
        onOpenAddMembers={() => setIsAddMembersOpen(true)}
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
                reactionStates={reactionStatesByMessage}
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
        title="Rời nhóm và xóa trò chuyện"
        variant="confirm"
        footer={
          <div className="flex gap-3 justify-end w-full">
            <button
              className="px-6 py-2 rounded-lg bg-[var(--surface-muted)] text-[var(--text)] font-bold text-[15px] hover:bg-[var(--surface-hover)] border-0 outline-none cursor-pointer"
              onClick={() => setConfirmLeaveGroupOpen(false)}
            >
              Hủy
            </button>
            <button
              className="px-6 py-2 rounded-lg bg-red-600 text-white font-bold text-[15px] hover:bg-red-700 border-0 outline-none cursor-pointer"
              onClick={doLeaveGroup}
            >
              Rời nhóm
            </button>
          </div>
        }
      >
        <div className="py-2 space-y-5">
          <p className="text-[15px] text-[var(--text)] leading-relaxed">
            Bạn sẽ không thể xem lại tin nhắn trong nhóm này sau khi rời nhóm.
          </p>

          <div
            className="flex items-center justify-between p-4 rounded-xl bg-[var(--surface-muted)] cursor-pointer group hover:bg-[var(--surface-hover)] transition-colors"
            onClick={() => setLeaveGroupSilently(!leaveGroupSilently)}
          >
            <div className="space-y-1">
              <p className="text-[15px] font-semibold text-[var(--text)]">Rời nhóm trong im lặng</p>
              <p className="text-[13px] text-[var(--text-secondary)]">Chỉ trưởng/phó nhóm biết bạn rời nhóm.</p>
            </div>
            <div
              className={`relative h-6 w-11 rounded-full transition-all duration-200 ${leaveGroupSilently ? 'bg-[#0091FF]' : 'bg-gray-400 shadow-inner'
                }`}
            >
              <div
                className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-all duration-200 transform ${leaveGroupSilently ? 'translate-x-5' : 'translate-x-0'
                  }`}
              />
            </div>
          </div>
        </div>
      </Modal>

      <UserProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
        userId={selectedProfileUserId}
        accessToken={accessToken}
        initialUser={selectedProfileUserId ? userMap[selectedProfileUserId] : undefined}
        onMessage={handleOpenFriendChat}
      />

      {/* Call UI moved to popup window */}
















      {/* INCOMING GROUP CALL NOTIFICATION shown to non-callers */}
      {(incomingGroupCall && !isInGroupCall) ? (
        <IncomingCallBanner
          peerName={incomingGroupCall.callerName}
          peerAvatar={incomingGroupCall.callerAvatar}
          isGroup={true}
          conversationName={incomingGroupCall.conversationName}
          isAudioOnly={incomingGroupCall.audioOnly}
          onAnswer={() => {
            const params = new URLSearchParams({
              type: "group",
              conversationId: incomingGroupCall.conversationId,
              audioOnly: String(incomingGroupCall.audioOnly),
              isCaller: "false",
              peerName: incomingGroupCall.conversationName,
              peerAvatar: incomingGroupCall.callerAvatar || "",
            });
            const url = `/call/${incomingGroupCall.callId}?${params.toString()}`;
            const width = window.screen.availWidth;
            const height = window.screen.availHeight;
            window.open(url, "VnaloCall", `width=${width},height=${height},menubar=no,toolbar=no,location=no,status=no`);
            declineGroupCall();
          }}
          onDecline={declineGroupCall}
        />
      ) : null}

      {/* Group Call UI moved to popup window */}













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
    console.log('[PinnedLogicHooks.effect] Checking pinned fetch conditions', { accessToken: !!accessToken, isBootstrapping, selectedConversationId, lastConv: lastConvRef.current });
    if (!accessToken || isBootstrapping || !selectedConversationId) {
      console.log('[PinnedLogicHooks.effect] Skipping pinned fetch due to missing conditions');
      return;
    }

    // Avoid re-fetching same conversation (Double Guard)
    if (lastConvRef.current === selectedConversationId) {
      console.log('[PinnedLogicHooks.effect] Skipping pinned fetch - same conversation');
      return;
    }
    console.log('[PinnedLogicHooks.effect] Calling loadPinnedMessages for conversation', selectedConversationId);
    lastConvRef.current = selectedConversationId

    void loadPinnedMessages(selectedConversationId)
  }, [accessToken, isBootstrapping, selectedConversationId, loadPinnedMessages, lastConvRef])

  // Mapping Pinned IDs -> Message Objects (with placeholder support)
  useEffect(() => {
    if (!selectedConversationId) return

    const ids = pinnedMessageIds[selectedConversationId] || []
    const convMessages = messagesByConversation[selectedConversationId] || []

    console.log('[PinnedLogicHooks] mapping pinned ids -> messages', { conversationId: selectedConversationId, ids, convCount: convMessages.length })

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

    console.log('[PinnedLogicHooks] mapped pinned messages count:', mapped.length)

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








