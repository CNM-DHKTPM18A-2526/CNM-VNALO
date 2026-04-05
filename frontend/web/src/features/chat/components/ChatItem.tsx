import type { ChatConversation } from '../../../shared/mock/data'
import { UserAvatar } from '../../../shared/components/UserAvatar'

type ChatItemProps = {
  conversation: ChatConversation
  active: boolean
  index: number
  onSelect: (conversationId: string) => void
}

export function ChatItem({ conversation, active, index, onSelect }: ChatItemProps) {
  return (
    <button
      className={active ? 'chat-item chat-item-active stagger-item' : 'chat-item stagger-item'}
      onClick={() => onSelect(conversation.id)}
      style={{ animationDelay: `${index * 28}ms` }}
      type='button'
    >
      <UserAvatar name={conversation.name} size='md' />
      <div className='chat-item-content'>
        <div className='chat-item-top'>
          <p>{conversation.name}</p>
          {conversation.unreadCount > 0 ? <span className='unread-badge'>{conversation.unreadCount}</span> : null}
        </div>
        <p className='chat-item-message'>{conversation.lastMessage}</p>
      </div>
    </button>
  )
}
