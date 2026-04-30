import type { FriendRequest } from '../../friends/friends.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'

type SentRequestListProps = {
  items: FriendRequest[]
  labels: {
    cancelRequest: string
    unknownUser: string
  }
  onCancel: (id: string) => void
  actionLoadingId?: string | null
}

export function SentRequestList({
  items,
  labels,
  onCancel,
  actionLoadingId = null,
}: SentRequestListProps) {
  return (
    <section className='contacts-list'>
      {items.map((item) => {
        const displayName = item.toUserDisplayName?.trim() || labels.unknownUser
        const subtitle = item.message?.trim() || null

        return (
          <article className='contacts-item contacts-request-item' key={item.id}>
            <div className='contacts-item-main'>
              <UserAvatar imageUrl={item.toUserAvatarUrl} name={displayName} size='md' />
              <div className='contacts-item-copy'>
                <h3>{displayName}</h3>
                {subtitle ? <p>{subtitle}</p> : null}
              </div>
            </div>
            <div className='contacts-item-actions'>
            <Button
              disabled={actionLoadingId === item.id}
              onClick={() => onCancel(item.id)}
              variant='ghost'
            >
              {labels.cancelRequest}
            </Button>

            </div>
          </article>
        )
      })}
    </section>
  )
}
