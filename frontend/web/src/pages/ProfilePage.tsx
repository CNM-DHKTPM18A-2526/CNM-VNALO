import { useAuth } from '../features/auth/useAuth'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Card } from '../shared/components/ui/Card'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { CURRENT_USER } from '../shared/mock/data'

export function ProfilePage() {
  const { isBootstrapping } = useAuth()
  const { t } = useLanguage()

  if (isBootstrapping) {
    return (
      <section className='panel-page'>
        <h2>{t('pages.profile.title')}</h2>
        <p className='panel-subtitle'>{t('pages.profile.subtitle')}</p>
        <Card className='profile-card'>
          <Skeleton className='profile-avatar-skeleton' />
          <div className='profile-copy'>
            <Skeleton className='skeleton-line skeleton-line-title' />
            <Skeleton className='skeleton-line' />
            <Skeleton className='skeleton-line skeleton-line-short' />
          </div>
        </Card>
      </section>
    )
  }

  return (
    <section className='panel-page'>
      <h2>{t('pages.profile.title')}</h2>
      <p className='panel-subtitle'>{t('pages.profile.subtitle')}</p>
      <Card className='profile-card'>
        <UserAvatar name={CURRENT_USER.name} size='lg' />
        <div className='profile-copy'>
          <h3>{CURRENT_USER.name}</h3>
          <p>{t('pages.profile.roleLine')}</p>
          <p className='profile-meta'>{t('pages.profile.metaLine')}</p>
        </div>
      </Card>
    </section>
  )
}
