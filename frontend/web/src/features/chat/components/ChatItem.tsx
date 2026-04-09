import type { ConversationSummary } from '../chat.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'

type ChatItemProps = {
  conversation: ConversationSummary
  active: boolean
  index: number
  onSelect: (conversationId: string) => void
}

export function ChatItem({ conversation, active, index, onSelect }: ChatItemProps) {
  const previewTimes = ['09:18', '08:50', '07:18', 'Yesterday']

  return (
    <button
      className={active ? 'chat-item chat-item-active stagger-item' : 'chat-item stagger-item'}
      onClick={() => onSelect(conversation.id)}
      style={{ animationDelay: `${index * 28}ms` }}
      type='button'
    >
      <div className='chat-item-avatar-wrap'>
        <UserAvatar name={conversation.name} size='md' />
        {conversation.online ? <span className='chat-item-online-dot' /> : null}
      </div>
      <div className='chat-item-content'>
        <div className='chat-item-top'>
          <p>{conversation.name}</p>
          <time>{previewTimes[index % previewTimes.length]}</time>
        </div>
        <div className='chat-item-bottom'>
          <p className='chat-item-message'>{conversation.lastMessage}</p>
          {conversation.unreadCount > 0 ? <span className='unread-badge'>{conversation.unreadCount}</span> : null}
        </div>
      </div>
    </button>
  )
}
