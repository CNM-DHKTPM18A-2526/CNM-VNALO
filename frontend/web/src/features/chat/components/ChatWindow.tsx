import { Info, UserPlus, MoreHorizontal } from 'lucide-react'
import React from 'react'

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
import { FriendWelcomeState } from './FriendWelcomeState'
import { WelcomeScreen } from './WelcomeScreen'
import { useAuth } from '../../auth/useAuth'
import { fetchSuggestedReplies } from '../chat.api'

const toast = {
  success: (msg: string) => console.log('SUCCESS:', msg),
  error: (msg: string) => console.error('ERROR:', msg),
  info: (msg: string) => console.log('INFO:', msg),
}

const AI_WEB_DRAFT_KEY_PREFIX = 'vnalo_ai_web_compose_draft:'

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
  onVotePoll?: (messageId: string, optionId: string) => void
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
  onVotePoll,
}: ChatWindowProps) {
  const { userMap } = useUserStore()
  const { t } = useLanguage()
  const messagesContainerRef = React.useRef<HTMLDivElement | null>(null)
  const [hoveredMessageId, setHoveredMessageId] = React.useState<string | null>(null)
  const [highlightedMessageId, setHighlightedMessageId] = React.useState<string | null>(null)
  const [replyMessage, setReplyMessage] = React.useState<ChatMessage | null>(null)
  const [isPinnedExpanded, setIsPinnedExpanded] = React.useState(false)
  const [seedComposeText, setSeedComposeText] = React.useState('')
  const lastHandledJumpIdRef = React.useRef<string | null>(null)

  const { accessToken } = useAuth()
  const [suggestedReplies, setSuggestedReplies] = React.useState<string[]>([])
  const [, setIsLoadingSuggestions] = React.useState(false)

  const conversationMessages = React.useMemo(() => {
    if (!conversation) {
      return []
    }

    return messages.filter((message) => message.conversationId === conversation.id && !deletedMessageIds[message.id])
  }, [conversation, deletedMessageIds, messages])

  React.useEffect(() => {
    const conversationId = conversation?.id
    if (!conversationId || typeof window === 'undefined') {
      setSeedComposeText('')
      return
    }

    const draftKey = `${AI_WEB_DRAFT_KEY_PREFIX}${conversationId}`
    const draft = window.localStorage.getItem(draftKey)?.trim() ?? ''
    if (!draft) {
      setSeedComposeText('')
      return
    }

    setSeedComposeText(draft)
    window.localStorage.removeItem(draftKey)
  }, [conversation?.id])

  const lastMessage = conversationMessages[conversationMessages.length - 1]
  const lastMessageId = lastMessage?.id

  React.useEffect(() => {
    if (!conversation || !lastMessageId || !currentUserId || !accessToken) {
      setSuggestedReplies([])
      return
    }

    // Only suggest replies if the last message was sent by someone else
    if (lastMessage.senderId === currentUserId) {
      setSuggestedReplies([])
      return
    }

    // Ignore system/call messages or placeholders
    if (lastMessage.text?.startsWith('{"action":') || lastMessage.text?.startsWith('CALL_LOG::') || lastMessage.isPlaceholder) {
      setSuggestedReplies([])
      return
    }

    const fetchSuggestions = async () => {
      setIsLoadingSuggestions(true)
      try {
        const formattedHistory = conversationMessages
          .filter(m => m.text && !m.text.startsWith('{"action":') && !m.text.startsWith('CALL_LOG::'))
          .slice(-10)
          .map(m => ({
            role: (m.senderId === currentUserId ? 'assistant' : 'user') as 'user' | 'assistant',
            content: m.text
          }))

        if (formattedHistory.length > 0) {
          const replies = await fetchSuggestedReplies(accessToken, formattedHistory)
          setSuggestedReplies(replies)
        } else {
          setSuggestedReplies([])
        }
      } catch (error) {
        console.error('Failed to load suggestions:', error)
        setSuggestedReplies([])
      } finally {
        setIsLoadingSuggestions(false)
      }
    }

    const timer = setTimeout(() => {
      fetchSuggestions()
    }, 500)

    return () => clearTimeout(timer)
  }, [lastMessageId, conversation?.id, currentUserId, accessToken])

  const viewerImages = React.useMemo<ViewerImageItem[]>(() => {
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

  React.useEffect(() => {
    if (!conversation?.id) {
      return
    }

    onLoadConversationMessages?.(conversation.id)
  }, [conversation?.id, onLoadConversationMessages])

  // 1. Initial scroll to bottom when switching conversation or finishing initial load
  React.useEffect(() => {
    if (!conversation || isLoadingMessages) {
      return
    }

    const container = messagesContainerRef.current
    if (!container) return

    container.scrollTop = container.scrollHeight
  }, [conversation?.id, isLoadingMessages])

  // 2. Smart scroll for new messages in the CURRENT conversation
  React.useEffect(() => {
    if (!conversation || isLoadingMessages) {
      return
    }

    const container = messagesContainerRef.current
    if (!container) return

    const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 200
    const lastMessageIsMine = conversationMessages.length > 0 && conversationMessages[conversationMessages.length - 1].sender === 'me'

    if (isNearBottom || lastMessageIsMine) {
      container.scrollTop = container.scrollHeight
    }
  }, [conversationMessages.length])

  React.useEffect(() => {
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

  React.useEffect(() => {
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
        <WelcomeScreen />
      </section>
    )
  }

  const isOnline = conversation.online
  const lastSeenTime = conversation.lastSeenTime ?? conversation.updatedAt ?? conversation.lastMessageAt ?? null
  const statusText = isOnline ? 'Đang hoạt động' : formatPresence(false, lastSeenTime)
  const isStranger = Boolean(conversation.isStranger)

  const peerId = !conversation.isGroup && !conversation.isCloud 
    ? (conversation.userId || (conversation.participantUserIds || []).find(id => id !== currentUserId))
    : null
  
  const displayName = conversation.isGroup 
    ? conversation.name 
    : (userMap[peerId || '']?.displayName || conversation.name)

  const collageData = conversation && conversation.isGroup && !conversation.avatarUrl
    ? getGroupCollageData(conversation, userMap)
    : { avatars: [], extraCount: 0 }

  const currentUserRole = conversation.members?.find(m => m.userId === currentUserId)?.role;
  const allowMemberPin = conversation.allowMemberPin;

  return (
    <section className='chat-window'>
      <header className='chat-window-header'>
        <div className='chat-window-header-main'>
          <div className='relative'>
            <UserAvatar
              name={displayName ?? ''}
              imageUrl={(!conversation.isGroup && peerId ? userMap[peerId]?.avatarUrl : conversation.avatarUrl) ?? conversation.avatarUrl ?? null}
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
            <h2>{displayName ?? ''}</h2>
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
          {!conversation.isCloud && (
            <>
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
            </>
          )}
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
      
      {isStranger && (
        <div className="chat-stranger-banner">
          <div className="chat-stranger-banner-left">
            <UserPlus size={20} />
            <span>Gửi yêu cầu kết bạn tới người này</span>
          </div>
          <div className="chat-stranger-banner-actions">
            <button 
              className="chat-stranger-banner-btn chat-stranger-banner-btn-primary"
              onClick={() => {
                const peerId = conversation.userId || conversation.members?.find(m => m.userId !== currentUserId)?.userId;
                if (peerId) onOpenUserProfile?.(peerId);
              }}
            >
              Gửi kết bạn
            </button>
            <div className="chat-stranger-banner-more">
              <MoreHorizontal size={20} />
            </div>
          </div>
        </div>
      )}

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

            // Add FriendWelcomeState at the top for 1-on-1 conversations
            const isOneOnOne = !conversation.isGroup && !conversation.isCloud;
            if (isOneOnOne) {
              const peerId = conversation.userId || conversation.members?.find(m => m.userId !== currentUserId)?.userId;
              const peerProfile = peerId ? userMap[peerId] : null;
              const myProfile = currentUserId ? userMap[currentUserId] : null;

              renderedElements.push(
                <FriendWelcomeState 
                  key="welcome-header"
                  currentUser={{
                    displayName: myProfile?.displayName || 'Bạn',
                    avatarUrl: myProfile?.avatarUrl
                  }}
                  user={{
                    id: peerId || '',
                    displayName: conversation.name,
                    avatarUrl: conversation.avatarUrl,
                    bio: peerProfile?.bio || '',
                    recentImages: conversation.avatarUrl ? [conversation.avatarUrl] : []
                   }}
                   onSendSticker={(sticker) => {
                      onSend({
                        text: '',
                        files: [],
                        sticker: { id: sticker.id, name: sticker.name, url: sticker.url }
                      });
                   }}
                   isStranger={isStranger}
                />
              );
            }

            if (conversationMessages.length === 0 && !isOneOnOne) {
              return (
                <EmptyState
                  title={t('chat.windowEmptyTitle')}
                  description={t('chat.windowEmptyDesc')}
                />
              );
            }

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
                    userRole={currentUserRole}
                    allowMemberPin={allowMemberPin}
                    onVotePoll={onVotePoll}
                    hoveredMessageId={hoveredMessageId}
                    setHoveredMessageId={setHoveredMessageId}
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
                    userRole={currentUserRole}
                    allowMemberPin={allowMemberPin}
                    onVotePoll={onVotePoll}
                    hoveredMessageId={hoveredMessageId}
                    setHoveredMessageId={setHoveredMessageId}
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
        const currentUserRole = String(conversation.members?.find(m => String(m.userId) === String(currentUserId))?.role || '').toUpperCase();
        const isBlocked = !!conversation.onlyAdminCanPost && currentUserRole === 'MEMBER';

        if (isBlocked) {
          return (
            <div className="flex items-center justify-center gap-3 py-4 bg-[var(--surface)] border-t border-[var(--border)] animate-in fade-in slide-in-from-bottom-2 duration-300">
              <div className="flex items-center justify-center w-8 h-8 rounded-full bg-blue-50 text-blue-500">
                <Info size={20} />
              </div>
              <p className="text-[14.5px] text-[var(--text-secondary)]">
                Chỉ <span className="text-blue-500 font-medium cursor-pointer hover:underline">trưởng/phó nhóm</span> được gửi tin nhắn vào cộng đồng.{" "}
                <span className="text-blue-500 font-medium cursor-pointer hover:underline">Tìm hiểu thêm</span>
              </p>
            </div>
          );
        }

        return (
          <MessageInput
            onSend={(payload) => {
              onSend(payload);
              setReplyMessage(null);
              setSuggestedReplies([]);
            }}
            replyMessage={replyMessage}
            onCancelReply={() => setReplyMessage(null)}
            recipientName={displayName}
            placeholder={isRestrictedMode ? 'Tin nhắn bị khóa khi ở chế độ giới hạn' : undefined}
            disabled={isRestrictedMode}
            suggestedReplies={suggestedReplies}
            onSelectSuggestedReply={() => setSuggestedReplies([])}
            initialText={seedComposeText}
            members={conversation.members?.map(m => ({
              userId: m.userId,
              displayName: userMap[m.userId]?.displayName || m.displayName || 'Người dùng',
              avatarUrl: userMap[m.userId]?.avatarUrl || m.avatarUrl
            })) || []}
          />
        );
      })()}
    </section>
  )
}
