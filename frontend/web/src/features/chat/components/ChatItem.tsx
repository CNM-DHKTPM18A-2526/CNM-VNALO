import type { ConversationSummary } from '../chat.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { formatPresence } from '../utils/presenceUtils'
import { useAuth } from '../../auth/useAuth'
import { formatMessagePreview } from '../utils/messageUtils'

type ChatItemProps = {
  conversation: ConversationSummary
  active: boolean
  index: number
  onSelect: (conversationId: string) => void
}

export function ChatItem({ conversation, active, index, onSelect }: ChatItemProps) {
  useAuth()
  const isOnline = conversation?.online
  const lastSeenTime = conversation?.lastSeenTime ?? conversation?.updatedAt ?? conversation?.lastMessageAt ?? null
  const statusText = isOnline ? 'Đang hoạt động' : formatPresence(false, lastSeenTime)

  // In a real ChatItem, we should ideally have lastMessageSenderId in ConversationSummary.
  // For now, we'll try to infer if it's "me" or just skip the "Bạn: " prefix for system messages.
  const isMe = conversation.lastMessage?.includes('Bạn:') ?? false // Fallback if already formatted
  const previewText = formatMessagePreview(conversation.lastMessage, isMe)

  return (
    <button
      className={active ? 'chat-item chat-item-active stagger-item' : 'chat-item stagger-item'}
      onClick={() => {
        if (conversation) {
          onSelect(conversation.id)
        }
      }}
      style={{ animationDelay: `${index * 28}ms` }}
      type='button'
    >
      <div className='chat-item-avatar-wrap'>
        <UserAvatar 
          name={conversation?.name ?? ''} 
          imageUrl={conversation?.avatarUrl ?? null} 
          size='md' 
          isGroup={conversation?.isGroup}
          isCloud={conversation?.isCloud}
        />
        {isOnline ? <span className='chat-item-online-dot' /> : null}
      </div>
      <div className='chat-item-content'>
        <div className='chat-item-top'>
          <p>{conversation?.name ?? ''}</p>
          <time>{statusText}</time>
        </div>
        <div className='chat-item-bottom'>
          <p className='chat-item-message'>{previewText}</p>
          {(conversation?.unreadCount ?? 0) > 0 ? (
            <span className='unread-badge'>{conversation?.unreadCount ?? 0}</span>
          ) : null}
        </div>
      </div>
    </button>
  )
}
