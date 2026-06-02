import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Copy, Mic, Paperclip, Reply, RotateCcw, Send, Share2, Sparkles, Trash2, X } from 'lucide-react'

import { extractMessage } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { AI_PENDING_PROMPT_KEY, useAiAssistant } from '../features/ai-assistant/AiAssistantProvider'
import { createGroupConversation, fetchInbox, sendAiChatMessage } from '../features/chat/chat.api'
import type { ConversationSummary } from '../features/chat/chat.types'
import { getFriends, searchUsers, sendFriendRequest } from '../features/friends/friends.api'
import { UserAvatar } from '../shared/components/UserAvatar'
import {
  buildAiDeferredActionReply,
  getAiActionLabel,
  getAiActionRisk,
  isKnownAiActionCommand,
  type AiActionCommand,
  type AiActionPreview,
} from '../features/ai-assistant/runtime/aiActionContract'
import {
  extractActionTarget,
  extractCreateGroupIntentTargets,
  buildUnsupportedActionIssue,
  resolveConversationAction,
  resolveCreateGroupAction,
  resolveFriendRequestAction,
  validateCreateGroupTargets,
} from '../features/ai-assistant/runtime/aiActionRuntime'

type ProviderStatus =
  | 'LIVE_PROVIDER_ACTIVE'
  | 'FALLBACK_PROVIDER_ACTIVE'
  | 'AI_PROVIDER_UNAVAILABLE'
  | null

