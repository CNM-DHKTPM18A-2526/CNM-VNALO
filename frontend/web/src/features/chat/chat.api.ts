import type { ChatAttachment, ChatMessage, ChatMessageType, ConversationSummary } from './chat.types'

const fallbackProtocol = typeof window !== 'undefined' ? window.location.protocol.replace(':', '') : 'http'
const fallbackHost = typeof window !== 'undefined' ? window.location.hostname : 'localhost'
const MESSAGE_API_URL = import.meta.env.VITE_MESSAGE_API_URL ?? `${fallbackProtocol}://${fallbackHost}:3000/api/v1`
const MEDIA_API_BASE_URL = import.meta.env.VITE_MEDIA_API_URL ?? 'http://localhost:8083'

type InboxItem = {
  conversationId: string
  unreadCount?: number
  lastMessagePreview?: string
  lastMessageSeq?: number
  lastMessageAt?: string | null
  updatedAt?: string | null
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
  messageType?: string | null
  mediaUrl?: string | null
  mediaThumbnailUrl?: string | null
  mediaMimeType?: string | null
  mediaSizeBytes?: number | null
}

type RawMessageLike = RawMessage & {
  conversation_id?: string
  sender_id?: string
  from?: string
  created_at?: string
  server_seq?: number
  client_message_id?: string | null
  messageType?: string | null
  media_url?: string | null
  media_thumbnail_url?: string | null
  media_mime_type?: string | null
  media_size_bytes?: number | null
}

type UploadResponse = {
  url?: string
  mediaId?: string
  mimeType?: string | null
  sizeBytes?: number | null
  thumbnailUrl?: string | null
}

export type UploadedChatMedia = {
  url: string
  mimeType: string | null
  sizeBytes: number | null
  thumbnailUrl: string | null
}

export type SearchConversationMessagesParams = {
  keyword?: string
  messageType?: 'TEXT' | 'IMAGE' | 'VIDEO' | 'FILE' | 'AUDIO' | 'STICKER'
  limit?: number
  offset?: number
}

export type SearchConversationMessagesResult = {
  items: RawMessage[]
  total: number
  limit: number
  offset: number
}

export type GlobalSearchResult = {
  type: 'message' | 'conversation' | 'user'
  id: string
  conversationId?: string
  conversationName?: string
  senderId?: string
  senderName?: string
  content?: string
  createdAt?: string
  phone?: string
  displayName?: string
  email?: string
  avatarUrl?: string
  bio?: string
  displayText?: string
}

export type GlobalSearchResults = {
  query: string
  queryType: 'keyword' | 'phone'
  results: GlobalSearchResult[]
  hasLocalResults: boolean
  totalCount: number
}

export type SendMessageRequest = {
  conversationId: string
  clientMessageId?: string
  messageType?: string
  content?: string
  mediaUrl?: string | null
  mediaThumbnailUrl?: string | null
  mediaMimeType?: string | null
  mediaSizeBytes?: number | null
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

function isImageMimeType(mimeType?: string | null): boolean {
  return Boolean(mimeType && mimeType.startsWith('image/'))
}

function isImageUrl(url?: string | null): boolean {
  if (!url) {
    return false
  }

  try {
    const parsed = new URL(url)
    const pathname = parsed.pathname.toLowerCase()
    return /\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)$/.test(pathname)
  } catch {
    const normalized = url.toLowerCase().split('?')[0]
    return /\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)$/.test(normalized)
  }
}

