import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Bot, Mic, Paperclip, Send, Sparkles, Trash2, X } from 'lucide-react'

import { extractMessage } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { fetchInbox, sendAiChatMessage } from '../features/chat/chat.api'
import type { ConversationSummary } from '../features/chat/chat.types'

type ProviderStatus =
  | 'LIVE_PROVIDER_ACTIVE'
  | 'FALLBACK_PROVIDER_ACTIVE'
  | 'AI_PROVIDER_UNAVAILABLE'
  | null

type AiActionCommand =
  | 'OPEN_CHAT'
  | 'COMPOSE_MESSAGE'
  | 'START_CALL'
  | 'RECALL_MESSAGE'
  | 'CREATE_GROUP'
  | 'MUTE_CONVERSATION'
  | 'UNMUTE_CONVERSATION'
  | 'PIN_MESSAGE'
  | 'UNPIN_MESSAGE'
  | 'OPEN_GROUP_SETTINGS'
  | 'OPEN_PROFILE'
  | 'SEND_FRIEND_REQUEST'
  | 'BLOCK_USER'
  | 'UNBLOCK_USER'
  | 'CHANGE_GROUP_NAME'
  | 'ADD_GROUP_MEMBER'
  | 'REMOVE_GROUP_MEMBER'
  | 'TRANSFER_GROUP_OWNER'
  | 'LEAVE_GROUP'
  | 'DISBAND_GROUP'
  | 'NAVIGATE_TO'
  | 'NAVIGATE_TO_SETTINGS'
  | 'NAVIGATE_TO_CHAT'
  | 'NAVIGATE_TO_CONTACTS'
  | 'NAVIGATE_TO_SCANNER'
  | 'NAVIGATE_TO_TIMELINE'

type AiMessage = {
  role: 'user' | 'assistant'
  content: string
  timestamp: string
  degraded?: boolean
  providerStatus?: ProviderStatus
  actionCommand?: AiActionCommand | null
  actionParams?: Record<string, unknown> | null
}


type PendingActionResolution = {
  candidates: ConversationSummary[]
  draft: string
  command: AiActionCommand
  targetLabel?: string
}

type PendingActionReview = {
  title: string
  description: string
  confirmLabel: string
  path?: string
  feedback: string
  preview?: AiActionPreview
}

type AiActionPreview = {
  targetLabel?: string
  draft?: string
  risk: 'low' | 'medium' | 'high'
}

type ActionFeedbackState = {
  tone: 'info' | 'success' | 'warning' | 'error'
  message: string
}

const isAxiosLikeError = (error: unknown): error is { response?: { status?: number; data?: unknown } } => {
  return Boolean(error && typeof error === 'object' && 'response' in error)
}

const isNetworkError = (error: unknown) => {
  if (!error || typeof error !== 'object') return false
  const maybeError = error as { response?: unknown; request?: unknown; code?: string; message?: string }
  return !maybeError.response && (Boolean(maybeError.request) || maybeError.code === 'ERR_NETWORK' || maybeError.message === 'Network Error')
}

function resolveErrorPresentation(error: unknown): { message: string; providerStatus: ProviderStatus; degraded: boolean } {
  const response = isAxiosLikeError(error) ? error.response : undefined
  const status = response?.status ?? null
  const extracted = extractMessage(response?.data) || extractMessage(error)

  if (status === 401) {
    return {
      message: extracted || 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục dùng Trợ lý AI.',
      providerStatus: null,
      degraded: false,
    }
  }

  if (status === 403) {
    return {
      message: extracted || 'Bạn chưa có quyền truy cập Trợ lý AI từ phiên đăng nhập hiện tại.',
      providerStatus: null,
      degraded: false,
    }
  }

  if (status === 404) {
    return {
      message: extracted || 'Đường dẫn AI trên máy chủ chưa sẵn sàng hoặc đang cấu hình sai. Vui lòng kiểm tra deploy gateway.',
      providerStatus: null,
      degraded: false,
    }
  }

  if (status === 429) {
    return {
      message: extracted || 'AI đang quá tải hoặc chạm giới hạn tạm thời. Hãy thử lại sau ít phút.',
      providerStatus: 'FALLBACK_PROVIDER_ACTIVE',
      degraded: true,
    }
  }

  if (status === 503) {
    return {
      message: extracted || 'Nhà cung cấp AI hiện chưa sẵn sàng. Hãy thử lại sau ít phút.',
      providerStatus: 'AI_PROVIDER_UNAVAILABLE',
      degraded: true,
    }
  }

  if (isNetworkError(error)) {
    return {
      message: extracted || 'Không kết nối được tới Trợ lý AI. Vui lòng kiểm tra mạng hoặc thử lại sau.',
      providerStatus: null,
      degraded: false,
    }
  }

  return {
    message: extracted || 'Đã xảy ra lỗi khi kết nối tới Trợ lý AI. Vui lòng thử lại sau.',
    providerStatus: null,
    degraded: false,
  }
}
const STORAGE_KEY = 'vnalo_ai_chat_history'
const LEGACY_STORAGE_KEY = STORAGE_KEY
const DRAFT_KEY_PREFIX = 'vnalo_ai_web_compose_draft:'
const PENDING_PROMPT_KEY = 'vnalo_ai_web_pending_prompt'
const MAX_API_HISTORY = 20

const MOJIBAKE_CODEPOINTS = [0x00C3, 0x00C4, 0x00C2, 0x00C6, 0x00C5, 0x00D0]

function mojibakeScore(value: string) {
  let total = 0
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0
    if (MOJIBAKE_CODEPOINTS.includes(code)) {
      total += 3
    }
    if (code >= 0x80 && code <= 0x9f) {
      total += 4
    }
  }
  return total
}

