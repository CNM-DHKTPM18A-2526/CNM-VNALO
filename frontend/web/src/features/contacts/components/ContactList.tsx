import type { Friend } from '../../friends/friends.types'
import { ContactItem } from './ContactItem'

type ContactListProps = {
  items: Friend[]
  labels: {
    chat: string
    unfriend: string
    friend: string
    unknownUser: string
  }
  actionLoadingId?: string | null
  onUnfriend: (friendId: string, displayName: string) => void
}

export function ContactList({ items, labels, onUnfriend, actionLoadingId = null }: ContactListProps) {
  return (
    <section className='contacts-list'>
      {items.map((item) => (
        <ContactItem
          key={item.friendshipId}
          item={item}
          labels={labels}
          onUnfriend={onUnfriend}
          isActionLoading={actionLoadingId === item.friendId}
        />
      ))}
    </section>
  )
}
