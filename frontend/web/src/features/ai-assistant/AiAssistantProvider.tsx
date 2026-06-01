import React from 'react'

import type { ConversationSummary } from '../chat/chat.types'
import { useAuth } from '../auth/useAuth'

export const AI_PENDING_PROMPT_KEY = 'vnalo_ai_web_pending_prompt'
export const AI_ASSISTANT_USER_ID = '__vnalo_ai__'
export const AI_ASSISTANT_CONVERSATION_ID = 'vnalo-ai-assistant'

const AI_ASSISTANT_META_KEY_PREFIX = 'vnalo_ai_chat_meta:'
const DEFAULT_AI_META: AiAssistantMeta = {
  preview: 'Sẵn sàng hỗ trợ',
  timestamp: new Date(0).toISOString(),
}

type AiAssistantMeta = {
  preview: string
  timestamp: string
}

type AiAssistantContextValue = {
  assistantConversation: ConversationSummary
  meta: AiAssistantMeta
  recordActivity: (activity: AiAssistantMeta) => void
  resetMeta: () => void
}

const AiAssistantContext = React.createContext<AiAssistantContextValue | null>(null)

function buildMetaKey(userId?: string | null) {
  return userId ? `${AI_ASSISTANT_META_KEY_PREFIX}${userId}` : null
}

function readMeta(userId?: string | null): AiAssistantMeta {
  const key = buildMetaKey(userId)
  if (!key) return DEFAULT_AI_META

  try {
    const parsed = JSON.parse(localStorage.getItem(key) || 'null') as Partial<AiAssistantMeta> | null
    if (!parsed?.preview || !parsed?.timestamp) return DEFAULT_AI_META
    return { preview: parsed.preview, timestamp: parsed.timestamp }
  } catch {
    return DEFAULT_AI_META
  }
}

function writeMeta(userId: string | undefined, meta: AiAssistantMeta) {
  const key = buildMetaKey(userId)
  if (!key) return
  localStorage.setItem(key, JSON.stringify(meta))
}

export function AiAssistantProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth()
  const [meta, setMeta] = React.useState<AiAssistantMeta>(() => readMeta(user?.id))

  React.useEffect(() => {
    setMeta(readMeta(user?.id))
  }, [user?.id])

  React.useEffect(() => {
    const handleStorage = (event: StorageEvent) => {
      if (!user?.id || event.key !== buildMetaKey(user.id)) return
      setMeta(readMeta(user.id))
    }

    window.addEventListener('storage', handleStorage)
    return () => window.removeEventListener('storage', handleStorage)
  }, [user?.id])

  const recordActivity = React.useCallback((activity: AiAssistantMeta) => {
    writeMeta(user?.id, activity)
    setMeta(activity)
  }, [user?.id])

  const resetMeta = React.useCallback(() => {
    writeMeta(user?.id, DEFAULT_AI_META)
    setMeta(DEFAULT_AI_META)
  }, [user?.id])

  const assistantConversation = React.useMemo<ConversationSummary>(() => ({
    id: AI_ASSISTANT_CONVERSATION_ID,
    userId: AI_ASSISTANT_USER_ID,
    name: 'VNALO AI Assistant',
    avatarUrl: null,
    isGroup: false,
    isAiAssistant: true,
    lastMessage: meta.preview,
    unreadCount: 0,
    online: true,
    isOnline: true,
    participantUserIds: [AI_ASSISTANT_USER_ID],
    memberCount: 2,
    lastMessageAt: meta.timestamp,
    updatedAt: meta.timestamp,
  }), [meta.preview, meta.timestamp])

  const value = React.useMemo<AiAssistantContextValue>(() => ({
    assistantConversation,
    meta,
    recordActivity,
    resetMeta,
  }), [assistantConversation, meta, recordActivity, resetMeta])

  return <AiAssistantContext.Provider value={value}>{children}</AiAssistantContext.Provider>
}

export function useAiAssistant() {
  const context = React.useContext(AiAssistantContext)
  if (!context) {
    throw new Error('useAiAssistant must be used inside AiAssistantProvider')
  }
  return context
}
