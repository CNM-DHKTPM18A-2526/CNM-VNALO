import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'

import { getSyncPolicy } from '../features/auth/auth.api'
import { ChatList } from '../features/chat/components/ChatList'
import { ChatWindow } from '../features/chat/components/ChatWindow'
import {
  fetchInbox,
  fetchMessages,
  getOrCreateDirectConversation,
  mapRawMessage,
  markConversationRead,
} from '../features/chat/chat.api'
import type { RawMessage } from '../features/chat/chat.api'
import { useChatSocket } from '../features/chat/useChatSocket'
import type { ChatMessage, ConversationSummary, MessageDeliveryState } from '../features/chat/chat.types'
import { getFriends, getUserById, searchUsers } from '../features/friends/friends.api'
import type { UserLookupResult } from '../features/friends/friends.types'
import { useAuth } from '../features/auth/useAuth'
import { Icon } from '../shared/components/Icon'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { Card } from '../shared/components/ui/Card'
import { useLanguage } from '../shared/i18n/LanguageContext'

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

function upsertMessage(messages: ChatMessage[], incoming: ChatMessage): ChatMessage[] {
  const index = messages.findIndex(
    (message) =>
      message.id === incoming.id ||
      (Boolean(incoming.clientMessageId) && message.clientMessageId === incoming.clientMessageId),
  )

  if (index === -1) {
    return sortMessages([...messages, incoming])
  }

  const next = [...messages]
  const mergedDeliveryState = resolveDeliveryState(next[index].deliveryState, incoming.deliveryState)
  next[index] = {
    ...next[index],
    ...incoming,
    deliveryState: mergedDeliveryState,
  }
  return sortMessages(next)
}

