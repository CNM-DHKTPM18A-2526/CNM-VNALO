import type { ChatMessage, ConversationSummary } from './chat.types'

const fallbackProtocol = typeof window !== 'undefined' ? window.location.protocol.replace(':', '') : 'http'
const fallbackHost = typeof window !== 'undefined' ? window.location.hostname : 'localhost'
const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? `${fallbackProtocol}://${fallbackHost}:3000/api/v1`

type InboxItem = {
  conversationId: string
  unreadCount?: number
  lastMessagePreview?: string
  lastMessageSeq?: number
  conversation?: {
    id?: string
    title?: string | null
    type?: string
    members?: Array<{
      userId?: string
      nickname?: string | null
    }>
  } | null
}

export type RawMessage = {
  id: string
  conversationId: string
  senderId: string
  from?: string
  content?: string | null
  createdAt?: string
  serverSeq?: number
  clientMessageId?: string | null
}

type RawMessageLike = RawMessage & {
  conversation_id?: string
  sender_id?: string
  from?: string
  created_at?: string
  server_seq?: number
  client_message_id?: string | null
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

  const body = (await response.json().catch(() => null)) as
    | { data?: T; message?: string }
    | T
    | null
  if (!response.ok) {
    const message =
      body && typeof body === 'object' && !Array.isArray(body) && typeof (body as { message?: string }).message === 'string'
        ? (body as { message: string }).message
        : null
    throw new Error(message ?? 'Message API request failed')
  }

  if (body && typeof body === 'object' && !Array.isArray(body) && 'data' in body) {
    return ((body as { data?: T }).data ?? ([] as unknown)) as T
  }

  return (body ?? ([] as unknown)) as T
}

export async function fetchInbox(token: string, currentUserId?: string): Promise<ConversationSummary[]> {
  const data = await authorizedFetch<InboxItem[]>(token, '/inbox')
  return data.map((item) => {
    const id = item.conversation?.id ?? item.conversationId
    const title = item.conversation?.title?.trim()
    const members = item.conversation?.members ?? []
    const peerMember = currentUserId
      ? members.find((member) => Boolean(member.userId) && member.userId !== currentUserId)
      : members.find((member) => Boolean(member.userId))
    const peerNickname = peerMember?.nickname?.trim()
    const peerFallback = peerMember?.userId ? `Người dùng ${peerMember.userId.slice(0, 8)}` : null

    return {
      id,
      name: title && title.length > 0 ? title : peerNickname || peerFallback || `Trò chuyện ${id.slice(0, 8)}`,
      lastMessage: item.lastMessagePreview ?? '',
      unreadCount: item.unreadCount ?? 0,
      online: false,
      lastMessageSeq: item.lastMessageSeq,
      participantUserIds: members
        .map((member) => member.userId)
        .filter((memberId): memberId is string => Boolean(memberId) && memberId !== currentUserId),
    }
  })
}

export function mapRawMessage(raw: RawMessageLike, currentUserId: string): ChatMessage {
  const conversationId = raw.conversationId ?? raw.conversation_id ?? ''
  const senderId = raw.senderId ?? raw.sender_id ?? raw.from ?? ''
  const createdAt = raw.createdAt ?? raw.created_at
  const serverSeq = raw.serverSeq ?? raw.server_seq
  const clientMessageId = raw.clientMessageId ?? raw.client_message_id ?? undefined

  return {
    id: raw.id,
    conversationId,
    senderId,
    sender: senderId === currentUserId ? 'me' : 'other',
    text: raw.content ?? '',
    timestamp: formatTime(createdAt),
    serverSeq,
    clientMessageId,
    deliveryState: 'sent',
  }
}

export async function fetchMessages(token: string, conversationId: string): Promise<RawMessage[]> {
  const data = await authorizedFetch<RawMessage[] | { items?: RawMessage[]; content?: RawMessage[] }>(
    token,
    `/conversations/${conversationId}/messages?limit=50`,
  )
  console.log('Dữ liệu tin nhắn nhận được:', data)

  if (Array.isArray(data)) return data
  if (!data || typeof data !== 'object') return []
  if (Array.isArray(data.items)) return data.items
  if (Array.isArray(data.content)) return data.content

  return []
}

export async function markConversationRead(token: string, conversationId: string, lastReadSeq: number): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/read`, {
    method: 'POST',
    body: JSON.stringify({ lastReadSeq }),
  })
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value)
}

export async function getOrCreateDirectConversation(token: string, targetUserId: string): Promise<string> {
  const response = await fetch(`${MESSAGE_API_URL}/conversations/direct`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ targetUserId }),
  })

  const json = await response.json().catch(() => null)

  if (!response.ok) {
    const message = isRecord(json) && typeof json.message === 'string' ? json.message : null
    throw new Error(message ?? 'Cannot open direct conversation.')
  }

  const payload = isRecord(json) && isRecord(json.data) ? json.data : json
  const conversationId =
    isRecord(payload) && typeof payload.id === 'string'
      ? payload.id
      : isRecord(payload) && typeof payload.conversationId === 'string'
        ? payload.conversationId
        : null

  if (!conversationId) {
    throw new Error('Invalid direct conversation response payload.')
  }

  return conversationId
}