function tryDecodeUtf8Mojibake(value: string) {
  const bytes: number[] = []
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0
    if (code > 255) {
      return value
    }
    bytes.push(code)
  }

  return new TextDecoder('utf-8', { fatal: false }).decode(new Uint8Array(bytes))
}

function normalizeIncomingText(value: string) {
  let best = value
  let bestScore = mojibakeScore(value)

  for (let pass = 0; pass < 4; pass += 1) {
    const candidate = tryDecodeUtf8Mojibake(best)
    if (!candidate || candidate === best) {
      break
    }

    const candidateScore = mojibakeScore(candidate)
    if (candidateScore >= bestScore) {
      break
    }

    best = candidate
    bestScore = candidateScore
  }

  return best
}

function buildAiStorageKey(userId?: string | number | null) {
  if (userId === undefined || userId === null || `${userId}`.trim().length === 0) {
    return null
  }
  return `${STORAGE_KEY}:${userId}`
}

const PRESET_PROMPTS = [
  'Tóm tắt nhanh các tính năng chính của VNALO',
  'Giúp tôi soạn một tin nhắn từ chối lịch hẹn lịch sự',
  'Mở cuộc trò chuyện với một người trong danh bạ',
  'Giải thích ngắn gọn một tính năng bảo mật trong ứng dụng',
]

const INITIAL_ASSISTANT_MESSAGE: AiMessage = {
  role: 'assistant',
  content: 'Xin chào! Mình là VNALO AI Assistant. Mình có thể trả lời câu hỏi và gợi ý thao tác an toàn trong hệ thống.',
  timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
}

const KNOWN_ACTION_COMMANDS = new Set<AiActionCommand>([
  'OPEN_CHAT',
  'COMPOSE_MESSAGE',
  'START_CALL',
  'RECALL_MESSAGE',
  'CREATE_GROUP',
  'MUTE_CONVERSATION',
  'UNMUTE_CONVERSATION',
  'PIN_MESSAGE',
  'UNPIN_MESSAGE',
  'OPEN_GROUP_SETTINGS',
  'OPEN_PROFILE',
  'SEND_FRIEND_REQUEST',
  'BLOCK_USER',
  'UNBLOCK_USER',
  'CHANGE_GROUP_NAME',
  'ADD_GROUP_MEMBER',
  'REMOVE_GROUP_MEMBER',
  'TRANSFER_GROUP_OWNER',
  'LEAVE_GROUP',
  'DISBAND_GROUP',
  'NAVIGATE_TO',
  'NAVIGATE_TO_SETTINGS',
  'NAVIGATE_TO_CHAT',
  'NAVIGATE_TO_CONTACTS',
  'NAVIGATE_TO_SCANNER',
  'NAVIGATE_TO_TIMELINE',
])

function isStaleRawAiError(content: string) {
  const normalized = content.trim().toLowerCase()
  return normalized === 'request failed with status code 403'
    || normalized === 'request failed with status code 401'
    || normalized === 'request failed with status code 404'
    || normalized === 'request failed with status code 500'
}

function normalizeStoredMessages(payload: unknown): AiMessage[] {
  if (!Array.isArray(payload)) return [INITIAL_ASSISTANT_MESSAGE]

  const normalized = payload
    .map<AiMessage | null>((item): AiMessage | null => {
      if (!item || typeof item !== 'object') return null
      const value = item as Record<string, unknown>
      const role = value.role === 'assistant' ? 'assistant' : value.role === 'user' ? 'user' : null
      const content = typeof value.content === 'string' ? normalizeIncomingText(value.content).trim() : ''
      const timestamp = typeof value.timestamp === 'string' && value.timestamp.trim() ? value.timestamp : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      if (!role || !content || isStaleRawAiError(content)) return null

      return {
        role,
        content,
        timestamp,
        degraded: Boolean(value.degraded),
        providerStatus: value.providerStatus === 'LIVE_PROVIDER_ACTIVE' || value.providerStatus === 'FALLBACK_PROVIDER_ACTIVE' || value.providerStatus === 'AI_PROVIDER_UNAVAILABLE' ? value.providerStatus : null,
        actionCommand: typeof value.actionCommand === 'string' && KNOWN_ACTION_COMMANDS.has(value.actionCommand as AiActionCommand)
          ? (value.actionCommand as AiActionCommand)
          : null,
        actionParams: value.actionParams && typeof value.actionParams === 'object' ? (value.actionParams as Record<string, unknown>) : null,
      }
    })
    .filter((item): item is AiMessage => item !== null)

  return normalized.length > 0 ? normalized : [INITIAL_ASSISTANT_MESSAGE]
}
function resolveProviderPresentation(messages: AiMessage[]) {
  const latestAssistantMessage = [...messages].reverse().find((message) => message.role === 'assistant')
  const providerStatus = latestAssistantMessage?.providerStatus ?? null
  const degraded = Boolean(latestAssistantMessage?.degraded)

  if (providerStatus === 'AI_PROVIDER_UNAVAILABLE') {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: 'ai-header-status ai-header-status-warning',
      label: 'AI đang bảo trì',
      helper: 'Một số phản hồi AI có thể tạm thời bị giới hạn.',
      banner: 'AI đang bảo trì. Hãy thử lại sau hoặc tiếp tục thao tác thủ công.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-warning',
    }
  }

  if (providerStatus === 'FALLBACK_PROVIDER_ACTIVE' || degraded) {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: 'ai-header-status ai-header-status-degraded',
      label: 'Chế độ dự phòng',
      helper: 'Hệ thống đang dùng tuyến phản hồi thay thế.',
      banner: 'AI đang chạy ở chế độ dự phòng, chất lượng phản hồi có thể giảm.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-info',
    }
  }

  return {
    providerStatus,
    degraded: false,
    badgeClassName: 'ai-header-status',
    label: 'Sẵn sàng hỗ trợ',
    helper: 'Trợ lý AI có thể trả lời và gợi ý thao tác an toàn trong VNALO.',
    banner: '',
    bannerClassName: 'ai-runtime-banner',
  }
}

