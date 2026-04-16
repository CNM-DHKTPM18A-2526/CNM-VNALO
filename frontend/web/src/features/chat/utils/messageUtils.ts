import type { ChatMessageType, SystemMessagePayload } from '../chat.types'

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

const CALL_LOG_PREFIX = 'CALL_LOG::'

/**
 * Tries to parse a call log from a message string.
 */
export function parseCallLog(text: string): CallLogData | null {
  if (!text || !text.startsWith(CALL_LOG_PREFIX)) {
    return null
  }

  try {
    const jsonStr = text.slice(CALL_LOG_PREFIX.length)
    return JSON.parse(jsonStr)
  } catch (error) {
    console.warn('[parseCallLog] Failed to parse call log JSON:', error)
    return null
  }
}

/**
 * Formats a message string for display in a message bubble.
 * If it's a call log, returns a human-readable text.
 */
export function formatMessageContent(text: string): string {
  if (!text) return ''

  const callLog = parseCallLog(text)
  if (!callLog) {
    return text
  }

  const isVideo = callLog.mediaType === 'video'
  const typeStr = isVideo ? 'video' : 'thoại'

  switch (callLog.outcome) {
    case 'missed':
      return `Cuộc gọi ${typeStr} nhỡ`
    case 'canceled':
      return `Cuộc gọi ${typeStr} đã hủy`
    case 'rejected':
    case 'busy':
      return `Cuộc gọi ${typeStr} bị từ chối`
    case 'completed':
      return `Cuộc gọi ${typeStr} (${formatDuration(callLog.durationSeconds)})`
    default:
      return `Cuộc gọi ${typeStr}`
  }
}

/**
 * Formats a preview string for the chat list (sidebar).
 */
export function formatMessagePreview(
  text: string | null | undefined,
  isMe: boolean,
  type?: ChatMessageType,
  sender?: string,
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

  if (type === 'image') return `${prefix}[Hình ảnh]`
  if (type === 'file') return `${prefix}[Tệp tin]`
  if (type === 'sticker') return `${prefix}[Sticker]`

  if (!content) return ''

  if (content === 'CALL LOG' || content === 'CALL_LOG' || content.startsWith(CALL_LOG_PREFIX)) {
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