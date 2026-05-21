import { useEffect, useMemo, useRef, useState } from 'react'
import { Send, Sparkles, Trash2 } from 'lucide-react'
import { extractMessage } from '../api.client'
import { useAuth } from '../features/auth/useAuth'
import { sendAiChatMessage } from '../features/chat/chat.api'

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
}

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
      banner: 'AI đang bảo trì. Hãy thử lại sau hoặc tiếp tục với các thao tác thủ công.',
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

export function AiChatPage() {
  const { accessToken } = useAuth()
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const saved = localStorage.getItem('vnalo_ai_chat_history')
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
    localStorage.setItem('vnalo_ai_chat_history', JSON.stringify(nextMessages))
  }

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isLoading])

  const runtimeState = useMemo(() => resolveProviderPresentation(messages), [messages])

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend ?? inputValue).trim()
    if (!query || isLoading || !accessToken) {
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
      const apiHistory = updatedMessages.map((message) => ({
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
      }

      saveMessages([...updatedMessages, assistantMessage])
    } catch (error) {
      console.error('AI chat failed:', error)
      const fallbackText =
        extractMessage((error as any)?.response?.data) ||
        extractMessage(error as any) ||
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
              onClick={() => handleSend(prompt)}
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

          {messages.map((message, index) => (
            <div
              key={`${message.role}-${message.timestamp}-${index}`}
              className={message.role === 'assistant' ? 'ai-msg-bubble-ai' : 'ai-msg-bubble-user'}
            >
              <p className='text-[14.5px] whitespace-pre-wrap' style={{ margin: 0 }}>
                {message.content}
              </p>
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
              handleSend()
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
                  handleSend()
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
