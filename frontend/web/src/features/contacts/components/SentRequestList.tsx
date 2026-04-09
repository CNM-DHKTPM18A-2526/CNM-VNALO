import type { FriendRequest } from '../../friends/friends.types'
import type { AddFriendTarget } from '../../friends/components/AddFriendModal'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'

type SentRequestListProps = {
  items: FriendRequest[]
  labels: {
    cancelRequest: string
    addFriend: string
    unknownUser: string
  }
  onCancel: (id: string) => void
  onOpenAddFriend?: (target: AddFriendTarget) => void
  actionLoadingId?: string | null
}

export function SentRequestList({
  items,
  labels,
  onCancel,
  onOpenAddFriend,
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
            {onOpenAddFriend ? (
              <Button
                disabled={actionLoadingId === item.id}
                onClick={() =>
                  onOpenAddFriend({
                    userId: item.toUserId,
                    displayName: item.toUserDisplayName,
                    avatarUrl: item.toUserAvatarUrl,
                  })
                }
                variant='subtle'
              >
                {labels.addFriend}
              </Button>
            ) : null}
            </div>
          </article>
        )
      })}
    </section>
  )
}
