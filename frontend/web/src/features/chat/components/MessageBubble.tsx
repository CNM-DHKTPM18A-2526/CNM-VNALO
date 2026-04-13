import { MoreHorizontal, Pin, Star } from 'lucide-react'
import { useEffect, useRef, useState, type MouseEvent as ReactMouseEvent } from 'react'

import type { ChatMessage } from '../chat.types'
import { Icon } from '../../../shared/components/Icon'
import { DEFAULT_CHAT_STICKERS } from '../chat.stickers'
import { useImageViewer } from './ImageViewer'
import { MessageReactionBar, MessageReactionSummary, REACTION_OPTIONS, type MessageReactionMap, type ReactionKey } from './MessageReaction'
import { MessageContextMenu, type MessageContextMenuAction } from './MessageContextMenu'

function getFileName(url?: string | null): string {
  if (!url) {
    return 'Tệp đính kèm'
  }

  try {
    const pathname = new URL(url).pathname
    const fileName = pathname.split('/').filter(Boolean).pop()
    return fileName || 'Tệp đính kèm'
  } catch {
    return 'Tệp đính kèm'
  }
}

function getMessageMediaUrl(message: ChatMessage): string | null {
  return message.mediaUrl ?? message.attachments?.[0]?.url ?? null
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
}

const HOVER_HIDE_DELAY_MS = 180

export function MessageBubble({
  message,
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
}: MessageBubbleProps) {
  const { openImageViewerByMessageId } = useImageViewer()
  const mediaSrc = getMessageMediaUrl(message)
  const stickerSrc = message.type === 'sticker' ? resolveStickerSrc(message) : null
  const stackRef = useRef<HTMLDivElement | null>(null)
  const contextMenuTriggerRef = useRef<HTMLButtonElement | null>(null)
  const contextMenuRef = useRef<HTMLDivElement | null>(null)
  const hideTimerRef = useRef<number | null>(null)
  const [supportsHover, setSupportsHover] = useState(true)
  const [isMessageHovered, setIsMessageHovered] = useState(false)
  const [isMessageTapped, setIsMessageTapped] = useState(false)
  const [isReactionBarOpen, setIsReactionBarOpen] = useState(false)
  const [isContextMenuOpen, setIsContextMenuOpen] = useState(false)
  const [contextMenuPosition, setContextMenuPosition] = useState({ top: 0, left: 0 })

  const isMyMessage = message.sender === 'me'

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

  const clearHideTimer = () => {
    if (hideTimerRef.current === null) {
      return
    }

    window.clearTimeout(hideTimerRef.current)
    hideTimerRef.current = null
  }

  const closeReactionUi = () => {
    setIsReactionBarOpen(false)
    setIsMessageTapped(false)
    setIsMessageHovered(false)
  }

  const closeContextMenu = () => {
    setIsContextMenuOpen(false)
  }

  const scheduleHideReactionUi = () => {
    clearHideTimer()
    hideTimerRef.current = window.setTimeout(() => {
      closeReactionUi()
    }, HOVER_HIDE_DELAY_MS)
  }

  const handleContainerMouseEnter = () => {
    if (!supportsHover) {
      return
    }

    clearHideTimer()
    setIsMessageHovered(true)
  }

  const handleContainerMouseLeave = () => {
    if (!supportsHover) {
      return
    }

    scheduleHideReactionUi()
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
    if (action === 'copy') {
      return
    }

    onContextMenuAction?.(action, message)
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
      if (stack.contains(target)) {
        return
      }

      closeReactionUi()
    }

    window.addEventListener('pointerdown', onPointerDown)

    return () => {
      window.removeEventListener('pointerdown', onPointerDown)
    }
  }, [])

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
  const quickReactionEmoji = REACTION_OPTIONS.find((item) => item.key === quickReaction)?.emoji ?? '👍'

  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'} data-message-id={message.id}>
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

          <button
            ref={contextMenuTriggerRef}
            type='button'
            className={isMyMessage ? 'message-context-menu-trigger message-context-menu-trigger-me' : 'message-context-menu-trigger'}
            onClick={handleContextMenuTriggerClick}
            aria-label='Mở menu tin nhắn'
            aria-expanded={isContextMenuOpen}
          >
            <MoreHorizontal />
          </button>

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
              ? `message-bubble message-bubble-me${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''}`
              : `message-bubble${isHighlighted ? ' message-bubble-highlight' : ''}${isSelected ? ' message-bubble-selected' : ''}`
          }
          onClick={handleMessageTap}
        >
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

        {isRecalled ? (
          <div className='message-recalled-state'>
            <span className='message-recalled-pill'>
              <Pin size={11} />
              Tin nhắn đã được thu hồi
            </span>
          </div>
        ) : null}

        {!isRecalled && message.type === 'image' ? (
          mediaSrc ? (
            <>
              <button
                type='button'
                className='message-bubble-media message-bubble-image border-0 bg-transparent p-0'
                onClick={(event) => {
                  event.preventDefault()
                  event.stopPropagation()
                  openImageViewerByMessageId(message.id)
                }}
                aria-label='Xem ảnh toàn màn hình'
              >
                <img
                  src={mediaSrc}
                  alt='chat-image'
                  className='chat-image'
                  loading='eager'
                  decoding='async'
                  style={{
                    width: '220px',
                    maxWidth: '100%',
                    height: 'auto',
                    borderRadius: '10px',
                    background: '#f1f5f9',
                    border: '1px solid #dbe3ef',
                  }}
                />
              </button>
              {message.text ? <p>{message.text}</p> : null}
            </>
          ) : (
            <p>Image not available</p>
          )
        ) : null}

        {!isRecalled && message.type === 'sticker' && stickerSrc ? (
          <>
            <img className='message-bubble-media message-bubble-sticker' src={stickerSrc} alt={message.text || 'Sticker'} />
            {message.text ? <p>{message.text}</p> : null}
          </>
        ) : null}

        {!isRecalled && message.type === 'file' ? (
          <>
            <a
              className='message-file-card'
              href={message.mediaUrl ?? message.attachments?.[0]?.url ?? '#'}
              target='_blank'
              rel='noreferrer'
            >
              <span className='message-file-icon'>
                <Icon name='attach' />
              </span>
              <span className='message-file-meta'>
                <strong>{message.attachments?.[0]?.name ?? getFileName(message.mediaUrl ?? message.attachments?.[0]?.url)}</strong>
                <span>{message.mediaMimeType ?? message.attachments?.[0]?.mimeType ?? 'Tệp đính kèm'}</span>
              </span>
            </a>
            {message.text ? <p>{message.text}</p> : null}
          </>
        ) : null}

        {!isRecalled && message.type === 'text' ? <p>{message.text}</p> : null}

        <time>
          {message.timestamp}
          {statusLabel}
        </time>
        </article>

        <MessageReactionSummary reactions={reactions} onRemoveReaction={onRemoveReaction} />
      </div>
    </div>
  )
}
