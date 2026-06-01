import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'

import { GlobalIncomingCallBridge } from '../features/chat/components/GlobalIncomingCallBridge'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { Icon } from '../shared/components/Icon'
import { UserAvatar } from '../shared/components/UserAvatar'

const adminNavItems = [
  { to: '/admin/monitoring', label: 'Dashboard', icon: 'database' as const },
]

export function AdminLayout() {
  const location = useLocation()
  const { user, logout } = useAuth()
  const { language } = useLanguage()
  const isVietnamese = language === 'vi'

  return (
    <div className='admin-shell'>
      <aside className='admin-shell-sidebar' aria-label={isVietnamese ? 'Điều hướng quản trị' : 'Admin navigation'}>
        <Link className='admin-shell-brand' to='/admin/monitoring'>
          <span className='admin-shell-brand-mark'>V</span>
          <span>
            <strong>VNALO Studio</strong>
            <small>{isVietnamese ? 'Bảng điều khiển' : 'Admin dashboard'}</small>
          </span>
        </Link>

        <nav className='admin-shell-nav'>
          {adminNavItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => isActive ? 'admin-shell-nav-item active' : 'admin-shell-nav-item'}
            >
              <Icon name={item.icon} />
              <span>{isVietnamese && item.label === 'Dashboard' ? 'Tổng quan' : item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className='admin-shell-sidebar-footer'>
          <Link className='admin-shell-nav-item subtle' to='/chat'>
            <Icon name='chat' />
            <span>{isVietnamese ? 'Về VNALO' : 'Back to VNALO'}</span>
          </Link>
        </div>
      </aside>

      <section className='admin-shell-main'>
        <header className='admin-shell-topbar'>
          <div>
            <p>{isVietnamese ? 'Quản trị vận hành' : 'Operations'}</p>
            <h1>{location.pathname.includes('monitoring') ? (isVietnamese ? 'Monitoring dashboard' : 'Monitoring dashboard') : 'Dashboard'}</h1>
          </div>
          <div className='admin-shell-actions'>
            <Link className='admin-shell-secondary' to='/chat'>{isVietnamese ? 'Mở app' : 'Open app'}</Link>
            <button className='admin-shell-secondary' type='button' onClick={logout}>{isVietnamese ? 'Đăng xuất' : 'Log out'}</button>
            <UserAvatar imageUrl={user?.avatarUrl} name={user?.name ?? user?.email ?? 'VNALO Admin'} size='sm' />
          </div>
        </header>
        <main className='admin-shell-content'>
          <Outlet />
        </main>
      </section>

      <GlobalIncomingCallBridge />
    </div>
  )
}
