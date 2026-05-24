import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Send, Sparkles, Trash2, X } from 'lucide-react'

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
const STORAGE_KEY = 'vnalo_ai_chat_history'
const DRAFT_KEY_PREFIX = 'vnalo_ai_web_compose_draft:'
const MAX_API_HISTORY = 20

const PRESET_PROMPTS = [
  'HÃ£y Ä‘á» xuáº¥t 3 thÃ³i quen lÃ nh máº¡nh má»—i ngÃ y',
  'GiÃºp tÃ´i soáº¡n má»™t tin nháº¯n tá»« chá»‘i lá»‹ch háº¹n khÃ©o lÃ©o',
  'Giáº£i thÃ­ch khÃ¡i niá»‡m WebRTC má»™t cÃ¡ch ngáº¯n gá»n',
]

const INITIAL_ASSISTANT_MESSAGE: AiMessage = {
  role: 'assistant',
  content: 'Xin chÃ o! MÃ¬nh lÃ  Trá»£ lÃ½ AI VNALO. MÃ¬nh cÃ³ thá»ƒ giÃºp gÃ¬ cho báº¡n hÃ´m nay?',
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
      label: 'AI Ä‘ang báº£o trÃ¬',
      helper: 'Má»™t sá»‘ pháº£n há»“i AI cÃ³ thá»ƒ táº¡m thá»i bá»‹ háº¡n cháº¿.',
      banner: 'AI Ä‘ang báº£o trÃ¬. HÃ£y thá»­ láº¡i sau hoáº·c tiáº¿p tá»¥c vá»›i thao tÃ¡c thá»§ cÃ´ng.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-warning',
    }
  }

  if (providerStatus === 'FALLBACK_PROVIDER_ACTIVE' || degraded) {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: 'ai-header-status ai-header-status-degraded',
      label: 'Cháº¿ Ä‘á»™ dá»± phÃ²ng',
      helper: 'Há»‡ thá»‘ng Ä‘ang dÃ¹ng tuyáº¿n pháº£n há»“i thay tháº¿.',
      banner: 'AI Ä‘ang cháº¡y á»Ÿ cháº¿ Ä‘á»™ dá»± phÃ²ng, cháº¥t lÆ°á»£ng pháº£n há»“i cÃ³ thá»ƒ giáº£m.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-info',
    }
  }

  return {
    providerStatus,
    degraded: false,
    badgeClassName: 'ai-header-status',
    label: 'Sáºµn sÃ ng há»— trá»£',
    helper: 'Trá»£ lÃ½ AI cÃ³ thá»ƒ tráº£ lá»i vÃ  gá»£i Ã½ thao tÃ¡c trong VNALO.',
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
    return count > 0 ? `${count} members` : 'Group conversation'
  }

  return 'Direct conversation'
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
      return 'Má»Ÿ cuá»™c trÃ² chuyá»‡n'
    case 'COMPOSE_MESSAGE':
      return 'Má»Ÿ chat + Ä‘iá»n sáºµn'
    case 'NAVIGATE_TO_CHAT':
      return 'Äi tá»›i Chat'
    case 'NAVIGATE_TO_CONTACTS':
      return 'Äi tá»›i Danh báº¡'
    case 'OPEN_PROFILE':
      return 'Äi tá»›i Há»“ sÆ¡'
    case 'NAVIGATE_TO':
      return 'Äi tá»›i mÃ n hÃ¬nh Ä‘Ã­ch'
    case 'START_CALL':
      return 'Má»Ÿ chat Ä‘á»ƒ gá»i'
    default:
      return 'Thá»­ thá»±c hiá»‡n thao tÃ¡c'
  }
}