function isHttpUrl(value?: string | null): boolean {
  if (!value) {
    return false
  }

  try {
    const parsed = new URL(value)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

function normalizeInboxPreview(rawPreview?: string | null): string {
  const preview = String(rawPreview ?? '').trim()
  if (!preview) {
    return ''
  }

  const lowered = preview.toLowerCase()

  if (lowered === '[sticker]' || lowered.startsWith('sticker://') || lowered.includes('sticker')) {
    return 'Sticker'
  }

  if (lowered === '[image]' || lowered === '[ảnh]') {
    return 'Ảnh'
  }

  if (lowered === '[file]' || lowered === '[tệp]') {
    return 'File'
  }

  if (isHttpUrl(preview)) {
    return isImageUrl(preview) ? 'Ảnh' : 'File'
  }

  if (/\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)$/i.test(preview)) {
    return 'Ảnh'
  }

  if (/\.[a-z0-9]{2,8}$/i.test(preview) && !preview.includes(' ')) {
    return 'File'
  }

  return preview
}

function normalizeMessageType(raw: RawMessageLike): ChatMessageType {
  const declaredType = String(raw.messageType ?? '').trim().toLowerCase()
  const content = String(raw.content ?? '').trim()

  if (declaredType === 'image' || declaredType === 'file' || declaredType === 'sticker' || declaredType === 'text') {
    return declaredType
  }

  if (isImageMimeType(raw.mediaMimeType ?? raw.media_mime_type)) {
    return 'image'
  }

  if (isImageUrl(raw.mediaUrl ?? raw.media_url)) {
    return 'image'
  }

  if (raw.mediaUrl ?? raw.media_url) {
    return 'file'
  }

  if (isImageUrl(content)) {
    return 'image'
  }

  if (isHttpUrl(content)) {
    return 'file'
  }

  return 'text'
}

export async function uploadChatMedia(token: string, file: File): Promise<UploadedChatMedia> {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('category', file.type.startsWith('image/') ? 'CHAT_IMAGE' : 'CHAT_FILE')

  const response = await fetch(`${MEDIA_API_BASE_URL}/media/upload`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: formData,
  })

  const body = (await response.json().catch(() => null)) as { data?: UploadResponse; message?: string } | UploadResponse | null

  if (!response.ok) {
    const message =
      body && typeof body === 'object' && !Array.isArray(body) && typeof (body as { message?: string }).message === 'string'
        ? (body as { message: string }).message
        : null
    throw new Error(message ?? 'Unable to upload chat media.')
  }

  const responsePayload = body && typeof body === 'object' && !Array.isArray(body) && 'data' in body ? body.data : body
  const payload = responsePayload && typeof responsePayload === 'object' && !Array.isArray(responsePayload)
    ? (responsePayload as Record<string, unknown>)
    : null
  const url = typeof payload?.url === 'string' ? payload.url : null

  if (!url) {
    throw new Error('Upload response did not include a media URL.')
  }

  return {
    url,
    mimeType: typeof payload?.mimeType === 'string' ? payload.mimeType : file.type || null,
    sizeBytes: typeof payload?.sizeBytes === 'number' ? payload.sizeBytes : file.size,
    thumbnailUrl: typeof payload?.thumbnailUrl === 'string' ? payload.thumbnailUrl : null,
  }
}

export async function fetchInbox(token: string, currentUserId?: string): Promise<ConversationSummary[]> {
  const data = await authorizedFetch<InboxItem[]>(token, '/inbox')
  const myId = String(currentUserId ?? '').trim()

  return data.map((item) => {
    const id = item.conversation?.id ?? item.conversationId
    const title = item.conversation?.title?.trim()
    const members = item.conversation?.members ?? []
    const normalizedMembers = members.filter((member) => Boolean(member.userId))
    const peerMember = normalizedMembers.find((member) => String(member.userId ?? '').trim() !== myId)
      ?? normalizedMembers[0]
    const partnerUserId = String(peerMember?.userId ?? '').trim() || null
    const peerNickname = peerMember?.nickname?.trim()
    const peerFallback = partnerUserId ? `Người dùng ${partnerUserId.slice(0, 8)}` : null

    return {
      id,
      userId: partnerUserId,
      name: title && title.length > 0 ? title : peerNickname || peerFallback || `Trò chuyện ${id.slice(0, 8)}`,
      lastMessage: normalizeInboxPreview(item.lastMessagePreview),
      unreadCount: item.unreadCount ?? 0,
      online: false,
      lastMessageSeq: item.lastMessageSeq,
      participantUserIds: members
        .map((member) => String(member.userId ?? '').trim())
        .filter((memberId): memberId is string => Boolean(memberId) && memberId !== myId),
      lastMessageAt: item.lastMessageAt ?? null,
      updatedAt: item.updatedAt ?? null,
      lastSeenTime: item.lastMessageAt ?? null,
    }
  })
}

