import type { ChatMessage, ChatMessageType, SystemMessagePayload } from '../chat.types'

export const CALL_LOG_PREFIX = 'CALL_LOG::'

/**
 * Normalizes a message to ensure consistent typing for call logs.
 */
export function normalizeMessage(msg: ChatMessage): ChatMessage {
  if (!msg) return msg

  const isCall =
    msg.type === 'call' ||
    (msg.text && (
      msg.text.startsWith(CALL_LOG_PREFIX) ||
      msg.text.includes('"type":"audio"') ||
      msg.text.includes('"type":"video"')
    ))

  if (isCall) {
    return {
      ...msg,
      type: 'call',
    }
  }

  return msg
}

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
  /** Group call extra fields */
  isGroup?: boolean
  participantCount?: number
}

export function formatMessageTimestamp(): string {
  return new Date().toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatMessageContent(text: string, currentUserId?: string): string {
  if (!text) return ''

  // Mention Detection: Use invisible marker \u200B to find exact mention boundaries
  const withMentions = text.replace(/\u200B(@.*?)\u200B/g, (match, name) => {
    return `<span class="text-[#0068ff] font-medium cursor-pointer hover:underline">${name}</span>`;
  }).replace(/\u200B/g, ''); // Clean up any stray markers

  const match = text.match(/CALL\s*_?LOG/i)
  if (!match) {
    return withMentions
  }

  const prefix = text.slice(0, match.index)
  const lowerText = text.toLowerCase()

  // Determine call type
  const isVideo = lowerText.includes('video')
  const typeStr = isVideo ? 'video' : 'thoại'

  // Try to parse JSON for more accurate direction
  let logData: any = null
  try {
    if (text.includes('::')) {
      logData = JSON.parse(text.split('::')[1])
    }
  } catch (e) { /* ignore */ }

  // Determine outcome via simple keywords (resilient to truncation)
  let formatted = `Cuộc gọi ${typeStr}`
  if (lowerText.includes('missed')) formatted = `Cuộc gọi ${typeStr} nhỡ`
  else if (lowerText.includes('canceled')) formatted = `Cuộc gọi ${typeStr} đã hủy`
  else if (lowerText.includes('rejected') || lowerText.includes('busy')) formatted = `Cuộc gọi ${typeStr} bị từ chối`
  else if (lowerText.includes('completed')) {
    const durationMatch = text.match(/"durationSeconds"\s*:\s*(\d+)/i)
    const durationStr = durationMatch ? ` (${formatDuration(parseInt(durationMatch[1], 10))})` : ''

    if (logData && currentUserId) {
      if (logData.callerId === currentUserId) {
        formatted = `Cuộc gọi ${typeStr} đi${durationStr}`
      } else {
        formatted = `Cuộc gọi ${typeStr} đến${durationStr}`
      }
    } else {
      formatted = `Cuộc gọi ${typeStr} đã kết thúc${durationStr}`
    }
  }

  return `${prefix}${formatted}`
}

export function parseCallLog(text: string): CallLogData | null {
  if (!text || (!text.startsWith(CALL_LOG_PREFIX) && !text.includes('CALL_LOG::'))) return null
  
  try {
    const jsonPart = text.includes('::') ? text.split('::')[1] : text
    return JSON.parse(jsonPart) as CallLogData
  } catch (e) {
    console.warn('[messageUtils.parseCallLog] Failed to parse JSON:', e)
    return null
  }
}

/**
 * Formats seconds into "X phút Y giây" or just "Y giây"
 */
export function formatDurationZalo(seconds: number): string {
  if (typeof seconds !== 'number' || isNaN(seconds) || seconds <= 0) return ''
  
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  
  if (mins > 0) {
    return `${mins} phút ${secs > 0 ? `${secs} giây` : ''}`.trim()
  }
  
  return `${secs} giây`
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
    return truncatePreview(`${prefix}${formatMessageContent(content, isMe ? undefined : 'peer')}`)
    // Simplified isMe check for preview
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
      case 'CHANGE_GROUP_AVATAR':
        return `${actorName} đã thay đổi ảnh đại diện nhóm`
      case 'PIN_MESSAGE':
        return `${actorName} đã ghim một tin nhắn`
      case 'UNPIN_MESSAGE':
        return `${actorName} đã bỏ ghim một tin nhắn`
      case 'UPDATE_MESSAGE_REACTIONS':
        return '' // Hide reaction sync signals completely
      case 'UPDATE_GROUP_INFO':
        if (payload.metadata?.newName) {
          return `${actorName} đã đổi tên nhóm thành "${payload.metadata.newName}"`
        }
        return `${actorName} đã cập nhật thông tin nhóm`
      case 'REMOVE_MEMBER': {
        const targetName = (payload.targetMemberIds ?? [])
          .map((id) => (id === currentUserId ? 'Bạn' : getDisplayName(id)))
          .join(', ')
        return `**${targetName}** đã được **${actorName}** xóa khỏi nhóm`
      }
      case 'PROMOTE_ADMIN': {
        const targetName = (payload.targetMemberIds ?? [])
          .map((id) => (id === currentUserId ? 'Bạn' : getDisplayName(id)))
          .join(', ')
        return `**${targetName}** đã được **${actorName}** chỉ định làm phó nhóm`
      }
      case 'TRANSFER_OWNERSHIP': {
        const targetName = (payload.targetMemberIds ?? [])
          .map((id) => (id === currentUserId ? 'Bạn' : getDisplayName(id)))
          .join(', ')
        return `**${targetName}** đã được **${actorName}** chuyển quyền trưởng nhóm`
      }
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

  return formatMessageContent(message.text, currentUserId)
}

/**
 * Checks if a mimeType or file extension indicates an image.
 */
export function isImageAttachment(mimeType?: string | null, url?: string | null, name?: string | null): boolean {
  if (mimeType?.startsWith('image/')) return true
  const path = (url || name || '').toLowerCase()
  return path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') || path.endsWith('.gif') || path.endsWith('.webp')
}

/**
 * Checks if a mimeType or file extension indicates a video.
 */
export function isVideoAttachment(mimeType?: string | null, url?: string | null, name?: string | null): boolean {
  if (mimeType?.startsWith('video/')) return true
  const path = (url || name || '').toLowerCase()
  return path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi') || path.endsWith('.mkv') || path.endsWith('.webm')
}