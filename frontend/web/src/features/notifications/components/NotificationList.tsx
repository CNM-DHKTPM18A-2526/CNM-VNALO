import { EmptyState } from '../../../shared/components/EmptyState'
import { Icon } from '../../../shared/components/Icon'
import { Card } from '../../../shared/components/ui/Card'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
import type { AppNotification } from '../../../shared/mock/data'

type NotificationListProps = {
  items: AppNotification[]
}

export function NotificationList({ items }: NotificationListProps) {
  const { t } = useLanguage()

  if (items.length === 0) {
    return (
      <EmptyState
        title={t('notifications.emptyTitle')}
        description={t('notifications.emptyDesc')}
      />
    )
  }

  return (
    <section className='notification-list'>
      {items.map((item, index) => (
        <Card
          as='article'
          key={item.id}
          className={
            item.isRead
              ? 'notification-item stagger-item'
              : 'notification-item notification-item-unread stagger-item'
          }
          style={{ animationDelay: `${index * 36}ms` }}
        >
          <div className='notification-item-head'>
            <span className='notification-icon'>
              <Icon name={item.title.toLowerCase().includes('tin') ? 'chat' : 'bell'} />
            </span>
            <div className='notification-item-content'>
              <h3 className='notification-title'>{item.title}</h3>
              <p>{item.content}</p>
              <time className='notification-time'>{item.createdAt}</time>
            </div>
          </div>
        </Card>
      ))}
    </section>
  )
}
