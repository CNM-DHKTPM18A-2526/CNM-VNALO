import type { ConversationSummary } from '../chat.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { formatPresence } from '../utils/presenceUtils'
import { getGroupCollageData } from '../../../shared/utils/avatarUtils'
import { useUserStore } from '../context/UserStoreContext'

import { useAuth } from '../../auth/useAuth'

type ChatItemProps = {
  conversation: ConversationSummary
  active: boolean
  index: number
  onSelect: (conversationId: string) => void
}

export function ChatItem({ conversation, active, index, onSelect }: ChatItemProps) {
  const { user } = useAuth()
  const { userMap } = useUserStore()
  const isOnline = conversation?.online
  const lastSeenTime = conversation?.lastSeenTime ?? conversation?.updatedAt ?? conversation?.lastMessageAt ?? null
  const statusText = isOnline ? 'Đang hoạt động' : formatPresence(false, lastSeenTime)

  const peerId = !conversation.isGroup && !conversation.isCloud 
    ? (conversation.userId || (conversation.participantUserIds || []).find(id => id !== user?.id))
    : null
  
  const displayName = conversation.isGroup 
    ? conversation.name 
    : (userMap[peerId || '']?.displayName || conversation.name)

  const collageData = conversation.isGroup && !conversation.avatarUrl 
    ? getGroupCollageData(conversation, userMap) 
    : { avatars: [], extraCount: 0 }

  return (
    <button
      className={active ? 'chat-item chat-item-active' : 'chat-item'}
      onClick={() => {
        if (conversation) {
          onSelect(conversation.id)
        }
      }}
      type='button'
    >
      <div className='chat-item-avatar-wrap'>
        <UserAvatar 
          name={displayName ?? ''} 
          imageUrl={(!conversation.isGroup && peerId ? userMap[peerId]?.avatarUrl : conversation?.avatarUrl) ?? conversation?.avatarUrl ?? null} 
          size='md' 
          isGroup={conversation.isGroup}
          memberAvatars={collageData.avatars}
          extraCount={collageData.extraCount}
        />
        {isOnline ? <span className='chat-item-online-dot' /> : null}
      </div>
      <div className='chat-item-content'>
        <div className='chat-item-top'>
          <p>{displayName ?? ''}</p>
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
