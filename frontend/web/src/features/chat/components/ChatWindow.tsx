import { useEffect, useMemo, useRef, useState } from 'react'

import { EmptyState } from '../../../shared/components/EmptyState'
import { Icon } from '../../../shared/components/Icon'
import { LoadingState } from '../../../shared/components/LoadingState'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
import type { ChatComposePayload, ChatMessage, ConversationSummary } from '../chat.types'
import { formatPresence } from '../utils/presenceUtils'
import type { MessageReactionState, ReactionKey } from './MessageReaction'
import { ImageViewerProvider, type ViewerImageItem } from './ImageViewer'
import { MessageBubble } from './MessageBubble'
import { MessageInput } from './MessageInput'
import type { MessageContextMenuAction } from './MessageContextMenu'

type ChatWindowProps = {
  conversation: ConversationSummary | undefined
  messages: ChatMessage[]
  isLoadingMessages: boolean
  onSend: (message: ChatComposePayload) => void
  onToggleSearchSidebar: () => void
  onToggleInfoSidebar: () => void
  onSyncHistory?: () => void
  rightSidebarContent: 'info' | 'search' | 'global-search' | null
  jumpToMessageId?: string | null
  onJumpToMessageHandled?: () => void
  isRestrictedMode?: boolean
  peerLastReadSeq?: number
  reactionStatesByMessage?: Record<string, MessageReactionState>
  onAddReaction?: (messageId: string, reactionKey: ReactionKey) => void
  onRemoveReaction?: (messageId: string, reactionKey: ReactionKey) => void
  pinnedMessageIds?: Record<string, true>
  starredMessageIds?: Record<string, true>
  recalledMessageIds?: Record<string, true>
  deletedMessageIds?: Record<string, true>
  userProfilesById?: Record<string, { displayName: string; avatarUrl: string | null }>
  selectedMessageIds?: string[]
  isMultiSelectMode?: boolean
  onToggleMessageSelection?: (messageId: string) => void
  onClearMultiSelectMode?: () => void
  onMessageContextMenuAction?: (messageId: string, action: MessageContextMenuAction, message: ChatMessage) => void
}

