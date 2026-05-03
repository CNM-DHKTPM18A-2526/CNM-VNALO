import React from 'react'
import { CheckSquare2, ChevronRight, Copy, Info, Pin, RotateCcw, Star, Trash2 } from 'lucide-react'

import type { CSSProperties } from 'react'

import type { ChatMessage } from '../chat.types'

export type MessageContextMenuAction = 'reply' | 'copy' | 'share' | 'pin' | 'star' | 'multiSelect' | 'details' | 'more' | 'recall' | 'deleteSelf' | 'recallGroup' | 'deleteGroupSelf'

type MessageContextMenuPosition = {
  top: number
  left: number
}

type MessageContextMenuProps = {
  message: ChatMessage
  isMyMessage: boolean
  position: MessageContextMenuPosition
  onClose: () => void
  onAction?: (action: MessageContextMenuAction) => void
  isVirtualGroup?: boolean
  isPinned?: boolean
  userRole?: string
  allowMemberPin?: boolean
}

type MenuItemConfig = {
  action: MessageContextMenuAction
  label: string
  icon: typeof Copy
  danger?: boolean
  hidden?: boolean
}

const MENU_ITEMS: MenuItemConfig[] = [
  { action: 'copy', label: 'Copy tin nhắn', icon: Copy },
  { action: 'pin', label: 'Ghim tin nhắn', icon: Pin },
  { action: 'star', label: 'Đánh dấu tin nhắn', icon: Star },
  { action: 'multiSelect', label: 'Chọn nhiều tin nhắn', icon: CheckSquare2 },
  { action: 'details', label: 'Xem chi tiết', icon: Info },
  { action: 'more', label: 'Tùy chọn khác', icon: ChevronRight },
  { action: 'recall', label: 'Thu hồi', icon: RotateCcw },
  { action: 'deleteSelf', label: 'Xóa chỉ ở phía tôi', icon: Trash2, danger: true },
  { action: 'recallGroup', label: 'Thu hồi cả nhóm', icon: RotateCcw },
  { action: 'deleteGroupSelf', label: 'Xóa phía tôi cả nhóm', icon: Trash2, danger: true },
]

const MENU_WIDTH = 256

// Helper to check if message was sent within 24 hours
const isWithin24Hours = (createdAt?: string) => {
  if (!createdAt) return true;
  const time = Date.parse(createdAt);
  const now = Date.now();
  return (now - time) < 24 * 60 * 60 * 1000;
};

async function copyMessageToClipboard(text: string) {
  if (!text.trim()) {
    return
  }

  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }

  const fallbackInput = document.createElement('textarea')
  fallbackInput.value = text
  fallbackInput.setAttribute('readonly', 'true')
  fallbackInput.style.position = 'fixed'
  fallbackInput.style.top = '-9999px'
  fallbackInput.style.opacity = '0'
  document.body.appendChild(fallbackInput)
  fallbackInput.select()
  document.execCommand('copy')
  document.body.removeChild(fallbackInput)
}

export const MessageContextMenu = React.forwardRef<HTMLDivElement, MessageContextMenuProps>(function MessageContextMenu(
  { message, isMyMessage, position, onClose, onAction, isVirtualGroup, isPinned, userRole, allowMemberPin },
  ref,
) {
  const menuStyle = React.useMemo<CSSProperties>(
    () => ({
      top: position.top,
      left: position.left,
      width: MENU_WIDTH,
    }),
    [position.left, position.top],
  )

  const isModerator = String(userRole || '').toUpperCase() === 'ADMIN' || String(userRole || '').toUpperCase() === 'DEPUTY';

  const visibleItems = MENU_ITEMS.filter((item) => {
    // Pin logic: ADMIN/DEPUTY always, MEMBER depends on group setting
    if (item.action === 'pin') {
      if (!isVirtualGroup) {
        return true
      }

      return isModerator || allowMemberPin
    }

    // Recall logic:
    // - My message: allowed if within 24h
    // - Others' message: allowed if I'm ADMIN/DEPUTY (moderation)
    if (item.action === 'recall') {
      if (isModerator) return true; // Admin/Deputy can recall anything anytime
      return isMyMessage && isWithin24Hours(message.createdAt);
    }

    // Group actions only if it's actually a virtual group
    if (item.action === 'recallGroup') return isVirtualGroup && isMyMessage;
    if (item.action === 'deleteGroupSelf') return isVirtualGroup;
    return true;
  })

  const handleItemClick = async (action: MessageContextMenuAction) => {
    try {
      if (action === 'copy') {
        await copyMessageToClipboard(message.text ?? '')
      }

      onAction?.(action)
    } finally {
      onClose()
    }
  }

  return (
    <div ref={ref} className='message-context-menu-popover' role='menu' aria-label='Tùy chọn tin nhắn' style={menuStyle}>
      <div className='message-context-menu-list'>
        {visibleItems.map((item) => {
          const IconComponent = item.icon

          return (
            <button
              key={item.action}
              type='button'
              className={item.danger ? 'message-context-menu-item message-context-menu-item-danger' : 'message-context-menu-item'}
              onClick={() => handleItemClick(item.action)}
              role='menuitem'
            >
              <span className='message-context-menu-item-icon'>
                <IconComponent />
              </span>
              <span className='message-context-menu-item-label'>
                {item.action === 'pin' ? (isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn') : item.label}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
})
