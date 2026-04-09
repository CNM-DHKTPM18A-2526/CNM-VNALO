import type { ChatMessage, ConversationSummary } from './chat.types'

const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? 'http://localhost:3000/api/v1'

type InboxItem = {
  conversationId: string
  unreadCount?: number
  lastMessagePreview?: string
  lastMessageSeq?: number
  conversation?: {
    id?: string
    title?: string | null
    type?: string
  } | null
}

export type RawMessage = {
  id: string
  conversationId: string
  senderId: string
  content?: string | null
  createdAt?: string
  serverSeq?: number
  clientMessageId?: string | null
}

function formatTime(value?: string): string {
  if (!value) {
    return ''
  }
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return ''
  }

  return date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  })
}

async function authorizedFetch<T>(token: string, endpoint: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${MESSAGE_API_URL}${endpoint}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  })

  const body = (await response.json().catch(() => null)) as { data?: T; message?: string } | null
  if (!response.ok) {
    throw new Error(body?.message ?? 'Message API request failed')
  }

  return (body?.data ?? ([] as unknown)) as T
}

export async function fetchInbox(token: string): Promise<ConversationSummary[]> {
  const data = await authorizedFetch<InboxItem[]>(token, '/inbox')
  return data.map((item) => {
    const id = item.conversation?.id ?? item.conversationId
    const title = item.conversation?.title?.trim()

    return {
      id,
      name: title && title.length > 0 ? title : `Trò chuyện ${id.slice(0, 8)}`,
      lastMessage: item.lastMessagePreview ?? '',
      unreadCount: item.unreadCount ?? 0,
      online: false,
      lastMessageSeq: item.lastMessageSeq,
    }
  })
}

export function mapRawMessage(raw: RawMessage, currentUserId: string): ChatMessage {
  return {
    id: raw.id,
    conversationId: raw.conversationId,
    senderId: raw.senderId,
    sender: raw.senderId === currentUserId ? 'me' : 'other',
    text: raw.content ?? '',
    timestamp: formatTime(raw.createdAt),
    serverSeq: raw.serverSeq,
    clientMessageId: raw.clientMessageId ?? undefined,
  }
}

export async function fetchMessages(token: string, conversationId: string): Promise<RawMessage[]> {
  return authorizedFetch<RawMessage[]>(token, `/conversations/${conversationId}/messages?limit=50`)
}

export async function markConversationRead(token: string, conversationId: string, lastReadSeq: number): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/read`, {
    method: 'POST',
    body: JSON.stringify({ lastReadSeq }),
  })
}
