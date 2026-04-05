import type { ContactItem as Contact } from '../../../shared/mock/data'
import { ContactItem } from './ContactItem'

type ContactListProps = {
  items: Contact[]
  labels: {
    chat: string
    addFriend: string
    more: string
    online: string
    busy: string
    offline: string
  }
}

export function ContactList({ items, labels }: ContactListProps) {
  return (
    <section className='contacts-list'>
      {items.map((item) => (
        <ContactItem key={item.id} item={item} labels={labels} />
      ))}
    </section>
  )
}
