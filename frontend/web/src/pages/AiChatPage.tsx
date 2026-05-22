import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Send, Sparkles, Trash2 } from 'lucide-react'

import { extractMessage } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { fetchInbox, sendAiChatMessage } from '../features/chat/chat.api'

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

const STORAGE_KEY = 'vnalo_ai_chat_history'
const DRAFT_KEY_PREFIX = 'vnalo_ai_web_compose_draft:'
const MAX_API_HISTORY = 20

const PRESET_PROMPTS = [
  'Hãy đề xuất 3 thói quen lành mạnh mỗi ngày',
  'Giúp tôi soạn một tin nhắn từ chối lịch hẹn khéo léo',
  'Giải thích khái niệm WebRTC một cách ngắn gọn',
]

const INITIAL_ASSISTANT_MESSAGE: AiMessage = {
  role: 'assistant',
  content: 'Xin chào! Mình là Trợ lý AI VNALO. Mình có thể giúp gì cho bạn hôm nay?',
  timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
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
      helper: 'Một số phản hồi AI có thể tạm thời bị hạn chế.',
      banner: 'AI đang bảo trì. Hãy thử lại sau hoặc tiếp tục với thao tác thủ công.',
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
    helper: 'Trợ lý AI có thể trả lời và gợi ý thao tác trong VNALO.',
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

function extractActionTarget(params?: Record<string, unknown> | null) {
  if (!params) return ''
  const raw =
    params.target ??
    params.recipient ??
    params.contactName ??
    params.displayName ??
    params.name ??
    ''
  return String(raw).trim()
}

function extractComposeContent(params?: Record<string, unknown> | null) {
  if (!params) return ''
  const raw = params.content ?? params.messageText ?? params.prefilledText ?? ''
  return String(raw).trim()
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

function buildActionLabel(command: AiActionCommand) {
  switch (command) {
    case 'OPEN_CHAT':
      return 'Mở cuộc trò chuyện'
    case 'COMPOSE_MESSAGE':
      return 'Mở chat + điền sẵn'
    case 'NAVIGATE_TO_CHAT':
      return 'Đi tới Chat'
    case 'NAVIGATE_TO_CONTACTS':
      return 'Đi tới Danh bạ'
    case 'OPEN_PROFILE':
      return 'Đi tới Hồ sơ'
    case 'NAVIGATE_TO':
      return 'Đi tới màn hình đích'
    case 'START_CALL':
      return 'Mở chat để gọi'
    default:
      return 'Thử thực hiện thao tác'
  }
}

export function AiChatPage() {
  const { accessToken } = useAuth()
  const navigate = useNavigate()
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [actionBusyIndex, setActionBusyIndex] = useState<number | null>(null)
  const [actionFeedback, setActionFeedback] = useState<string>('')
  const messagesEndRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (!saved) {
      setMessages([INITIAL_ASSISTANT_MESSAGE])
      return
    }

    try {
      const parsed = JSON.parse(saved) as AiMessage[]
      setMessages(parsed.length > 0 ? parsed : [INITIAL_ASSISTANT_MESSAGE])
    } catch (error) {
      console.warn('Failed to parse AI chat history', error)
      setMessages([INITIAL_ASSISTANT_MESSAGE])
    }
  }, [])

  const saveMessages = (nextMessages: AiMessage[]) => {
    setMessages(nextMessages)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(nextMessages))
  }

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isLoading, actionFeedback])

  const runtimeState = useMemo(() => resolveProviderPresentation(messages), [messages])

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend ?? inputValue).trim()
    if (!query || isLoading) {
      return
    }

    if (!accessToken) {
      const authError: AiMessage = {
        role: 'assistant',
        content: 'Bạn cần đăng nhập lại để sử dụng Trợ lý AI trên web.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: true,
        providerStatus: 'AI_PROVIDER_UNAVAILABLE',
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
    setIsLoading(true)

    try {
      const apiHistory = updatedMessages.slice(-MAX_API_HISTORY).map((message) => ({
        role: message.role,
        content: message.content,
      }))

      const aiResponse = await sendAiChatMessage(accessToken, query, apiHistory)
      const assistantMessage: AiMessage = {
        role: 'assistant',
        content: aiResponse.textReply || 'Rất tiếc, mình không thể xử lý yêu cầu lúc này.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: Boolean(aiResponse.degraded),
        providerStatus: (aiResponse.providerStatus as ProviderStatus | undefined) ?? null,
        actionCommand: (aiResponse.actionCommand as AiActionCommand | undefined) ?? null,
        actionParams: aiResponse.actionParams ?? null,
      }

      saveMessages([...updatedMessages, assistantMessage])
    } catch (error) {
      console.error('AI chat failed:', error)
      const fallbackText =
        extractMessage((error as { response?: { data?: unknown } })?.response?.data) ||
        extractMessage(error) ||
        'Có lỗi xảy ra khi kết nối tới Trợ lý AI. Vui lòng thử lại sau.'

      const errorMessage: AiMessage = {
        role: 'assistant',
        content: fallbackText,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: true,
        providerStatus: 'AI_PROVIDER_UNAVAILABLE',
      }

      saveMessages([...updatedMessages, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }

  const handleAction = async (message: AiMessage, index: number) => {
    if (!accessToken || !message.actionCommand) {
      return
    }

    setActionBusyIndex(index)
    setActionFeedback('')

    try {
      const command = message.actionCommand
      const params = message.actionParams ?? {}
      const directPath = resolveNavigatePath(command, params)

      if (directPath) {
        navigate(directPath)
        setActionFeedback('Đã mở đúng màn hình theo yêu cầu AI.')
        return
      }

      if (command === 'OPEN_CHAT' || command === 'COMPOSE_MESSAGE' || command === 'START_CALL') {
        const target = extractActionTarget(params)
        if (!target) {
          setActionFeedback('AI chưa xác định được người nhận. Hãy nhập rõ hơn.')
          return
        }

        const inbox = await fetchInbox(accessToken)
        const normalizedTarget = normalizeLookupText(target)
        const matched = inbox
          .map((conversation) => ({
            conversation,
            score: normalizeLookupText(conversation.name).includes(normalizedTarget) ? normalizedTarget.length : -1,
          }))
          .filter((item) => item.score >= 0)
          .sort((left, right) => right.score - left.score)[0]?.conversation

        if (!matched) {
          setActionFeedback(`Không tìm thấy cuộc trò chuyện phù hợp với "${target}".`)
          return
        }

        if (command === 'COMPOSE_MESSAGE') {
          const draft = extractComposeContent(params)
          if (draft) {
            localStorage.setItem(`${DRAFT_KEY_PREFIX}${matched.id}`, draft)
          }
        }

        navigate(`/chat/${matched.id}`)
        if (command === 'START_CALL') {
          setActionFeedback('Đã mở cuộc trò chuyện. Hãy nhấn nút gọi để xác nhận cuộc gọi trên web.')
        } else {
          setActionFeedback('Đã mở cuộc trò chuyện đích.')
        }
        return
      }

      setActionFeedback('Lệnh này chưa hỗ trợ thao tác trực tiếp trên web. Bạn có thể tiếp tục trên mobile.')
    } catch (error) {
      console.error('AI action execution failed:', error)
      setActionFeedback('Không thể thực thi thao tác AI trên web lúc này. Vui lòng thử lại.')
    } finally {
      setActionBusyIndex(null)
    }
  }

  const handleClearHistory = () => {
    saveMessages([
      {
        role: 'assistant',
        content: 'Lịch sử đã được dọn dẹp. Mình có thể hỗ trợ gì tiếp theo cho bạn?',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      },
    ])
  }

  return (
    <div className='ai-chat-layout'>
      <aside className='ai-chat-sidebar'>
        <div className='ai-assistant-card'>
          <div className='ai-avatar-glow'>
            <Sparkles size={28} />
          </div>
          <h3>Trợ lý AI VNALO</h3>
          <p>Hỗ trợ trả lời câu hỏi, giải thích nhanh và gợi ý thao tác an toàn trong hệ thống VNALO.</p>
        </div>

        <div className='ai-presets-container'>
          <span className='ai-presets-title'>Gợi ý câu hỏi</span>
          {PRESET_PROMPTS.map((prompt) => (
            <button
              key={prompt}
              type='button'
              className='ai-preset-btn'
              onClick={() => void handleSend(prompt)}
              disabled={isLoading}
            >
              {prompt}
            </button>
          ))}
        </div>

        <div className='flex-grow' style={{ flexGrow: 1 }} />

        <button
          type='button'
          className='ai-clear-btn flex items-center justify-center gap-2'
          onClick={handleClearHistory}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
        >
          <Trash2 size={14} />
          Dọn dẹp lịch sử
        </button>
      </aside>

      <main className='ai-chat-main'>
        <header className='ai-chat-header'>
          <div className='ai-header-stack'>
            <div className='ai-header-info'>
              <div className={runtimeState.badgeClassName} />
              <strong className='text-[15px] font-semibold'>{runtimeState.label}</strong>
            </div>
            <span className='ai-header-helper'>{runtimeState.helper}</span>
          </div>
        </header>

        <div className='ai-chat-messages'>
          {runtimeState.degraded && <div className={runtimeState.bannerClassName}>{runtimeState.banner}</div>}
          {actionFeedback ? <div className='ai-runtime-banner ai-runtime-banner-info'>{actionFeedback}</div> : null}

          {messages.map((message, index) => (
            <div
              key={`${message.role}-${message.timestamp}-${index}`}
              className={message.role === 'assistant' ? 'ai-msg-bubble-ai' : 'ai-msg-bubble-user'}
            >
              <p className='text-[14.5px] whitespace-pre-wrap' style={{ margin: 0 }}>
                {message.content}
              </p>
              {message.role === 'assistant' && message.actionCommand ? (
                <div style={{ marginTop: '10px' }}>
                  <button
                    type='button'
                    className='ai-send-btn'
                    style={{ width: 'auto', padding: '8px 14px', borderRadius: '999px' }}
                    onClick={() => void handleAction(message, index)}
                    disabled={actionBusyIndex === index || isLoading}
                  >
                    {actionBusyIndex === index ? 'Đang xử lý...' : buildActionLabel(message.actionCommand)}
                  </button>
                </div>
              ) : null}
              <div className='text-[10px] opacity-60 text-right mt-1.5' style={{ marginTop: '6px' }}>
                {message.timestamp}
              </div>
            </div>
          ))}

          {isLoading && (
            <div className='ai-typing-indicator'>
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
            <textarea
              className='ai-input-field'
              placeholder='Hỏi trợ lý AI điều gì đó...'
              value={inputValue}
              onChange={(event) => setInputValue(event.target.value)}
              rows={1}
              disabled={isLoading}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault()
                  void handleSend()
                }
              }}
            />
            <button type='submit' className='ai-send-btn' disabled={isLoading || !inputValue.trim()}>
              <Send size={18} />
            </button>
          </form>
        </footer>
      </main>
    </div>
  )
}