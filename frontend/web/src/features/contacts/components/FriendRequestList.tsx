import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'
import type { FriendRequestItem } from '../../../shared/mock/data'

type FriendRequestListProps = {
  items: FriendRequestItem[]
  labels: {
    mutualFriends: string
    accept: string
    decline: string
  }
  onAccept: (id: string) => void
  onDecline: (id: string) => void
}

export function FriendRequestList({ items, labels, onAccept, onDecline }: FriendRequestListProps) {
  return (
    <section className='contacts-list'>
      {items.map((item) => (
        <article className='contacts-item contacts-request-item' key={item.id}>
          <div className='contacts-item-main'>
            <UserAvatar name={item.displayName} size='md' />
            <div className='contacts-item-copy'>
              <h3>{item.displayName}</h3>
              <p>{item.subtitle}</p>
              <p className='contacts-request-meta'>
                {item.mutualCount} {labels.mutualFriends}
              </p>
            </div>
          </div>
          <div className='contacts-item-actions'>
            <Button onClick={() => onAccept(item.id)} variant='primary'>
              {labels.accept}
            </Button>
            <Button onClick={() => onDecline(item.id)} variant='ghost'>
              {labels.decline}
            </Button>
          </div>
        </article>
      ))}
    </section>
  )
}
