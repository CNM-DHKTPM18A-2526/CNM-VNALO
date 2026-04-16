import type { ChatMessageType, SystemMessagePayload } from '../chat.types'

export const CALL_LOG_PREFIX = 'CALL_LOG::'

/**
 * Interface representing the parsed call log data.
 */
export interface CallLogData {
  v: number
  callId: string
  conversationId: string
  callerId: string
  calleeId: string
  mediaType: 'voice' | 'video'
  outcome: 'completed' | 'canceled' | 'missed' | 'rejected' | 'busy'
  durationSeconds: number
  createdAt: string
}

export function formatMessageContent(text: string): string {
  if (!text) return ''
  
  const match = text.match(/CALL\s*_?LOG/i)
  if (!match) {
    return text
  }

  const prefix = text.slice(0, match.index)
  const lowerText = text.toLowerCase()
  
  // Determine call type
  const isVideo = lowerText.includes('video')
  const typeStr = isVideo ? 'video' : 'thoại'

  // Determine outcome via simple keywords (resilient to truncation)
  let formatted = `Cuộc gọi ${typeStr}`
  if (lowerText.includes('missed')) formatted = `Cuộc gọi ${typeStr} nhỡ`
  else if (lowerText.includes('canceled')) formatted = `Cuộc gọi ${typeStr} đã hủy`
  else if (lowerText.includes('rejected') || lowerText.includes('busy')) formatted = `Cuộc gọi ${typeStr} bị từ chối`
  else if (lowerText.includes('completed')) {
    const durationMatch = text.match(/"durationSeconds"\s*:\s*(\d+)/i)
    if (durationMatch) {
      formatted = `Cuộc gọi ${typeStr} (${formatDuration(parseInt(durationMatch[1], 10))})`
    } else {
      formatted = `Cuộc gọi ${typeStr} đã kết thúc`
    }
  }
  
  return `${prefix}${formatted}`
}

export function parseCallLog(text: string): any | null {
  // Legacy support for other parts of the system if needed
  if (!/CALL\s*_?LOG/i.test(text)) return null
  return { outcome: 'unknown' } // Minimal object to satisfy truthy checks
}

/**
 * Formats a preview string for the chat list (sidebar).
 */
export function formatMessagePreview(
  text: string | null | undefined,
  isMe: boolean,
  type?: ChatMessageType,
  sender?: string,
  attachments?: any[],
): string {
  const content = text || ''
  let prefix = ''
  if (isMe) {
    prefix = 'Bạn: '
  } else if (sender) {
    prefix = sender + ': '
  }
  const maxPreviewLength = 27

  const truncatePreview = (value: string) =>
    value.length > maxPreviewLength ? `${value.slice(0, maxPreviewLength - 3).trimEnd()}...` : value

  if (attachments && attachments.length > 1) {
    const isAllImages = attachments.every(att => att.mimeType?.startsWith('image/') || att.type === 'image')
    if (isAllImages) return `${prefix}📷 ${attachments.length} hình ảnh`
    return `${prefix}📎 ${attachments.length} tệp tin`
  }

  if (type === 'image') return `${prefix}[Hình ảnh]`
  if (type === 'file') return `${prefix}[Tệp tin]`
  if (type === 'sticker') return `${prefix}[Sticker]`

  if (type === 'call') {
    return truncatePreview(`${prefix}${formatMessageContent(content)}`)
  }

  if (!content) return ''

  // Support for system-like strings that might be raw JSON in the fallback text
  if (content.startsWith('{"action":')) {
    // If we are in formatMessagePreview we don't always have getDisplayName, 
    // but the system should have handled this at a higher level. 
    // We return a generic label if it's still raw JSON.
    return `${prefix}[Thông báo hệ thống]`
  }

  if (content.startsWith(CALL_LOG_PREFIX) || /CALL\s*_?LOG/i.test(content)) {
    return truncatePreview(`${prefix}${formatMessageContent(content)}`)
  }

  return truncatePreview(`${prefix}${content}`)
}

/**
 * Helper to format seconds into mm:ss
 */
function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

/**
 * Parses and renders structured system messages for group chat.
 * Handles personalization ("Bạn") and localized strings.
 */
export function renderSystemMessage(
  content: string,
  currentUserId: string,
  getDisplayName: (id: string) => string,
): string {
  if (!content) return ''

  // Support legacy string-based system messages
  if (!content.includes('"action"')) {
    return content
  }

  try {
    const payload: SystemMessagePayload = JSON.parse(content)
    const actorName = payload.actorId === currentUserId ? 'Bạn' : getDisplayName(payload.actorId)

    switch (payload.action) {
      case 'ADD_MEMBERS': {
        const targets = (payload.targetMemberIds ?? [])
          .map((id) => (id === currentUserId ? 'Bạn' : getDisplayName(id)))
          .join(', ')
        return `${actorName} đã thêm ${targets} vào nhóm`
      }
      case 'LEAVE_GROUP':
        return `${actorName} đã rời khỏi nhóm`
      case 'CREATE_GROUP':
        return `${actorName} đã tạo nhóm`
      case 'RENAME_GROUP':
        return `${actorName} đã đổi tên nhóm thành "${payload.metadata?.newName || ''}"`
      default:
        return content
    }
  } catch (error) {
    console.warn('[renderSystemMessage] Failed to parse system message JSON:', error)
    return content
  }
}

/**
 * Centralized function to format message content for UI display.
 * Used in both MessageBubble (chat) and Sidebar (preview).
 */
export function formatMessage(
  message: { type: string; text: string },
  currentUserId: string,
  getDisplayName: (id: string) => string,
): string {
  if (message.type === 'system') {
    return renderSystemMessage(message.text, currentUserId, getDisplayName)
  }

  return formatMessageContent(message.text)
}