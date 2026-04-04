import { useAuth } from '../features/auth/useAuth'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Card } from '../shared/components/ui/Card'
import { CURRENT_USER } from '../shared/mock/data'

export function ProfilePage() {
  const { isBootstrapping } = useAuth()

  if (isBootstrapping) {
    return (
      <section className='panel-page'>
        <h2>Hồ sơ cá nhân</h2>
        <p className='panel-subtitle'>Quản lý thông tin tài khoản và cài đặt hiển thị.</p>
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
      <h2>Hồ sơ cá nhân</h2>
      <p className='panel-subtitle'>Quản lý thông tin tài khoản và cài đặt hiển thị.</p>
      <Card className='profile-card'>
        <UserAvatar name={CURRENT_USER.name} size='lg' />
        <div className='profile-copy'>
          <h3>{CURRENT_USER.name}</h3>
          <p>Frontend Engineer • VNALO Team</p>
          <p className='profile-meta'>ID: vna-user-001 • Active now</p>
        </div>
      </Card>
    </section>
  )
}