export function ChatWindow({
  conversation,
  messages,
  isLoadingMessages,
  onSend,
  onToggleSearchSidebar,
  onToggleInfoSidebar,
  onSyncHistory,
  rightSidebarContent,
  jumpToMessageId = null,
  onJumpToMessageHandled,
  isRestrictedMode = false,
  peerLastReadSeq,
  reactionStatesByMessage = {},
  onAddReaction,
  onRemoveReaction,
  pinnedMessageIds = {},
  starredMessageIds = {},
  recalledMessageIds = {},
  deletedMessageIds = {},
  userProfilesById = {},
  selectedMessageIds = [],
  isMultiSelectMode = false,
  onToggleMessageSelection,
  onClearMultiSelectMode,
  onMessageContextMenuAction,
}: ChatWindowProps) {
  const { t } = useLanguage()
  const messagesContainerRef = useRef<HTMLDivElement | null>(null)
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null)
  const lastHandledJumpIdRef = useRef<string | null>(null)

  const conversationMessages = useMemo(() => {
    if (!conversation) {
      return []
    }

    return messages.filter((message) => message.conversationId === conversation.id && !deletedMessageIds[message.id])
  }, [conversation, deletedMessageIds, messages])

  const viewerImages = useMemo<ViewerImageItem[]>(() => {
    if (!conversation) {
      return []
    }

    return conversationMessages
      .filter((message) => message.type === 'image')
      .map((message) => {
        const url = message.mediaUrl ?? message.attachments?.[0]?.url ?? null
        if (!url) {
          return null
        }

        return {
          messageId: message.id,
          url,
          senderName: message.sender === 'me' ? 'Bạn' : conversation.name,
          timestamp: message.timestamp,
        }
      })
      .filter((item): item is ViewerImageItem => Boolean(item))
  }, [conversation, conversationMessages])

  useEffect(() => {
    if (!conversation || isLoadingMessages) {
      return
    }

    const container = messagesContainerRef.current
    if (!container) {
      return
    }

    container.scrollTop = container.scrollHeight
  }, [conversation, conversationMessages.length, isLoadingMessages])

  useEffect(() => {
    if (!jumpToMessageId || lastHandledJumpIdRef.current === jumpToMessageId) {
      return
    }

    const container = messagesContainerRef.current
    if (!container) {
      return
    }

    const target = container.querySelector(`[data-message-id="${jumpToMessageId}"]`) as HTMLElement | null
    if (!target) {
      return
    }

    target.scrollIntoView({ behavior: 'smooth', block: 'center' })
    setHighlightedMessageId(jumpToMessageId)
    lastHandledJumpIdRef.current = jumpToMessageId
    onJumpToMessageHandled?.()
  }, [conversationMessages, jumpToMessageId, onJumpToMessageHandled])

  useEffect(() => {
    if (!highlightedMessageId) {
      return
    }

    const timerId = window.setTimeout(() => {
      setHighlightedMessageId(null)
    }, 1800)

    return () => {
      window.clearTimeout(timerId)
    }
  }, [highlightedMessageId])

  if (!conversation) {
    return (
      <section className='chat-window'>
        <EmptyState
          title={t('chat.windowEmptyTitle')}
          description={t('chat.windowEmptyDesc')}
        />
      </section>
    )
  }

  const isOnline = conversation.online
  const lastSeenTime = conversation.lastSeenTime ?? conversation.updatedAt ?? conversation.lastMessageAt ?? null
  const statusText = isOnline ? 'Đang hoạt động' : formatPresence(false, lastSeenTime)
  const isStranger = Boolean(conversation.isStranger)

  console.log('[ChatWindow.mode]', {
    conversationId: conversation.id,
    isRestrictedMode,
    statusText,
  })

  console.log('[ChatWindow.presence]', {
    conversationId: conversation.id,
    online: conversation.online,
    lastSeenTime: conversation.lastSeenTime,
    updatedAt: conversation.updatedAt,
    lastMessageAt: conversation.lastMessageAt,
    resolvedIsOnline: isOnline,
    resolvedLastSeenTime: lastSeenTime,
    statusText,
  })

  return (
    <section className='chat-window'>
      <header className='chat-window-header'>
        <div className='chat-window-header-main'>
          <div className='relative'>
            <UserAvatar
              name={conversation.name}
              imageUrl={conversation.avatarUrl ?? null}
              size='md'
              isGroup={conversation.isGroup}
              isCloud={conversation.isCloud}
            />
            {isOnline && !conversation.isCloud && (
              <span className='absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-white rounded-full' />
            )}
          </div>
          <div className='chat-window-header-copy'>
            <h2>{conversation.name}</h2>
            <div className='chat-window-header-meta'>
              {isStranger ? <span className='chat-stranger-badge'>Người lạ</span> : null}
              {conversation.isCloud ? (
                <p>Lưu và đồng bộ dữ liệu giữa các thiết bị</p>
              ) : conversation.isGroup ? (
                <p>{conversation.memberCount || 0} thành viên</p>
              ) : (
                <p>{statusText}</p>
              )}
            </div>
          </div>
        </div>
        <div className='chat-window-header-actions'>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='phone' />
          </button>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='video' />
          </button>
          <button
            className={rightSidebarContent === 'search' || rightSidebarContent === 'global-search' ? 'chat-header-action-btn chat-header-action-btn-active' : 'chat-header-action-btn'}
            type='button'
            onClick={onToggleSearchSidebar}
            aria-pressed={rightSidebarContent === 'search' || rightSidebarContent === 'global-search'}
          >
            <Icon name='search' />
          </button>
          <button
            className={rightSidebarContent === 'info' ? 'chat-header-action-btn chat-header-action-btn-active' : 'chat-header-action-btn'}
            type='button'
            onClick={onToggleInfoSidebar}
            aria-pressed={rightSidebarContent === 'info'}
            title='Bật/tắt thông tin hội thoại'
          >
            <Icon name='layoutSidebar' />
          </button>
        </div>
      </header>
      {isMultiSelectMode ? (
        <div className='chat-multiselect-banner'>
          <span>Đã chọn {selectedMessageIds.length} tin nhắn</span>
          <button type='button' onClick={onClearMultiSelectMode}>
            Hủy
          </button>
        </div>
      ) : null}
      <ImageViewerProvider images={viewerImages}>
        <div className='chat-window-messages' ref={messagesContainerRef}>
          {isLoadingMessages ? (
            <LoadingState label={t('chat.loadingConversation')} />
          ) : conversationMessages.length === 0 ? (
            <EmptyState
              title={t('chat.windowEmptyTitle')}
              description={t('chat.windowEmptyDesc')}
            />
          ) : (
            conversationMessages.map((message, index) => {
              const previous = index > 0 ? conversationMessages[index - 1] : null
              const profile = userProfilesById[message.senderId]
              const isIncoming = message.sender !== 'me'
              const isFirstInCluster =
                !previous ||
                previous.sender !== message.sender ||
                previous.senderId !== message.senderId
              const resolvedSenderName = isIncoming
                ? profile?.displayName || (conversation.isGroup ? 'Thành viên' : conversation.name)
                : 'Bạn'
              const resolvedSenderAvatar = isIncoming
                ? (profile?.avatarUrl ?? (conversation.isGroup ? null : conversation.avatarUrl) ?? null)
                : null

              return (
                <MessageBubble
                  key={message.id}
                  message={message}
                  senderName={resolvedSenderName}
                  senderAvatarUrl={resolvedSenderAvatar}
                  showAvatar={isIncoming ? isFirstInCluster : false}
                  showSenderName={isIncoming && conversation.isGroup ? isFirstInCluster : false}
                  reactions={reactionStatesByMessage[message.id]?.reactions ?? {}}
                  quickReaction={reactionStatesByMessage[message.id]?.lastUsedReaction}
                  onAddReaction={(reactionKey) => onAddReaction?.(message.id, reactionKey)}
                  onRemoveReaction={(reactionKey) => onRemoveReaction?.(message.id, reactionKey)}
                  onContextMenuAction={(action, currentMessage) => onMessageContextMenuAction?.(message.id, action, currentMessage)}
                  isHighlighted={highlightedMessageId === message.id}
                  isPinned={Boolean(pinnedMessageIds[message.id])}
                  isStarred={Boolean(starredMessageIds[message.id])}
                  isRecalled={Boolean(recalledMessageIds[message.id])}
                  isMultiSelectMode={isMultiSelectMode}
                  isSelected={selectedMessageIds.includes(message.id)}
                  onToggleSelection={() => onToggleMessageSelection?.(message.id)}
                  isReadByPeer={
                    message.sender === 'me' &&
                    message.serverSeq !== undefined &&
                    peerLastReadSeq !== undefined &&
                    message.serverSeq <= peerLastReadSeq
                  }
                />
              )
            })
          )}
        </div>
      </ImageViewerProvider>
      {isRestrictedMode ? (
        <div className='chat-restricted-banner'>
          <div className='banner-content'>
            <Icon name='info' />
            <span>Đồng bộ tin nhắn đang tắt. Web chỉ hiển thị dữ liệu mới.</span>
          </div>
          <button className='sync-button' type='button' onClick={() => onSyncHistory?.()}>
            Đồng bộ ngay
          </button>
        </div>
      ) : null}
      <MessageInput
        onSend={onSend}
        recipientName={conversation.name}
        placeholder={isRestrictedMode ? 'Tin nhắn bị khóa khi ở chế độ giới hạn' : undefined}
        disabled={isRestrictedMode}
      />
    </section>
  )
}
