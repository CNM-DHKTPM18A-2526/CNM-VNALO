import { NavLink } from 'react-router-dom'

import { useAuth } from '../../features/auth/useAuth'
import { useLanguage } from '../i18n/LanguageContext'
import { useNotifications } from '../../features/notifications/NotificationContext'
import { Icon } from './Icon'
import { UserAvatar } from './UserAvatar'
import { SettingsMenu } from './SettingsMenu'

type SidebarProps = {
  onOpenSettingsModal?: () => void
  onOpenCaptureModal?: () => void
}

export function Sidebar({ onOpenSettingsModal, onOpenCaptureModal }: SidebarProps) {
  const { t } = useLanguage()
  const { user } = useAuth()
  const { unreadMessageCount, pendingFriendRequestCount } = useNotifications()

  const primaryNav: Array<{ to: string; labelKey: string; icon: any; badge: number }> = [
    { to: '/chat', labelKey: 'sidebar.chat', icon: 'chat' as const, badge: unreadMessageCount },
    { to: '/contacts', labelKey: 'sidebar.contacts', icon: 'addressBook' as const, badge: pendingFriendRequestCount },
    { to: '/chat-ai', labelKey: 'sidebar.ai', icon: 'spark' as const, badge: 0 },
  ]

  const secondaryNav = [
    {
      to: user ? `/chat/vnalo_cloud_${user.id}` : '/chat',
      labelKey: 'sidebar.cloud',
      icon: 'cloud' as const
    },
    { to: '/chat/my-documents', labelKey: 'sidebar.documents', icon: 'folder' as const },
    { labelKey: 'sidebar.todo', icon: 'capture' as const, onClick: onOpenCaptureModal },
    { to: '/tools', labelKey: 'sidebar.tools', icon: 'briefcase' as const },
    { to: '/face-auth', labelKey: 'sidebar.faceAuth', icon: 'spark' as const },
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

      <nav className='sidebar-nav primary-nav'>
        {primaryNav.map((item) => (
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
              {item.badge > 0 && (
                <span className='sidebar-badge'>
                  {item.badge > 99 ? '99+' : item.badge}
                </span>
              )}
            </span>
          </NavLink>
        ))}
      </nav>

      <div className='sidebar-spacer' />

      <nav className='sidebar-nav secondary-nav'>
        {secondaryNav.map((item) => {
          if ((item as any).onClick) {
            return (
              <button
                key={item.labelKey}
                className='sidebar-link'
                onClick={(item as any).onClick}
                title={t(item.labelKey)}
                type='button'
              >
                <span aria-hidden className='sidebar-link-icon'>
                  <Icon name={item.icon} />
                </span>
              </button>
            )
          }

          return (
            <NavLink
              key={item.labelKey}
              to={(item as any).to}
              className={({ isActive }) =>
                isActive ? 'sidebar-link sidebar-link-active' : 'sidebar-link'
              }
              title={t(item.labelKey)}
            >
              <span aria-hidden className='sidebar-link-icon'>
                <Icon name={item.icon} />
              </span>
            </NavLink>
          )
        })}
      </nav>

      <div className='sidebar-footer'>
        <SettingsMenu onOpenSettings={handleOpenSettings} />
      </div>
    </aside>
  )
}