export function mapRawMessage(raw: RawMessageLike, currentUserId: string): ChatMessage {
  const conversationId = raw.conversationId ?? raw.conversation_id ?? ''
  const senderId = raw.senderId ?? raw.sender_id ?? raw.from ?? ''
  const createdAt = raw.createdAt ?? raw.created_at
  const serverSeq = raw.serverSeq ?? raw.server_seq
  const clientMessageId = raw.clientMessageId ?? raw.client_message_id ?? undefined
  const content = raw.content ?? ''
  const mediaUrlFromPayload = raw.mediaUrl ?? raw.media_url ?? null
  const mediaUrlFromContent = isHttpUrl(content) ? content : null
  const mediaThumbnailUrl = raw.mediaThumbnailUrl ?? raw.media_thumbnail_url ?? null
  const mediaMimeType = raw.mediaMimeType ?? raw.media_mime_type ?? null
  const mediaSizeBytes = raw.mediaSizeBytes ?? raw.media_size_bytes ?? null
  const type = normalizeMessageType(raw)
  const mediaUrl = mediaUrlFromPayload ?? ((type === 'image' || type === 'file' || type === 'sticker') ? mediaUrlFromContent : null)
  const messageText = mediaUrlFromContent && content.trim() === mediaUrlFromContent ? '' : content
  const attachmentName = type === 'file' && messageText && !isHttpUrl(messageText) ? messageText : undefined

  const attachments: ChatAttachment[] | undefined = mediaUrl
    ? [
        {
          url: mediaUrl,
          name: attachmentName,
          thumbnailUrl: mediaThumbnailUrl,
          mimeType: mediaMimeType,
          sizeBytes: mediaSizeBytes,
        },
      ]
    : undefined

  return {
    id: raw.id,
    conversationId,
    senderId,
    sender: senderId === currentUserId ? 'me' : 'other',
    type,
    text: messageText,
    mediaUrl,
    mediaThumbnailUrl,
    mediaMimeType,
    mediaSizeBytes,
    attachments,
    createdAt: createdAt ?? null,
    timestamp: formatTime(createdAt),
    serverSeq,
    clientMessageId,
    deliveryState: 'sent',
  }
}

function extractRawMessages(payload: unknown): RawMessage[] {
  if (Array.isArray(payload)) {
    return payload as RawMessage[]
  }

  if (!payload || typeof payload !== 'object') {
    return []
  }

  const candidate = payload as {
    data?: unknown
    items?: unknown
    content?: unknown
    messages?: unknown
    results?: unknown
  }

  const direct = [candidate.items, candidate.content, candidate.messages, candidate.results]
  for (const value of direct) {
    if (Array.isArray(value)) {
      return value as RawMessage[]
    }
  }

  if (candidate.data !== undefined) {
    return extractRawMessages(candidate.data)
  }

  return []
}

export async function fetchMessages(token: string, conversationId: string, forceSync = false): Promise<RawMessage[]> {
  const query = forceSync ? '&forceSync=true' : ''
  const data = await authorizedFetch<RawMessage[] | { items?: RawMessage[]; content?: RawMessage[] }>(
    token,
    `/conversations/${conversationId}/messages?limit=50${query}`,
  )
  const normalizedMessages = extractRawMessages(data)
  console.log('[chat.api.fetchMessages] Loaded messages:', {
    conversationId,
    total: normalizedMessages.length,
  })

  return normalizedMessages
}

export async function sendMessage(token: string, payload: SendMessageRequest): Promise<RawMessage> {
  const sanitizedPayload: SendMessageRequest = {
    ...payload,
    mediaUrl: payload.mediaUrl ?? undefined,
    mediaThumbnailUrl: payload.mediaThumbnailUrl ?? undefined,
    mediaMimeType: payload.mediaMimeType ?? undefined,
    mediaSizeBytes: payload.mediaSizeBytes ?? undefined,
  }

  return authorizedFetch<RawMessage>(token, '/messages', {
    method: 'POST',
    body: JSON.stringify(sanitizedPayload),
  })
}

