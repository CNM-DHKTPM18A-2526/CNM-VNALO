import { MoreHorizontal, Pin, Reply, Share2, Star } from 'lucide-react'
import React, { useEffect, useState, type MouseEvent as ReactMouseEvent } from 'react'

import type { ChatMessage, MessageReactionMap, ReactionKey } from '../chat.types'
import { REACTION_OPTIONS } from '../chat.constants'
import { Icon } from '../../../shared/components/Icon'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { DEFAULT_CHAT_STICKERS } from '../chat.stickers'
import { useImageViewer } from '../context/ImageViewerContext'
import { MessageReactionBar, MessageReactionSummary } from './MessageReaction'
import { MessageContextMenu, type MessageContextMenuAction } from './MessageContextMenu'
import { formatMessage, formatMessageContent } from '../utils/messageUtils'
import { useUserStore } from '../context/UserStoreContext'
import { CallLogBubble } from './CallLogBubble'
import { PollBubble } from './PollBubble'

function getMessageMediaUrl(message: ChatMessage): string | null {
  return message.mediaUrl ?? message.attachments?.[0]?.url ?? null
}

function isImageAttachment(mimeType?: string | null, url?: string | null, name?: string | null, type?: string) {
  if (type === 'image' || mimeType?.startsWith('image/')) {
    return true
  }

  const check = (str?: string | null) => {
    if (!str) return false
    const pathname = str.toLowerCase().split('?')[0].split('#')[0]
    return /\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)$/.test(pathname)
  }

  return check(url) || check(name)
}

function isVideoAttachment(mimeType?: string | null, url?: string | null, name?: string | null, type?: string) {
  if (type === 'video' || mimeType?.startsWith('video/')) {
    return true
  }

  const check = (str?: string | null) => {
    if (!str) return false
    const pathname = str.toLowerCase().split('?')[0].split('#')[0]
    return /\.(mp4|webm|ogv|mov|m4v|3gp|mkv)$/.test(pathname)
  }

  return check(url) || check(name)
}

function resolveStickerSrc(message: ChatMessage): string | null {
  const mediaSrc = getMessageMediaUrl(message)
  if (mediaSrc?.startsWith('sticker://')) {
    const stickerId = decodeURIComponent(mediaSrc.slice('sticker://'.length))
    const sticker = DEFAULT_CHAT_STICKERS.find((item) => item.id === stickerId)
    return sticker?.url ?? null
  }

  return mediaSrc
}

type MessageBubbleProps = {
  message: ChatMessage
  senderName?: string
  senderAvatarUrl?: string | null
  showAvatar?: boolean
  showSenderName?: boolean
  quickReaction?: ReactionKey
  reactions: MessageReactionMap
  onAddReaction: (reactionKey: ReactionKey) => void
  onRemoveReaction: (reactionKey: ReactionKey) => void
  onContextMenuAction?: (action: MessageContextMenuAction, message: ChatMessage) => void
  isPinned?: boolean
  isStarred?: boolean
  isRecalled?: boolean
  isMultiSelectMode?: boolean
  isSelected?: boolean
  onToggleSelection?: () => void
  isReadByPeer?: boolean
  isHighlighted?: boolean
  isGroupedWithPrevious?: boolean
  isVirtualGroup?: boolean
  groupedMessages?: ChatMessage[]
  currentUserId?: string
  onReply?: () => void
  onJumpToOriginal?: (messageId: string) => void
  onOpenUserProfile?: (userId: string) => void
  onInitiateCall?: (type: 'audio' | 'video') => void
  isGroupedWithNext?: boolean
  userRole?: string
  allowMemberPin?: boolean
  onVotePoll?: (messageId: string, optionId: string) => void
  hoveredMessageId?: string | null
  setHoveredMessageId?: (messageId: string | null) => void
}

const HOVER_HIDE_DELAY_MS = 180