type AiMessage = {
  role: 'user' | 'assistant'
  content: string
  timestamp: string
  degraded?: boolean
  providerStatus?: ProviderStatus
  actionCommand?: AiActionCommand | null
  actionParams?: Record<string, unknown> | null
  requiresConfirmation?: boolean | null
  riskLevel?: string | null
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
  execute?: () => Promise<void> | void
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
const AI_HISTORY_UPDATED_EVENT = 'vnalo:ai-history-updated'
const AI_PENDING_UPDATED_EVENT = 'vnalo:ai-pending-updated'
const AI_PENDING_KEY_PREFIX = 'vnalo_ai_chat_pending:'
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

function buildAiPendingKey(userId?: string | number | null) {
  if (userId === undefined || userId === null || `${userId}`.trim().length === 0) {
    return null
  }
  return `${AI_PENDING_KEY_PREFIX}${userId}`
}

function buildClientEntryId(prefix: string) {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return `${prefix}-${crypto.randomUUID()}`
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}`
}
function readAiPending(key: string | null) {
  if (!key) return false
  return localStorage.getItem(key) === 'true'
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
        actionCommand: typeof value.actionCommand === 'string' && isKnownAiActionCommand(value.actionCommand)
          ? (value.actionCommand as AiActionCommand)
          : null,
        actionParams: value.actionParams && typeof value.actionParams === 'object' ? (value.actionParams as Record<string, unknown>) : null,
        requiresConfirmation: typeof value.requiresConfirmation === 'boolean' ? value.requiresConfirmation : null,
        riskLevel: typeof value.riskLevel === 'string' ? value.riskLevel : null,
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
    helper: 'Đang hoạt động',
    banner: '',
    bannerClassName: 'ai-runtime-banner',
  }
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
  if (page === 'scanner' || page === 'qr') return '/scanner'
  if (page === 'timeline' || page === 'social') return '/timeline'
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


function isConversationAction(command: AiActionCommand) {
  return CONVERSATION_ACTION_COMMANDS.has(command)
}

function buildActionSuccessFeedback(command: AiActionCommand) {
  if (command === 'START_CALL') {
    return 'Đã mở đúng cuộc trò chuyện. Hãy bấm nút gọi để xác nhận cuộc gọi trên web.'
  }

  if (command === 'COMPOSE_MESSAGE') {
    return 'Đã mở đúng cuộc trò chuyện và lưu nội dung nháp nếu AI có cung cấp. Hãy kiểm tra lại trước khi gửi.'
  }

  if (getAiActionRisk(command) === 'high') {
    return 'Đã mở đúng cuộc trò chuyện. Hãy tự kiểm tra kỹ và xác nhận thủ công trước khi thực hiện thao tác nhạy cảm.'
  }

  return 'Đã mở đúng cuộc trò chuyện đích.'
}

type AiChatPageProps = {
  embedded?: boolean
  onActivity?: (activity: { preview: string; timestamp: string }) => void
}

function getAiMessagePreview(message: AiMessage): string {
  const trimmed = message.content.trim().replace(/\s+/g, ' ')
  if (!trimmed) return 'Sẵn sàng hỗ trợ'
  return trimmed.length > 96 ? trimmed.slice(0, 93) + '...' : trimmed
}

export function AiChatPage({ embedded = false, onActivity }: AiChatPageProps = {}) {
  const { accessToken, user } = useAuth()
  const { recordActivity: recordAiAssistantActivity, resetMeta: resetAiAssistantMeta } = useAiAssistant()
  const navigate = useNavigate()
  const historyStorageKey = useMemo(() => buildAiStorageKey(user?.id as string | number | undefined), [user?.id])
  const pendingStorageKey = useMemo(() => buildAiPendingKey(user?.id as string | number | undefined), [user?.id])
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [isPersistentPending, setIsPersistentPending] = useState(() => readAiPending(pendingStorageKey))
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
    const pendingPrompt = localStorage.getItem(AI_PENDING_PROMPT_KEY)
    if (!pendingPrompt?.trim()) return

    localStorage.removeItem(AI_PENDING_PROMPT_KEY)
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

  useEffect(() => {
    setIsPersistentPending(readAiPending(pendingStorageKey))
  }, [pendingStorageKey])

  useEffect(() => {
    if (!pendingStorageKey) return

    const handlePendingUpdated = (event: Event) => {
      const detail = (event as CustomEvent<{ key?: string; pending?: boolean }>).detail
      if (detail?.key !== pendingStorageKey) return
      setIsPersistentPending(Boolean(detail.pending))
    }

    window.addEventListener(AI_PENDING_UPDATED_EVENT, handlePendingUpdated)
    return () => window.removeEventListener(AI_PENDING_UPDATED_EVENT, handlePendingUpdated)
  }, [pendingStorageKey])

  const persistPending = (pending: boolean) => {
    if (!pendingStorageKey) return
    if (pending) {
      localStorage.setItem(pendingStorageKey, 'true')
    } else {
      localStorage.removeItem(pendingStorageKey)
    }
    setIsPersistentPending(pending)
    window.dispatchEvent(new CustomEvent(AI_PENDING_UPDATED_EVENT, {
      detail: { key: pendingStorageKey, pending },
    }))
  }

  useEffect(() => {
    if (!historyStorageKey) return

    const handleHistoryUpdated = (event: Event) => {
      const detail = (event as CustomEvent<{ key?: string; messages?: AiMessage[] }>).detail
      if (detail?.key !== historyStorageKey || !Array.isArray(detail.messages)) return
      setMessages(normalizeStoredMessages(detail.messages))
    }

    window.addEventListener(AI_HISTORY_UPDATED_EVENT, handleHistoryUpdated)
    return () => window.removeEventListener(AI_HISTORY_UPDATED_EVENT, handleHistoryUpdated)
  }, [historyStorageKey])

  const persistMessages = (nextMessages: AiMessage[]) => {
    const normalized = normalizeStoredMessages(nextMessages)
    const latestActivity = [...normalized].reverse().find((message) => message.content.trim())
    if (latestActivity && latestActivity !== INITIAL_ASSISTANT_MESSAGE) {
      const activity = { preview: getAiMessagePreview(latestActivity), timestamp: new Date().toISOString() }
      recordAiAssistantActivity(activity)
      onActivity?.(activity)
    }
    if (!historyStorageKey) {
      return normalized
    }
    localStorage.setItem(historyStorageKey, JSON.stringify(normalized))
    localStorage.removeItem(LEGACY_STORAGE_KEY)
    window.setTimeout(() => {
      window.dispatchEvent(new CustomEvent(AI_HISTORY_UPDATED_EVENT, {
        detail: { key: historyStorageKey, messages: normalized },
      }))
    }, 0)
    return normalized
  }

  const saveMessages = (nextMessages: AiMessage[]) => {
    const normalized = persistMessages(nextMessages)
    setMessages(normalized)
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
      const activity = { preview: getAiMessagePreview(feedbackMessage), timestamp: new Date().toISOString() }
      recordAiAssistantActivity(activity)
      onActivity?.(activity)
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
  }, [messages, isLoading, isPersistentPending, actionFeedback])

  const runtimeState = useMemo(() => resolveProviderPresentation(messages), [messages])
  const showTypingIndicator = isLoading || isPersistentPending
  const isAssistantBusy = showTypingIndicator || actionBusyIndex !== null || pendingActionReview !== null || pendingResolution !== null

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

    const createGroupIntentTargets = extractCreateGroupIntentTargets(query)
    if (createGroupIntentTargets.length > 0) {
      const userMessage: AiMessage = {
        role: 'user',
        content: query,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      }

      if (!textToSend) {
        setInputValue('')
      }

      const friends = await getFriends(accessToken)
      const { missingTargets, ambiguousTargets } = validateCreateGroupTargets(friends, createGroupIntentTargets)

      if (missingTargets.length > 0 || ambiguousTargets.length > 0) {
        const assistantText = missingTargets.length > 0
          ? `Không tìm thấy ${missingTargets.map((target) => `"${target}"`).join(', ')} trong danh bạ. Mình sẽ không tạo nhóm hoặc mở luồng tạo nhóm để tránh chọn nhầm người.`
          : `Có nhiều liên hệ khớp với ${ambiguousTargets.map((target) => `"${target}"`).join(', ')}. Hãy nói rõ hơn hoặc tự chọn thủ công trong modal tạo nhóm.`
        const assistantMessage: AiMessage = {
          role: 'assistant',
          content: assistantText,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          providerStatus: null,
          degraded: false,
        }
        saveMessages([...messages, userMessage, assistantMessage])
        setActionFeedback({ tone: 'warning', message: assistantText })
        setRetryPrompt('')
        return
      }
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
    persistPending(true)

    try {
      const apiHistory = updatedMessages.slice(-MAX_API_HISTORY).map((message) => ({
        role: message.role,
        content: message.content,
      }))

      const aiResponse = await sendAiChatMessage(accessToken, query, apiHistory, {
        analyzeIntent: true,
        contextId: historyStorageKey ?? undefined,
        clientUserEntryId: buildClientEntryId('web-user'),
        clientAssistantEntryId: buildClientEntryId('web-assistant'),
      })
      const responseActionCommand = (aiResponse.actionCommand as AiActionCommand | undefined) ?? null
      const safeActionCommand = responseActionCommand && isKnownAiActionCommand(responseActionCommand) ? responseActionCommand : null
      const assistantMessage: AiMessage = {
        role: 'assistant',
        content: safeActionCommand
          ? buildAiDeferredActionReply(safeActionCommand)
          : aiResponse.textReply || 'Mình chưa thể xử lý yêu cầu này ngay lúc này.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: Boolean(aiResponse.degraded),
        providerStatus: (aiResponse.providerStatus as ProviderStatus | undefined) ?? null,
        actionCommand: safeActionCommand,
        actionParams: aiResponse.actionParams ?? null,
        requiresConfirmation: aiResponse.requiresConfirmation ?? null,
        riskLevel: aiResponse.riskLevel ?? null,
      }

      const baseMessages = messages.some((message) => message.role === 'user' && message.content === query)
        ? messages
        : updatedMessages
      const persisted = persistMessages([...baseMessages, assistantMessage])
      setMessages(persisted)
      setRetryPrompt('')
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

      const baseMessages = messages.some((message) => message.role === 'user' && message.content === query)
        ? messages
        : updatedMessages
      const persisted = persistMessages([...baseMessages, errorMessage])
      setMessages(persisted)
    } finally {
      persistPending(false)
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
    setActiveActionLabel(getAiActionLabel(message.actionCommand))
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
        const friends = await getFriends(accessToken)
        const { resolution, issues } = resolveCreateGroupAction(params, friends)

        if (!resolution) {
          const messageText = issues.map((issue) => issue.message).join(' ')
          setActionFeedback({ tone: 'warning', message: messageText })
          appendAssistantFeedback(messageText)
          return
        }

        setPendingActionReview({
          title: 'Xac nhan tao nhom',
          description: `Tro ly se tao nhom "${resolution.groupName}" voi ${resolution.memberLabels.join(', ')}. Ban van co the huy neu danh sach chua dung.`,
          confirmLabel: 'Tao nhom',
          feedback: `Da tao nhom "${resolution.groupName}".`,
          preview: { risk: 'medium', targetLabel: resolution.groupName, draft: resolution.memberLabels.join(', ') },
          execute: async () => {
            const conversationId = await createGroupConversation(accessToken, {
              title: resolution.groupName,
              memberUserIds: resolution.memberIds,
            })
            navigate('/chat/' + conversationId)
          },
        })
        return
      }

      if (command === 'SEND_FRIEND_REQUEST') {
        const target = extractActionTarget(params)
        if (!target) {
          const messageText = 'Minh chua xac dinh duoc nguoi can ket ban. Hay noi ro ten, email hoac so dien thoai.'
          setActionFeedback({ tone: 'warning', message: messageText })
          appendAssistantFeedback(messageText)
          return
        }

        const lookupUsers = await searchUsers(accessToken, target)
        const { resolution, issues } = resolveFriendRequestAction(params, lookupUsers)
        if (!resolution) {
          const messageText = issues.map((issue) => issue.message).join(' ')
          setActionFeedback({ tone: 'warning', message: messageText })
          appendAssistantFeedback(messageText)
          return
        }

        setPendingActionReview({
          title: 'Xac nhan gui ket ban',
          description: `Tro ly se gui loi moi ket ban toi ${resolution.targetLabel}.`,
          confirmLabel: 'Gui ket ban',
          feedback: `Da gui loi moi ket ban toi ${resolution.targetLabel}.`,
          preview: { risk: 'medium', targetLabel: resolution.targetLabel, draft: resolution.message },
          execute: async () => {
            await sendFriendRequest(accessToken, {
              toUserId: resolution.targetUser.id,
              message: resolution.message,
            })
          },
        })
        return
      }

      if (isConversationAction(command)) {
        const target = extractActionTarget(params)
        if (!target) {
          navigate('/chat')
          const messageText = 'Minh chua xac dinh duoc nguoi nhan hoac cuoc tro chuyen cu the, nen da mo Chat de ban tu chon thu cong.'
          setActionFeedback({ tone: 'info', message: messageText })
          appendAssistantFeedback(messageText)
          return
        }

        const inbox = await fetchInbox(accessToken, user?.id)
        const { resolution, issues } = resolveConversationAction(command, params, inbox)

        if (!resolution) {
          const messageText = issues.map((issue) => issue.message).join(' ')
          setActionFeedback({ tone: 'warning', message: messageText })
          appendAssistantFeedback(messageText)
          return
        }

        if (command === 'COMPOSE_MESSAGE' && resolution.draft) {
          localStorage.setItem(DRAFT_KEY_PREFIX + resolution.conversation.id, resolution.draft)
        }

        navigate('/chat/' + resolution.conversation.id)
        const successFeedback = buildActionSuccessFeedback(command)
        setActionFeedback({ tone: getAiActionRisk(command) === 'high' ? 'warning' : 'success', message: successFeedback })
        appendAssistantFeedback(successFeedback)
        return
      }

      const unsupportedIssue = buildUnsupportedActionIssue(command)
      setPendingActionReview({
        title: 'Thao tac can xu ly thu cong',
        description: unsupportedIssue.message,
        confirmLabel: 'Mo Chat',
        path: '/chat',
        feedback: 'Da mo Chat de ban tiep tuc thao tac thu cong mot cach an toan.',
        preview: { risk: getAiActionRisk(command), targetLabel: getAiActionLabel(command) },
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

  const confirmPendingActionReview = async () => {
    if (!pendingActionReview) {
      return
    }

    const review = pendingActionReview
    setPendingActionReview(null)
    setActionFeedback({ tone: 'info', message: 'Đang thực hiện thao tác AI...' })

    try {
      if (review.execute) {
        await review.execute()
      }
      if (review.path) {
        navigate(review.path)
      }
      setActionFeedback({ tone: 'success', message: review.feedback })
      appendAssistantFeedback(review.feedback)
    } catch (error) {
      console.error('AI confirmed action failed:', error)
      const message = extractMessage(error) || 'Không thể thực hiện thao tác AI trên web lúc này. Vui lòng thử lại.'
      setActionFeedback({ tone: 'error', message })
      appendAssistantFeedback(message)
    }
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
    resetAiAssistantMeta()
    saveMessages([
      {
        role: 'assistant',
        content: 'Đã dọn lịch sử AI chat. Mình có thể hỗ trợ gì tiếp theo?',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      },
    ])
  }

  const handleCopyMessage = async (content: string) => {
    try {
      await navigator.clipboard?.writeText(content)
      setActionFeedback({ tone: 'success', message: 'Đã sao chép tin nhắn.' })
    } catch {
      setActionFeedback({ tone: 'error', message: 'Không thể sao chép tin nhắn trên trình duyệt hiện tại.' })
    }
  }

  const handleShareMessage = async (message: AiMessage) => {
    const text = message.content.trim()
    if (!text) return

    try {
      if (navigator.share) {
        await navigator.share({ text, title: 'VNALO AI Assistant' })
        return
      }

      await navigator.clipboard?.writeText(text)
      setActionFeedback({ tone: 'success', message: 'Trình duyệt chưa hỗ trợ chia sẻ trực tiếp, nội dung đã được sao chép.' })
    } catch (error) {
      if ((error as { name?: string })?.name === 'AbortError') return
      setActionFeedback({ tone: 'error', message: 'Không thể chia sẻ tin nhắn. Vui lòng thử lại.' })
    }
  }

  const handleReplyToMessage = (message: AiMessage) => {
    const preview = getAiMessagePreview(message)
    setInputValue((current) => {
      const existing = current.trim()
      const quoted = `Trả lời: "${preview}"\n`
      return existing ? `${quoted}${existing}` : quoted
    })
    requestAnimationFrame(() => inputRef.current?.focus())
  }

  return (
    <div className={embedded ? 'ai-chat-layout ai-chat-layout-embedded' : 'ai-chat-layout'}>
      {!embedded ? <aside className='ai-chat-sidebar'>
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
      </aside> : null}

      <main className='ai-chat-main'>
        <header className={embedded ? 'chat-window-header ai-chat-header ai-chat-header-embedded' : 'ai-chat-header'}>
          <div className={embedded ? 'chat-window-header-main' : 'ai-header-main'}>
            <div className='relative'>
              <UserAvatar name='VNALO AI Assistant' size='md' isAiAssistant />
              <span className='absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-white rounded-full' />
            </div>
            <div className={embedded ? 'chat-window-header-copy' : 'ai-header-stack'}>
              <h2>VNALO AI Assistant</h2>
              <div className='chat-window-header-meta'>
                <p>{runtimeState.degraded ? runtimeState.label : 'Đang hoạt động'}</p>
              </div>
            </div>
          </div>
          <div className='chat-window-header-actions ai-chat-header-actions'>
            <button
              type='button'
              className='chat-window-icon-btn ai-header-clear-btn'
              onClick={handleClearHistory}
              disabled={isAssistantBusy}
              title='Xóa lịch sử chat AI'
              aria-label='Xóa lịch sử chat AI'
            >
              <Trash2 size={18} />
            </button>
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
              <div className='ai-message-action-toolbar' aria-label='Thao tác tin nhắn'>
                <button type='button' className='ai-message-action-btn' onClick={() => handleReplyToMessage(message)} title='Trả lời tin nhắn' aria-label='Trả lời tin nhắn'>
                  <Reply size={14} />
                </button>
                <button type='button' className='ai-message-action-btn' onClick={() => void handleShareMessage(message)} title='Chia sẻ tin nhắn' aria-label='Chia sẻ tin nhắn'>
                  <Share2 size={14} />
                </button>
                <button type='button' className='ai-message-action-btn' onClick={() => void handleCopyMessage(message.content)} title='Sao chép tin nhắn' aria-label='Sao chép tin nhắn'>
                  <Copy size={14} />
                </button>
                {message.role === 'assistant' && message.degraded && retryPrompt ? (
                  <button type='button' className='ai-message-action-btn' onClick={handleRetry} disabled={isAssistantBusy} title='Thử lại' aria-label='Thử lại'>
                    <RotateCcw size={14} />
                  </button>
                ) : null}
              </div>
              <p className='ai-message-text'>{message.content}</p>
              {message.role === 'assistant' && message.actionCommand ? (
                <div className='ai-action-row'>
                  <button
                    type='button'
                    className='ai-action-btn'
                    onClick={() => void handleAction(message, index)}
                    disabled={isLoading || actionBusyIndex !== null || pendingActionReview !== null || pendingResolution !== null}
                  >
                    {actionBusyIndex === index ? 'Đang xử lý...' : getAiActionLabel(message.actionCommand)}
                  </button>
                </div>
              ) : null}
              <div className='ai-message-time'>{message.timestamp}</div>
            </div>
          ))}
          {showTypingIndicator && (
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
              <button className='btn btn-primary' type='button' onClick={() => void confirmPendingActionReview()}>
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
                {renderActionPreview({ risk: getAiActionRisk(pendingResolution.command), targetLabel: pendingResolution.targetLabel, draft: pendingResolution.draft })}
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
