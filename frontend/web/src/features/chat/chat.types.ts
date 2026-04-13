export interface ConversationSummary {
  id: string
  name: string
  avatarUrl?: string | null
  lastMessage?: string | null
  lastMessagePreview?: string | null
  unreadCount?: number
  lastMessageAt?: string | null
  updatedAt?: string | null
  participantUserIds?: string[]
  memberCount?: number
  lastSeenTime?: string | null
  isGroup?: boolean
  isCloud?: boolean
}

export type ChatMessageType = 'text' | 'image' | 'file' | 'sticker'

export type MessageDeliveryState = 'sending' | 'sent' | 'read' | 'failed'

export type ChatAttachment = {
  url: string
  name?: string | null
  mimeType?: string | null
  sizeBytes?: number | null
  thumbnailUrl?: string | null
}

export type ChatSticker = {
  id: string
  name: string
  url: string
}

export type ChatComposePayload = {
  text: string
  file?: File | null
  sticker?: ChatSticker | null
}

export type ChatMessage = {
  id: string
  conversationId: string
  sender: 'me' | 'other'
  senderId: string
  type: ChatMessageType
  isLocal?: boolean
  text: string
  mediaUrl?: string | null
  mediaThumbnailUrl?: string | null
  mediaMimeType?: string | null
  mediaSizeBytes?: number | null
  attachments?: ChatAttachment[]
  createdAt?: string | null
  timestamp: string
  serverSeq?: number
  clientMessageId?: string
  deliveryState?: MessageDeliveryState
}

export type MessageReadEvent = {
  userId: string
  conversationId: string
  lastReadSeq: number
}
