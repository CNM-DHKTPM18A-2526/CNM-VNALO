export type ConversationSummary = {
  id: string
  name: string
  lastMessage: string
  unreadCount: number
  online: boolean
  lastMessageSeq?: number
}

export type ChatMessage = {
  id: string
  conversationId: string
  sender: 'me' | 'other'
  senderId: string
  text: string
  timestamp: string
  serverSeq?: number
  clientMessageId?: string
}

export type MessageReadEvent = {
  userId: string
  conversationId: string
  lastReadSeq: number
}
