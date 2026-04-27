import type { ChatAttachment, ChatMessage, ChatMessageType, ConversationSummary, ReplyMetadata } from './chat.types'
import { formatMessageContent } from './utils/messageUtils'
import { API_BASE_URL, extractMessage, messageApi, mediaApi } from '../../api.client'
import { resolveMediaUrl } from '../../utils/mediaUtils'

type InboxItem = {
  conversationId: string
  unreadCount?: number
  lastMessagePreview?: string
  lastMessageSeq?: number
  lastMessageSenderId?: string | null
  lastMessageAt?: string | null
  updatedAt?: string | null
  conversation?: {
    id?: string
    title?: string | null
    type?: string
    avatarUrl?: string | null
    members?: Array<{
      userId?: string
      nickname?: string | null
      avatarUrl?: string | null
      role?: string | null
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
  attachments?: ChatAttachment[]
  status?: string | null
  recalledAt?: string | null
  recalled_at?: string | null
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
  attachments?: ChatAttachment[]
  status?: string | null
  recalledAt?: string | null
  recalled_at?: string | null
}

type MediaUploadResponse = {
  url: string
  mediaId?: string
  mimeType: string | null
  sizeBytes: number | null
  thumbnailUrl: string | null
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
  attachments?: Array<{
    url: string
    name?: string | null
    mimeType?: string | null
    sizeBytes?: number | null
    thumbnailUrl?: string | null
  }>
  replyTo?: ReplyMetadata | null
  replyToMessageId?: string | null
  replyToSenderId?: string | null
  replyToContent?: string | null
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
  try {
    const response = await messageApi.request({
      url: endpoint,
      method: init?.method ?? 'GET',
      data: init?.body ? JSON.parse(init.body as string) : undefined,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(init?.headers as any ?? {}),
      },
    });

    const body = response.data;
    if (body && typeof body === 'object' && !Array.isArray(body) && 'data' in body) {
      return ((body as { data?: T }).data ?? ([] as unknown)) as T;
    }
    return body as T;
  } catch (error: any) {
    const errorData = error.response?.data;
    const message = errorData && typeof errorData === 'object' ? errorData.message : error.message;
    throw new Error(message ?? 'Message API request failed');
  }
}

function isImageMimeType(mimeType?: string | null): boolean {
  return Boolean(mimeType && mimeType.startsWith('image/'))
}

function isImageUrl(url?: string | null): boolean {
  if (!url) {
    return false
  }

  // Define image pattern once
  const imagePattern = /\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)(\?|#|$)/i

  try {
    const parsed = new URL(url)
    const pathname = parsed.pathname.toLowerCase()
    return imagePattern.test(pathname)
  } catch {
    const normalized = url.toLowerCase()
    return imagePattern.test(normalized)
  }
}

function isVideoUrl(url?: string | null): boolean {
  if (!url) {
    return false
  }

  const videoPattern = /\.(mp4|webm|ogv|mov|m4v|3gp|mkv)(\?|#|$)/i

  try {
    const parsed = new URL(url)
    const pathname = parsed.pathname.toLowerCase()
    return videoPattern.test(pathname)
  } catch {
    const normalized = url.toLowerCase()
    return videoPattern.test(normalized)
  }
}

function extractFilenameFromUrl(url: string): string {
  if (!url) return 'Tệp tin';
  try {
    const decodedUrl = decodeURIComponent(url);
    const parts = decodedUrl.split('/');
    const lastPart = parts[parts.length - 1] || '';
    // Remove query params and possible hash fragments
    const filename = lastPart.split('?')[0].split('#')[0];
    return filename || 'Tệp tin';
  } catch (e) {
    return 'Tệp tin';
  }
}

/**
 * Recursive scanner to find any evidence of an image inside a raw message payload.
 * Crucial for cross-platform compatibility where field names vary wildly.
 */
function hasImageEvidence(obj: any, depth = 0): boolean {
  if (!obj || depth > 3) return false

  if (typeof obj === 'string') {
    const s = obj.toLowerCase()
    // Check for MIME types
    if (isImageMimeType(s)) return true
    // Check for common extensions
    if (isImageUrl(s)) return true
    return false
  }

  if (Array.isArray(obj)) {
    return obj.some(item => hasImageEvidence(item, depth + 1))
  }

  if (typeof obj === 'object') {
    return Object.values(obj).some(val => hasImageEvidence(val, depth + 1))
  }

  return false
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

  // Handle specific multi-attachment strings if they come from backend or local cache
  if (/📷\s*\d+\s*hình ảnh/i.test(preview)) return preview;
  if (/📎\s*\d+\s*tệp tin/i.test(preview)) return preview;

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
    if (isImageUrl(preview)) return 'Ảnh'
    if (isVideoUrl(preview)) return 'Video'
    return 'File'
  }

  if (/\.(png|jpe?g|gif|webp|bmp|svg|avif|heic)$/i.test(preview)) {
    return 'Ảnh'
  }

  if (/\.(mp4|webm|ogv|mov|m4v|3gp|mkv)$/i.test(preview)) {
    return 'Video'
  }

  if (/\.[a-z0-9]{2,8}$/i.test(preview) && !preview.includes(' ')) {
    return 'File'
  }

  if (/CALL_LOG/i.test(preview)) {
    return formatMessageContent(preview)
  }

  return preview
}

function normalizeMessageType(rawType: any, raw?: RawMessageLike): ChatMessageType {
  const declaredType = String(rawType || '').trim().toLowerCase()

  // 1. Handle specialized types that should NOT be overridden by guessing
  if (declaredType === 'sticker' || declaredType === 'system' || declaredType === 'call') {
    return declaredType as ChatMessageType
  }

  // 2. Universal Detection: Deep scan the raw payload for image evidence
  if (raw && hasImageEvidence(raw)) {
    return 'image'
  }

  // 3. Fallback to declared types
  if (declaredType === 'image' || declaredType === 'file' || declaredType === 'text') {
    return declaredType as ChatMessageType
  }

  // 4. Ultimate media fallback
  if (raw && (raw.mediaUrl ?? raw.media_url ?? (raw as any).mediaPath)) return 'file'

  return 'text'
}

export async function uploadChatMedia(token: string, file: File): Promise<MediaUploadResponse> {
  const formData = new FormData()
  formData.append('file', file)
  
  const ext = file.name.split('.').pop()?.toLowerCase() || '';
  const isImage = file.type.startsWith('image/') || ['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext);
  formData.append('category', isImage ? 'AVATAR' : 'CHAT_FILE');

  try {
    // We use mediaApi (Axios instance for port 8083)
    const response = await mediaApi.post('/upload', formData, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    const json = response.data;

    const payload = json && typeof json === 'object' && !Array.isArray(json) && 'data' in json 
      ? (json.data as Record<string, unknown>) 
      : (json as Record<string, unknown>);

    const url = typeof payload?.url === 'string' ? payload.url : null;
    if (!url) {
      throw new Error('Upload response did not include a media URL.');
    }

    return {
      url,
      mimeType: typeof payload?.mimeType === 'string' ? payload.mimeType : file.type || null,
      sizeBytes: typeof payload?.sizeBytes === 'number' ? payload.sizeBytes : file.size,
      thumbnailUrl: typeof payload?.thumbnailUrl === 'string' ? payload.thumbnailUrl : null,
    };
  } catch (error: any) {
    if (error.message.includes('fetch')) {
       throw new Error('Connection failed to media service. Please check if backend is running.');
    }
    throw error;
  }
}

export async function fetchInbox(token: string, currentUserId?: string): Promise<ConversationSummary[]> {
  const data = await authorizedFetch<InboxItem[]>(token, '/inbox')
  const myId = String(currentUserId ?? '').trim()

  return data
    .filter((item) => {
      // If we have a members list, we MUST be in it to see the conversation
      // (This filters out conversations we have left)
      const members = item.conversation?.members ?? []
      if (members.length > 0) {
        return members.some((m) => String(m.userId ?? '').trim() === myId)
      }
      // Fallback: if no members returned (might be a different API response), 
      // check participantUserIds if available
      return true
    })
    .map((item) => {
      const id = item.conversation?.id ?? item.conversationId
      const title = item.conversation?.title?.trim()
      const members = item.conversation?.members ?? []
      const normalizedMembers = members.filter((member) => Boolean(member.userId))
      const peerMember = normalizedMembers.find((member) => String(member.userId ?? '').trim() !== myId)
        ?? normalizedMembers[0]
      const partnerUserId = String(peerMember?.userId ?? '').trim() || null
      const peerNickname = peerMember?.nickname?.trim()
      const peerFallback = partnerUserId ? `Người dùng ${partnerUserId.slice(0, 8)}` : null
      const normalizedPreview = normalizeInboxPreview(item.lastMessagePreview)
      const isGroup = item.conversation?.type?.toUpperCase() === 'GROUP' || (item as any).isGroup === true
      const avatarUrl = item.conversation?.avatarUrl ?? (item as any).avatarUrl ?? (item as any).avatar_url ?? null

      // Fallback for direct chat only
      const finalAvatarUrl = (!isGroup && !avatarUrl) ? (peerMember?.avatarUrl ?? null) : avatarUrl

      return {
        id,
        userId: partnerUserId,
        name: title && title.length > 0 ? title : peerNickname || peerFallback || `Trò chuyện ${id.slice(0, 8)}`,
        lastMessage: normalizedPreview,
        lastMessagePreview: normalizedPreview,
        unreadCount: item.unreadCount ?? 0,
        online: false,
        lastMessageSeq: item.lastMessageSeq,
        lastMessageSenderId: item.lastMessageSenderId ?? null,
        participantUserIds: members
          .map((member) => String(member.userId ?? '').trim())
          .filter((memberId): memberId is string => Boolean(memberId) && memberId !== myId),
        lastMessageAt: item.lastMessageAt ?? null,
        updatedAt: item.updatedAt ?? null,
        lastSeenTime: item.lastMessageAt ?? null,
        isGroup,
        isCloud: id.startsWith('vnalo_cloud_') || item.conversationId?.startsWith('vnalo_cloud_'),
        avatarUrl: finalAvatarUrl,
        memberCount: members.length,
        members: members.map((m) => ({
          userId: String(m.userId ?? '').trim(),
          role: String(m.role ?? 'MEMBER').toUpperCase(),
        })),
        onlyAdminCanPost: Boolean((item.conversation as any)?.onlyAdminCanPost ?? (item as any).onlyAdminCanPost),
      }
    })
}

export function mapRawMessage(raw: RawMessageLike, currentUserId: string): ChatMessage {
  const conversationId = raw.conversationId ?? raw.conversation_id ?? (raw as any).groupId ?? (raw as any).group_id ?? ''
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
  console.log('Mapped type debug:', (raw as any).type, raw.messageType)
  const type = normalizeMessageType((raw as any).type || raw.messageType || (raw as any).message_type, raw)
  const mediaUrl = mediaUrlFromPayload ?? ((type === 'image' || type === 'file' || type === 'sticker') ? mediaUrlFromContent : null)
  let messageText = mediaUrlFromContent && content.trim() === mediaUrlFromContent ? '' : content
  // Suppression: If it's an image and the text is just the filename/URL, clear it.
  if (type === 'image' && messageText && isImageUrl(messageText)) {
    messageText = ''
  }

  // Extract filename: 
  // 1. Text content if message type is file
  // 2. URL if message type is file
  const attachmentName = type === 'file'
    ? (messageText && !isHttpUrl(messageText) ? messageText : (mediaUrl ? extractFilenameFromUrl(mediaUrl) : undefined))
    : undefined

  let attachments: ChatAttachment[] | undefined = raw.attachments?.map((att: any) => ({
    url: att.url ?? att.mediaUrl ?? att.media_url ?? att.path ?? att.mediaPath ?? att.link ?? att.fullUrl ?? att.url_full ?? '',
    name: att.name ?? att.fileName ?? att.filename ?? att.file_name ?? att.title ?? att.displayName ?? att.originName ?? att.original_name ?? (att.url ? extractFilenameFromUrl(att.url) : undefined),
    mimeType: att.mimeType ?? att.mediaMimeType ?? att.media_mime_type ?? att.contentType ?? null,
    sizeBytes: att.sizeBytes ?? att.mediaSizeBytes ?? att.media_size_bytes ?? att.fileSize ?? att.size ?? null,
    thumbnailUrl: att.thumbnailUrl ?? att.mediaThumbnailUrl ?? att.media_thumbnail_url ?? att.thumbUrl ?? null,
  }))
  if ((!attachments || attachments.length === 0) && mediaUrl) {
    attachments = [
      {
        url: mediaUrl,
        name: attachmentName,
        thumbnailUrl: mediaThumbnailUrl,
        mimeType: mediaMimeType,
        sizeBytes: mediaSizeBytes,
      },
    ]
  }

  return {
    id: raw.id,
    conversationId,
    senderId,
    sender: type === 'system' ? 'system' : (senderId === currentUserId ? 'me' : 'other'),
    type: type as ChatMessageType,
    text: messageText,
    mediaUrl: mediaUrl ? resolveMediaUrl(mediaUrl) : mediaUrl,
    mediaThumbnailUrl: mediaThumbnailUrl ? resolveMediaUrl(mediaThumbnailUrl) : mediaThumbnailUrl,
    mediaMimeType,
    mediaSizeBytes,
    attachments: attachments?.map(att => ({ ...att, url: resolveMediaUrl(att.url), thumbnailUrl: att.thumbnailUrl ? resolveMediaUrl(att.thumbnailUrl) : null })),
    createdAt: createdAt ?? null,
    timestamp: formatTime(createdAt),
    serverSeq,
    clientMessageId,
    deliveryState: 'sent',
    replyTo: ((raw as any).replyTo || (raw as any).reply_to) ? ((raw as any).replyTo || (raw as any).reply_to) : (
      ((raw as any).replyToMessageId || (raw as any).reply_to_message_id) ? {
        id: (raw as any).replyToMessageId || (raw as any).reply_to_message_id,
        senderId: (raw as any).replyToSenderId || (raw as any).reply_to_sender_id,
        senderName: 'Người dùng', // Will be resolved by UI via senderId
        preview: (raw as any).replyToContent || (raw as any).reply_to_content || '',
        type: 'text' // Fallback type
      } : null
    ),
    isRecalled: raw.status === 'RECALLED' || !!(raw.recalledAt || raw.recalled_at)
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
    if (Array.isArray(candidate.data)) {
      return candidate.data as RawMessage[]
    }
    return extractRawMessages(candidate.data)
  }

  return []
}

export async function fetchConversation(token: string, conversationId: string): Promise<unknown> {
  return authorizedFetch<unknown>(token, `/conversations/${conversationId}`)
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
    attachments: payload.attachments ?? undefined,
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

export async function updateGroupAvatar(token: string, conversationId: string, avatarUrl: string): Promise<unknown> {
  return authorizedFetch<unknown>(token, `/conversations/${conversationId}`, {
    method: 'PATCH',
    body: JSON.stringify({ avatarUrl }),
  })
}

export async function renameGroupConversation(token: string, conversationId: string, name: string): Promise<unknown> {
  return authorizedFetch<unknown>(token, `/conversations/${conversationId}`, {
    method: 'PATCH',
    body: JSON.stringify({ title: name }),
  })
}

export async function setConversationNickname(token: string, conversationId: string, targetUserId: string, nickname: string): Promise<unknown> {
  return authorizedFetch<unknown>(token, `/conversations/${conversationId}/member/${targetUserId}`, {
    method: 'PATCH',
    body: JSON.stringify({ nickname }),
  })
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
  try {
    const response = await messageApi.post('/conversations/direct', { targetUserId }, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const json = response.data;

    const payload = isRecord(json) && isRecord(json.data) ? json.data : json
    const conversationId =
      isRecord(payload) && typeof payload.id === 'string'
        ? payload.id
        : isRecord(payload) && typeof payload.conversationId === 'string'
          ? payload.conversationId
          : null

    if (!conversationId) {
      throw new Error('Invalid direct conversation response payload.');
    }

    return conversationId;
  } catch (error: any) {
    throw new Error(extractMessage(error.response?.data) ?? 'Cannot open direct conversation.');
  }
}

export type CreateGroupConversationPayload = {
  title: string
  memberUserIds: string[]
  avatarUrl?: string | null
}

export type CreateGroupConversationResponse = {
  id: string
  title: string
  type: string
  members?: Array<{
    userId: string
    nickname?: string | null
  }>
}

/**
 * Create a new group conversation
 * @param token - Authorization token
 * @param payload - Group creation payload with title, member IDs, and optional avatar URL
 * @returns Conversation ID of the newly created group
 */
export async function createGroupConversation(
  token: string,
  payload: CreateGroupConversationPayload,
): Promise<string> {
  const res = await authorizedFetch<any>(token, '/conversations/group', {
    method: 'POST',
    body: JSON.stringify({
      title: payload.title.trim(),
      memberIds: payload.memberUserIds,
      ...(payload.avatarUrl ? { avatarUrl: payload.avatarUrl } : {}),
    }),
  });

  // Extract ID from response which might be wrapped in { data: { id: ... } } or just { id: ... }
  if (res && typeof res === 'object') {
    if (typeof res.id === 'string') return res.id;
    if (res.data && typeof res.data.id === 'string') return res.data.id;
    if (typeof res.conversationId === 'string') return res.conversationId;
  }

  throw new Error('Malformed response from group creation API');
}
export async function fetchStickerPacks(token: string): Promise<any[]> {
  try {
    const response = await mediaApi.get('/stickers/my-packs', {
      headers: { Authorization: `Bearer ${token}` }
    });
    const json = response.data;
    const items = json.data?.content || json.data || json || [];

    if (Array.isArray(items)) {
      items.forEach((item: any) => {
        if (item.coverUrl) item.coverUrl = normalizeMediaUrl(item.coverUrl);
      });
    }

    return items;
  } catch (error: any) {
    throw new Error(`Failed to fetch sticker packs: ${error.message}`);
  }
}

export async function fetchStickerPackDetails(token: string, packId: string): Promise<any> {
  try {
    const response = await mediaApi.get(`/stickers/packs/${packId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const json = response.data;
    const data = json.data || json;

    if (data && Array.isArray(data.stickers)) {
      data.stickers.forEach((s: any) => {
        if (s.url) s.url = normalizeMediaUrl(s.url);
      });
    }
    if (data && data.coverUrl) {
      data.coverUrl = normalizeMediaUrl(data.coverUrl);
    }

    return data;
  } catch (error: any) {
    throw new Error(`Failed to fetch pack details: ${error.message}`);
  }
}

export async function fetchMediaByCategory(token: string, category: 'EMOJI' | 'GIF'): Promise<any[]> {
  try {
    const response = await mediaApi.get(`/media?category=${category}&size=100`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    const json = response.data;
    let items = json.data?.content || json.data || json || []
    if (!Array.isArray(items)) items = []

    // Fallback: Deep discovery from SYSTEM assets
    if (items.length === 0) {
      console.log(`[chat.api.fetchMediaByCategory] ${category} list empty, performing MASSIVE discovery (limit 3000)...`)
      const fbResponse = await mediaApi.get('/media?size=3000', {
        headers: { Authorization: `Bearer ${token}` }
      });

      if (fbResponse.status === 200) {
        const fbJson = fbResponse.data;
        const fbItems = fbJson.data?.content || fbJson.data || fbJson || []
        // ... rest of the filtering logic ...

        if (Array.isArray(fbItems) && fbItems.length > 0) {
          console.log(`[chat.api.discovery] Total system assets found: ${fbItems.length}`);
          const distinctCats = [...new Set(fbItems.map((m: any) => m.category))];
          console.log(`[chat.api.discovery] Distinct categories in DB:`, distinctCats);

          items = fbItems.filter((m: any) => {
            const mCat = String(m.category).toUpperCase();
            const targetCat = category.toUpperCase();
            const name = String(m.originalFilename || '').toLowerCase();
            const url = String(m.url || '').toLowerCase();
            const keyword = category.toLowerCase(); // "emoji" or "gif"

            // 1. Match by explicit category
            if (mCat === targetCat) return true;

            // 2. Match by keyword in name/url
            if (name.includes(keyword) || url.includes(keyword)) return true;

            // 3. Match by specific S3 folder path (e.g. ".../emoji/..." for EMOJI tab)
            if (url.includes('s3.amazonaws.com') && url.includes(`/${keyword}/`)) return true;

            return false;
          });

          // Prioritize S3 URLs over Tenor links
          items.sort((a: any, b: any) => {
            const aS3 = String(a.url || '').includes('s3.amazonaws.com');
            const bS3 = String(b.url || '').includes('s3.amazonaws.com');
            if (aS3 && !bS3) return -1;
            if (!aS3 && bS3) return 1;
            return 0;
          });
        }
      }
    }

    // SYNTHETIC INJECTION: Add the specific S3 files you provided if no DB records match them
    const S3_BUCKET_BASE = 'https://vnalo-media-cnm.s3.ap-southeast-1.amazonaws.com';
    const S3_SYS_OWNER = '00000000-0000-0000-0000-000000000000';

    if (category === 'GIF') {
      const manualGifs = [
        '231fb5027639114dd7cf3f8f3ef9cb86_1e11ebf8.gif',
        '6be7aff1e380d160a12b24a9c7e84c31_02af819b.gif',
        'anh-dong-dang-yeu-cua-chu-meo-dang-nhay_187a6c8f.gif',
        'b0067ade5e832d2aefec8ee9bda50fdc_6e53714b.gif',
        'cute-dragon-where-are-you_e1be4667.gif',
        'hinh-anh-dong-de-thuong_026ab5d8.gif',
        'image_861306190008386347778_644997d6.gif'
      ];

      manualGifs.reverse().forEach((filename, idx) => {
        const url = `${S3_BUCKET_BASE}/gif/${S3_SYS_OWNER}/${filename}`;
        if (!items.some((it: any) => it.url?.includes(filename))) {
          items.unshift({
            mediaId: `v-gif-${idx}`,
            url,
            category: 'GIF',
            originalFilename: filename
          });
        }
      });
    } else if (category === 'EMOJI') {
      // Manual emojis removed as requested
    }

    // Normalize URLs
    if (Array.isArray(items)) {
      items.forEach((item: any) => {
        if (item.url) item.url = normalizeMediaUrl(item.url);
        if (item.thumbnailUrl) item.thumbnailUrl = normalizeMediaUrl(item.thumbnailUrl);
      });
    }

    return items
  } catch (error) {
    console.error(`[chat.api.fetchMediaByCategory] Exception:`, error)
    throw error
  }
}

/**
 * Normalizes a media URL from the backend.
 */
function normalizeMediaUrl(url: string | null | undefined): string {
  if (!url) return '';

  let normalized = url;

  // Fix S3 URLs missing region (common in seeded data)
  if (normalized.startsWith('https://') && normalized.includes('.s3.amazonaws.com')) {
    if (!normalized.match(/\.s3\.[a-z0-9-]+\.amazonaws\.com/)) {
      normalized = normalized.replace('.s3.amazonaws.com', '.s3.ap-southeast-1.amazonaws.com');
      console.log(`[chat.api.normalize] CORRECTED region: ${url} -> ${normalized}`);
    }
  }

  if (normalized.startsWith('http')) {
    console.log(`[chat.api.normalize] Final URL: ${normalized}`);
    return normalized;
  }

  // Handle relative paths from backend local-storage
  const backendHost = API_BASE_URL.split('/api/v1')[0];
  const result = `${backendHost}${normalized.startsWith('/') ? '' : '/'}${normalized}`;
  console.log(`[chat.api.normalize] Relative to Absolute: ${url} -> ${result}`);
  return result;
}


export async function addMembersToConversation(token: string, conversationId: string, memberIds: string[]): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/members`, {
    method: 'POST',
    body: JSON.stringify({ memberIds }),
  })
}

export async function leaveConversation(token: string, conversationId: string): Promise<void> {
  try {
    await messageApi.post(`/conversations/${conversationId}/leave`, {}, {
      headers: { Authorization: `Bearer ${token}` },
    });
  } catch (error: any) {
    if (error.response?.status === 403) {
      throw new Error('Bạn cần chuyển quyền trước khi rời nhóm');
    }
    throw new Error(extractMessage(error.response?.data) ?? 'Unable to leave conversation');
  }
}

export async function disbandConversation(token: string, conversationId: string): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}`, {
    method: 'DELETE',
  })
}

export async function removeMember(token: string, conversationId: string, userId: string): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/members/${userId}`, {
    method: 'DELETE',
  })
}

export async function updateMemberRole(token: string, conversationId: string, userId: string, role: string): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}/member/${userId}`, {
    method: 'PATCH',
    body: JSON.stringify({ role }),
  })
}

export async function updateConversation(token: string, conversationId: string, settings: Partial<any>): Promise<void> {
  await authorizedFetch(token, `/conversations/${conversationId}`, {
    method: 'PATCH',
    body: JSON.stringify(settings),
  })
}