export function MessageBubble({
  message,
  senderName,
  senderAvatarUrl = null,
  showAvatar = true,
  showSenderName = false,
  quickReaction,
  reactions,
  onAddReaction,
  onRemoveReaction,
  onContextMenuAction,
  isPinned = false,
  isStarred = false,
  isRecalled = false,
  isMultiSelectMode = false,
  isSelected = false,
  onToggleSelection,
  isReadByPeer = false,
  isHighlighted = false,
  isGroupedWithPrevious = false,
  isGroupedWithNext = false,
  isVirtualGroup = false,
  groupedMessages = [],
  currentUserId,
  onReply,
  onJumpToOriginal,
  onOpenUserProfile,
  onInitiateCall,
  userRole,
  allowMemberPin,
  onVotePoll,
  hoveredMessageId = null,
  setHoveredMessageId,
}: MessageBubbleProps) {
  const { userMap } = useUserStore()
  const { openImageViewerByMessageId } = useImageViewer()
  const stickerSrc = message.type === 'sticker' ? resolveStickerSrc(message) : null
  const attachments = message.attachments ?? []
  const isImageMsg = message.type === 'image'
  const imageAttachments = attachments.filter((attachment) => 
    isImageMsg || isImageAttachment(attachment.mimeType, attachment.url, attachment.name)
  )
  const isVideoMsg = message.type === 'video'
  const videoAttachments = attachments.filter((attachment) => 
    isVideoMsg || isVideoAttachment(attachment.mimeType, attachment.url, attachment.name)
  )
  const fileAttachments = attachments.filter((attachment) => 
    !isImageMsg && !isVideoMsg &&
    !isImageAttachment(attachment.mimeType, attachment.url, attachment.name) &&
    !isVideoAttachment(attachment.mimeType, attachment.url, attachment.name)
  )

  const stackRef = useRef<HTMLDivElement | null>(null)
  const contextMenuTriggerRef = useRef<HTMLButtonElement | null>(null)
  const contextMenuRef = useRef<HTMLDivElement | null>(null)

  const isMyMessage = message.sender === 'me'

  // Visual grouping classes
  const groupingClasses = [
    isGroupedWithPrevious ? 'message-grouped-prev' : '',
    isGroupedWithNext ? 'message-grouped-next' : '',
  ].filter(Boolean).join(' ')

  const handleAvatarClick = (e: ReactMouseEvent) => {
    e.stopPropagation()
    const targetUserId = isMyMessage ? currentUserId : message.senderId
    if (targetUserId) {
      onOpenUserProfile?.(targetUserId)
    }
  }

  const hideTimerRef = useRef<number | null>(null)
  const [supportsHover, setSupportsHover] = useState(true)
  const [isMessageHovered, setIsMessageHovered] = useState(false)
  const [isMessageTapped, setIsMessageTapped] = useState(false)
  const [isReactionBarOpen, setIsReactionBarOpen] = useState(false)
  const [isContextMenuOpen, setIsContextMenuOpen] = useState(false)
  const [contextMenuPosition, setContextMenuPosition] = useState({ top: 0, left: 0 })
  const isHoverToolbarActive = hoveredMessageId === message.id

  const statusLabel = (() => {
    if (message.sender !== 'me') {
      return ''
    }

    if (message.deliveryState === 'failed') {
      return ' • Lỗi gửi'
    }

    if (message.deliveryState === 'sending') {
      return ' • Đang gửi'
    }

    if (message.deliveryState === 'read' || isReadByPeer) {
      return ' • Đã xem'
    }

    return ' • Đã gửi'
  })()

  const handleContainerMouseEnter = () => {
    if (!supportsHover || isRecalled) return
    setHoveredMessageId?.(message.id)
    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current)
      hideTimerRef.current = null
    }
  }

  const handleContainerMouseLeave = (e?: ReactMouseEvent) => {
    // If context menu is open, don't auto-close here; menu manages its own lifecycle.
    if (isContextMenuOpen) return

    const related = (e?.relatedTarget ?? null) as Node | null
    const stack = stackRef.current

    // If pointer moved into an element inside this stack (including reaction popover), keep it open
    if (related && stack && stack.contains(related)) {
      return
    }

    // If the reaction bar is currently open, we may be transitioning into it; give a short grace period
    // so users can move the pointer into the popover without it immediately closing.
    if (isReactionBarOpen) {
      if (hideTimerRef.current) {
        window.clearTimeout(hideTimerRef.current)
      }
      hideTimerRef.current = window.setTimeout(() => {
        if (hoveredMessageId === message.id) {
          setHoveredMessageId?.(null)
        }
        hideTimerRef.current = null
      }, 250)
      return
    }

    // Otherwise (reaction bar not open), clear hover state immediately for snappy UX
    if (hoveredMessageId === message.id) {
      setHoveredMessageId?.(null)
    }
    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current)
      hideTimerRef.current = null
    }
  }

  const clearHideTimer = () => {
    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current)
      hideTimerRef.current = null
    }
  }

  const closeReactionUi = () => {
    setIsReactionBarOpen(false)
    setIsMessageTapped(false)
    if (hoveredMessageId === message.id) {
      setHoveredMessageId?.(null)
    }
  }

  const closeContextMenu = () => {
    setIsContextMenuOpen(false)
  }

  const handleReactionAdd = (reactionKey: ReactionKey) => {
    onAddReaction(reactionKey)
    if (!supportsHover) {
      setIsReactionBarOpen(false)
    }
  }

  const handleMessageTap = (event: ReactMouseEvent<HTMLElement>) => {
    if (isMultiSelectMode) {
      const target = event.target as HTMLElement
      if (target.closest('a, button')) {
        return
      }

      onToggleSelection?.()
      return
    }

    if (supportsHover) {
      return
    }

    const target = event.target as HTMLElement
    if (target.closest('a, button')) {
      return
    }

    // Mobile fallback: tap message first to reveal quick-reaction trigger.
    setIsMessageTapped(true)
  }

  const handleReactionTriggerHover = () => {
    clearHideTimer()
    setIsReactionBarOpen(true)
  }

  const handleReactionTriggerClick = () => {
    clearHideTimer()
    setIsReactionBarOpen((prev) => !prev)
    setIsMessageTapped(true)
  }

  const handleContextMenuTriggerClick = (event: ReactMouseEvent<HTMLButtonElement>) => {
    event.preventDefault()
    event.stopPropagation()

    const triggerRect = event.currentTarget.getBoundingClientRect()
    const estimatedWidth = 256
    const estimatedHeight = isMyMessage ? 330 : 294
    const gap = 10
    const viewportPadding = 12

    const preferredTop = triggerRect.top - estimatedHeight - gap
    const fallbackTop = triggerRect.bottom + gap
    const top = preferredTop >= viewportPadding ? preferredTop : fallbackTop

    const left = isMyMessage
      ? triggerRect.left - estimatedWidth - gap
      : triggerRect.right + gap

    const clampedLeft = Math.min(
      Math.max(left, viewportPadding),
      window.innerWidth - estimatedWidth - viewportPadding,
    )

    setContextMenuPosition({
      top: Math.min(Math.max(top, viewportPadding), window.innerHeight - estimatedHeight - viewportPadding),
      left: clampedLeft,
    })
    setIsContextMenuOpen((prev) => !prev)
    closeReactionUi()
  }

  const handleContextMenuAction = (action: MessageContextMenuAction) => {
    if (action === 'reply') {
      onReply?.()
      return
    }

    if ((action === 'recallGroup' || action === 'deleteGroupSelf') && isVirtualGroup && groupedMessages) {
      // We pass the current message but the handler in parent should know it's a group action
      // and use groupedMessages instead of just the message.id.
      // However, to make it explicit, we'll pass groupedMessages as a 3rd arg if we modify the type.
      // For now, let's keep it simple: pass the last message (which is what 'message' is in synthetic case)
      // and rely on the parent having access to the group (which it does via its own state).
      // Actually, easier to just pass the group here if we can.
    }

    onContextMenuAction?.(action, message)
  }

  const handleShareClick = (event: ReactMouseEvent<HTMLButtonElement>) => {
    event.preventDefault()
    event.stopPropagation()
    closeContextMenu()
    closeReactionUi()
    onContextMenuAction?.('share', message)
  }

  useEffect(() => {
    const mediaQuery = window.matchMedia('(hover: hover) and (pointer: fine)')

    const applyMode = () => {
      setSupportsHover(mediaQuery.matches)
      if (mediaQuery.matches) {
        setIsMessageTapped(false)
      }
    }

    applyMode()
    mediaQuery.addEventListener('change', applyMode)

    return () => {
      mediaQuery.removeEventListener('change', applyMode)
    }
  }, [])

  useEffect(() => {
    if (!isHoverToolbarActive) {
      setIsReactionBarOpen(false)
      setIsMessageTapped(false)
    }
  }, [isHoverToolbarActive])

  useEffect(() => {
    const onPointerDown = (event: PointerEvent) => {
      const stack = stackRef.current
      if (!stack) {
        return
      }

      const target = event.target as Node
      if (!stack.contains(target)) {
        closeReactionUi()
        closeContextMenu()
      }
    }

    window.addEventListener('pointerdown', onPointerDown)

    return () => {
      window.removeEventListener('pointerdown', onPointerDown)
    }
  }, [isReactionBarOpen, isContextMenuOpen])

  useEffect(() => {
    if (!isContextMenuOpen) {
      return
    }

    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as Node
      if (contextMenuRef.current?.contains(target) || contextMenuTriggerRef.current?.contains(target)) {
        return
      }

      closeContextMenu()
    }

    const onEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeContextMenu()
      }
    }

    const onWindowChange = () => {
      closeContextMenu()
    }

    window.addEventListener('pointerdown', onPointerDown)
    window.addEventListener('keydown', onEscape)
    window.addEventListener('scroll', onWindowChange, true)
    window.addEventListener('resize', onWindowChange)

    return () => {
      window.removeEventListener('pointerdown', onPointerDown)
      window.removeEventListener('keydown', onEscape)
      window.removeEventListener('scroll', onWindowChange, true)
      window.removeEventListener('resize', onWindowChange)
    }
  }, [isContextMenuOpen])

  useEffect(() => {
    return () => {
      clearHideTimer()
    }
  }, [])

  // Desktop uses hover state, mobile uses tap state.
  const showReactionTrigger = isReactionBarOpen || (supportsHover ? isHoverToolbarActive : isMessageTapped)
  const quickReactionEmoji = REACTION_OPTIONS.find((item) => item.key === quickReaction)?.emoji ?? '❤️'

  const isModerator = userRole?.toUpperCase() === 'ADMIN' || userRole?.toUpperCase() === 'DEPUTY'

  if (message.type === 'system') {
    const getDisplayName = (id: string) => {
      if (id === currentUserId) return 'Bạn'
      return userMap[id]?.displayName || 'Người dùng'
    }

    // Silent Leave Group logic: Only show to Moderators if payload has silent: true
    try {
      const payload = JSON.parse(message.text || '{}');
      if (payload.action === 'LEAVE_GROUP' && payload.silent && !isModerator) {
        return null;
      }
    } catch (e) {
      // Not a JSON payload or missing action, continue normally
    }

    const systemText = formatMessage(message, currentUserId || '', getDisplayName)

    if (!systemText) return null

    return (
      <div
        data-message-id={message.id}
        className="w-full flex justify-center my-3"
      >
        <span
          className="text-[13px] text-[var(--text-secondary)] leading-[18px] text-center"
          dangerouslySetInnerHTML={{
            __html: systemText.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold text-[var(--text)]">$1</strong>')
          }}
        />
      </div>
    )
  }

  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'} data-message-id={message.id}>
      {!isMyMessage ? (
        <div
          className={showAvatar ? 'message-row-avatar cursor-pointer hover:opacity-80 transition-opacity' : 'message-row-avatar message-row-avatar-spacer'}
          onClick={showAvatar ? handleAvatarClick : undefined}
        >
          {showAvatar ? <UserAvatar name={senderName || 'Người dùng'} imageUrl={senderAvatarUrl} size='sm' /> : null}
        </div>
      ) : null}
      <div
        ref={stackRef}
        className={isHoverToolbarActive ? 'message-stack message-stack-hover-active' : 'message-stack'}
        onMouseEnter={handleContainerMouseEnter}
        onMouseLeave={handleContainerMouseLeave}
      >
        {isReactionBarOpen ? (
          <div
            className={`message-reaction-pop absolute -top-[62px] z-30 ${message.sender === 'me' ? 'right-2' : 'left-2'}`}
            onMouseEnter={clearHideTimer}
            onMouseLeave={handleContainerMouseLeave}
          >
            <MessageReactionBar
              reactions={reactions}
              onAddReaction={handleReactionAdd}
              onRemoveReaction={onRemoveReaction}
              onOpenFullEmoji={() => {
                setIsReactionBarOpen(false)
              }}
            />
          </div>
        ) : null}

        {showReactionTrigger ? (
          <button
            type='button'
            className='absolute -bottom-3 -right-3 z-20 flex h-7 w-7 items-center justify-center rounded-full border border-slate-200 bg-white text-sm shadow-[0_4px_14px_rgba(15,23,42,0.12)] transition hover:scale-105'
            onMouseEnter={handleReactionTriggerHover}
            onClick={handleReactionTriggerClick}
            aria-label='Mở thanh reaction'
          >
            {quickReactionEmoji}
          </button>
        ) : null}

        <div className={isMyMessage ? 'message-action-toolbar message-action-toolbar-me' : 'message-action-toolbar'}>
          <button
            type='button'
            className='message-reply-trigger'
            onClick={(e) => {
              e.stopPropagation()
              onReply?.()
            }}
            aria-label='Trả lời tin nhắn'
          >
            <Reply />
          </button>

          <button
            type='button'
            className='message-share-trigger'
            onClick={handleShareClick}
            aria-label='Chia sẻ tin nhắn'
          >
            <Share2 />
          </button>

          <button
            ref={contextMenuTriggerRef}
            type='button'
            className='message-context-menu-trigger'
            onClick={handleContextMenuTriggerClick}
            aria-label='Mở menu tin nhắn'
            aria-expanded={isContextMenuOpen}
          >
            <MoreHorizontal />
          </button>
        </div>

        {isContextMenuOpen ? (
          <MessageContextMenu
            ref={contextMenuRef}
            message={message}
            isMyMessage={isMyMessage}
            position={contextMenuPosition}
            onClose={closeContextMenu}
            onAction={handleContextMenuAction}
            isVirtualGroup={isVirtualGroup}
            isPinned={isPinned}
            userRole={userRole}
            allowMemberPin={allowMemberPin}
          />
        ) : null}

        <article
          className={
            isMyMessage
              ? `message-bubble message-bubble-me ${groupingClasses}${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''} ${message.type === 'call' ? 'message-bubble-call' : ''}`
              : `message-bubble ${groupingClasses}${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''} ${message.type === 'call' ? 'message-bubble-call' : ''}`
          }
          style={message.type === 'call' ? { background: 'none', border: 'none', padding: 0, boxShadow: 'none' } : {}}
          onClick={handleMessageTap}
        >
          {!isMyMessage && showSenderName ? <div className='message-sender-name'>{senderName || 'Người dùng'}</div> : null}

          {isPinned || isStarred ? (
            <div className='message-bubble-flag-row'>
              {isPinned ? (
                <span className='message-bubble-flag message-bubble-flag-pin'>
                  <Pin size={11} />
                  Ghim
                </span>
              ) : null}
              {isStarred ? (
                <span className='message-bubble-flag message-bubble-flag-star'>
                  <Star size={11} />
                  Đánh dấu
                </span>
              ) : null}
            </div>
          ) : null}

          {!isRecalled && message.replyTo && (
            <div
              className={`message-reply-quote mb-2 p-2 rounded bg-black/5 border-l-2 border-blue-500 cursor-pointer hover:bg-black/10 transition-colors max-w-[240px] overflow-hidden`}
              onClick={(e) => {
                e.stopPropagation();
                if (message.replyTo) onJumpToOriginal?.(message.replyTo.id);
              }}
            >
              <p className="text-[11px] font-bold text-blue-600 truncate">
                {message.replyTo.senderId && userMap[message.replyTo.senderId]
                  ? userMap[message.replyTo.senderId].displayName
                  : message.replyTo.senderName}
              </p>
              <p className="text-xs text-slate-500 line-clamp-1 overflow-hidden whitespace-nowrap overflow-ellipsis">
                {message.replyTo.preview}
              </p>
            </div>
          )}

          {isRecalled ? (
            <div className='message-recalled-state'>
              <span className='message-recalled-pill'>
                <Pin size={11} />
                Tin nhắn đã được thu hồi
              </span>
            </div>
          ) : null}

          {!isRecalled && (imageAttachments.length > 0) && (
            <div className={
              imageAttachments.length === 1 ? 'message-bubble-images-single' :
                imageAttachments.length === 2 ? 'message-bubble-images-grid grid-cols-2 gap-1' :
                  imageAttachments.length === 3 ? 'message-bubble-images-staircase grid grid-cols-2 gap-1' :
                    'message-bubble-images-grid grid-cols-2 gap-1'
            }>
              {imageAttachments.map((att, idx) => {
                // Special layout for 3 images: first 2 are small (top), 3rd is big (bottom span 2)
                const isStaircaseBottom = imageAttachments.length === 3 && idx === 2;

                // If it's a virtual group, each attachment actually belongs to a message in groupedMessages
                const originalMessageId = (att as any).originalMessageId || message.id;

                return (
                  <button
                    key={(att.url + idx) || originalMessageId}
                    type='button'
                    className={`message-bubble-media message-bubble-image relative border-0 bg-transparent p-0 overflow-hidden ${isStaircaseBottom ? 'col-span-2' : ''}`}
                    onClick={(event) => {
                      event.preventDefault()
                      event.stopPropagation()
                      openImageViewerByMessageId(originalMessageId)
                    }}
                    onContextMenu={(_e) => {
                      if (isVirtualGroup && groupedMessages.length > 0) {
                        const targetMsg = groupedMessages.find(m => m.id === originalMessageId) || message;
                        onContextMenuAction?.('recall', targetMsg); // Default action just to trigger handleContextMenu from child if possible
                        // More accurately, we'd want to trigger the context menu for that message.
                      }
                    }}
                    aria-label={`Xem ảnh ${idx + 1}`}
                  >
                    <img
                      src={att.url}
                      alt='chat-image'
                      className='chat-image object-cover w-full h-full'
                      loading='eager'
                      decoding='async'
                      style={{
                        maxHeight: imageAttachments.length === 1 ? '320px' : (isStaircaseBottom ? '200px' : '120px'),
                        borderRadius: '4px',
                        background: '#f1f5f9',
                        border: '1px solid rgba(0,0,0,0.05)',
                      }}
                    />
                    <span className='absolute top-1 left-1 bg-black/40 text-white text-[9px] px-1 rounded font-bold backdrop-blur-sm'>HD</span>
                    {idx === 3 && imageAttachments.length > 4 && (
                      <div className='absolute inset-0 bg-black/50 flex items-center justify-center text-white font-bold text-lg'>
                        +{imageAttachments.length - 3}
                      </div>
                    )}
                  </button>
                );
              })}
            </div>
          )}

          {!isRecalled && (videoAttachments.length > 0) && (
            <div className='message-bubble-video flex flex-col gap-2 mt-1'>
               {videoAttachments.map((att, idx) => {
                 return (
                   <video 
                     key={att.url + idx}
                     src={att.url} 
                     controls 
                     preload="metadata"
                     className='max-w-full rounded-lg border border-slate-200 shadow-sm transition-all hover:shadow-md'
                     style={{ maxHeight: '300px', background: '#000' }}
                   />
                 );
               })}
            </div>
          )}

          {!isRecalled && (fileAttachments.length > 0) && (
            <div className='message-bubble-attachments message-bubble-files flex flex-col gap-2 mt-1'>
              {fileAttachments.map((att, idx) => {
                const originalMessageId = (att as any).originalMessageId || message.id;
                return (
                  <a
                    key={(att.url + idx) || originalMessageId}
                    className='message-file-card'
                    href={att.url}
                    target='_blank'
                    rel='noreferrer'
                  >
                    <span className='message-file-icon'>
                      <Icon name='attach' />
                    </span>
                    <span className='message-file-meta'>
                      <strong>{att.name || 'Tệp tin'}</strong>
                      <span>{att.mimeType || 'Ứng dụng'}</span>
                    </span>
                  </a>
                );
              })}
            </div>
          )}

          {!isRecalled && message.type === 'sticker' && stickerSrc ? (
            <img className='message-bubble-media message-bubble-sticker' src={stickerSrc} alt={message.text || 'Sticker'} />
          ) : null}

          {!isRecalled && (
            message.type === 'call' ? (
              <CallLogBubble 
                message={message} 
                currentUserId={currentUserId} 
                onInitiateCall={onInitiateCall} 
              />
            ) : (message.text || message.type === 'poll') ? (
              <>
                {(message.type !== 'file' || !(message.attachments && message.attachments[0] && message.text === message.attachments[0].name)) && message.text ? (
                  <div className={`${message.type === 'text' ? '' : 'mt-2'} whitespace-pre-wrap break-words overflow-hidden flex items-center gap-2`}>
                    <span>
                      {message.text.split(/(\u200B@.*?\u200B)/g).map((part, i) => {
                        if (part.startsWith('\u200B@')) {
                          const content = part.replace(/\u200B/g, '').substring(1); // Remove markers and leading @
                          const [displayName, userId] = content.split('|');
                          
                          return (
                            <span 
                              key={i} 
                              className="text-[#0068ff] font-medium cursor-pointer hover:underline"
                              onClick={(e) => {
                                e.stopPropagation();
                                if (userId) onOpenUserProfile?.(userId);
                              }}
                            >
                              @{displayName}
                            </span>
                          );
                        }
                        // Use formatMessageContent for regular text to handle call logs etc.
                        return <span key={i}>{formatMessageContent(part, currentUserId)}</span>;
                      })}
                    </span>
                  </div>
                ) : null}

                {message.type === 'poll' && message.pollData && (
                  <div className="mt-2 min-w-[240px]">
                    <PollBubble 
                      poll={message.pollData}
                      isMyMessage={isMyMessage}
                      currentUserId={currentUserId}
                      onVote={(optionId) => onVotePoll?.(message.id, optionId)}
                      reactions={reactions}
                    />
                  </div>
                )}
              </>
            ) : null
          )}

          <time>
            {isPinned && <Icon name='pin' size={10} className='message-pin-icon inline-block mr-1' />}
            {message.timestamp}
            {statusLabel}
          </time>
        </article>

        <MessageReactionSummary 
          reactions={reactions} 
          onRemoveReaction={onRemoveReaction} 
          isIncoming={!isMyMessage} 
        />
      </div>
    </div>
  )
}
