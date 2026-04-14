import { NavLink } from 'react-router-dom'

import { useAuth } from '../../features/auth/useAuth'
import { useLanguage } from '../i18n/LanguageContext'
import { Icon } from './Icon'
import { UserAvatar } from './UserAvatar'
import { SettingsMenu } from './SettingsMenu'

type SidebarProps = {
  onOpenSettingsModal?: () => void
}

export function Sidebar({ onOpenSettingsModal }: SidebarProps) {
  const { t } = useLanguage()
  const { user } = useAuth()

  const menuItems = [
    { to: '/chat', labelKey: 'sidebar.chat', icon: 'chat' as const },
    { to: '/contacts', labelKey: 'sidebar.contacts', icon: 'addressBook' as const },
    { to: '/todo', labelKey: 'sidebar.todo', icon: 'checkSquare' as const },
    { to: '/documents', labelKey: 'sidebar.documents', icon: 'folder' as const },
    { 
      to: user ? `/chat/vnalo_cloud_${user.id}` : '/chat', 
      labelKey: 'sidebar.cloud', 
      icon: 'cloud' as const 
    },
  ]

  const handleOpenSettings = () => {
    onOpenSettingsModal?.()
  }

  return (
    <aside className='sidebar'>
      <div className='sidebar-top'>
        <NavLink className='sidebar-profile-link' title={t('sidebar.profile')} to='/profile'>
          <UserAvatar imageUrl={user?.avatarUrl} name={user?.name ?? user?.email ?? 'VNALO User'} size='md' />
        </NavLink>
      </div>
      <nav className='sidebar-nav'>
        {menuItems.map((item) => (
          <NavLink
            key={item.labelKey}
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
        <NavLink className='sidebar-link' to='/tools' title="Công cụ">
          <span aria-hidden className='sidebar-link-icon'>
            <Icon name="briefcase" />
          </span>
        </NavLink>
        <SettingsMenu onOpenSettings={handleOpenSettings} />
      </div>
    </aside>
  )
}