function resolveDeliveryState(
  current: MessageDeliveryState | undefined,
  incoming: MessageDeliveryState | undefined,
): MessageDeliveryState | undefined {
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

const RESTRICTED_TEXT = 'Noi dung duoc an tren web do chinh sach dong bo.'

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
  const [friendResults, setFriendResults] = useState<UserLookupResult[]>([])
  const [userProfileCache, setUserProfileCache] = useState<Record<string, CachedUserProfile>>({})

  const selectedConversationIdRef = useRef('')
  const conversationsRef = useRef<ConversationSummary[]>([])
  const userProfileCacheRef = useRef<Record<string, CachedUserProfile>>({})
  const pendingProfileLookupRef = useRef<Set<string>>(new Set())
  const lastLoadedMessagesKeyRef = useRef('')
  const messageLoadRequestSeqRef = useRef(0)

  useEffect(() => {
    selectedConversationIdRef.current = selectedConversationId
  }, [selectedConversationId])

  useEffect(() => {
    conversationsRef.current = conversations
  }, [conversations])

  useEffect(() => {
    userProfileCacheRef.current = userProfileCache
  }, [userProfileCache])

  const selectedConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === selectedConversationId),
    [conversations, selectedConversationId],
  )

  const selectedMessages = useMemo(() => {
    if (!selectedConversationId) {
      return []
    }

    return messagesByConversation[selectedConversationId] ?? []
  }, [messagesByConversation, selectedConversationId])

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

  const loadInbox = useCallback(
    async (token: string, preferredConversationId?: string) => {
      setIsLoadingConversations(true)

      try {
        const [items, policy, friends] = await Promise.all([
          fetchInbox(token, user?.id),
          getSyncPolicy(token).catch(() => null),
          getFriends(token).catch(() => []),
        ])
        const restricted = Boolean(policy?.webRestrictedMode) || policy?.syncEnabled === false
        const friendNameById = new Map(
          friends
            .filter((friend) => Boolean(friend.friendId))
            .map((friend) => [friend.friendId, friend.nickname?.trim() || friend.displayName?.trim() || null]),
        )

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
          const withName = resolvedPeerName
            ? {
                ...item,
                name: resolvedPeerName,
              }
            : item

          return applyRestrictedConversationPreview(withName, restricted)
        })

        setIsRestrictedMode(restricted)
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
    [routedConversationId, user?.id],
  )

  const updateConversationAfterMessage = useCallback(
    (conversationId: string, message: ChatMessage, markAsReadNow: boolean) => {
      setConversations((prev) => {
        const index = prev.findIndex((conversation) => conversation.id === conversationId)
        if (index === -1) {
          return prev
        }

        const next = [...prev]
        const current = next[index]
        next[index] = {
          ...current,
          lastMessage: message.text,
          lastMessageSeq: message.serverSeq ?? current.lastMessageSeq,
          unreadCount: markAsReadNow ? 0 : current.unreadCount + (message.sender === 'me' ? 0 : 1),
        }

        return next
      })
    },
    [],
  )

  useEffect(() => {
    if (!accessToken) {
      setConversations([])
      setMessagesByConversation({})
      setSelectedConversationId('')
      setFriendResults([])
      lastLoadedMessagesKeyRef.current = ''
      return
    }

    void loadInbox(accessToken)
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

      try {
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

  const activeConversationId = routedConversationId || selectedConversationId

  const handleSyncHistory = useCallback(async () => {
    if (!accessToken || !activeConversationId || !user) {
      return
    }

    setIsLoadingMessages(true)
    try {
      const rawMessages = await fetchMessages(accessToken, activeConversationId, true)
      const mapped = sortMessages(
        rawMessages.map((message) => applyRestrictedMessage(mapRawMessage(message, user.id), isRestrictedMode)),
      )
      setMessagesByConversation((prev) => ({
        ...prev,
        [activeConversationId]: mapped,
      }))
      
      // Refresh inbox to update previews if needed
      void loadInbox(accessToken, activeConversationId)
    } catch (error) {
      console.error('Failed to sync history', error)
    } finally {
      setIsLoadingMessages(false)
    }
  }, [accessToken, activeConversationId, isRestrictedMode, loadInbox, user])

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
          rawMessages.map((message) => applyRestrictedMessage(mapRawMessage(message, user.id), isRestrictedMode)),
        )
        setMessagesByConversation((prev) => ({
          ...prev,
          [activeConversationId]: mapped,
        }))

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
  }, [accessToken, activeConversationId, isRestrictedMode, user])

  const { emitSendMessage, joinConversation, markAsRead } = useChatSocket({
    token: accessToken,
    onConnected: async () => {
      console.log('[ChatPage.onConnected] Socket connected, joining all conversations...')
      for (const conversation of conversationsRef.current) {
        await joinConversation(conversation.id)
      }
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
                lastMessage: mapped.text,
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

      const isActiveConversation = selectedConversationIdRef.current === mapped.conversationId
      updateConversationAfterMessage(mapped.conversationId, mapped, isActiveConversation)

      if (isActiveConversation && mapped.serverSeq !== undefined) {
        const emitted = markAsRead({ conversationId: mapped.conversationId, lastReadSeq: mapped.serverSeq })
        if (!emitted) {
          void markConversationRead(accessToken, mapped.conversationId, mapped.serverSeq).catch(() => undefined)
        }
      }
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

      setConversations((prev) =>
        prev.map((conversation) => {
          const participants = conversation.participantUserIds ?? []
          const isPeerConversation = participants.includes(payload.userId) && payload.userId !== user.id
          if (!isPeerConversation) {
            return conversation
          }

          return {
            ...conversation,
            online: payload.status === 'online',
          }
        }),
      )
    },
  })

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
    if (conversations.length === 0) {
      return
    }

    const joinAllConversations = async () => {
      console.log('[ChatPage.useEffect] Joining conversations after list updated, count:', conversations.length)
      for (const conversation of conversations) {
        const joined = await joinConversation(conversation.id)
        if (!joined) {
          console.warn('[ChatPage.useEffect] Failed to join conversation:', conversation.id)
        }
      }
    }

    joinAllConversations()
  }, [conversations, joinConversation])

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

  const handleSend = useCallback(
    async (content: string) => {
      if (!selectedConversationId || !user || !accessToken) {
        console.warn('[ChatPage.send] Precondition failed:', {
          conversationId: !!selectedConversationId,
          user: !!user,
          token: !!accessToken,
        })
        return
      }

      if (isRestrictedMode) {
        console.warn('[ChatPage.send] Restricted mode active')
        return
      }

      const clientMessageId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `${Date.now()}-${Math.random().toString(16).slice(2)}`

      console.log('[ChatPage.send] Start:', {
        clientMessageId,
        conversationId: selectedConversationId,
        contentLength: content.length,
      })

      const optimisticMessage: ChatMessage = {
        id: clientMessageId,
        clientMessageId,
        conversationId: selectedConversationId,
        sender: 'me',
        senderId: user.id,
        text: content,
        timestamp: new Date().toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        }),
        deliveryState: 'sending',
      }

      setMessagesByConversation((prev) => {
        const current = prev[selectedConversationId] ?? []
        return {
          ...prev,
          [selectedConversationId]: upsertMessage(current, optimisticMessage),
        }
      })

      updateConversationAfterMessage(selectedConversationId, optimisticMessage, true)

      console.log('[ChatPage.send] Emitting message...')
      const ack = await emitSendMessage({
        conversationId: selectedConversationId,
        content,
        clientMessageId,
      })

      console.log('[ChatPage.send] ACK received:', ack, 'event:', ack?.event)

      if (ack?.event === 'message.sent' && ack?.data) {
        console.log('[ChatPage.send] Success, got message.sent')
        const serverMessage = {
          ...mapRawMessage(ack.data, user.id),
          deliveryState: 'sent' as const,
        }
        setMessagesByConversation((prev) => {
          const current = prev[selectedConversationId] ?? []
          return {
            ...prev,
            [selectedConversationId]: upsertMessage(current, serverMessage),
          }
        })

        updateConversationAfterMessage(selectedConversationId, serverMessage, true)
        return
      }

      console.log('[ChatPage.send] Failed, no message.sent ACK')
      setMessagesByConversation((prev) => {
        const current = prev[selectedConversationId] ?? []
        return {
          ...prev,
          [selectedConversationId]: current.map((message) =>
            message.clientMessageId === clientMessageId
              ? {
                  ...message,
                  deliveryState: 'failed' as const,
                }
              : message,
          ),
        }
      })
    },
    [accessToken, emitSendMessage, isRestrictedMode, selectedConversationId, updateConversationAfterMessage, user],
  )

  if (isBootstrapping || isLoadingConversations) {
    return (
      <div className='chat-layout'>
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
        <aside className='chat-side-panel'>
          <Skeleton className='skeleton-line skeleton-line-title' />
          <Skeleton className='skeleton-line' />
          <Card className='chat-side-card'>
            <Skeleton className='skeleton-line' />
            <Skeleton className='skeleton-line skeleton-line-short' />
          </Card>
        </aside>
      </div>
    )
  }

  return (
    <div className='chat-layout'>
      <ChatList
        conversations={conversations}
        friendResults={friendResults}
        selectedConversationId={selectedConversationId}
        onSearchFriends={handleSearchFriends}
        onOpenFriendChat={handleOpenFriendChat}
        onSelectConversation={handleSelectConversation}
      />
      <ChatWindow
        conversation={selectedConversation}
        messages={selectedMessages}
        isLoadingMessages={isLoadingMessages}
        onSend={handleSend}
        onSyncHistory={handleSyncHistory}
        isRestrictedMode={isRestrictedMode}
        peerLastReadSeq={selectedConversationId ? peerLastReadByConversation[selectedConversationId] : undefined}
      />
      <aside className='chat-side-panel'>
        <div className='chat-side-head'>
          <h3>{t('pages.chat.sideInfoTitle')}</h3>
        </div>

        {selectedConversation ? (
          <Card className='chat-side-profile'>
            <UserAvatar name={selectedConversation.name} size='lg' />
            <h4>{selectedConversation.name}</h4>
            <p>{`${t('pages.chat.sideInfoWith')} ${selectedConversation.name}.`}</p>
            <div className='chat-side-quick-actions'>
              <button className='chat-side-action-btn' type='button'>
                <Icon name='phone' />
              </button>
              <button className='chat-side-action-btn' type='button'>
                <Icon name='search' />
              </button>
              <button className='chat-side-action-btn' type='button'>
                <Icon name='info' />
              </button>
            </div>
          </Card>
        ) : (
          <p>{t('pages.chat.sideInfoFallback')}</p>
        )}

        <Card className='chat-side-card'>
          <div className='chat-side-section-title'>
            <Icon name='file' />
            <p>{t('pages.chat.sharedFiles')}</p>
          </div>
          <strong>{t('pages.chat.sharedFilesCount')}</strong>
        </Card>

        <Card className='chat-side-card'>
          <div className='chat-side-section-title'>
            <Icon name='image' />
            <p>{t('pages.chat.media')}</p>
          </div>
          <strong>{t('pages.chat.mediaCount')}</strong>
        </Card>
      </aside>
    </div>
  )
}
