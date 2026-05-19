import { useState, useEffect, useRef } from 'react'
import { Sparkles, Send, Trash2 } from 'lucide-react'
import { useAuth } from '../features/auth/useAuth'
import { sendAiChatMessage } from '../features/chat/chat.api'

type AiMessage = {
  role: 'user' | 'assistant'
  content: string
  timestamp: string
}

const PRESET_PROMPTS = [
  'Hãy đề xuất 3 thói quen lành mạnh mỗi ngày',
  'Giúp tôi soạn một tin nhắn từ chối lịch hẹn khéo léo',
  'Giải thích khái niệm WebRTC một cách ngắn gọn'
]

export function AiChatPage() {
  const { accessToken } = useAuth()
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement | null>(null)

  // Load history on mount
  useEffect(() => {
    const saved = localStorage.getItem('vnalo_ai_chat_history')
    if (saved) {
      try {
        setMessages(JSON.parse(saved))
      } catch (e) {
        console.warn('Failed to parse AI chat history', e)
      }
    } else {
      // Set initial greeting
      setMessages([
        {
          role: 'assistant',
          content: 'Xin chào! Mình là Trợ lý AI VNALO. Mình có thể giúp gì cho bạn hôm nay?',
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        }
      ])
    }
  }, [])

  // Persist history when messages change
  const saveMessages = (newMsgs: AiMessage[]) => {
    setMessages(newMsgs)
    localStorage.setItem('vnalo_ai_chat_history', JSON.stringify(newMsgs))
  }

  // Scroll to bottom on new message
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, isLoading])

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend || inputValue).trim()
    if (!query || isLoading || !accessToken) return

    if (!textToSend) {
      setInputValue('')
    }

    const userMsg: AiMessage = {
      role: 'user',
      content: query,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }

    const updatedMessages = [...messages, userMsg]
    saveMessages(updatedMessages)
    setIsLoading(true)

    try {
      // Format history to API structure (excluding the current user prompt)
      const apiHistory = messages.map(m => ({
        role: m.role,
        content: m.content
      }))

      const aiResponse = await sendAiChatMessage(accessToken, query, apiHistory)

      const aiMsg: AiMessage = {
        role: 'assistant',
        content: aiResponse || 'Rất tiếc, mình không thể xử lý yêu cầu lúc này.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }

      saveMessages([...updatedMessages, aiMsg])
    } catch (error) {
      console.error('AI chat failed:', error)
      const errorMsg: AiMessage = {
        role: 'assistant',
        content: 'Có lỗi xảy ra khi kết nối tới Trợ lý AI. Vui lòng thử lại sau!',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }
      saveMessages([...updatedMessages, errorMsg])
    } finally {
      setIsLoading(false)
    }
  }

  const handleClearHistory = () => {
    const initial = [
      {
        role: 'assistant' as const,
        content: 'Lịch sử đã được dọn dẹp. Mình có thể hỗ trợ gì tiếp theo cho bạn?',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }
    ]
    saveMessages(initial)
  }

  return (
    <div className="ai-chat-layout">
      <aside className="ai-chat-sidebar">
        <div className="ai-assistant-card">
          <div className="ai-avatar-glow">
            <Sparkles size={28} />
          </div>
          <h3>Trợ lý AI VNALO</h3>
          <p>Trợ lý thông minh hỗ trợ giải đáp mọi câu hỏi và gợi ý công việc nhanh chóng.</p>
        </div>

        <div className="ai-presets-container">
          <span className="ai-presets-title">Gợi ý câu hỏi</span>
          {PRESET_PROMPTS.map((prompt, index) => (
            <button
              key={index}
              type="button"
              className="ai-preset-btn"
              onClick={() => handleSend(prompt)}
              disabled={isLoading}
            >
              {prompt}
            </button>
          ))}
        </div>

        <div className="flex-grow" style={{ flexGrow: 1 }} />

        <button
          type="button"
          className="ai-clear-btn flex items-center justify-center gap-2"
          onClick={handleClearHistory}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
        >
          <Trash2 size={14} />
          Dọn dẹp lịch sử
        </button>
      </aside>

      <main className="ai-chat-main">
        <header className="ai-chat-header">
          <div className="ai-header-info">
            <div className="ai-header-status" />
            <strong className="text-[15px] font-semibold">Trợ lý AI đang hoạt động</strong>
          </div>
        </header>

        <div className="ai-chat-messages">
          {messages.map((msg, index) => (
            <div
              key={index}
              className={msg.role === 'assistant' ? 'ai-msg-bubble-ai' : 'ai-msg-bubble-user'}
            >
              <p className="text-[14.5px] whitespace-pre-wrap" style={{ margin: 0 }}>{msg.content}</p>
              <div className="text-[10px] opacity-60 text-right mt-1.5" style={{ marginTop: '6px' }}>{msg.timestamp}</div>
            </div>
          ))}

          {isLoading && (
            <div className="ai-typing-indicator">
              <div className="ai-typing-dot" />
              <div className="ai-typing-dot" />
              <div className="ai-typing-dot" />
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        <footer className="ai-chat-footer">
          <form
            className="ai-input-wrapper"
            onSubmit={(e) => {
              e.preventDefault()
              handleSend()
            }}
          >
            <input
              type="text"
              className="ai-input-field"
              placeholder="Hỏi trợ lý AI điều gì đó..."
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              disabled={isLoading}
            />
            <button type="submit" className="ai-send-btn" disabled={isLoading || !inputValue.trim()}>
              <Send size={18} />
            </button>
          </form>
        </footer>
      </main>
    </div>
  )
}
