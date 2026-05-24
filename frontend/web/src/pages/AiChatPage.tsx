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

type ActionFeedbackState = {
  tone: 'info' | 'success' | 'warning' | 'error'
  message: string
}
const STORAGE_KEY = 'vnalo_ai_chat_history'
const DRAFT_KEY_PREFIX = 'vnalo_ai_web_compose_draft:'
const MAX_API_HISTORY = 20

const PRESET_PROMPTS = [
  'Suggest 3 healthy habits I can keep every day',
  'Help me draft a polite message to decline an appointment',
  'Explain WebRTC in a short and simple way',
]

const INITIAL_ASSISTANT_MESSAGE: AiMessage = {
  role: 'assistant',
  content: 'Hello! I am the VNALO AI assistant. What can I help you with today?',
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

function normalizeStoredMessages(payload: unknown): AiMessage[] {
  if (!Array.isArray(payload)) return [INITIAL_ASSISTANT_MESSAGE]

  const normalized = payload
    .map<AiMessage | null>((item): AiMessage | null => {
      if (!item || typeof item !== 'object') return null
      const value = item as Record<string, unknown>
      const role = value.role === 'assistant' ? 'assistant' : value.role === 'user' ? 'user' : null
      const content = typeof value.content === 'string' ? value.content.trim() : ''
      const timestamp = typeof value.timestamp === 'string' && value.timestamp.trim() ? value.timestamp : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      if (!role || !content) return null

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
      label: 'AI maintenance mode',
      helper: 'Some assistant replies may be temporarily limited.',
      banner: 'AI is currently unavailable. Please try again later or continue manually.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-warning',
    }
  }

  if (providerStatus === 'FALLBACK_PROVIDER_ACTIVE' || degraded) {
    return {
      providerStatus,
      degraded: true,
      badgeClassName: 'ai-header-status ai-header-status-degraded',
      label: 'Fallback mode active',
      helper: 'The assistant is currently using a backup response route.',
      banner: 'AI is running in fallback mode, so response quality may be reduced.',
      bannerClassName: 'ai-runtime-banner ai-runtime-banner-info',
    }
  }

  return {
    providerStatus,
    degraded: false,
    badgeClassName: 'ai-header-status',
    label: 'Ready to help',
    helper: 'The AI assistant can answer questions and suggest safe actions inside VNALO.',
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
      return 'Open conversation'
    case 'COMPOSE_MESSAGE':
      return 'Open chat with draft'
    case 'NAVIGATE_TO_CHAT':
      return 'Go to Chat'
    case 'NAVIGATE_TO_CONTACTS':
      return 'Go to Contacts'
    case 'OPEN_PROFILE':
      return 'Go to Profile'
    case 'NAVIGATE_TO':
      return 'Go to destination'
    case 'START_CALL':
      return 'Open chat for call'
    default:
      return 'Try this action'
  }
}

export function AiChatPage() {
  const { accessToken, user } = useAuth()
  const navigate = useNavigate()
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
  const inputRef = useRef<HTMLTextAreaElement | null>(null)
  const isUnmountedRef = useRef(false)
  const inFlightRequestRef = useRef(false)

  useEffect(() => {
    return () => {
      isUnmountedRef.current = true
    }
  }, [])

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (!saved) {
      setMessages([INITIAL_ASSISTANT_MESSAGE])
      return
    }

    try {
      const parsed = JSON.parse(saved)
      setMessages(normalizeStoredMessages(parsed))
    } catch (error) {
      console.warn('Failed to parse AI chat history', error)
      setMessages([INITIAL_ASSISTANT_MESSAGE])
    }
  }, [])

  const saveMessages = (nextMessages: AiMessage[]) => {
    const normalized = normalizeStoredMessages(nextMessages)
    setMessages(normalized)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(normalized))
  }

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
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
        content: 'Please sign in again to use the AI assistant on web.',
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
        content: aiResponse.textReply || 'Sorry, I cannot process that request right now.',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: Boolean(aiResponse.degraded),
        providerStatus: (aiResponse.providerStatus as ProviderStatus | undefined) ?? null,
        actionCommand: safeActionCommand,
        actionParams: aiResponse.actionParams ?? null,
      }

      if (!isUnmountedRef.current) {
        saveMessages([...updatedMessages, assistantMessage])
      }
    } catch (error) {
      console.error('AI chat failed:', error)
      const fallbackText =
        extractMessage((error as { response?: { data?: unknown } })?.response?.data) ||
        extractMessage(error) ||
        'There was a problem connecting to the AI assistant. Please try again later.'

      const errorMessage: AiMessage = {
        role: 'assistant',
        content: fallbackText,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        degraded: true,
        providerStatus: 'AI_PROVIDER_UNAVAILABLE',
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
        setActionFeedback({ tone: 'success', message: 'Opened the requested VNALO screen.' })
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
          setActionFeedback({ tone: 'warning', message: 'AI did not identify a specific conversation. Opened Chat so you can choose manually.' })
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
          setActionFeedback({ tone: 'info', message: `Found ${candidateConversations.length} matching conversations for "${target}". Please choose the exact target before continuing.` })
          return
        }

        const matched = candidateConversations[0]

        if (!matched) {
          setActionFeedback({ tone: 'warning', message: `No matching conversation found for "${target}".` })
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
          setActionFeedback({ tone: 'success', message: 'Opened the conversation. Use the call button to confirm the call manually on web.' })
        } else if (HIGH_RISK_ACTION_COMMANDS.has(command)) {
          setActionFeedback({ tone: 'warning', message: 'Opened the target conversation. Please confirm and perform this sensitive action manually.' })
        } else {
          setActionFeedback({ tone: 'success', message: 'Opened the target conversation.' })
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
      setActionFeedback({ tone: 'error', message: 'Could not execute the AI action on web right now. Please try again manually.' })
    } finally {
      setActionBusyIndex(null)
      setActiveActionLabel('')
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
    setActionFeedback({ tone: 'info', message: pendingActionReview.feedback })
    setPendingActionReview(null)
  }

  const executeResolvedConversationAction = (conversation: ConversationSummary, resolution: PendingActionResolution) => {
    if (resolution.command === 'COMPOSE_MESSAGE' && resolution.draft) {
      localStorage.setItem(`${DRAFT_KEY_PREFIX}${conversation.id}`, resolution.draft)
    }

    setPendingResolution(null)
    navigate(`/chat/${conversation.id}`)
  }

  useEffect(() => {
    if (!pendingActionReview && !pendingResolution) {
      return
    }

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') {
        return
      }

      setPendingActionReview(null)
      setPendingResolution(null)
    }

    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [pendingActionReview, pendingResolution])

  const handleRetry = () => {
    if (!retryPrompt || isAssistantBusy) {
      return
    }

    void handleSend(retryPrompt)
  }

  const handleClearHistory = () => {
    setActionFeedback(null)
    setRetryPrompt('')
    setPendingActionReview(null)
    setPendingResolution(null)
    saveMessages([
      {
        role: 'assistant',
        content: 'History was cleared. What can I help you with next?',
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
          <h3>VNALO AI Assistant</h3>
          <p>Helps answer questions, explain quickly, and suggest safe actions inside VNALO.</p>
        </div>

        <div className='ai-presets-container'>
          <span className='ai-presets-title'>Suggested prompts</span>
          {PRESET_PROMPTS.map((prompt) => (
            <button
              key={prompt}
              type='button'
              className='ai-preset-btn'
              onClick={() => void handleSend(prompt)}
              disabled={isAssistantBusy}
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
          disabled={isAssistantBusy}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
        >
          <Trash2 size={14} />
          Clear history
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
          {actionFeedback ? (
            <div className={`ai-runtime-banner ai-runtime-banner-${actionFeedback.tone}`}>
              <span>{actionFeedback.message}</span>
              {actionFeedback.tone === 'error' && retryPrompt ? (
                <button type='button' className='ai-banner-action' onClick={handleRetry} disabled={isAssistantBusy}>
                  Retry
                </button>
              ) : null}
            </div>
          ) : null}

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
                    disabled={isLoading || actionBusyIndex !== null || pendingActionReview !== null || pendingResolution !== null}
                  >
                    {actionBusyIndex === index ? 'Processing...' : buildActionLabel(message.actionCommand)}
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
              <span className='ai-typing-label'>{activeActionLabel ? `${activeActionLabel} in progress` : 'AI assistant is typing'}</span>
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
              placeholder='Ask the AI assistant something...'
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
            <button type='submit' className='ai-send-btn' disabled={isAssistantBusy || !inputValue.trim()}>

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