export async function searchConversationMessages(
  token: string,
  conversationId: string,
  params: SearchConversationMessagesParams,
): Promise<SearchConversationMessagesResult> {
  const searchParams = new URLSearchParams()

  if (params.keyword) {
    searchParams.set('keyword', params.keyword)
  }
  if (params.messageType) {
    searchParams.set('messageType', params.messageType)
  }
  if (typeof params.limit === 'number') {
    searchParams.set('limit', String(params.limit))
  }
  if (typeof params.offset === 'number') {
    searchParams.set('offset', String(params.offset))
  }

  const query = searchParams.toString()
  const endpoint = `/conversations/${conversationId}/messages/search${query ? `?${query}` : ''}`
  const data = await authorizedFetch<
    | SearchConversationMessagesResult
    | {
        items?: RawMessage[]
        total?: number
        limit?: number
        offset?: number
      }
  >(token, endpoint)

  const payload = data && typeof data === 'object' && !Array.isArray(data) ? data : {}
  const items = Array.isArray(payload.items) ? payload.items : []

  return {
    items,
    total: typeof payload.total === 'number' ? payload.total : items.length,
    limit: typeof payload.limit === 'number' ? payload.limit : items.length,
    offset: typeof payload.offset === 'number' ? payload.offset : 0,
  }
}

export async function markConversationRead(token: string, conversationId: string, lastReadSeq: number): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/read`, {
    method: 'POST',
    body: JSON.stringify({ lastReadSeq }),
  })
}

export type RawMessageReaction = {
  id: string
  messageId: string
  userId: string
  emoji: string
  createdAt?: string
}

export async function addMessageReaction(token: string, messageId: string, emoji: string): Promise<void> {
  await authorizedFetch(token, `/messages/${messageId}/reactions`, {
    method: 'POST',
    body: JSON.stringify({ emoji }),
  })
}

export async function removeMessageReaction(token: string, messageId: string): Promise<void> {
  await authorizedFetch(token, `/messages/${messageId}/reactions`, {
    method: 'DELETE',
  })
}

export async function fetchMessageReactions(token: string, messageId: string): Promise<RawMessageReaction[]> {
  return authorizedFetch<RawMessageReaction[]>(token, `/messages/${messageId}/reactions`)
}

export type RawPinnedMessage = {
  id: string
  conversationId: string
  messageId: string
  serverSeq?: number
  pinnedBy?: string
  pinnedAt?: string
}

export async function recallMessage(token: string, messageId: string): Promise<RawMessage | null> {
  return authorizedFetch<RawMessage | null>(token, `/messages/${messageId}`, {
    method: 'DELETE',
  })
}

export async function deleteMessageForMe(token: string, messageId: string): Promise<void> {
  await authorizedFetch(token, `/messages/${messageId}/for-me`, {
    method: 'DELETE',
  })
}

export async function pinMessage(token: string, conversationId: string, messageId: string): Promise<RawPinnedMessage | null> {
  return authorizedFetch<RawPinnedMessage | null>(token, `/conversations/${conversationId}/pin/${messageId}`, {
    method: 'POST',
  })
}

export async function unpinMessage(token: string, conversationId: string, messageId: string): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/pin/${messageId}`, {
    method: 'DELETE',
  })
}

export async function fetchPinnedMessages(token: string, conversationId: string): Promise<RawPinnedMessage[]> {
  return authorizedFetch<RawPinnedMessage[]>(token, `/conversations/${conversationId}/pins`)
}

/**
 * Search globally across all conversations, messages, and support users/phone lookup
 * This backend endpoint searches across all user's conversations and messages
 */
export async function searchGlobalMessages(
  token: string,
  keyword: string,
  limit = 50,
  offset = 0,
): Promise<SearchConversationMessagesResult> {
  const searchParams = new URLSearchParams()
  searchParams.set('keyword', keyword)
  searchParams.set('limit', String(limit))
  searchParams.set('offset', String(offset))

  const query = searchParams.toString()
  const endpoint = `/messages/search${query ? `?${query}` : ''}`

  try {
    const data = await authorizedFetch<SearchConversationMessagesResult>(token, endpoint)
    return data
  } catch (error) {
    // Fallback: if global search endpoint doesn't exist, return empty results
    // Frontend will use local index instead
    console.warn('[chat.api.searchGlobalMessages] Global search failed, using local index:', error)
    return {
      items: [],
      total: 0,
      limit,
      offset,
    }
  }
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
