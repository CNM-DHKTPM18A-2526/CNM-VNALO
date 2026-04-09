import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { Socket } from 'socket.io-client'

import { getSyncPolicy } from '../features/auth/auth.api'
import { ChatList } from '../features/chat/components/ChatList'
import { ChatWindow } from '../features/chat/components/ChatWindow'
import { fetchInbox, fetchMessages, mapRawMessage, markConversationRead } from '../features/chat/chat.api'
import type { RawMessage } from '../features/chat/chat.api'
import { createChatSocket, emitSendMessage } from '../features/chat/chat.socket'
import type { ChatMessage, ConversationSummary } from '../features/chat/chat.types'
import { useAuth } from '../features/auth/useAuth'
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
  next[index] = {
    ...next[index],
    ...incoming,
  }
  return sortMessages(next)
}

const RESTRICTED_TEXT = 'Noi dung duoc an tren web do chinh sach dong bo.'

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
  const [conversations, setConversations] = useState<ConversationSummary[]>([])
  const [messagesByConversation, setMessagesByConversation] = useState<Record<string, ChatMessage[]>>({})
  const [selectedConversationId, setSelectedConversationId] = useState('')
  const [isLoadingConversations, setIsLoadingConversations] = useState(false)
  const [isLoadingMessages, setIsLoadingMessages] = useState(false)
  const [isRestrictedMode, setIsRestrictedMode] = useState(false)
  const [peerLastReadByConversation, setPeerLastReadByConversation] = useState<Record<string, number>>({})

  const socketRef = useRef<Socket | null>(null)
  const selectedConversationIdRef = useRef('')
  const conversationsRef = useRef<ConversationSummary[]>([])

  useEffect(() => {
    selectedConversationIdRef.current = selectedConversationId
  }, [selectedConversationId])

  useEffect(() => {
    conversationsRef.current = conversations
  }, [conversations])

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
      return
    }

    let isMounted = true
    setIsLoadingConversations(true)

    void Promise.all([fetchInbox(accessToken), getSyncPolicy(accessToken).catch(() => null)])
      .then(([items, policy]) => {
        if (!isMounted) {
          return
        }

        const restricted = Boolean(policy?.webRestrictedMode) || policy?.syncEnabled === false
        setIsRestrictedMode(restricted)
        const mappedItems = items.map((item) => applyRestrictedConversationPreview(item, restricted))

        setConversations(mappedItems)
        setSelectedConversationId((prev) => {
          if (prev && mappedItems.some((item) => item.id === prev)) {
            return prev
          }

          return mappedItems[0]?.id ?? ''
        })
      })
      .catch((error: unknown) => {
        console.error('Failed to fetch inbox', error)
        if (!isMounted) {
          return
        }
        setConversations([])
        setSelectedConversationId('')
      })
      .finally(() => {
        if (isMounted) {
          setIsLoadingConversations(false)
        }
      })

    return () => {
      isMounted = false
    }
  }, [accessToken])

  useEffect(() => {
    if (!accessToken || !selectedConversationId || !user) {
      return
    }

    let isMounted = true
    setIsLoadingMessages(true)

    void fetchMessages(accessToken, selectedConversationId)
      .then((rawMessages) => {
        if (!isMounted) {
          return
        }

        const mapped = sortMessages(
          rawMessages.map((message) => applyRestrictedMessage(mapRawMessage(message, user.id), isRestrictedMode)),
        )
        setMessagesByConversation((prev) => ({
          ...prev,
          [selectedConversationId]: mapped,
        }))

        const newestSeq = mapped[mapped.length - 1]?.serverSeq
        if (newestSeq !== undefined) {
          void markConversationRead(accessToken, selectedConversationId, newestSeq).catch(() => undefined)
          setConversations((prev) =>
            prev.map((conversation) =>
              conversation.id === selectedConversationId
                ? {
                    ...conversation,
                    unreadCount: 0,
                  }
                : conversation,
            ),
          )
        }
      })
      .catch((error: unknown) => {
        console.error('Failed to fetch messages', error)
      })
      .finally(() => {
        if (isMounted) {
          setIsLoadingMessages(false)
        }
      })

    return () => {
      isMounted = false
    }
  }, [accessToken, isRestrictedMode, selectedConversationId, user])

  useEffect(() => {
    if (!accessToken || !user) {
      return
    }

    const socket = createChatSocket(accessToken)
    socketRef.current = socket

    const handleConnect = () => {
      for (const conversation of conversationsRef.current) {
        socket.emit('conversation.join', { conversationId: conversation.id })
      }
    }

    socket.on('connect', handleConnect)

    socket.on('message.received', (raw: RawMessage) => {
      const mapped = applyRestrictedMessage(mapRawMessage(raw, user.id), isRestrictedMode)

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
        void markConversationRead(accessToken, mapped.conversationId, mapped.serverSeq).catch(() => undefined)
      }
    })

    socket.on('message.read', (payload: { userId: string; conversationId: string; lastReadSeq: number }) => {
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
    })

    return () => {
      socket.off('connect', handleConnect)
      socket.off('message.received')
      socket.off('message.read')
      socket.disconnect()
      socketRef.current = null
    }
  }, [accessToken, isRestrictedMode, updateConversationAfterMessage, user])

  useEffect(() => {
    const socket = socketRef.current
    if (!socket || !socket.connected || conversations.length === 0) {
      return
    }

    for (const conversation of conversations) {
      socket.emit('conversation.join', { conversationId: conversation.id })
    }
  }, [conversations])

  const handleSend = useCallback(
    async (content: string) => {
      if (!selectedConversationId || !user || !accessToken) {
        return
      }

      if (isRestrictedMode) {
        return
      }

      const socket = socketRef.current
      if (!socket) {
        return
      }

      const clientMessageId =
        typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
          ? crypto.randomUUID()
          : `${Date.now()}-${Math.random().toString(16).slice(2)}`

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
      }

      setMessagesByConversation((prev) => {
        const current = prev[selectedConversationId] ?? []
        return {
          ...prev,
          [selectedConversationId]: upsertMessage(current, optimisticMessage),
        }
      })

      updateConversationAfterMessage(selectedConversationId, optimisticMessage, true)

      const ack = await emitSendMessage(socket, {
        conversationId: selectedConversationId,
        content,
        clientMessageId,
      })

      if (ack?.event === 'message.sent' && ack?.data) {
        const serverMessage = mapRawMessage(ack.data, user.id)
        setMessagesByConversation((prev) => {
          const current = prev[selectedConversationId] ?? []
          return {
            ...prev,
            [selectedConversationId]: upsertMessage(current, serverMessage),
          }
        })

        updateConversationAfterMessage(selectedConversationId, serverMessage, true)
      }
    },
    [accessToken, isRestrictedMode, selectedConversationId, updateConversationAfterMessage, user],
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
        selectedConversationId={selectedConversationId}
        onSelectConversation={setSelectedConversationId}
      />
      <ChatWindow
        conversation={selectedConversation}
        messages={selectedMessages}
        isLoadingMessages={isLoadingMessages}
        onSend={handleSend}
        isRestrictedMode={isRestrictedMode}
        peerLastReadSeq={selectedConversationId ? peerLastReadByConversation[selectedConversationId] : undefined}
      />
      <aside className='chat-side-panel'>
        <h3>{t('pages.chat.sideInfoTitle')}</h3>
        <p>
          {selectedConversation
            ? `${t('pages.chat.sideInfoWith')} ${selectedConversation.name}.`
            : t('pages.chat.sideInfoFallback')}
        </p>
        <Card className='chat-side-card'>
          <p>{t('pages.chat.sharedFiles')}</p>
          <strong>{t('pages.chat.sharedFilesCount')}</strong>
        </Card>
        <Card className='chat-side-card'>
          <p>{t('pages.chat.media')}</p>
          <strong>{t('pages.chat.mediaCount')}</strong>
        </Card>
      </aside>
    </div>
  )
}
