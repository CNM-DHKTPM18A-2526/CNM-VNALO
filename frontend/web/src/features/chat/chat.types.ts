export type ConversationSummary = {
  id: string
  userId?: string | null
  name: string
  avatarUrl?: string | null
  isStranger?: boolean
  lastMessage: string
  unreadCount: number
  online?: boolean
  isOnline?: boolean
  lastMessageSeq?: number
  lastMessagePreview?: string | null
  lastMessageSenderId?: string | null
  participantUserIds?: string[]
  lastMessageAt?: string | null
  updatedAt?: string | null
  lastSeenTime?: string | null
  isGroup?: boolean
  isCloud?: boolean
  memberCount?: number
  isPinned?: boolean
  members?: Array<{ userId: string; role: string }>
}

export type ChatMessageType = 'text' | 'image' | 'file' | 'sticker' | 'system' | 'call'

export type ReplyMetadata = {
  id: string
  senderId?: string        // stored for name resolution after refresh
  senderName: string
  preview: string
  type: ChatMessageType
}

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

export type ReactionKey = 'like' | 'love' | 'haha' | 'wow' | 'sad' | 'angry'

export type ReactionOption = {
  key: ReactionKey
  emoji: string
  label: string
}

export type MessageReactionMap = Record<
  ReactionKey,
  {
    count: number
    myCount: number
  }
>

export type MessageReactionState = {
  reactions: MessageReactionMap
  lastUsedReaction?: ReactionKey
}

export type ChatComposePayload = {
  text: string
  file?: File | null
  files?: File[] | null
  sticker?: ChatSticker | null
  replyTo?: ReplyMetadata | null
}

export type ChatMessage = {
  id: string
  conversationId: string
  sender: 'me' | 'other' | 'system'
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
  replyTo?: ReplyMetadata | null
  isRecalled?: boolean
  isPlaceholder?: boolean
}

export type MessageReadEvent = {
  userId: string
  conversationId: string
  lastReadSeq: number
}

export type ViewerImageItem = {
  messageId: string
  url: string
  senderName: string
  timestamp: string
}

export interface SystemMessagePayload {
  action: 'ADD_MEMBERS' | 'LEAVE_GROUP' | 'CREATE_GROUP' | 'RENAME_GROUP' | 'PIN_MESSAGE' | 'UNPIN_MESSAGE';
  actorId: string;
  targetMemberIds?: string[];
  metadata?: Record<string, any>;
}
