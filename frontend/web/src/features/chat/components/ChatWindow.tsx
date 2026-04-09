import { useMemo } from 'react'

import { EmptyState } from '../../../shared/components/EmptyState'
import { Icon } from '../../../shared/components/Icon'
import { LoadingState } from '../../../shared/components/LoadingState'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
import type { ChatMessage, ConversationSummary } from '../chat.types'
import { MessageBubble } from './MessageBubble'
import { MessageInput } from './MessageInput'

type ChatWindowProps = {
  conversation: ConversationSummary | undefined
  messages: ChatMessage[]
  isLoadingMessages: boolean
  onSend: (message: string) => void
  isRestrictedMode?: boolean
  peerLastReadSeq?: number
}

export function ChatWindow({
  conversation,
  messages,
  isLoadingMessages,
  onSend,
  isRestrictedMode = false,
  peerLastReadSeq,
}: ChatWindowProps) {
  const { t } = useLanguage()

  const conversationMessages = useMemo(() => {
    if (!conversation) {
      return []
    }

    return messages.filter((message) => message.conversationId === conversation.id)
  }, [conversation, messages])

  if (!conversation) {
    return (
      <section className='chat-window'>
        <EmptyState
          title={t('chat.windowEmptyTitle')}
          description={t('chat.windowEmptyDesc')}
        />
      </section>
    )
  }

  return (
    <section className='chat-window'>
      <header className='chat-window-header'>
        <div className='chat-window-header-main'>
          <UserAvatar name={conversation.name} size='md' />
          <div className='chat-window-header-copy'>
            <h2>{conversation.name}</h2>
            <p>{conversation.online ? t('chat.online') : t('chat.offline')}</p>
          </div>
        </div>
        <div className='chat-window-header-actions'>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='phone' />
          </button>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='video' />
          </button>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='search' />
          </button>
          <button className='chat-header-action-btn' type='button'>
            <Icon name='more' />
          </button>
        </div>
      </header>
      <div className='chat-window-messages'>
        {isLoadingMessages ? (
          <LoadingState label={t('chat.loadingConversation')} />
        ) : conversationMessages.length === 0 ? (
          <EmptyState
            title={t('chat.windowEmptyTitle')}
            description={t('chat.windowEmptyDesc')}
          />
        ) : (
          conversationMessages.map((message) => (
            <MessageBubble
              key={message.id}
              message={message}
              isReadByPeer={
                message.sender === 'me' &&
                message.serverSeq !== undefined &&
                peerLastReadSeq !== undefined &&
                message.serverSeq <= peerLastReadSeq
              }
            />
          ))
        )}
      </div>
      {isRestrictedMode ? (
        <div className='chat-restricted-banner'>
          Đồng bộ đa thiết bị đang tắt. Web chỉ hiển thị dữ liệu giới hạn.
        </div>
      ) : null}
      <MessageInput
        onSend={onSend}
        placeholder={isRestrictedMode ? 'Tin nhắn bị khóa khi ở chế độ giới hạn' : t('chat.messageInputPlaceholder')}
        disabled={isRestrictedMode}
      />
    </section>
  )
}
