import type { ChatMessageType } from '../chat.types'

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
): string {
  const content = text || ''
  const prefix = isMe ? 'Bạn: ' : ''

  if (type === 'image') return `${prefix}[Hình ảnh]`
  if (type === 'file') return `${prefix}[Tệp tin]`
  if (type === 'sticker') return `${prefix}[Sticker]`

  if (!content) return ''

  // Fallback detections if type is not provided
  if (content.startsWith('CALL_LOG::')) {
    const callLogText = formatMessageContent(content)
    return `${prefix}[${callLogText}]`
  }
  
  // Detect other types based on content patterns if necessary
  // (e.g. if we know certain strings mean certain types)

  return `${prefix}${content}`
}

/**
 * Helper to format seconds into mm:ss
 */
function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}
