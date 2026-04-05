import { useEffect, useState } from 'react'

import { NotificationList } from '../features/notifications/components/NotificationList'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { notifications } from '../shared/mock/data'

export function NotificationsPage() {
  const [isLoading, setIsLoading] = useState(true)
  const { t } = useLanguage()

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      setIsLoading(false)
    }, 220)

    return () => {
      window.clearTimeout(timeoutId)
    }
  }, [])

  return (
    <section className='panel-page'>
      <h2>{t('pages.notifications.title')}</h2>
      <p className='panel-subtitle'>{t('pages.notifications.subtitle')}</p>
      {isLoading ? (
        <div className='notification-skeleton-list'>
          {Array.from({ length: 4 }).map((_, index) => (
            <article className='notification-item notification-item-skeleton' key={`n-skeleton-${index}`}>
              <Skeleton className='skeleton-line skeleton-line-title' />
              <Skeleton className='skeleton-line' />
              <Skeleton className='skeleton-line skeleton-line-short' />
            </article>
          ))}
        </div>
      ) : (
        <NotificationList items={notifications} />
      )}
    </section>
  )
}