export function AiChatPage() {
  const { accessToken, user } = useAuth()
  const navigate = useNavigate()
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [actionBusyIndex, setActionBusyIndex] = useState<number | null>(null)
  const [actionFeedback, setActionFeedback] = useState<string>('')
  const [pendingResolution, setPendingResolution] = useState<PendingActionResolution | null>(null)
  const [pendingActionReview, setPendingActionReview] = useState<PendingActionReview | null>(null)
  const messagesEndRef = useRef<HTMLDivElement | null>(null)
  const inputRef = useRef<HTMLTextAreaElement | null>(null)

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

  useEffect(() => {
    const input = inputRef.current
    if (!input) return

    input.style.height = '0px'
    input.style.height = `${Math.min(input.scrollHeight, 132)}px`
  }, [inputValue])

  const handleSend = async (textToSend?: string) => {
    const query = (textToSend ?? inputValue).trim()
    if (!query || isLoading) {
      return
    }

    if (!accessToken) {
      const authError: AiMessage = {
        role: 'assistant',
        content: 'Báº¡n cáº§n Ä‘Äƒng nháº­p láº¡i Ä‘á»ƒ sá»­ dá»¥ng Trá»£ lÃ½ AI trÃªn web.',
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
        content: aiResponse.textReply || 'Ráº¥t tiáº¿c, mÃ¬nh khÃ´ng thá»ƒ xá»­ lÃ½ yÃªu cáº§u lÃºc nÃ y.',
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
        'CÃ³ lá»—i xáº£y ra khi káº¿t ná»‘i tá»›i Trá»£ lÃ½ AI. Vui lÃ²ng thá»­ láº¡i sau.'

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
        setActionFeedback('Opened the requested VNALO screen.')
        return
      }

      if (command === 'CREATE_GROUP') {
        setPendingActionReview({
          title: 'Open create group flow',
          description: 'AI can open the group creation screen, but you still choose members and confirm the group manually.',
          confirmLabel: 'Open create group',
          path: '/chat?createGroup=true',
          feedback: 'Opened create group flow. Review members and group name before creating.',
          preview: { risk: 'medium', targetLabel: String(params.title ?? params.groupName ?? 'New group') },
        })
        return
      }

      if (command === 'SEND_FRIEND_REQUEST') {
        setPendingActionReview({
          title: 'Open contacts to add friend',
          description: 'Web AI will not send a friend request automatically. Open Contacts, verify the person, then send the request yourself.',
          confirmLabel: 'Open Contacts',
          path: '/contacts',
          feedback: 'Opened Contacts. Please verify the target before sending a friend request.',
          preview: { risk: 'medium', targetLabel: extractActionTarget(params) || 'Unknown contact' },
        })
        return
      }

      if (HIGH_RISK_ACTION_COMMANDS.has(command) && !isConversationAction(command)) {
        setPendingActionReview({
          title: 'Manual confirmation required',
          description: 'This AI action can affect accounts, messages, or group membership. Web AI will not execute it automatically in this audit wave.',
          confirmLabel: 'Open Chat',
          path: '/chat',
          feedback: 'Opened Chat. Please perform the sensitive action manually after checking the target.',
          preview: { risk: 'high', targetLabel: extractActionTarget(params) || command },
        })
        return
      }

      if (isConversationAction(command)) {
        const target = extractActionTarget(params)
        if (!target) {
          navigate('/chat')
          setActionFeedback('AI did not identify a specific conversation. Opened Chat so you can choose manually.')
          return
        }

        const inbox = await fetchInbox(accessToken, user?.id)
        const normalizedTarget = normalizeLookupText(target)
        const matches = inbox
          .map((conversation) => {
            const normalizedName = normalizeLookupText(conversation.name)
            const isExact = normalizedName === normalizedTarget

            return {
              conversation,
              normalizedName,
              score: isExact ? 1000 : normalizedName.includes(normalizedTarget) ? normalizedTarget.length : -1,
            }
          })
          .filter((item) => item.score >= 0)
          .sort((left, right) => right.score - left.score)

        const exactMatches = matches.filter((item) => item.normalizedName === normalizedTarget)
        const candidateConversations = (exactMatches.length > 0 ? exactMatches : matches).map((item) => item.conversation)

        if (candidateConversations.length > 1) {
          setPendingResolution({
            candidates: candidateConversations.slice(0, 8),
            draft: command === 'COMPOSE_MESSAGE' ? extractComposeContent(params) : '',
            command,
            targetLabel: target,
          })
          setActionFeedback(`Found ${candidateConversations.length} matching conversations for "${target}". Please choose the exact target before continuing.`)
          return
        }

        const matched = candidateConversations[0]

        if (!matched) {
          setActionFeedback(`No matching conversation found for "${target}".`)
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
          setActionFeedback('Opened the conversation. Use the call button to confirm the call manually on web.')
        } else if (HIGH_RISK_ACTION_COMMANDS.has(command)) {
          setActionFeedback('Opened the target conversation. Please confirm and perform this sensitive action manually.')
        } else {
          setActionFeedback('Opened the target conversation.')
        }
        return
      }

      setPendingActionReview({
        title: 'Action not available on web yet',
        description: 'This AI command is recognized, but the web client does not have a safe executor for it yet.',
        confirmLabel: 'Open Chat',
        path: '/chat',
        feedback: 'Opened Chat. Continue manually or use mobile for this AI action.',
        preview: { risk: 'medium', targetLabel: command },
      })
    } catch (error) {
      console.error('AI action execution failed:', error)
      setActionFeedback('Could not execute the AI action on web right now. Please try again manually.')
    } finally {
      setActionBusyIndex(null)
    }
  }

  const renderActionPreview = (preview?: AiActionPreview) => {
    if (!preview) return null

    return (
      <div className={`ai-action-preview ai-action-preview-${preview.risk}`}>

        <span className='ai-action-preview-risk'>{preview.risk.toUpperCase()} RISK</span>
        {preview.targetLabel ? (
          <div className='ai-action-preview-row'>
            <span>Target</span>
            <strong>{preview.targetLabel}</strong>
          </div>
        ) : null}
        {preview.draft ? (
          <div className='ai-action-preview-row ai-action-preview-draft'>
            <span>Draft</span>
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
    setActionFeedback(pendingActionReview.feedback)
    setPendingActionReview(null)
  }

  const executeResolvedConversationAction = (conversation: ConversationSummary, resolution: PendingActionResolution) => {
    if (resolution.command === 'COMPOSE_MESSAGE' && resolution.draft) {
      localStorage.setItem(`${DRAFT_KEY_PREFIX}${conversation.id}`, resolution.draft)
    }

    setPendingResolution(null)
    navigate(`/chat/${conversation.id}`)
  }

  const handleClearHistory = () => {
    saveMessages([
      {
        role: 'assistant',
        content: 'Lá»‹ch sá»­ Ä‘Ã£ Ä‘Æ°á»£c dá»n dáº¹p. MÃ¬nh cÃ³ thá»ƒ há»— trá»£ gÃ¬ tiáº¿p theo cho báº¡n?',
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
          <h3>Trá»£ lÃ½ AI VNALO</h3>
          <p>Helps answer questions, explain quickly, and suggest safe actions inside VNALO.</p>
        </div>

        <div className='ai-presets-container'>
          <span className='ai-presets-title'>Gá»£i Ã½ cÃ¢u há»i</span>
          {PRESET_PROMPTS.map((prompt) => (
            <button
              key={prompt}
              type='button'
              className='ai-preset-btn'
              onClick={() => void handleSend(prompt)}
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
          Dá»n dáº¹p lá»‹ch sá»­
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
                <div className='ai-action-row'>
                  <button
                    type='button'
                    className='ai-action-btn'
                    onClick={() => void handleAction(message, index)}
                    disabled={actionBusyIndex === index || isLoading}
                  >
                    {actionBusyIndex === index ? 'Äang xá»­ lÃ½...' : buildActionLabel(message.actionCommand)}
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
              <span className='ai-typing-label'>AI assistant is typing</span>
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
              ref={inputRef}
              className='ai-input-field'
              placeholder='Há»i trá»£ lÃ½ AI Ä‘iá»u gÃ¬ Ä‘Ã³...'
              value={inputValue}
              onChange={(event) => setInputValue(event.target.value)}
              rows={1}
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
            <span className='ai-input-hint'>Enter to send, Shift + Enter for a new line</span>
          </form>
        </footer>
      </main>

      {pendingActionReview ? (
        <div className='modal-overlay' role='dialog' aria-modal='true' aria-labelledby='ai-action-review-title' onClick={() => setPendingActionReview(null)}>
          <div className='modal-card ai-resolution-modal' onClick={(event) => event.stopPropagation()}>
            <div className='modal-header'>
              <div>
                <h3 id='ai-action-review-title'>{pendingActionReview.title}</h3>
                <p>{pendingActionReview.description}</p>
                {renderActionPreview(pendingActionReview.preview)}
              </div>
              <button className='modal-close-btn' type='button' onClick={() => setPendingActionReview(null)} aria-label='Close'>
                <X size={18} />
              </button>
            </div>
            <div className='modal-footer'>
              <button className='btn btn-subtle' type='button' onClick={() => setPendingActionReview(null)}>
                Cancel
              </button>
              <button className='btn btn-primary' type='button' onClick={confirmPendingActionReview}>
                {pendingActionReview.confirmLabel}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {pendingResolution ? (
        <div className='modal-overlay' role='dialog' aria-modal='true' aria-labelledby='ai-resolution-title' onClick={() => setPendingResolution(null)}>
          <div className='modal-card ai-resolution-modal' onClick={(event) => event.stopPropagation()}>
            <div className='modal-header'>
              <div>
                <h3 id='ai-resolution-title'>Choose the exact conversation</h3>
                <p>Confirm the target to avoid opening or drafting for the wrong contact.</p>
                {renderActionPreview({ risk: buildActionRisk(pendingResolution.command), targetLabel: pendingResolution.targetLabel, draft: pendingResolution.draft })}
              </div>
              <button className='modal-close-btn' type='button' onClick={() => setPendingResolution(null)} aria-label='Close'>
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
              <button className='btn btn-subtle' type='button' onClick={() => setPendingResolution(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
