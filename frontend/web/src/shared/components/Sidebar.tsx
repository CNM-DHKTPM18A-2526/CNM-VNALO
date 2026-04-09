import { NavLink } from 'react-router-dom'

import { useAuth } from '../../features/auth/useAuth'
import { useLanguage } from '../i18n/LanguageContext'
import { Icon } from './Icon'
import { UserAvatar } from './UserAvatar'
import { SettingsMenu } from './SettingsMenu'

const menuItems = [
  { to: '/chat', labelKey: 'sidebar.chat', icon: 'chat' as const },
  { to: '/contacts', labelKey: 'sidebar.contacts', icon: 'addressBook' as const },
  { to: '/profile', labelKey: 'sidebar.profile', icon: 'user' as const },
]

type SidebarProps = {
  onOpenSettingsModal?: () => void
}

export function Sidebar({ onOpenSettingsModal }: SidebarProps) {
  const { t } = useLanguage()
  const { user } = useAuth()

  const handleOpenSettings = () => {
    onOpenSettingsModal?.()
  }

  return (
    <aside className='sidebar'>
      <div className='sidebar-top'>
        <NavLink className='sidebar-profile-link' title={t('sidebar.profile')} to='/profile'>
          <UserAvatar imageUrl={user?.avatarUrl} name={user?.name ?? user?.email ?? 'VNALO User'} size='md' />
        </NavLink>
        <span aria-hidden className='brand-logo'>
          V
        </span>
      </div>
      <nav className='sidebar-nav'>
        {menuItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              isActive ? 'sidebar-link sidebar-link-active' : 'sidebar-link'
            }
            title={t(item.labelKey)}
          >
            <span aria-hidden className='sidebar-link-icon'>
              <Icon name={item.icon} />
            </span>
          </NavLink>
        ))}
      </nav>
      <div className='sidebar-footer'>
        <SettingsMenu onOpenSettings={handleOpenSettings} />
      </div>
    </aside>
  )
}
