export type ConversationSummary = {
  id: string
  name: string
  lastMessage: string
  unreadCount: number
  online: boolean
  lastMessageSeq?: number
  participantUserIds?: string[]
}

export type MessageDeliveryState = 'sending' | 'sent' | 'read' | 'failed'

export type ChatMessage = {
  id: string
  conversationId: string
  sender: 'me' | 'other'
  senderId: string
  text: string
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
