import type { ConversationSummary } from '../chat.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { formatPresence } from '../utils/presenceUtils'

type ChatItemProps = {
  conversation: ConversationSummary
  active: boolean
  index: number
  onSelect: (conversationId: string) => void
}

export function ChatItem({ conversation, active, index, onSelect }: ChatItemProps) {
  const isOnline = conversation?.online
  const lastSeenTime = conversation?.lastSeenTime ?? conversation?.updatedAt ?? conversation?.lastMessageAt ?? null
  const statusText = isOnline ? 'Đang hoạt động' : formatPresence(false, lastSeenTime)

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
        <UserAvatar name={conversation?.name ?? ''} imageUrl={conversation?.avatarUrl ?? null} size='md' />
        {isOnline ? <span className='chat-item-online-dot' /> : null}
      </div>
      <div className='chat-item-content'>
        <div className='chat-item-top'>
          <p>{conversation?.name ?? ''}</p>
          <time>{statusText}</time>
        </div>
        <div className='chat-item-bottom'>
          <p className='chat-item-message'>{conversation?.lastMessage ?? ''}</p>
          {(conversation?.unreadCount ?? 0) > 0 ? (
            <span className='unread-badge'>{conversation?.unreadCount ?? 0}</span>
          ) : null}
        </div>
      </div>
    </button>
  )
}
