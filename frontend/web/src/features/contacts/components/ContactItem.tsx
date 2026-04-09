import { useNavigate } from 'react-router-dom'

import type { Friend } from '../../friends/friends.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'

type ContactItemProps = {
  item: Friend
  labels: {
    chat: string
    unfriend: string
    friend: string
    unknownUser: string
  }
  onUnfriend: (friendId: string, displayName: string) => void
  isActionLoading?: boolean
}

export function ContactItem({ item, labels, onUnfriend, isActionLoading = false }: ContactItemProps) {
  const navigate = useNavigate()
  const displayName = item.displayName?.trim() || item.nickname?.trim() || labels.unknownUser
  const subtitle = item.statusMessage?.trim() || null

  return (
    <article className='contacts-item'>
      <div className='contacts-item-main'>
        <UserAvatar imageUrl={item.avatarUrl} name={displayName} size='md' />
        <div className='contacts-item-copy'>
          <h3>{displayName}</h3>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
      </div>
      <div className='contacts-item-meta'>
        <span className='contacts-status contacts-status-online'>{labels.friend}</span>
        <div className='contacts-item-actions'>
          <Button disabled={isActionLoading} onClick={() => navigate('/chat')} variant='primary'>
            {labels.chat}
          </Button>
          <Button
            disabled={isActionLoading}
            onClick={() => onUnfriend(item.friendId, displayName)}
            variant='ghost'
          >
            {labels.unfriend}
          </Button>
        </div>
      </div>
    </article>
  )
}
