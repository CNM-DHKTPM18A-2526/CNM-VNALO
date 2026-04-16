import { MoreHorizontal, Pin, Reply, Share2, Star } from 'lucide-react'
import { useEffect, useRef, useState, type MouseEvent as ReactMouseEvent } from 'react'

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

function getMessageMediaUrl(message: ChatMessage): string | null {
  return message.mediaUrl ?? message.attachments?.[0]?.url ?? null
}

function isImageAttachment(mimeType?: string | null, type?: string) {
  return type === 'image' || mimeType?.startsWith('image/')
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
  isGroupedWithNext?: boolean
  currentUserId?: string
  onReply?: () => void
  onJumpToOriginal?: (messageId: string) => void
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
  currentUserId,
  onReply,
  onJumpToOriginal,
}: MessageBubbleProps) {
  const { userMap } = useUserStore()
  const { openImageViewerByMessageId } = useImageViewer()
  const stickerSrc = message.type === 'sticker' ? resolveStickerSrc(message) : null
  const attachments = message.attachments ?? []
  const imageAttachments = attachments.filter((attachment) => isImageAttachment(attachment.mimeType))
  const fileAttachments = attachments.filter((attachment) => !isImageAttachment(attachment.mimeType))

  const stackRef = useRef<HTMLDivElement | null>(null)
  const contextMenuTriggerRef = useRef<HTMLButtonElement | null>(null)
  const contextMenuRef = useRef<HTMLDivElement | null>(null)

  const isMyMessage = message.sender === 'me'

  // Visual grouping classes
  const groupingClasses = [
    isGroupedWithPrevious ? 'message-grouped-prev' : '',
    isGroupedWithNext ? 'message-grouped-next' : '',
  ].filter(Boolean).join(' ')

  const hideTimerRef = useRef<number | null>(null)
  const [supportsHover, setSupportsHover] = useState(true)
  const [isMessageHovered, setIsMessageHovered] = useState(false)
  const [isMessageTapped, setIsMessageTapped] = useState(false)
  const [isReactionBarOpen, setIsReactionBarOpen] = useState(false)
  const [isContextMenuOpen, setIsContextMenuOpen] = useState(false)
  const [contextMenuPosition, setContextMenuPosition] = useState({ top: 0, left: 0 })

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
    setIsMessageHovered(true)
    if (hideTimerRef.current) {
      window.clearTimeout(hideTimerRef.current)
      hideTimerRef.current = null
    }
  }

  const handleContainerMouseLeave = () => {
    if (isReactionBarOpen || isContextMenuOpen) return
    hideTimerRef.current = window.setTimeout(() => {
      setIsMessageHovered(false)
    }, HOVER_HIDE_DELAY_MS)
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
    setIsMessageHovered(false)
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
  const showReactionTrigger = isReactionBarOpen || (supportsHover ? isMessageHovered : isMessageTapped)
  const quickReactionEmoji = REACTION_OPTIONS.find((item) => item.key === quickReaction)?.emoji ?? '❤️'

  if (message.type === 'system') {
    const getDisplayName = (id: string) => {
      if (id === currentUserId) return 'Bạn'
      return userMap[id]?.displayName || 'Người dùng'
    }
    const systemText = formatMessage(message, currentUserId || '', getDisplayName)

    return (
      <div
        data-message-id={message.id}
        className="w-full flex justify-center my-3"
      >
        <span
          className="text-[13px] text-[#596677] leading-[18px] text-center"
          dangerouslySetInnerHTML={{
            __html: systemText.replace(/\*\*(.*?)\*\*/g, '<strong class="font-semibold text-slate-800">$1</strong>')
          }}
        />
      </div>
    )
  }

  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'} data-message-id={message.id}>
      {!isMyMessage ? (
        <div className={showAvatar ? 'message-row-avatar' : 'message-row-avatar message-row-avatar-spacer'}>
          {showAvatar ? <UserAvatar name={senderName || 'Người dùng'} imageUrl={senderAvatarUrl} size='sm' /> : null}
        </div>
      ) : null}
      <div
        ref={stackRef}
        className='message-stack'
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
          />
        ) : null}

        <article
          className={
            isMyMessage
              ? `message-bubble message-bubble-me ${groupingClasses}${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''}`
              : `message-bubble ${groupingClasses}${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''}`
          }
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
              className={`message-reply-quote mb-2 p-2 rounded bg-black/5 border-l-2 border-blue-500 cursor-pointer hover:bg-black/10 transition-colors`}
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
              <p className="text-xs text-slate-500 truncate line-clamp-1">
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

                return (
                  <button
                    key={att.url + idx}
                    type='button'
                    className={`message-bubble-media message-bubble-image relative border-0 bg-transparent p-0 overflow-hidden ${isStaircaseBottom ? 'col-span-2' : ''}`}
                    onClick={(event) => {
                      event.preventDefault()
                      event.stopPropagation()
                      openImageViewerByMessageId(message.id)
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

          {!isRecalled && (fileAttachments.length > 0) && (
            <div className='message-bubble-attachments message-bubble-files flex flex-col gap-2 mt-1'>
              {fileAttachments.map((att, idx) => (
                <a
                  key={att.url + idx}
                  className='message-file-card'
                  href={att.url}
                  target='_blank'
                  rel='noreferrer'
                >
                  <span className='message-file-icon'>
                    <Icon name='attach' />
                  </span>
                  <span className='message-file-meta'>
                    <strong>{att.name || 'Tệp đính kèm'}</strong>
                    <span>{att.mimeType || 'Ứng dụng'}</span>
                  </span>
                </a>
              ))}
            </div>
          )}

          {!isRecalled && message.type === 'sticker' && stickerSrc ? (
            <img className='message-bubble-media message-bubble-sticker' src={stickerSrc} alt={message.text || 'Sticker'} />
          ) : null}

          {!isRecalled && message.text && (
            <p className={message.type === 'text' ? '' : 'mt-2'}>{formatMessageContent(message.text)}</p>
          )}

          {!isGroupedWithNext && (
            <time>
              {message.timestamp}
              {statusLabel}
            </time>
          )}
        </article>

        <MessageReactionSummary reactions={reactions} onRemoveReaction={onRemoveReaction} />
      </div>
    </div>
  )
}