function normalizeLookupText(value: string) {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

function tokenizeLookupText(value: string) {
  const normalized = normalizeLookupText(value)
  return normalized ? normalized.split(' ') : []
}

function computeConversationMatchScore(conversationName: string, target: string) {
  const normalizedName = normalizeLookupText(conversationName)
  const normalizedTarget = normalizeLookupText(target)
  if (!normalizedName || !normalizedTarget) return -1
  if (normalizedName === normalizedTarget) return 1000
  if (normalizedName.startsWith(`${normalizedTarget} `)) return 930
  if (normalizedName.endsWith(` ${normalizedTarget}`)) return 920
  if (normalizedName.includes(normalizedTarget)) return 870 + normalizedTarget.length

  const nameTokens = tokenizeLookupText(normalizedName)
  const targetTokens = tokenizeLookupText(normalizedTarget)
  if (!nameTokens.length || !targetTokens.length || targetTokens.length > nameTokens.length) return -1

  let cursor = 0
  let score = 700 + targetTokens.length * 25
  for (const targetToken of targetTokens) {
    let foundIndex = -1
    for (let index = cursor; index < nameTokens.length; index += 1) {
      const nameToken = nameTokens[index]
      if (nameToken === targetToken || nameToken.startsWith(targetToken)) {
        foundIndex = index
        break
      }
    }
    if (foundIndex < 0) return -1
    score -= (foundIndex - cursor) * 8
    cursor = foundIndex + 1
  }

  if (nameTokens[0] === targetTokens[0]) score += 30
  if (nameTokens[nameTokens.length - 1] === targetTokens[targetTokens.length - 1]) score += 45
  score -= Math.max(0, nameTokens.length - targetTokens.length) * 6
  return score
}

function extractActionTarget(params?: Record<string, unknown> | null) {
  if (!params) return ''
  const raw =
    params.target ??
    params.recipient ??
    params.contactName ??
    params.displayName ??
    params.conversationName ??
    params.groupName ??
    params.groupTitle ??
    params.chatName ??
    params.name ??
    ''
  return String(raw).trim()
}

function extractComposeContent(params?: Record<string, unknown> | null) {
  if (!params) return ''
  const raw = params.content ?? params.messageText ?? params.prefilledText ?? ''
  return String(raw).trim()
}

function buildConversationSubtitle(conversation: ConversationSummary) {
  if (conversation.isGroup) {
    const count = conversation.memberCount ?? conversation.members?.length ?? 0
    return count > 0 ? `${count} thành viên` : 'Cuộc trò chuyện nhóm'
  }

  return 'Cuộc trò chuyện 1-1'
}

function buildRiskLabel(risk: AiActionPreview['risk']) {
  if (risk === 'high') return 'Rủi ro cao'
  if (risk === 'medium') return 'Cần xác nhận'
  return 'An toàn'
}

function buildActionRisk(command: AiActionCommand): AiActionPreview['risk'] {
  if (HIGH_RISK_ACTION_COMMANDS.has(command)) return 'high'
  if (command === 'CREATE_GROUP' || command === 'SEND_FRIEND_REQUEST' || command === 'START_CALL') return 'medium'
  return 'low'
}

function resolveNavigatePath(command: AiActionCommand, params?: Record<string, unknown> | null) {
  if (command === 'NAVIGATE_TO_CHAT') return '/chat'
  if (command === 'NAVIGATE_TO_CONTACTS') return '/contacts'
  if (command === 'OPEN_PROFILE') return '/profile'
  if (command === 'NAVIGATE_TO_SETTINGS') return '/profile'
  if (command !== 'NAVIGATE_TO') return null

  const page = String(params?.page ?? params?.destination ?? params?.screen ?? '').trim().toLowerCase()
  if (page === 'chat') return '/chat'
  if (page === 'contacts') return '/contacts'
  if (page === 'profile' || page === 'settings') return '/profile'
  return null
}

const CONVERSATION_ACTION_COMMANDS = new Set<AiActionCommand>([
  'OPEN_CHAT',
  'COMPOSE_MESSAGE',
  'START_CALL',
  'OPEN_GROUP_SETTINGS',
  'MUTE_CONVERSATION',
  'UNMUTE_CONVERSATION',
  'CHANGE_GROUP_NAME',
  'ADD_GROUP_MEMBER',
  'REMOVE_GROUP_MEMBER',
  'TRANSFER_GROUP_OWNER',
  'LEAVE_GROUP',
  'DISBAND_GROUP',
])

const HIGH_RISK_ACTION_COMMANDS = new Set<AiActionCommand>([
  'BLOCK_USER',
  'UNBLOCK_USER',
  'REMOVE_GROUP_MEMBER',
  'TRANSFER_GROUP_OWNER',
  'LEAVE_GROUP',
  'DISBAND_GROUP',
  'RECALL_MESSAGE',
])

function isConversationAction(command: AiActionCommand) {
  return CONVERSATION_ACTION_COMMANDS.has(command)
}

function buildActionLabel(command: AiActionCommand) {
  switch (command) {
    case 'OPEN_CHAT':
      return 'Mở cuộc trò chuyện'
    case 'COMPOSE_MESSAGE':
      return 'Mở chat và điền nháp'
    case 'OPEN_GROUP_SETTINGS':
      return 'Mở cài đặt nhóm'
    case 'START_CALL':
      return 'Mở chat để gọi'
    case 'RECALL_MESSAGE':
      return 'Thu hồi tin nhắn'
    case 'CREATE_GROUP':
      return 'Tạo nhóm mới'
    case 'MUTE_CONVERSATION':
      return 'Tắt thông báo cuộc trò chuyện'
    case 'UNMUTE_CONVERSATION':
      return 'Bật lại thông báo cuộc trò chuyện'
    case 'PIN_MESSAGE':
      return 'Ghim tin nhắn'
    case 'UNPIN_MESSAGE':
      return 'Bỏ ghim tin nhắn'
    case 'SEND_FRIEND_REQUEST':
      return 'Gửi lời mời kết bạn'
    case 'BLOCK_USER':
      return 'Chặn người dùng'
    case 'UNBLOCK_USER':
      return 'Bỏ chặn người dùng'
    case 'CHANGE_GROUP_NAME':
      return 'Đổi tên nhóm'
    case 'ADD_GROUP_MEMBER':
      return 'Thêm thành viên'
    case 'REMOVE_GROUP_MEMBER':
      return 'Xóa thành viên'
    case 'TRANSFER_GROUP_OWNER':
      return 'Chuyển quyền trưởng nhóm'
    case 'LEAVE_GROUP':
      return 'Rời nhóm'
    case 'DISBAND_GROUP':
      return 'Giải tán nhóm'
    case 'NAVIGATE_TO':
      return 'Đi đến trang yêu cầu'
    case 'NAVIGATE_TO_SETTINGS':
      return 'Mở cài đặt'
    case 'NAVIGATE_TO_CHAT':
      return 'Đi đến Chat'
    case 'NAVIGATE_TO_CONTACTS':
      return 'Đi đến Danh bạ'
    case 'NAVIGATE_TO_SCANNER':
      return 'Mở trình quét'
    case 'NAVIGATE_TO_TIMELINE':
      return 'Mở nhật ký'
    case 'OPEN_PROFILE':
      return 'Mở hồ sơ'
    default:
      return 'Thực hiện thao tác'
  }
}

function buildDeferredActionReply(command: AiActionCommand) {
  return `Mình đã nhận diện yêu cầu: ${buildActionLabel(command)}. Hãy bấm nút bên dưới để mình kiểm tra đúng đối tượng và mở luồng an toàn.`
}

function buildMissingConversationFeedback(command: AiActionCommand, target: string) {
  const targetLabel = target ? `"${target}"` : 'người/cuộc trò chuyện đó'

  if (command === 'START_CALL') {
    return `Mình không tìm thấy ${targetLabel} trong danh bạ hoặc danh sách trò chuyện của bạn, nên chưa thể chuẩn bị cuộc gọi. Hãy kiểm tra lại tên hoặc kết bạn trước khi gọi.`
  }

  if (command === 'COMPOSE_MESSAGE') {
    return `Mình không tìm thấy ${targetLabel} trong danh bạ hoặc danh sách trò chuyện của bạn, nên chưa thể mở chat và điền nháp. Hãy kiểm tra lại tên người nhận.`
  }

  return `Mình không tìm thấy ${targetLabel} trong danh bạ hoặc danh sách trò chuyện của bạn. Hãy kiểm tra lại tên hoặc chọn thủ công trong Chat.`
}

function buildActionSuccessFeedback(command: AiActionCommand) {
  if (command === 'START_CALL') {
    return 'Đã mở đúng cuộc trò chuyện. Hãy bấm nút gọi để xác nhận cuộc gọi trên web.'
  }

  if (command === 'COMPOSE_MESSAGE') {
    return 'Đã mở đúng cuộc trò chuyện và lưu nội dung nháp nếu AI có cung cấp. Hãy kiểm tra lại trước khi gửi.'
  }

  if (HIGH_RISK_ACTION_COMMANDS.has(command)) {
    return 'Đã mở đúng cuộc trò chuyện. Hãy tự kiểm tra kỹ và xác nhận thủ công trước khi thực hiện thao tác nhạy cảm.'
  }

  return 'Đã mở đúng cuộc trò chuyện đích.'
}

type AiChatPageProps = {
  embedded?: boolean
}

export function AiChatPage({ embedded = false }: AiChatPageProps = {}) {
  const { accessToken, user } = useAuth()
  const navigate = useNavigate()
  const historyStorageKey = useMemo(() => buildAiStorageKey(user?.id as string | number | undefined), [user?.id])
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [actionBusyIndex, setActionBusyIndex] = useState<number | null>(null)
  const [activeActionLabel, setActiveActionLabel] = useState<string>('')
  const [actionFeedback, setActionFeedback] = useState<ActionFeedbackState | null>(null)
  const [pendingResolution, setPendingResolution] = useState<PendingActionResolution | null>(null)
  const [pendingActionReview, setPendingActionReview] = useState<PendingActionReview | null>(null)
  const [retryPrompt, setRetryPrompt] = useState<string>('')
  const messagesEndRef = useRef<HTMLDivElement | null>(null)
  const messagesContainerRef = useRef<HTMLDivElement | null>(null)
  const inputRef = useRef<HTMLTextAreaElement | null>(null)
  const isUnmountedRef = useRef(false)
  const inFlightRequestRef = useRef(false)

  useEffect(() => {
    return () => {
      isUnmountedRef.current = true
    }
  }, [])

  useEffect(() => {
    const pendingPrompt = localStorage.getItem(PENDING_PROMPT_KEY)
    if (!pendingPrompt?.trim()) return

    localStorage.removeItem(PENDING_PROMPT_KEY)
    setInputValue(pendingPrompt.trim())
    setTimeout(() => {
      inputRef.current?.focus()
    }, 50)
  }, [])

  useEffect(() => {
    if (!historyStorageKey) {
      setMessages([INITIAL_ASSISTANT_MESSAGE])
      return
    }

    const saved = localStorage.getItem(historyStorageKey)
    const legacySaved = localStorage.getItem(LEGACY_STORAGE_KEY)
    if (!saved && !legacySaved) {
      setMessages([INITIAL_ASSISTANT_MESSAGE])
      return
    }

    try {
      const parsed = JSON.parse(saved ?? legacySaved ?? 'null')
      const normalized = normalizeStoredMessages(parsed)
      setMessages(normalized)
      if (!saved && legacySaved) {
        localStorage.setItem(historyStorageKey, JSON.stringify(normalized))
        localStorage.removeItem(LEGACY_STORAGE_KEY)
      }
    } catch (error) {
      console.warn('Failed to parse AI chat history', error)
      setMessages([INITIAL_ASSISTANT_MESSAGE])
    }
  }, [historyStorageKey])

  const saveMessages = (nextMessages: AiMessage[]) => {
    const normalized = normalizeStoredMessages(nextMessages)
    setMessages(normalized)
    if (!historyStorageKey) {
      return
    }
    localStorage.setItem(historyStorageKey, JSON.stringify(normalized))
    localStorage.removeItem(LEGACY_STORAGE_KEY)
  }

  const appendAssistantFeedback = (
    content: string,
    options?: Partial<Pick<AiMessage, 'degraded' | 'providerStatus'>>,
  ) => {
    const feedbackMessage: AiMessage = {
      role: 'assistant',
      content,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      degraded: options?.degraded,
      providerStatus: options?.providerStatus ?? null,
    }

    setMessages((currentMessages) => {
      const nextMessages = normalizeStoredMessages([...currentMessages, feedbackMessage])
      if (historyStorageKey) {
        localStorage.setItem(historyStorageKey, JSON.stringify(nextMessages))
        localStorage.removeItem(LEGACY_STORAGE_KEY)
      }
      return nextMessages
    })
  }

  useEffect(() => {
    const container = messagesContainerRef.current
    if (!container) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
      return
    }

    container.scrollTo({ top: container.scrollHeight, behavior: 'smooth' })
  }, [messages, isLoading, actionFeedback])

  const runtimeState = useMemo(() => resolveProviderPresentation(messages), [messages])
  const isAssistantBusy = isLoading || actionBusyIndex !== null || pendingActionReview !== null || pendingResolution !== null

  useEffect(() => {
    const input = inputRef.current
    if (!input) return

    input.style.height = '0px'
    input.style.height = `${Math.min(input.scrollHeight, 132)}px`
  }, [inputValue])

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend ?? inputValue).trim()
    if (!query || isAssistantBusy || inFlightRequestRef.current) {
      return
    }

    if (!accessToken) {
      const authError: AiMessage = {
        role: 'assistant',
        content: 'Bạn cần đăng nhập lại để dùng Trợ lý AI trên web.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: false,
        providerStatus: null,
      }
      saveMessages([...messages, authError])
      return
    }

    if (!textToSend) {
      setInputValue('')
    }

    const userMessage: AiMessage = {
      role: 'user',
      content: query,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    }

    const updatedMessages = [...messages, userMessage]
    saveMessages(updatedMessages)
    setRetryPrompt(query)
    setActionFeedback(null)
    inFlightRequestRef.current = true
    setIsLoading(true)

    try {
      const apiHistory = updatedMessages.slice(-MAX_API_HISTORY).map((message) => ({
        role: message.role,
        content: message.content,
      }))

      const aiResponse = await sendAiChatMessage(accessToken, query, apiHistory)
      const responseActionCommand = (aiResponse.actionCommand as AiActionCommand | undefined) ?? null
      const safeActionCommand = responseActionCommand && KNOWN_ACTION_COMMANDS.has(responseActionCommand) ? responseActionCommand : null
      const assistantMessage: AiMessage = {
        role: 'assistant',
        content: safeActionCommand
          ? buildDeferredActionReply(safeActionCommand)
          : aiResponse.textReply || 'Mình chưa thể xử lý yêu cầu này ngay lúc này.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: Boolean(aiResponse.degraded),
        providerStatus: (aiResponse.providerStatus as ProviderStatus | undefined) ?? null,
        actionCommand: safeActionCommand,
        actionParams: aiResponse.actionParams ?? null,
      }

      if (!isUnmountedRef.current) {
        saveMessages([...updatedMessages, assistantMessage])
        setRetryPrompt('')
      }
    } catch (error) {
      console.error('AI chat failed:', error)
      const errorPresentation = resolveErrorPresentation(error)

      const errorMessage: AiMessage = {
        role: 'assistant',
        content: errorPresentation.message,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: errorPresentation.degraded,
        providerStatus: errorPresentation.providerStatus,
      }

      if (!isUnmountedRef.current) {
        saveMessages([...updatedMessages, errorMessage])
      }
    } finally {
      if (!isUnmountedRef.current) {
        inFlightRequestRef.current = false
        setIsLoading(false)
      } else {
        inFlightRequestRef.current = false
      }
    }
  }

  const handleAction = async (message: AiMessage, index: number) => {
    if (!accessToken || !message.actionCommand || actionBusyIndex !== null || isLoading) {
      return
    }

    setActionBusyIndex(index)
    setActiveActionLabel(buildActionLabel(message.actionCommand))
    setActionFeedback(null)

    try {
      const command = message.actionCommand
      const params = message.actionParams ?? {}
      const directPath = resolveNavigatePath(command, params)

      if (directPath) {
        navigate(directPath)
        setActionFeedback({ tone: 'success', message: 'Đã mở đúng màn hình bạn yêu cầu trong VNALO.' })
        appendAssistantFeedback('Mình đã mở đúng màn hình bạn yêu cầu trong VNALO.')
        return
      }

      if (command === 'CREATE_GROUP') {
        setPendingActionReview({
          title: 'Mở luồng tạo nhóm',
          description: 'AI sẽ mở màn hình tạo nhóm. Bạn vẫn cần kiểm tra thành viên và xác nhận tạo nhóm thủ công.',
          confirmLabel: 'Mở tạo nhóm',
          path: '/chat?createGroup=true',
          feedback: 'Đã mở luồng tạo nhóm. Hãy kiểm tra tên nhóm và danh sách thành viên trước khi tạo.',
          preview: { risk: 'medium', targetLabel: String(params.title ?? params.groupName ?? 'Nhóm mới') },
        })
        return
      }

      if (command === 'SEND_FRIEND_REQUEST') {
        setPendingActionReview({
          title: 'Mở danh bạ để gửi kết bạn',
          description: 'Trợ lý web sẽ không tự gửi lời mời kết bạn. Mình sẽ mở Danh bạ để bạn kiểm tra đúng người rồi tự gửi.',
          confirmLabel: 'Mở Danh bạ',
          path: '/contacts',
          feedback: 'Đã mở Danh bạ. Hãy xác nhận đúng người trước khi gửi lời mời kết bạn.',
          preview: { risk: 'medium', targetLabel: extractActionTarget(params) || 'Chưa rõ liên hệ' },
        })
        return
      }

      if (HIGH_RISK_ACTION_COMMANDS.has(command) && !isConversationAction(command)) {
        setPendingActionReview({
          title: 'Cần xác nhận thủ công',
          description: 'Thao tác này có thể ảnh hưởng đến tài khoản, tin nhắn hoặc thành viên nhóm. Trợ lý web sẽ chỉ mở đúng luồng để bạn tự xác nhận.',
          confirmLabel: 'Mở Chat',
          path: '/chat',
          feedback: 'Đã mở Chat. Hãy kiểm tra đúng đối tượng rồi tự thực hiện thao tác nhạy cảm này.',
          preview: { risk: 'high', targetLabel: extractActionTarget(params) || command },
        })
        return
      }

      if (isConversationAction(command)) {
        const target = extractActionTarget(params)
        if (!target) {
          navigate('/chat')
          setActionFeedback({ tone: 'warning', message: 'AI chưa xác định được cuộc trò chuyện cụ thể. Mình đã mở Chat để bạn tự chọn.' })
          appendAssistantFeedback('Mình chưa xác định được người nhận hoặc cuộc trò chuyện cụ thể, nên đã mở Chat để bạn tự chọn thủ công.')
          return
        }

        const inbox = await fetchInbox(accessToken, user?.id)
        const matches = inbox
          .map((conversation) => {
            return {
              conversation,
              normalizedName: normalizeLookupText(conversation.name),
              score: computeConversationMatchScore(conversation.name, target),
            }
          })
          .filter((item) => item.score >= 0)
          .sort((left, right) => right.score - left.score)

        const normalizedTarget = normalizeLookupText(target)
        const exactMatches = matches.filter((item) => item.normalizedName === normalizedTarget)
        const candidateConversations = (exactMatches.length > 0 ? exactMatches : matches).map((item) => item.conversation)

        if (candidateConversations.length > 1) {
          setPendingResolution({
            candidates: candidateConversations.slice(0, 8),
            draft: command === 'COMPOSE_MESSAGE' ? extractComposeContent(params) : '',
            command,
            targetLabel: target,
          })
          setActionFeedback({ tone: 'info', message: `Mình tìm thấy ${candidateConversations.length} cuộc trò chuyện khớp với "${target}". Hãy chọn đúng đối tượng trước khi tiếp tục.` })
          appendAssistantFeedback(`Mình tìm thấy ${candidateConversations.length} cuộc trò chuyện khớp với "${target}". Hãy chọn đúng đối tượng trong danh sách xác nhận để mình tiếp tục an toàn.`)
          return
        }

        const matched = candidateConversations[0]

        if (!matched) {
          const missingFeedback = buildMissingConversationFeedback(command, target)
          setActionFeedback({ tone: 'warning', message: missingFeedback })
          appendAssistantFeedback(missingFeedback)
          return
        }

        if (command === 'COMPOSE_MESSAGE') {
          const draft = extractComposeContent(params)
          if (draft) {
            localStorage.setItem(`${DRAFT_KEY_PREFIX}${matched.id}`, draft)
          }
        }

        navigate(`/chat/${matched.id}`)
        const successFeedback = buildActionSuccessFeedback(command)
        setActionFeedback({ tone: HIGH_RISK_ACTION_COMMANDS.has(command) ? 'warning' : 'success', message: successFeedback })
        appendAssistantFeedback(successFeedback)
        return
      }

      setPendingActionReview({
        title: 'Web chưa hỗ trợ tự động thao tác này',
        description: 'Trợ lý đã nhận ra ý định của bạn, nhưng web hiện chưa có executor an toàn cho thao tác này.',
        confirmLabel: 'Mở Chat',
        path: '/chat',
        feedback: 'Đã mở Chat. Bạn có thể tiếp tục thủ công hoặc dùng mobile để thực hiện thao tác này.',
        preview: { risk: 'medium', targetLabel: command },
      })
    } catch (error) {
      console.error('AI action execution failed:', error)
      const errorPresentation = resolveErrorPresentation(error)
      const errorFeedback = errorPresentation.message || 'Chưa thể thực thi thao tác AI trên web lúc này. Vui lòng thử lại hoặc thao tác thủ công.'
      setActionFeedback({ tone: 'error', message: errorFeedback })
      appendAssistantFeedback(errorFeedback, { degraded: false, providerStatus: null })
    } finally {
      setActionBusyIndex(null)
      setActiveActionLabel('')
    }
  }

  const renderActionPreview = (preview?: AiActionPreview) => {
    if (!preview) return null

    return (
      <div className={`ai-action-preview ai-action-preview-${preview.risk}`}>

        <span className='ai-action-preview-risk'>{buildRiskLabel(preview.risk)}</span>
        {preview.targetLabel ? (
          <div className='ai-action-preview-row'>
            <span>Đối tượng</span>
            <strong>{preview.targetLabel}</strong>
          </div>
        ) : null}
        {preview.draft ? (
          <div className='ai-action-preview-row ai-action-preview-draft'>
            <span>Nội dung nháp</span>
            <p>{preview.draft}</p>
          </div>
        ) : null}
      </div>
    )
  }

  const confirmPendingActionReview = () => {
    if (!pendingActionReview) {
      return
    }

    if (pendingActionReview.path) {
      navigate(pendingActionReview.path)
    }
    setActionFeedback({ tone: 'info', message: pendingActionReview.feedback })
    appendAssistantFeedback(pendingActionReview.feedback)
    setPendingActionReview(null)
  }

  const executeResolvedConversationAction = (conversation: ConversationSummary, resolution: PendingActionResolution) => {
    if (resolution.command === 'COMPOSE_MESSAGE' && resolution.draft) {
      localStorage.setItem(`${DRAFT_KEY_PREFIX}${conversation.id}`, resolution.draft)
    }

    setPendingResolution(null)
    navigate(`/chat/${conversation.id}`)
    appendAssistantFeedback(
      resolution.command === 'COMPOSE_MESSAGE' && resolution.draft
        ? `Mình đã mở đúng cuộc trò chuyện với "${conversation.name}" và lưu sẵn nội dung nháp để bạn kiểm tra trước khi gửi.`
        : `Mình đã mở đúng cuộc trò chuyện với "${conversation.name}" để bạn tiếp tục thao tác an toàn.`,
    )
  }

  useEffect(() => {
    if (!pendingActionReview && !pendingResolution) {
      return
    }

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') {
        return
      }

      closePendingActionReview()
      closePendingResolution()
    }

    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [pendingActionReview, pendingResolution])

  const handleRetry = () => {
    if (!retryPrompt || isAssistantBusy) {
      return
    }

    setActionFeedback(null)
    void handleSend(retryPrompt)
  }

  const closePendingActionReview = (reason: 'dismiss' | 'cancel' = 'dismiss') => {
    setPendingActionReview(null)
    if (reason === 'cancel') {
      setActionFeedback({ tone: 'info', message: 'Đã hủy bước xác nhận thao tác AI trên web.' })
    }
  }

  const closePendingResolution = (reason: 'dismiss' | 'cancel' = 'dismiss') => {
    setPendingResolution(null)
    if (reason === 'cancel') {
      setActionFeedback({ tone: 'info', message: 'Đã hủy bước chọn cuộc trò chuyện. Bạn có thể thử lại với tên cụ thể hơn.' })
    }
  }

  const handleClearHistory = () => {
    setActionFeedback(null)
    setRetryPrompt('')
    setPendingActionReview(null)
    setPendingResolution(null)
    if (historyStorageKey) {
      localStorage.removeItem(historyStorageKey)
    }
    localStorage.removeItem(LEGACY_STORAGE_KEY)
    saveMessages([
      {
        role: 'assistant',
        content: 'Đã dọn lịch sử AI chat. Mình có thể hỗ trợ gì tiếp theo?',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      },
    ])
  }

  return (
    <div className={embedded ? 'ai-chat-layout ai-chat-layout-embedded' : 'ai-chat-layout'}>
      <aside className='ai-chat-sidebar'>
        <div className='ai-chat-sidebar-scroll'>
          <section className='ai-assistant-card ai-context-card' aria-label='Ngữ cảnh trợ lý AI'>
            <div>
              <h3>VNALO AI Assistant</h3>
              <p>Đoạn chat riêng 1:1 với trợ lý trong VNALO.</p>
            </div>
            <div className='ai-context-status'>
              <span className={runtimeState.badgeClassName} />
              <strong>{runtimeState.label}</strong>
            </div>
          </section>

          <section className='ai-presets-container' aria-label='Gợi ý câu hỏi AI'>
            <span className='ai-presets-title'>Gợi ý nhanh</span>
            {PRESET_PROMPTS.map((prompt) => (
              <button
                key={prompt}
                type='button'
                className='ai-preset-btn'
                onClick={() => void handleSend(prompt)}
                disabled={isAssistantBusy}
              >
                <Sparkles size={14} />
                <span>{prompt}</span>
              </button>
            ))}
          </section>

        </div>
        <div className='ai-chat-sidebar-footer'>
          <button
            type='button'
            className='ai-clear-btn flex items-center justify-center gap-2'
            onClick={handleClearHistory}
            disabled={isAssistantBusy}
            style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
          >
            <Trash2 size={14} />
            Xóa lịch sử
          </button>
        </div>
      </aside>

      <main className='ai-chat-main'>
        <header className='ai-chat-header'>
          <div className='ai-header-avatar' aria-hidden='true'>
            <Bot size={20} />
          </div>
          <div className='ai-header-stack'>
            <div className='ai-header-info'>
              <strong className='text-[15px] font-semibold'>VNALO AI Assistant</strong>
              <span className={runtimeState.badgeClassName} />
              <span>{runtimeState.label}</span>
            </div>
            <span className='ai-header-helper'>{runtimeState.helper}</span>
          </div>
        </header>

        <div className='ai-chat-messages' ref={messagesContainerRef} role='log' aria-live='polite' aria-relevant='additions text'>
          {runtimeState.degraded && <div className={runtimeState.bannerClassName}>{runtimeState.banner}</div>}
          {actionFeedback ? (
            <div className={`ai-runtime-banner ai-runtime-banner-${actionFeedback.tone}`}>
              <span>{actionFeedback.message}</span>
              {actionFeedback.tone === 'error' && retryPrompt ? (
                <button type='button' className='ai-banner-action' onClick={handleRetry} disabled={isAssistantBusy}>
                  Thử lại
                </button>
              ) : null}
            </div>
          ) : null}

          {messages.map((message, index) => (
            <div
              key={`${message.role}-${message.timestamp}-${index}`}
              className={message.role === 'assistant' ? 'ai-msg-bubble-ai' : 'ai-msg-bubble-user'} data-role={message.role}
            >
              <p className='ai-message-text'>{message.content}</p>
              {message.role === 'assistant' && message.actionCommand ? (
                <div className='ai-action-row'>
                  <button
                    type='button'
                    className='ai-action-btn'
                    onClick={() => void handleAction(message, index)}
                    disabled={isLoading || actionBusyIndex !== null || pendingActionReview !== null || pendingResolution !== null}
                  >
                    {actionBusyIndex === index ? 'Đang xử lý...' : buildActionLabel(message.actionCommand)}
                  </button>
                </div>
              ) : null}
              <div className='ai-message-time'>{message.timestamp}</div>
            </div>
          ))}
          {isLoading && (
            <div className='ai-typing-indicator'>
              <span className='ai-typing-label'>{activeActionLabel ? `${activeActionLabel} đang được chuẩn bị` : 'Trợ lý AI đang soạn phản hồi'}</span>
              <div className='ai-typing-dot' />
              <div className='ai-typing-dot' />
              <div className='ai-typing-dot' />
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        <footer className='ai-chat-footer'>
          <form
            className='ai-input-wrapper'
            onSubmit={(event) => {
              event.preventDefault()
              void handleSend()
            }}
          >
            <button type='button' className='ai-composer-tool-btn' aria-label='Đính kèm ngữ cảnh' disabled>
              <Paperclip size={18} />
            </button>
            <div className='ai-composer-field'>
              <textarea
                ref={inputRef}
                className='ai-input-field'
                placeholder='Nhắn điều bạn cần cho VNALO AI Assistant...'
                value={inputValue}
                onChange={(event) => setInputValue(event.target.value)}
                disabled={pendingActionReview !== null || pendingResolution !== null}
                rows={1}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' && !event.shiftKey) {
                    event.preventDefault()
                    void handleSend()
                  }
                }}
              />
              <span className='ai-input-hint'>Enter để gửi · Shift + Enter để xuống dòng</span>
            </div>
            <div className='ai-composer-actions'>
              <button type='button' className='ai-composer-tool-btn' aria-label='Nhập bằng giọng nói' disabled>
                <Mic size={18} />
              </button>
              <button type='submit' className='ai-send-btn' disabled={isAssistantBusy || !inputValue.trim()} aria-label='Gửi tin nhắn cho VNALO AI Assistant'>
                <Send size={18} />
              </button>
            </div>
          </form>
        </footer>
      </main>

      {pendingActionReview ? (
        <div className='modal-overlay' role='dialog' aria-modal='true' aria-labelledby='ai-action-review-title' onClick={() => closePendingActionReview('dismiss')}>
          <div className='modal-card ai-resolution-modal' onClick={(event) => event.stopPropagation()}>
            <div className='modal-header'>
              <div>
                <h3 id='ai-action-review-title'>{pendingActionReview.title}</h3>
                <p>{pendingActionReview.description}</p>
                {renderActionPreview(pendingActionReview.preview)}
              </div>
              <button className='modal-close-btn' type='button' onClick={() => closePendingActionReview('dismiss')} aria-label='Đóng'>
                <X size={18} />
              </button>
            </div>
            <div className='modal-footer'>
              <button className='btn btn-subtle' type='button' onClick={() => closePendingActionReview('cancel')}>
                Hủy
              </button>
              <button className='btn btn-primary' type='button' onClick={confirmPendingActionReview}>
                {pendingActionReview.confirmLabel}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {pendingResolution ? (
        <div className='modal-overlay' role='dialog' aria-modal='true' aria-labelledby='ai-resolution-title' onClick={() => closePendingResolution('dismiss')}>
          <div className='modal-card ai-resolution-modal' onClick={(event) => event.stopPropagation()}>
            <div className='modal-header'>
              <div>
                <h3 id='ai-resolution-title'>Chọn đúng cuộc trò chuyện</h3>
                <p>Hãy xác nhận đúng đối tượng để tránh mở nhầm cuộc trò chuyện hoặc điền nháp sai người.</p>
                {renderActionPreview({ risk: buildActionRisk(pendingResolution.command), targetLabel: pendingResolution.targetLabel, draft: pendingResolution.draft })}
              </div>
              <button className='modal-close-btn' type='button' onClick={() => closePendingResolution('dismiss')} aria-label='Đóng'>
                <X size={18} />
              </button>
            </div>
            <div className='modal-body ai-resolution-list'>
              {pendingResolution.candidates.map((conversation) => (
                <button
                  key={conversation.id}
                  type='button'
                  className='ai-resolution-option'
                  onClick={() => executeResolvedConversationAction(conversation, pendingResolution)}
                >
                  <span className='ai-resolution-avatar'>{conversation.name.charAt(0).toUpperCase()}</span>
                  <span className='ai-resolution-meta'>
                    <strong>{conversation.name}</strong>
                    <small>{buildConversationSubtitle(conversation)}</small>
                  </span>
                </button>
              ))}
            </div>
            <div className='modal-footer'>
              <button className='btn btn-subtle' type='button' onClick={() => closePendingResolution('cancel')}>
                Hủy
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
