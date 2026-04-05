import { useNavigate } from 'react-router-dom'

import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'
import type { ContactItem as Contact } from '../../../shared/mock/data'

type ContactItemProps = {
  item: Contact
  labels: {
    chat: string
    addFriend: string
    more: string
    online: string
    busy: string
    offline: string
  }
}

function getStatusLabel(status: Contact['status'], labels: ContactItemProps['labels']) {
  if (status === 'online') {
    return labels.online
  }

  if (status === 'busy') {
    return labels.busy
  }

  return labels.offline
}

export function ContactItem({ item, labels }: ContactItemProps) {
  const navigate = useNavigate()

  return (
    <article className='contacts-item'>
      <div className='contacts-item-main'>
        <UserAvatar name={item.displayName} size='md' />
        <div className='contacts-item-copy'>
          <h3>{item.displayName}</h3>
          <p>{item.subtitle}</p>
        </div>
      </div>
      <div className='contacts-item-meta'>
        <span className={`contacts-status contacts-status-${item.status}`}>{getStatusLabel(item.status, labels)}</span>
        <div className='contacts-item-actions'>
          <Button onClick={() => navigate('/chat')} variant='primary'>
            {labels.chat}
          </Button>
          <Button variant='subtle'>{labels.addFriend}</Button>
          <Button variant='ghost'>{labels.more}</Button>
        </div>
      </div>
    </article>
  )
}
