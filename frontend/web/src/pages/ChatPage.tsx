import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { getSyncPolicy } from '../features/auth/auth.api'
import { ChatList } from '../features/chat/components/ChatList'
import { ConversationInfo } from '../features/chat/components/ConversationInfo'
import { SearchMessagesPanel } from '../features/chat/components/SearchMessagesPanel'
import { SearchGlobalPanel } from '../features/chat/components/SearchGlobalPanel'
import { MessageShareModal } from '../features/chat/components/MessageShareModal'
import { ChatWindow } from '../features/chat/components/ChatWindow'
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
  uploadChatMedia,
} from '../features/chat/chat.api';
import type { RawMessage } from '../features/chat/chat.api'
import { REACTION_OPTIONS, type MessageReactionState, type ReactionKey } from '../features/chat/components/MessageReaction'
import { useChatSocket } from '../features/chat/useChatSocket'
import type {
  ChatComposePayload,
  ChatMessage,
  ChatMessageType,
  ConversationSummary,
  MessageDeliveryState,
} from '../features/chat/chat.types'
import { getFriends, getUserById, searchUsers } from '../features/friends/friends.api'
import { getUserByPhone } from '../features/friends/friends.api'
import type { Friend, UserLookupResult } from '../features/friends/friends.types'
import { useAuth } from '../features/auth/useAuth'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { Card } from '../shared/components/ui/Card'
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

function formatMessageTimestamp(): string {
  return new Date().toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  })
}

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

function getConversationPreview(message: ChatMessage): string {
  switch (message.type) {
    case 'image':
      return 'Ảnh'
    case 'file':
      return 'File'
    case 'sticker':
      return 'Sticker'
    default:
      return message.text.trim()
  }
}

function formatPreviewSenderName(displayName?: string | null): string {
  const normalized = String(displayName ?? '').trim().replace(/\s+/g, ' ')
  if (!normalized) {
    return ''
  }

  const parts = normalized.split(' ')
  if (parts.length <= 2) {
    return normalized
  }

  return parts.slice(-2).join(' ')
}

function formatConversationPreview(senderName: string | null | undefined, message: ChatMessage | string): string {
  const rawMessage = typeof message === 'string' ? message : getConversationPreview(message)
  const content = String(rawMessage ?? '').trim()

  if (!content) {
    return ''
  }

  const previewSender = formatPreviewSenderName(senderName)
  if (!previewSender) {
    return content
  }

  const prefix = `${previewSender}:`
  if (content.startsWith(prefix)) {
    return content
  }

  return `${previewSender}: ${content}`
}

