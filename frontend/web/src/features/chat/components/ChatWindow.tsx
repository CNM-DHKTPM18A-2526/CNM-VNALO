import { useEffect, useMemo, useRef, useState } from 'react'

import { EmptyState } from '../../../shared/components/EmptyState'
import { Icon } from '../../../shared/components/Icon'
import { LoadingState } from '../../../shared/components/LoadingState'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
import type {
  ChatComposePayload,
  ChatMessage,
  ConversationSummary,
  MessageReactionState,
  ReactionKey,
  ViewerImageItem,
} from '../chat.types'
import { useUserStore } from '../context/UserStoreContext'
import { formatPresence } from '../utils/presenceUtils'
import { ImageViewerProvider } from './ImageViewer'
import { MessageBubble } from './MessageBubble'
import { MessageInput } from './MessageInput'
import type { MessageContextMenuAction } from './MessageContextMenu'

type ChatWindowProps = {
  conversation: ConversationSummary | undefined
  messages: ChatMessage[]
  isLoadingMessages: boolean
  onLoadConversationMessages?: (conversationId: string) => void
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
  currentUserId?: string
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
  onLoadConversationMessages,
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
  currentUserId,
  selectedMessageIds = [],
  isMultiSelectMode = false,
  onToggleMessageSelection,
  onClearMultiSelectMode,
  onMessageContextMenuAction,
}: ChatWindowProps) {
  const { userMap } = useUserStore()
  const { t } = useLanguage()
  const messagesContainerRef = useRef<HTMLDivElement | null>(null)
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null)
  const [replyMessage, setReplyMessage] = useState<ChatMessage | null>(null)
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
    if (!conversation?.id) {
      return
    }

    onLoadConversationMessages?.(conversation.id)
  }, [conversation?.id, onLoadConversationMessages])

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

    // Use requestAnimationFrame to avoid synchronous setState in effect warning
    requestAnimationFrame(() => {
      if (lastHandledJumpIdRef.current !== jumpToMessageId) {
        setHighlightedMessageId(jumpToMessageId)
      }
    })

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

  const handleJumpToMessage = (messageId: string) => {
    const container = messagesContainerRef.current
    if (!container) return

    const target = container.querySelector(`[data-message-id="${messageId}"]`) as HTMLElement | null
    if (!target) {
      alert('Tin nhắn không tồn tại hoặc đã cũ')
      return
    }

    target.scrollIntoView({ behavior: 'smooth', block: 'center' })
    setHighlightedMessageId(messageId)
  }

  const handleReplyAction = (message: ChatMessage) => {
    console.log('[ChatWindow] Initiating reply to:', message.id)
    setReplyMessage(message)
  }

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
                <p>{conversation.memberCount || (conversation.participantUserIds?.length ? conversation.participantUserIds.length + 1 : 0)} thành viên</p>
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
          ) : (() => {
            // Virtual Grouping Logic (Zalo-style Album)
            const renderedElements: React.ReactNode[] = [];
            const processedIds = new Set<string>();

            for (let i = 0; i < conversationMessages.length; i++) {
              const message = conversationMessages[i];
              if (processedIds.has(message.id)) continue;

              const profile = userMap[message.senderId];
              const isIncoming = message.sender !== 'me';
              const previous = i > 0 ? conversationMessages[i - 1] : null;

              const isFirstInCluster =
                !previous ||
                previous.sender !== message.sender ||
                previous.senderId !== message.senderId;

              // Identify if this is a media message that can be bundled
              const isImage = message.type === 'image';

              if (isImage && !recalledMessageIds[message.id]) {
                const group: ChatMessage[] = [message];
                let j = i + 1;
                while (j < conversationMessages.length) {
                  const nextMsg = conversationMessages[j];
                  const timeDiff = Math.abs(Date.parse(nextMsg.timestamp) - Date.parse(message.timestamp));

                  if (
                    nextMsg.sender === message.sender &&
                    nextMsg.type === 'image' &&
                    !recalledMessageIds[nextMsg.id] &&
                    timeDiff < 30000
                  ) {
                    group.push(nextMsg);
                    processedIds.add(nextMsg.id);
                    j++;
                  } else {
                    break;
                  }
                }

                if (group.length > 1) {
                  const virtualMessage: ChatMessage = {
                    ...message,
                    attachments: group.map(m => ({
                      url: m.mediaUrl || m.attachments?.[0]?.url || "",
                      name: m.attachments?.[0]?.name || "Ảnh",
                      mimeType: m.mediaMimeType || "image/jpeg",
                      sizeBytes: m.mediaSizeBytes || 0,
                      thumbnailUrl: m.mediaThumbnailUrl || null
                    })) as any
                  };

                  renderedElements.push(
                    <MessageBubble
                      key={"group-" + message.id}
                      message={virtualMessage}
                      reactions={reactionStatesByMessage[message.id]?.reactions ?? {}}
                      onAddReaction={(reactionKey) => onAddReaction?.(message.id, reactionKey)}
                      onRemoveReaction={(reactionKey) => onRemoveReaction?.(message.id, reactionKey)}
                      onContextMenuAction={(action, currentMsg) => onMessageContextMenuAction?.(message.id, action, currentMsg)}
                      senderName={isIncoming ? (profile?.displayName || (conversation.isGroup ? 'Thành viên' : conversation.name)) : 'Bạn'}
                      senderAvatarUrl={isIncoming ? (profile?.avatarUrl ?? (conversation.isGroup ? null : conversation.avatarUrl) ?? null) : null}
                      showAvatar={isFirstInCluster && isIncoming}
                      showSenderName={isFirstInCluster && isIncoming && conversation.isGroup}
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
                      isHighlighted={highlightedMessageId === message.id}
                      currentUserId={currentUserId}
                    />
                  );
                  continue;
                }
              }

              // Normal message rendering
              renderedElements.push(
                <MessageBubble
                  key={message.id}
                  message={message}
                  reactions={reactionStatesByMessage[message.id]?.reactions ?? {}}
                  onAddReaction={(reactionKey) => onAddReaction?.(message.id, reactionKey)}
                  onRemoveReaction={(reactionKey) => onRemoveReaction?.(message.id, reactionKey)}
                  onContextMenuAction={(action, currentMsg) => onMessageContextMenuAction?.(message.id, action, currentMsg)}
                  senderName={isIncoming ? (userMap[message.senderId]?.displayName || profile?.displayName || (conversation.isGroup ? 'Thành viên' : conversation.name)) : 'Bạn'}
                  senderAvatarUrl={isIncoming ? (userMap[message.senderId]?.avatarUrl || profile?.avatarUrl || (conversation.isGroup ? null : conversation.avatarUrl) || null) : null}
                  showAvatar={isFirstInCluster && isIncoming}
                  showSenderName={isFirstInCluster && isIncoming && conversation.isGroup}
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
                  isHighlighted={highlightedMessageId === message.id}
                  currentUserId={currentUserId}
                  onReply={() => handleReplyAction(message)}
                  onJumpToOriginal={(id) => handleJumpToMessage(id)}
                />
              );
            }
            return renderedElements;
          })()}
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
        onSend={(payload) => {
          onSend(payload);
          setReplyMessage(null);
        }}
        replyMessage={replyMessage}
        onCancelReply={() => setReplyMessage(null)}
        recipientName={conversation.name}
        placeholder={isRestrictedMode ? 'Tin nhắn bị khóa khi ở chế độ giới hạn' : undefined}
        disabled={isRestrictedMode}
      />
    </section>
  )
}
