import type { FriendRequest } from '../../friends/friends.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'

type FriendRequestListProps = {
  items: FriendRequest[]
  labels: {
    accept: string
    decline: string
    unknownUser: string
  }
  onAccept: (id: string) => void
  onDecline: (id: string) => void
  actionLoadingId?: string | null
  actionType?: 'accept' | 'decline' | null
}

export function FriendRequestList({
  items,
  labels,
  onAccept,
  onDecline,
  actionLoadingId = null,
  actionType = null,
}: FriendRequestListProps) {
  return (
    <section className='contacts-list'>
      {items.map((item) => {
        const displayName = item.fromUserDisplayName?.trim() || labels.unknownUser
        const subtitle = item.message?.trim() || null

        return (
          <article className='contacts-item contacts-request-item' key={item.id}>
            <div className='contacts-item-main'>
              <UserAvatar imageUrl={item.fromUserAvatarUrl} name={displayName} size='md' />
              <div className='contacts-item-copy'>
                <h3>{displayName}</h3>
                {subtitle ? <p>{subtitle}</p> : null}
              </div>
            </div>
            <div className='contacts-item-actions'>
            <Button
              disabled={actionLoadingId === item.id}
              onClick={() => onAccept(item.id)}
              variant='primary'
            >
              {labels.accept}
            </Button>
            <Button
              disabled={actionLoadingId === item.id}
              onClick={() => onDecline(item.id)}
              variant='ghost'
            >
              {labels.decline}
            </Button>

            {actionLoadingId === item.id && actionType ? <p className='contacts-inline-loading'>{actionType}...</p> : null}
            </div>
          </article>
        )
      })}
    </section>
  )
}