function getDraftMessageType(payload: ChatComposePayload): ChatMessageType {
  if (payload.sticker) {
    return 'sticker'
  }

  if (payload.file) {
    return payload.file.type.startsWith('image/') ? 'image' : 'file'
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

type CachedUserProfile = {
  displayName: string
  avatarUrl: string | null
}

function fallbackUserDisplayName(userId: string): string {
  return `Nguoi dung ${userId.slice(0, 8)}`
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

export function ChatPage() {
  const { isBootstrapping, accessToken, user } = useAuth()
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
  const [userProfileCache, setUserProfileCache] = useState<Record<string, CachedUserProfile>>({})
  const [isSocketConnected, setIsSocketConnected] = useState(false)
  const [rightSidebarContent, setRightSidebarContent] = useState<'info' | 'search' | 'global-search' | null>('info')
  const [jumpToMessageId, setJumpToMessageId] = useState<string | null>(null)
  const [pinnedMessageIds, setPinnedMessageIds] = useState<Record<string, true>>({})
  const [starredMessageIds, setStarredMessageIds] = useState<Record<string, true>>({})
  const [recalledMessageIds, setRecalledMessageIds] = useState<Record<string, true>>({})
  const [deletedMessageIds, setDeletedMessageIds] = useState<Record<string, true>>({})
  const [selectedMessageIds, setSelectedMessageIds] = useState<string[]>([])
  const [isMultiSelectMode, setIsMultiSelectMode] = useState(false)
  const [isTokenRestrictedMode, setIsTokenRestrictedMode] = useState(false)
  const [shareModalMessage, setShareModalMessage] = useState<ChatMessage | null>(null)
  const [isShareSubmitting, setIsShareSubmitting] = useState(false)

  const selectedConversationIdRef = useRef('')
  const selectedMessagesRef = useRef<ChatMessage[]>([])
  const conversationsRef = useRef<ConversationSummary[]>([])
  const friendIdSetRef = useRef<Set<string>>(new Set())
  const userProfileCacheRef = useRef<Record<string, CachedUserProfile>>({})
  const pendingProfileLookupRef = useRef<Set<string>>(new Set())
  const lastLoadedMessagesKeyRef = useRef('')
  const messageLoadRequestSeqRef = useRef(0)

  const [isCreateGroupOpen, setIsCreateGroupOpen] = useState(false);
  const [isCreatingGroup, setIsCreatingGroup] = useState(false);

  useEffect(() => {
    selectedConversationIdRef.current = routedConversationId || selectedConversationId
  }, [routedConversationId, selectedConversationId])

  useEffect(() => {
    conversationsRef.current = conversations
  }, [conversations])

  useEffect(() => {
    userProfileCacheRef.current = userProfileCache
  }, [userProfileCache])

  const selectedConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === (routedConversationId || selectedConversationId)),
    [conversations, routedConversationId, selectedConversationId],
  )

  const selectedMessages = useMemo(() => {
    const resolvedConversationId = routedConversationId || selectedConversationId
    if (!resolvedConversationId) {
      return []
    }

    return messagesByConversation[resolvedConversationId] ?? []
  }, [messagesByConversation, routedConversationId, selectedConversationId])

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

  const toReactionState = useCallback(
    (rows: Array<{ userId: string; emoji: string }>): MessageReactionState => {
      const reactions: MessageReactionState['reactions'] = {}

      for (const row of rows) {
        const reactionKey = EMOJI_TO_REACTION_KEY[row.emoji]
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

  const syncConversationReactions = useCallback(async () => {
    if (!selectedConversationIdRef.current || !accessToken) {
      return
    }

    const messageIds = selectedMessagesRef.current
      .map((message) => message.id)
      .slice(-25)

    if (messageIds.length === 0) {
      return
    }

    await Promise.all(messageIds.map((messageId) => syncMessageReaction(messageId)))
  }, [accessToken, syncMessageReaction])

  const syncPinnedMessages = useCallback(
    async (conversationId: string) => {
      if (!accessToken || !conversationId) {
        return
      }

      try {
        const pins = await fetchPinnedMessages(accessToken, conversationId)
        const nextPinnedIds = pins.reduce<Record<string, true>>((acc, pin) => {
          if (pin.messageId) {
            acc[pin.messageId] = true
          }
          return acc
        }, {})

        setPinnedMessageIds(nextPinnedIds)
      } catch (error) {
        console.warn('[ChatPage.syncPinnedMessages] Failed to fetch pinned messages', { conversationId, error })
      }
    },
    [accessToken],
  )

  const handleAddReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken) {
        return
      }

      const emoji = REACTION_OPTIONS.find((item) => item.key === reactionKey)?.emoji
      if (!emoji) {
        return
      }

      try {
        await addMessageReaction(accessToken, messageId, emoji)
        await syncMessageReaction(messageId)
      } catch (error) {
        console.error('[ChatPage.handleAddReaction] Failed to add reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, syncMessageReaction],
  )

  const handleRemoveReaction = useCallback(
    async (messageId: string, reactionKey: ReactionKey) => {
      if (!accessToken) {
        return
      }

      const current = reactionStatesByMessage[messageId]?.reactions[reactionKey]
      if (!current || current.myCount <= 0) {
        return
      }

      try {
        await removeMessageReaction(accessToken, messageId)
        await syncMessageReaction(messageId)
      } catch (error) {
        console.error('[ChatPage.handleRemoveReaction] Failed to remove reaction', { messageId, reactionKey, error })
      }
    },
    [accessToken, reactionStatesByMessage, syncMessageReaction],
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
    [accessToken, syncMessageReaction, syncPinnedMessages],
  )

  const handleTogglePinMessage = useCallback(
    async (messageId: string, conversationId: string) => {
      if (!accessToken) {
        return
      }

      const isPinned = Boolean(pinnedMessageIds[messageId])

      try {
        if (isPinned) {
          await unpinMessage(accessToken, conversationId, messageId)
          setPinnedMessageIds((prev) => {
            const next = { ...prev }
            delete next[messageId]
            return next
          })
          return
        }

        await pinMessage(accessToken, conversationId, messageId)
        await syncPinnedMessages(conversationId)
      } catch (error) {
        console.error('[ChatPage.handleTogglePinMessage] Failed to toggle pin', { messageId, conversationId, error })
      }
    },
    [accessToken, pinnedMessageIds, syncPinnedMessages],
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
    (messageId: string, action: MessageContextMenuAction, message: ChatMessage) => {
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

      const trimmedNote = note.trim()
      const mediaUrl = shareModalMessage.mediaUrl ?? shareModalMessage.attachments?.[0]?.url ?? null
      const mediaThumbnailUrl = shareModalMessage.mediaThumbnailUrl ?? shareModalMessage.attachments?.[0]?.thumbnailUrl ?? null
      const mediaMimeType = shareModalMessage.mediaMimeType ?? shareModalMessage.attachments?.[0]?.mimeType ?? null
      const mediaSizeBytes = shareModalMessage.mediaSizeBytes ?? shareModalMessage.attachments?.[0]?.sizeBytes ?? null
      const messageType =
        shareModalMessage.type === 'image'
          ? 'IMAGE'
          : shareModalMessage.type === 'file'
            ? 'FILE'
            : shareModalMessage.type === 'sticker'
              ? 'STICKER'
              : 'TEXT'

      const payloadContent =
        (shareModalMessage.text ?? '').trim().length > 0
          ? shareModalMessage.text
          : shareModalMessage.type === 'image'
            ? mediaUrl ?? '[image]'
            : shareModalMessage.type === 'file'
              ? shareModalMessage.attachments?.[0]?.name ?? mediaUrl ?? '[file]'
              : shareModalMessage.type === 'sticker'
                ? '[sticker]'
                : ''

      setIsShareSubmitting(true)

      try {
        for (const userId of targetUserIds) {
          const conversationId = await getOrCreateDirectConversation(accessToken, userId)
          await joinConversation(conversationId)

          if (trimmedNote) {
            const noteAck = await emitSendMessage({
              conversationId,
              content: trimmedNote,
              messageType: 'TEXT',
            })

            if (noteAck?.event !== 'message.sent') {
              await sendMessageViaRest(accessToken, {
                conversationId,
                content: trimmedNote,
                messageType: 'TEXT',
              })
            }
          }

          const shareAck = await emitSendMessage({
            conversationId,
            content: payloadContent,
            messageType: toSocketMessageType(shareModalMessage.type),
            mediaUrl,
            mediaThumbnailUrl,
            mediaMimeType,
            mediaSizeBytes,
          })

          if (shareAck?.event !== 'message.sent') {
            await sendMessageViaRest(accessToken, {
              conversationId,
              content: payloadContent || undefined,
            messageType,
            mediaUrl,
            mediaThumbnailUrl,
            mediaMimeType,
            mediaSizeBytes,
            })
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
    [accessToken, shareModalMessage],
  )

  const getCachedProfileFromStore = useCallback(
    (userId: string): CachedUserProfile | null => {
      const cached = userProfileCacheRef.current[userId]
      if (cached) {
        return cached
      }

      const fromFriendResults = friendResults.find((friend) => friend.id === userId)
      if (fromFriendResults) {
        return {
          displayName:
            fromFriendResults.displayName?.trim() ||
            fromFriendResults.phone ||
            fromFriendResults.email ||
            fallbackUserDisplayName(userId),
          avatarUrl: fromFriendResults.avatarUrl ?? null,
        }
      }

      const fromConversation = conversationsRef.current.find((conversation) =>
        (conversation.participantUserIds ?? []).includes(userId),
      )

      if (fromConversation?.name) {
        return {
          displayName: fromConversation.name,
          avatarUrl: null,
        }
      }

      return null
    },
    [friendResults],
  )

  const ensureUserProfile = useCallback(
    async (token: string, userId: string): Promise<CachedUserProfile> => {
      const fromStore = getCachedProfileFromStore(userId)
      if (fromStore) {
        setUserProfileCache((prev) => ({
          ...prev,
          [userId]: fromStore,
        }))
        return fromStore
      }

      if (pendingProfileLookupRef.current.has(userId)) {
        return {
          displayName: fallbackUserDisplayName(userId),
          avatarUrl: null,
        }
      }

      pendingProfileLookupRef.current.add(userId)

      try {
        const profile = await getUserById(token, userId)
        const resolved: CachedUserProfile = {
          displayName:
            profile?.displayName?.trim() || profile?.phone || profile?.email || fallbackUserDisplayName(userId),
          avatarUrl: profile?.avatarUrl ?? null,
        }

        setUserProfileCache((prev) => ({
          ...prev,
          [userId]: resolved,
        }))

        return resolved
      } catch {
        const fallback = {
          displayName: fallbackUserDisplayName(userId),
          avatarUrl: null,
        }

        setUserProfileCache((prev) => ({
          ...prev,
          [userId]: fallback,
        }))

        return fallback
      } finally {
        pendingProfileLookupRef.current.delete(userId)
      }
    },
    [getCachedProfileFromStore],
  )

const handleCreateGroup = useCallback(
  async (groupName: string, avatarUrl: string | null, memberIds: string[]) => {
    if (!accessToken || !user) {
      toast.error("Vui lòng đăng nhập lại");
      return;
    }

    console.log("🚀 [CREATE GROUP] Bắt đầu tạo nhóm:", {
      groupName,
      memberCount: memberIds.length,
      memberIds,
      avatarUrl,
    });

    setIsCreatingGroup(true);

    try {
      const groupId = await createGroupConversation(accessToken, {
        title: groupName,
        memberUserIds: memberIds,
        avatarUrl: avatarUrl,
      });

      console.log("✅ [CREATE GROUP] Thành công! Group ID:", groupId);

      toast.success(`✅ Đã tạo nhóm "${groupName}" thành công!`);

      // Chuyển hướng vào nhóm vừa tạo
      navigate(`/chat/${groupId}`);
      setIsCreateGroupOpen(false);
    } catch (error: any) {
      console.error("❌ [CREATE GROUP] Lỗi:", error);
      toast.error(error.message || "Không thể tạo nhóm. Vui lòng thử lại.");
    } finally {
      setIsCreatingGroup(false);
    }
  },
  [accessToken, user, navigate]
);

  const loadInbox = useCallback(
    async (token: string, preferredConversationId?: string) => {
      setIsLoadingConversations(true)

      try {
        const [items, policy, friends] = await Promise.all([
          fetchInbox(token, user?.id),
          getSyncPolicy(token).catch(() => null),
          getFriends(token).catch(() => []),
        ])
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

        setUserProfileCache((prev) => {
          const next = { ...prev }
          for (const friend of friends) {
            if (!friend.friendId) {
              continue
            }

            next[friend.friendId] = {
              displayName: friend.nickname?.trim() || friend.displayName?.trim() || fallbackUserDisplayName(friend.friendId),
              avatarUrl: friend.avatarUrl ?? null,
            }
          }
          return next
        })

        const unresolvedPeerIds = [
          ...new Set(
            items
              .map((item) => (item.participantUserIds ?? []).find((participantId) => participantId !== user?.id))
              .filter((peerId): peerId is string => typeof peerId === 'string' && !friendNameById.has(peerId)),
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

        setUserProfileCache((prev) => {
          const next = { ...prev }
          for (const fallback of fallbackProfiles) {
            next[fallback.peerId] = {
              displayName: fallback.name || fallbackUserDisplayName(fallback.peerId),
              avatarUrl: fallback.avatarUrl,
            }
          }

          return next
        })

        const mappedItems = items.map((item) => {
          const peerId = (item.participantUserIds ?? []).find((participantId) => participantId !== user?.id)
          const resolvedPeerName = peerId ? friendNameById.get(peerId) : null
          const resolvedPeerAvatar = peerId ? (friendAvatarById.get(peerId) ?? null) : null
          const resolvedLastMessageSenderName = item.lastMessageSenderId
            ? (previewNameById.get(item.lastMessageSenderId) ?? null)
            : null
          const formattedLastMessage = formatConversationPreview(
            resolvedLastMessageSenderName,
            item.lastMessagePreview ?? item.lastMessage ?? '',
          )
          const isStranger = peerId ? !friendIdSet.has(peerId) : false
          const withName = resolvedPeerName
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
                avatarUrl: resolvedPeerAvatar,
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
        setConversations((prev) => {
          if (!preferredConversationId) {
            return mappedItems
          }

          if (mappedItems.some((item) => item.id === preferredConversationId)) {
            return mappedItems
          }

          const preserved = prev.find((item) => item.id === preferredConversationId)
          if (!preserved) {
            return mappedItems
          }

          return [preserved, ...mappedItems]
        })
        setSelectedConversationId((prev) => {
          if (preferredConversationId) {
            return preferredConversationId
          }
          if (routedConversationId && mappedItems.some((item) => item.id === routedConversationId)) {
            return routedConversationId
          }
          if (prev && mappedItems.some((item) => item.id === prev)) {
            return prev
          }
          return mappedItems[0]?.id ?? ''
        })
      } catch (error) {
        console.error('Failed to fetch inbox', error)
        setConversations([])
        setSelectedConversationId('')
      } finally {
        setIsLoadingConversations(false)
      }
    },
    [routedConversationId, user?.id, user?.name],
  )

  const updateConversationAfterMessage = useCallback(
    (conversationId: string, message: ChatMessage, markAsReadNow: boolean) => {
      const senderName =
        message.senderId === user?.id
          ? user?.name?.trim() || fallbackUserDisplayName(message.senderId)
          : userProfileCacheRef.current[message.senderId]?.displayName || fallbackUserDisplayName(message.senderId)
      const formattedPreview = formatConversationPreview(senderName, message)

      setConversations((prev) => {
        const index = prev.findIndex((conversation) => conversation.id === conversationId)
        if (index === -1) {
          return prev
        }

        const next = [...prev]
        const current = next[index]
        next[index] = {
          ...current,
          lastMessage: formattedPreview,
          lastMessageSeq: message.serverSeq ?? current.lastMessageSeq,
          unreadCount: markAsReadNow ? 0 : current.unreadCount + (message.sender === 'me' ? 0 : 1),
        }

        return next
      })
    },
    [user?.id, user?.name],
  )

  useEffect(() => {
    if (!accessToken || !user) {
      setConversations([])
      setMessagesByConversation({})
      setSelectedConversationId('')
      setFriendResults([])
      setFriendsDirectory([])
      setShareModalMessage(null)
      setIsTokenRestrictedMode(false)
      lastLoadedMessagesKeyRef.current = ''
      return
    }

    const tokenPayload = parseJwtPayload(accessToken)
    const rawRestrictedClaim = tokenPayload?.restrictedWebMode
    const tokenRestricted = isRestrictedWebToken(accessToken)
    setIsTokenRestrictedMode(false)
    console.log('[ChatPage.auth] Token policy decoded:', {
      tokenRestricted,
      rawRestrictedClaim,
      rawRestrictedClaimType: typeof rawRestrictedClaim,
      accessTokenTail: accessToken.slice(-12),
    })

    // Do not hard-lock composer from token claim; backend enforces real permission.
    setIsRestrictedMode(false)

    void loadInbox(accessToken)
  }, [accessToken, loadInbox, user?.id, user?.name])

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

      try {
        if (normalizedPhone.length >= 2 && normalizedPhone.length >= Math.max(2, normalizedKeyword.length - 2)) {
          const user = await getUserByPhone(accessToken, normalizedKeyword)
          setFriendResults(user ? [user] : [])
          return
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
    (conversationId: string) => {
      setSelectedConversationId(conversationId)
      navigate(`/chat/${conversationId}`)
    },
    [navigate],
  )

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

  const activeConversationId = routedConversationId || selectedConversationId


  useEffect(() => {
    if (!accessToken || !activeConversationId || !user) {
      return
    }

    const loadKey = `${activeConversationId}:${isRestrictedMode ? 'restricted' : 'full'}`
    if (lastLoadedMessagesKeyRef.current === loadKey) {
      return
    }
    lastLoadedMessagesKeyRef.current = loadKey
    const requestSeq = ++messageLoadRequestSeqRef.current

    setIsLoadingMessages(true)

    void (async () => {
      try {
        const rawMessages = await fetchMessages(accessToken, activeConversationId)
        console.log('Dữ liệu tin nhắn nhận được:', rawMessages)
        const mapped = sortMessages(
          rawMessages
            .map((message) => applyRestrictedMessage(mapRawMessage(message, user.id), isRestrictedMode))
            .filter((message) => !deletedMessageIds[message.id]),
        )
        setMessagesByConversation((prev) => ({
          ...prev,
          [activeConversationId]: mapped,
        }))
        void syncPinnedMessages(activeConversationId)
        void syncConversationReactions()

        const newestSeq = mapped[mapped.length - 1]?.serverSeq
        if (newestSeq !== undefined) {
          void markConversationRead(accessToken, activeConversationId, newestSeq).catch(() => undefined)
          setConversations((prev) =>
            prev.map((conversation) =>
              conversation.id === activeConversationId
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
  }, [accessToken, activeConversationId, deletedMessageIds, isRestrictedMode, syncConversationReactions, syncPinnedMessages, user])

  const { emitSendMessage, emitRecallMessage, joinConversation, markAsRead, getSocket } = useChatSocket({
    token: accessToken,
    onConnected: async () => {
      setIsSocketConnected(true)
      void syncConversationReactions()
      void syncPinnedMessages(selectedConversationIdRef.current)
    },
    onDisconnected: () => {
      setIsSocketConnected(false)
    },
    onMessageReceived: (raw: RawMessage) => {
      if (!user || !accessToken) {
        return
      }

      const senderId = raw.senderId || raw.from || ''

      const mapped = applyRestrictedMessage(mapRawMessage(raw, user.id), isRestrictedMode)

      if (!mapped.conversationId) {
        console.warn('[ChatPage.onMessageReceived] Missing conversationId in payload, skipping render', raw)
        return
      }

      if (deletedMessageIds[mapped.id]) {
        return
      }

      console.log('[ChatPage.onMessageReceived] Realtime message mapped:', {
        messageId: mapped.id,
        conversationId: mapped.conversationId,
        selectedConversationId: selectedConversationIdRef.current,
        sender: mapped.sender,
      })

      if (!selectedConversationIdRef.current) {
        setSelectedConversationId(mapped.conversationId)
        navigate(`/chat/${mapped.conversationId}`)
      }

      void ensureUserProfile(accessToken, senderId).then((profile) => {
        setConversations((prev) => {
          const existingIndex = prev.findIndex((conversation) => conversation.id === mapped.conversationId)

          if (existingIndex === -1) {
            return [
              {
                id: mapped.conversationId,
                name: profile.displayName,
                avatarUrl: profile.avatarUrl,
                isStranger: senderId ? !friendIdSetRef.current.has(senderId) : false,
                  lastMessage: formatConversationPreview(profile.displayName, mapped),
                unreadCount: mapped.sender === 'me' ? 0 : 1,
                online: false,
                lastMessageSeq: mapped.serverSeq,
                participantUserIds: senderId ? [senderId] : undefined,
              },
              ...prev,
            ]
          }

          const next = [...prev]
          const current = next[existingIndex]
          const shouldReplaceName =
            !current.name?.trim() ||
            current.name.startsWith('Trò chuyện ') ||
            current.name.startsWith('Nguoi dung ')
          next[existingIndex] = {
            ...current,
            name: shouldReplaceName ? profile.displayName : current.name,
            avatarUrl: current.avatarUrl ?? profile.avatarUrl,
            lastMessage: formatConversationPreview(profile.displayName, mapped),
            isStranger:
              senderId && friendIdSetRef.current.has(senderId)
                ? false
                : current.isStranger ?? Boolean(senderId),
            participantUserIds:
              current.participantUserIds && senderId
                ? Array.from(new Set([...current.participantUserIds, senderId]))
                : current.participantUserIds ?? (senderId ? [senderId] : undefined),
          }

          return next
        })
      })

      setMessagesByConversation((prev) => {
        const current = prev[mapped.conversationId] ?? []
        return {
          ...prev,
          [mapped.conversationId]: upsertMessage(current, mapped),
        }
      })

      // Socket event arrived: refresh reaction snapshot for that message.
      void syncMessageReaction(mapped.id)

      const isActiveConversation = selectedConversationIdRef.current === mapped.conversationId
      updateConversationAfterMessage(mapped.conversationId, mapped, isActiveConversation)

      if (isActiveConversation && mapped.serverSeq !== undefined) {
        const emitted = markAsRead({ conversationId: mapped.conversationId, lastReadSeq: mapped.serverSeq })
        if (!emitted) {
          void markConversationRead(accessToken, mapped.conversationId, mapped.serverSeq).catch(() => undefined)
        }
      }
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
  })

  useEffect(() => {
    if (!isSocketConnected || !selectedConversationId || !accessToken) {
      return
    }

    void syncConversationReactions()

    const timerId = window.setInterval(() => {
      void syncConversationReactions()
    }, 2500)

    return () => {
      window.clearInterval(timerId)
    }
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
    console.log('Trạng thái Socket:', socket?.connected ?? false, 'ID:', socket?.id ?? 'unknown')
  }, [conversations, getSocket])

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
    if (routedConversationId || conversations.length === 0) {
      return
    }

    const fallbackConversationId = selectedConversationId || conversations[0]?.id
    if (!fallbackConversationId) {
      return
    }

    navigate(`/chat/${fallbackConversationId}`, { replace: true })
  }, [conversations, navigate, routedConversationId, selectedConversationId])

  useEffect(() => {
    if (conversations.length === 0 || !isSocketConnected) {
      return
    }

    console.log('[ChatPage.joinEffect] conversations changed while socket connected, re-joining rooms')
    void joinAllConversations(conversations)
  }, [conversationIdsSignature, conversations, isSocketConnected, joinAllConversations])

  useEffect(() => {
    if (!selectedConversationId) {
      return
    }

    const latestSeq = messagesByConversation[selectedConversationId]?.at(-1)?.serverSeq
    if (latestSeq === undefined) {
      return
    }

    markAsRead({ conversationId: selectedConversationId, lastReadSeq: latestSeq })
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

      const restrictedByToken = accessToken ? isRestrictedWebToken(accessToken) : false
      if (restrictedByToken || isTokenRestrictedMode || isRestrictedMode) {
        console.warn('[ChatPage.send] Token indicates restricted mode, but send is still allowed by client-side override')
      }

      const content = getDraftContent(draft)
      const messageType = getDraftMessageType(draft)

      const clientMessageId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `${Date.now()}-${Math.random().toString(16).slice(2)}`

      let mediaUrl: string | null = null
      let mediaThumbnailUrl: string | null = null
      let mediaMimeType: string | null = null
      let mediaSizeBytes: number | null = null
      let localPreviewUrl: string | null = null

      if (draft.file && messageType === 'image') {
        localPreviewUrl = URL.createObjectURL(draft.file)

        const optimisticPreviewMessage: ChatMessage = {
          id: clientMessageId,
          clientMessageId,
          conversationId,
          sender: 'me',
          senderId: user.id,
          type: 'image',
          isLocal: true,
          text: content,
          mediaUrl: localPreviewUrl,
          mediaMimeType: draft.file.type || null,
          mediaSizeBytes: draft.file.size,
          attachments: [
            {
              url: localPreviewUrl,
              mimeType: draft.file.type || null,
              sizeBytes: draft.file.size,
            },
          ],
          timestamp: formatMessageTimestamp(),
          deliveryState: 'sending',
        }

        console.log('[OPTIMISTIC MESSAGE]', optimisticPreviewMessage)

        setMessagesByConversation((prev) => {
          const current = prev[conversationId] ?? []
          return {
            ...prev,
            [conversationId]: upsertMessage(current, optimisticPreviewMessage),
          }
        })

        updateConversationAfterMessage(conversationId, optimisticPreviewMessage, true)
      }

      if (draft.file) {
        try {
          const uploadResult = await uploadChatMedia(accessToken, draft.file)
          console.log('[UPLOAD RESULT]', uploadResult)
          mediaUrl = uploadResult.url
          mediaThumbnailUrl = uploadResult.thumbnailUrl
          mediaMimeType = uploadResult.mimeType
          mediaSizeBytes = uploadResult.sizeBytes

          if (messageType === 'image') {
            if (!mediaUrl) {
              console.warn('[ChatPage.send] Upload finished but mediaUrl is missing for image message')
              return
            }

            const uploadedImageUrl = mediaUrl
            let previousBlobUrl: string | null = null
            setMessagesByConversation((prev) => {
              const current = prev[conversationId] ?? []
              return {
                ...prev,
                [conversationId]: current.map((message) => {
                  if (message.clientMessageId !== clientMessageId) {
                    return message
                  }

                  if (message.mediaUrl?.startsWith('blob:')) {
                    previousBlobUrl = message.mediaUrl
                  }

                  return {
                    ...message,
                    isLocal: false,
                    mediaUrl: uploadedImageUrl,
                    mediaThumbnailUrl,
                    mediaMimeType,
                    mediaSizeBytes,
                    attachments: [
                      {
                        url: uploadedImageUrl,
                        thumbnailUrl: mediaThumbnailUrl,
                        mimeType: mediaMimeType,
                        sizeBytes: mediaSizeBytes,
                      },
                    ],
                  }
                }),
              }
            })

            if (previousBlobUrl && previousBlobUrl !== uploadedImageUrl) {
              queueMicrotask(() => {
                URL.revokeObjectURL(previousBlobUrl as string)
              })
            }
          }
        } catch (error) {
          console.error('[ChatPage.send] Upload failed', error)

          if (messageType === 'image') {
            setMessagesByConversation((prev) => {
              const current = prev[conversationId] ?? []
              return {
                ...prev,
                [conversationId]: markLocalMessageFailed(current, clientMessageId),
              }
            })
          }
          return
        }
      } else if (draft.sticker) {
        mediaUrl = `sticker://${encodeURIComponent(draft.sticker.id)}`
        mediaMimeType = 'application/x-chat-sticker'
      }

      if (messageType === 'image' && !mediaUrl) {
        console.warn('[ChatPage.send] Skip optimistic image message because mediaUrl is missing')
        return
      }

      console.log('[ChatPage.send] Start:', {
        clientMessageId,
        conversationId,
        contentLength: content.length,
        messageType,
      })

      const optimisticMessage: ChatMessage = {
        id: clientMessageId,
        clientMessageId,
        conversationId,
        sender: 'me',
        senderId: user.id,
        type: messageType,
        isLocal: false,
        text: content,
        mediaUrl,
        mediaThumbnailUrl,
        mediaMimeType,
        mediaSizeBytes,
        attachments: mediaUrl
          ? [
              {
                url: mediaUrl,
                name: draft.file?.name ?? undefined,
                thumbnailUrl: mediaThumbnailUrl,
                mimeType: mediaMimeType,
                sizeBytes: mediaSizeBytes,
              },
            ]
          : undefined,
        timestamp: formatMessageTimestamp(),
        deliveryState: 'sending',
      }

      console.log('[OPTIMISTIC MESSAGE]', optimisticMessage)

      const payloadContent =
        content.trim().length > 0
          ? content
          : messageType === 'image'
            ? mediaUrl ?? '[image]'
            : messageType === 'file'
              ? draft.file?.name ?? mediaUrl ?? '[file]'
              : messageType === 'sticker'
                ? '[sticker]'
                : content

      const payload = {
        conversationId,
        content: payloadContent,
        clientMessageId,
        messageType: toSocketMessageType(messageType),
        mediaUrl,
        mediaThumbnailUrl,
        mediaMimeType,
        mediaSizeBytes,
      }

      console.log('[SEND PAYLOAD]', payload)

      if (messageType !== 'image') {
        setMessagesByConversation((prev) => {
          const current = prev[conversationId] ?? []
          return {
            ...prev,
            [conversationId]: upsertMessage(current, optimisticMessage),
          }
        })

        updateConversationAfterMessage(conversationId, optimisticMessage, true)
      }

      console.log('[ChatPage.send] Emitting message...')
      const ack = await emitSendMessage(payload)

      console.log('[ChatPage.send] ACK received:', ack, 'event:', ack?.event)

      if (ack?.event === 'message.sent' && ack?.data) {
        console.log('[ChatPage.send] Success, got message.sent')
        const mappedServerMessage = mapRawMessage(ack.data, user.id)
        const resolvedMediaUrl = mappedServerMessage.mediaUrl ?? mediaUrl ?? null
        const serverMessage: ChatMessage = {
          ...mappedServerMessage,
          clientMessageId,
          type: messageType === 'image' ? 'image' : mappedServerMessage.type,
          isLocal: false,
          mediaUrl: resolvedMediaUrl,
          mediaThumbnailUrl: mappedServerMessage.mediaThumbnailUrl ?? mediaThumbnailUrl,
          mediaMimeType: mappedServerMessage.mediaMimeType ?? mediaMimeType,
          mediaSizeBytes: mappedServerMessage.mediaSizeBytes ?? mediaSizeBytes,
          attachments: resolvedMediaUrl
            ? [
                {
                  url: resolvedMediaUrl,
                  name: draft.file?.name ?? mappedServerMessage.attachments?.[0]?.name ?? undefined,
                  thumbnailUrl: mappedServerMessage.mediaThumbnailUrl ?? mediaThumbnailUrl,
                  mimeType: mappedServerMessage.mediaMimeType ?? mediaMimeType,
                  sizeBytes: mappedServerMessage.mediaSizeBytes ?? mediaSizeBytes,
                },
              ]
            : mappedServerMessage.attachments,
          deliveryState: 'sent' as const,
        }
        setMessagesByConversation((prev) => {
          const current = prev[conversationId] ?? []
          return {
            ...prev,
            [conversationId]: upsertMessage(current, serverMessage),
          }
        })

        updateConversationAfterMessage(conversationId, serverMessage, true)
        return
      }

      console.warn('[ChatPage.send] No valid ACK, trying REST fallback /messages before marking failed')
      try {
        const restMessage = await sendMessageViaRest(accessToken, {
          conversationId,
          content: payloadContent,
          clientMessageId,
          messageType: payload.messageType,
          mediaUrl,
          mediaThumbnailUrl,
          mediaMimeType,
          mediaSizeBytes,
        })

        if (restMessage?.id) {
          console.log('[ChatPage.send] REST fallback send succeeded')
          const mappedRestMessage: ChatMessage = {
            ...mapRawMessage(restMessage, user.id),
            clientMessageId,
            deliveryState: 'sent',
          }

          setMessagesByConversation((prev) => {
            const current = prev[conversationId] ?? []
            return {
              ...prev,
              [conversationId]: upsertMessage(current, mappedRestMessage),
            }
          })

          updateConversationAfterMessage(conversationId, mappedRestMessage, true)
          return
        }
      } catch (restFallbackError) {
        console.warn('[ChatPage.send] REST fallback failed, continue reconcile flow', restFallbackError)

        const message = restFallbackError instanceof Error ? restFallbackError.message : String(restFallbackError)
        if (message.toLowerCase().includes('restricted web session cannot send messages')) {
          setMessagesByConversation((prev) => {
            const current = prev[conversationId] ?? []
            return {
              ...prev,
              [conversationId]: markLocalMessageFailed(current, clientMessageId),
            }
          })
          console.warn('[ChatPage.send] Send blocked by restricted web policy; message marked failed immediately')
          return
        }
      }

      console.warn('[ChatPage.send] No valid ACK, reconciling from API before marking failed')
      try {
        const latestRawMessages = await fetchMessages(accessToken, conversationId)
        const matchedRawMessage = latestRawMessages.find((message) => {
          const sameClientMessageId =
            message.clientMessageId === clientMessageId ||
            (message as RawMessage & { client_message_id?: string | null }).client_message_id === clientMessageId

          if (sameClientMessageId) {
            return true
          }

          return (
            (message.senderId ?? message.from ?? '') === user.id &&
            String(message.content ?? '').trim() === payloadContent.trim()
          )
        })

        if (matchedRawMessage) {
          console.log('[ChatPage.send] Message found in API after ACK timeout, marking sent')
          const reconciledMessage: ChatMessage = {
            ...mapRawMessage(matchedRawMessage, user.id),
            clientMessageId,
            deliveryState: 'sent',
          }

          setMessagesByConversation((prev) => {
            const current = prev[conversationId] ?? []
            return {
              ...prev,
              [conversationId]: upsertMessage(current, reconciledMessage),
            }
          })

          updateConversationAfterMessage(conversationId, reconciledMessage, true)
          return
        }
      } catch (reconcileError) {
        console.warn('[ChatPage.send] Reconcile after ACK timeout failed', reconcileError)
      }

      console.log('[ChatPage.send] Failed after reconcile, marking as failed')
      setMessagesByConversation((prev) => {
        const current = prev[conversationId] ?? []
        return {
          ...prev,
          [conversationId]: markLocalMessageFailed(current, clientMessageId),
        }
      })
    },
    [accessToken, emitSendMessage, isRestrictedMode, isTokenRestrictedMode, routedConversationId, selectedConversationId, updateConversationAfterMessage, user],
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

  return (
    <div className={rightSidebarContent ? 'chat-layout' : 'chat-layout chat-layout-sidebar-closed'}>
      <ChatList
        conversations={conversations}
        friendResults={friendResults}
        selectedConversationId={routedConversationId || selectedConversationId}
        onSearchFriends={handleSearchFriends}
        onOpenFriendChat={handleOpenFriendChat}
        onSelectConversation={handleSelectConversation}
      />
      <ChatWindow
        conversation={selectedConversation}
        messages={selectedMessages}
        isLoadingMessages={isLoadingMessages}
        onSend={handleSend}
        onToggleSearchSidebar={handleToggleSearchSidebar}
        onToggleInfoSidebar={handleToggleInfoSidebar}
        rightSidebarContent={rightSidebarContent}
        jumpToMessageId={jumpToMessageId}
        onJumpToMessageHandled={() => setJumpToMessageId(null)}
        isRestrictedMode={isRestrictedMode}
        peerLastReadSeq={(routedConversationId || selectedConversationId)
          ? peerLastReadByConversation[routedConversationId || selectedConversationId]
          : undefined}
        reactionStatesByMessage={reactionStatesByMessage}
        onAddReaction={handleAddReaction}
        onRemoveReaction={handleRemoveReaction}
        pinnedMessageIds={pinnedMessageIds}
        starredMessageIds={starredMessageIds}
        recalledMessageIds={recalledMessageIds}
        deletedMessageIds={deletedMessageIds}
        userProfilesById={userProfileCache}
        selectedMessageIds={selectedMessageIds}
        isMultiSelectMode={isMultiSelectMode}
        onToggleMessageSelection={toggleMessageIdInList}
        onClearMultiSelectMode={handleClearMultiSelectMode}
        onMessageContextMenuAction={handleMessageContextMenuAction}
      />
      <CreateGroupModal
        isOpen={isCreateGroupOpen}
        friends={friendsDirectory}           // Danh sách bạn bè đã load
        isSubmitting={isCreatingGroup}
        onClose={() => setIsCreateGroupOpen(false)}
        onCreate={handleCreateGroup}
      />
      {rightSidebarContent ? (
        <aside className='chat-side-panel'>
          {rightSidebarContent === 'search' && selectedConversation ? (
            <SearchMessagesPanel
              conversation={selectedConversation}
              onSearchConversation={handleSearchConversation}
              onSelectMessage={(messageId) => setJumpToMessageId(messageId)}
            />
          ) : null}

          {rightSidebarContent === 'search' && !selectedConversation ? (
            <p>{t('pages.chat.sideInfoFallback')}</p>
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

          {rightSidebarContent === 'info' ? (
            <>
              {selectedConversation ? (
                <ConversationInfo conversation={selectedConversation} messages={selectedMessages} />
              ) : (
                <p>{t('pages.chat.sideInfoFallback')}</p>
              )}
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
    </div>
  )
}
