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
import { getGroupCollageData } from '../../../shared/utils/avatarUtils'
import { ImageViewerProvider } from './ImageViewer'
import { MessageBubble } from './MessageBubble'
import { MessageGroupBubble } from './MessageGroupBubble'
import { MessageInput } from './MessageInput'
import type { MessageContextMenuAction } from './MessageContextMenu'
import { renderSystemMessage, formatMessagePreview } from '../utils/messageUtils'

const toast = {
  success: (msg: string) => alert(msg),
  error: (msg: string) => alert(msg),
  info: (msg: string) => alert(msg),
}

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
  onOpenUserProfile?: (userId: string) => void
  starredMessageIds?: Record<string, true>
  recalledMessageIds?: Record<string, true>
  deletedMessageIds?: Record<string, true>
  currentUserId?: string
  selectedMessageIds?: string[]
  isMultiSelectMode?: boolean
  onToggleMessageSelection?: (messageId: string) => void
  onClearMultiSelectMode?: () => void
  onMessageContextMenuAction?: (messageId: string, action: MessageContextMenuAction, message: ChatMessage, groupMessages?: ChatMessage[]) => void
  pinnedMessages?: ChatMessage[]
  onUnpinMessage?: (messageId: string) => void
  onTogglePin?: (message: ChatMessage) => void
  onInitiateCall?: (type: 'audio' | 'video') => void
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
  onOpenUserProfile,
  starredMessageIds = {},
  recalledMessageIds = {},
  deletedMessageIds = {},
  currentUserId,
  selectedMessageIds = [],
  isMultiSelectMode = false,
  onToggleMessageSelection,
  onClearMultiSelectMode,
  onMessageContextMenuAction,
  pinnedMessages = [],
  onUnpinMessage,
  onInitiateCall,
}: ChatWindowProps) {
  const { userMap } = useUserStore()
  const { t } = useLanguage()
  const messagesContainerRef = useRef<HTMLDivElement | null>(null)
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null)
  const [replyMessage, setReplyMessage] = useState<ChatMessage | null>(null)
  const [isPinnedExpanded, setIsPinnedExpanded] = useState(false)
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
      toast.info('Đang tải tin nhắn...')
      return
    }

    target.scrollIntoView({ behavior: 'smooth', block: 'center' })
    setHighlightedMessageId(messageId)
  }

  const handleReplyAction = (message: ChatMessage) => {
    console.log('[ChatWindow] Initiating reply to:', message.id)

    // Clean up preview text for the quote. Use the same logic as Sidebar/Preview.
    let cleanPreview = message.text;
    if (cleanPreview.startsWith('{"action":')) {
      cleanPreview = renderSystemMessage(cleanPreview, currentUserId || '', (id: string) => userMap[id]?.displayName || 'Người dùng');
    } else if (cleanPreview.startsWith('CALL_LOG::')) {
      const actorName = message.senderId === currentUserId ? 'Bạn' : (userMap[message.senderId]?.displayName || 'Người dùng');
      cleanPreview = `${actorName} đã thực hiện cuộc gọi`;
    }

    setReplyMessage({
      ...message,
      text: cleanPreview // Use cleaned text for the reply preview
    })
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

  const collageData = conversation && conversation.isGroup && !conversation.avatarUrl 
    ? getGroupCollageData(conversation, userMap) 
    : { avatars: [], extraCount: 0 }

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
              memberAvatars={collageData.avatars}
              extraCount={collageData.extraCount}
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
          <button
            className='chat-header-action-btn'
            type='button'
            onClick={() => onInitiateCall?.('audio')}
          >
            <Icon name='phone' />
          </button>
          <button
            className='chat-header-action-btn'
            type='button'
            onClick={() => onInitiateCall?.('video')}
          >
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

      {pinnedMessages.length > 0 && (
        <div className={`chat-pinned-area ${isPinnedExpanded ? 'expanded' : 'collapsed'}`}>
          {!isPinnedExpanded ? (
            <div className='pinned-item-header' onClick={() => handleJumpToMessage(pinnedMessages[0].id)}>
              <Icon name='chat' size={18} className='pinned-icon' />
              <div className='pinned-list'>
                <div className='pinned-item'>
                  <span className='pinned-label'>Tin nhắn:</span>
                  <span className='pinned-preview'>
                    {pinnedMessages[0].isPlaceholder ? 'Tin nhắn đã ghim' : formatMessagePreview(pinnedMessages[0].text, pinnedMessages[0].sender === 'me', pinnedMessages[0].type)}
                  </span>
                </div>
              </div>

              <div className='flex items-center gap-2' onClick={(e) => e.stopPropagation()}>
                {pinnedMessages.length > 1 && (
                  <button
                    className='pinned-count-pill'
                    onClick={() => setIsPinnedExpanded(true)}
                  >
                    +{pinnedMessages.length - 1} ghim
                    <Icon name='chevronDown' size={14} />
                  </button>
                )}
                <div className='pinned-item-more'>
                  <Icon name='more' size={18} />
                </div>
              </div>
            </div>
          ) : (
            <>
              <div className='flex justify-between items-center mb-2 px-1' onClick={() => setIsPinnedExpanded(false)}>
                <div className='flex items-center gap-2'>
                  <Icon name='pin' size={16} className='pinned-icon' />
                  <span className='font-bold text-sm'>Danh sách tin nhắn ghim</span>
                </div>
                <Icon name='chevronUp' size={18} className='cursor-pointer text-gray-500' />
              </div>
              <div className='pinned-list'>
                {pinnedMessages.map((msg) => (
                  <div key={msg.id} className='pinned-item' onClick={() => handleJumpToMessage(msg.id)}>
                    <Icon name='pin' size={14} className='pinned-icon' />
                    <span className='pinned-preview'>
                      {msg.isPlaceholder ? 'Tin nhắn đã ghim' : formatMessagePreview(msg.text, msg.sender === 'me', msg.type)}
                    </span>
                    <div className='pinned-actions' onClick={(e) => e.stopPropagation()}>
                      <button
                        className='pinned-action-btn'
                        title='Thêm tùy chọn'
                        onClick={async () => {
                          if (msg.text) await navigator.clipboard.writeText(msg.text)
                          // toast.success('Đã copy tin nhắn')
                        }}
                      >
                        <Icon name='copy' size={14} />
                      </button>
                      <button
                        className='pinned-action-btn pinned-action-btn-danger'
                        title='Bỏ ghim'
                        onClick={() => onUnpinMessage?.(msg.id)}
                      >
                        <Icon name='close' size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      )}

      {isMultiSelectMode && (
        <div className='chat-multiselect-banner'>
          <span>Đã chọn {selectedMessageIds.length} tin nhắn</span>
          <button type='button' onClick={onClearMultiSelectMode}>
            Hủy
          </button>
        </div>
      )}

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
            type GroupedRenderItem = {
              type: 'single' | 'group';
              items: ChatMessage[];
            };

            function getGroupedMessages(messages: ChatMessage[]): GroupedRenderItem[] {
              const groups: GroupedRenderItem[] = [];
              let currentGroup: ChatMessage[] = [];

              for (let i = 0; i < messages.length; i++) {
                const msg = messages[i];
                const prevMsg = currentGroup[currentGroup.length - 1];

                const msgIsRecalled = msg.isRecalled || recalledMessageIds[msg.id];
                const prevIsRecalled = prevMsg && (prevMsg.isRecalled || recalledMessageIds[prevMsg.id]);
                const canGroup = (msg.type === 'image' || msg.type === 'file') && !msgIsRecalled;

                const isSameSender = prevMsg && prevMsg.senderId === msg.senderId;
                const isSameType = prevMsg && prevMsg.type === msg.type;

                const getMs = (m: ChatMessage) => m.createdAt ? Date.parse(m.createdAt) : 0;
                const withinTime = prevMsg && Math.abs(getMs(msg) - getMs(prevMsg)) <= 60000;

                if (canGroup && prevMsg && !prevIsRecalled && isSameSender && isSameType && withinTime) {
                  currentGroup.push(msg);
                } else {
                  if (currentGroup.length > 0) {
                    groups.push({
                      type: currentGroup.length > 1 ? 'group' : 'single',
                      items: [...currentGroup]
                    });
                  }
                  currentGroup = [msg];
                }
              }

              if (currentGroup.length > 0) {
                groups.push({
                  type: currentGroup.length > 1 ? 'group' : 'single',
                  items: [...currentGroup]
                });
              }

              return groups;
            }

            const groupedItems = getGroupedMessages(conversationMessages);
            const renderedElements: React.ReactNode[] = [];
            let lastProcessedSenderId: string | null = null;

            groupedItems.forEach((group) => {
              const firstMsg = group.items[0];
              const lastMsg = group.items[group.items.length - 1];
              const isIncoming = firstMsg.sender !== 'me';
              const profile = userMap[firstMsg.senderId];
              const isSystem = firstMsg.type === 'system';

              // Only calculate clustering for non-system messages
              const isFirstInCluster = isSystem || (firstMsg.senderId !== lastProcessedSenderId);
              
              // Only update lastProcessedSenderId for real chat messages so that 
              // the first real message after a system message always shows an avatar.
              if (!isSystem) {
                lastProcessedSenderId = firstMsg.senderId;
              } else {
                lastProcessedSenderId = null; // Reset cluster after system message
              }

              if (group.type === 'group') {
                renderedElements.push(
                  <MessageGroupBubble
                    key={"group-" + firstMsg.id}
                    messages={group.items}
                    senderName={isIncoming ? (profile?.displayName || (conversation.isGroup ? 'Thành viên' : conversation.name)) : 'Bạn'}
                    senderAvatarUrl={isIncoming ? (profile?.avatarUrl ?? (conversation.isGroup ? null : conversation.avatarUrl) ?? null) : null}
                    showAvatar={isFirstInCluster && isIncoming}
                    showSenderName={isFirstInCluster && isIncoming && conversation.isGroup}
                    reactionStatesByMessage={reactionStatesByMessage}
                    onAddReaction={onAddReaction!}
                    onRemoveReaction={onRemoveReaction!}
                    onMessageContextMenuAction={onMessageContextMenuAction!}
                    pinnedMessages={pinnedMessages}
                    starredMessageIds={starredMessageIds}
                    recalledMessageIds={recalledMessageIds}
                    isRecalled={lastMsg.isRecalled || !!recalledMessageIds[lastMsg.id]}
                    isMultiSelectMode={isMultiSelectMode}
                    selectedMessageIds={selectedMessageIds}
                    onToggleMessageSelection={onToggleMessageSelection!}
                    peerLastReadSeq={peerLastReadSeq}
                    highlightedMessageId={highlightedMessageId}
                    currentUserId={currentUserId}
                    handleReplyAction={handleReplyAction}
                    handleJumpToMessage={handleJumpToMessage}
                    isIncoming={isIncoming}
                    isFirstInCluster={isFirstInCluster}
                    isGroupConversation={conversation.isGroup || false}
                    onOpenUserProfile={onOpenUserProfile}
                    onInitiateCall={onInitiateCall}
                  />
                );
              } else {
                const message = firstMsg;
                renderedElements.push(
                  <MessageBubble
                    key={message.id}
                    message={message}
                    reactions={reactionStatesByMessage[message.id]?.reactions ?? {}}
                    onAddReaction={(reactionKey) => onAddReaction?.(message.id, reactionKey)}
                    onRemoveReaction={(reactionKey) => onRemoveReaction?.(message.id, reactionKey)}
                    onContextMenuAction={(action, currentMsg) => onMessageContextMenuAction?.(message.id, action, currentMsg, group.items)}
                    senderName={isIncoming ? (userMap[message.senderId]?.displayName || profile?.displayName || (conversation.isGroup ? 'Thành viên' : conversation.name)) : 'Bạn'}
                    senderAvatarUrl={isIncoming ? (userMap[message.senderId]?.avatarUrl || profile?.avatarUrl || (conversation.isGroup ? null : conversation.avatarUrl) || null) : null}
                    showAvatar={isFirstInCluster && isIncoming}
                    showSenderName={isFirstInCluster && isIncoming && conversation.isGroup}
                    isPinned={pinnedMessages.some(pm => pm.id === message.id)}
                    isStarred={Boolean(starredMessageIds[message.id])}
                    isRecalled={message.isRecalled || Boolean(recalledMessageIds[message.id])}
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
                    onOpenUserProfile={onOpenUserProfile}
                    onInitiateCall={onInitiateCall}
                  />
                );
              }
            });

            return renderedElements;
          })()}
        </div>
      </ImageViewerProvider>
      {isRestrictedMode && (
        <div className='chat-restricted-banner'>
          <div className='banner-content'>
            <Icon name='info' />
            <span>Đồng bộ tin nhắn đang tắt. Web chỉ hiển thị dữ liệu mới.</span>
          </div>
          <button className='sync-button' type='button' onClick={() => onSyncHistory?.()}>
            Đồng bộ ngay
          </button>
        </div>
      )}
      {(() => {
        const currentUserRole = conversation.members?.find(m => m.userId === currentUserId)?.role;
        const isBlocked = conversation.onlyAdminCanPost && currentUserRole === 'MEMBER';

        if (isBlocked) {
          return (
            <div className="text-center text-sm text-gray-500 py-3 bg-white border-t border-gray-200">
              Chỉ Trưởng/Phó nhóm mới có thể gửi tin nhắn
            </div>
          );
        }

        return (
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
        );
      })()}
    </section>
  )
}
