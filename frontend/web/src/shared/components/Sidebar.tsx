import { NavLink } from 'react-router-dom'

import { useLanguage } from '../i18n/LanguageContext'
import { Icon } from './Icon'

const menuItems = [
  { to: '/chat', labelKey: 'sidebar.chat', icon: 'chat' as const },
  { to: '/contacts', labelKey: 'sidebar.contacts', icon: 'user' as const },
  { to: '/profile', labelKey: 'sidebar.profile', icon: 'user' as const },
  { to: '/settings', labelKey: 'sidebar.settings', icon: 'settings' as const },
]

export function Sidebar() {
  const { t } = useLanguage()

  return (
    <aside className='sidebar'>
      <div className='brand'>
        <span className='brand-logo'>V</span>
        <div>
          <p className='brand-title'>{t('common.appName')}</p>
          <p className='brand-sub'>{t('sidebar.brandSub')}</p>
        </div>
      </div>
      <nav className='sidebar-nav'>
        {menuItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              isActive ? 'sidebar-link sidebar-link-active' : 'sidebar-link'
            }
          >
            <span aria-hidden className='sidebar-link-icon'>
              <Icon name={item.icon} />
            </span>
            <span>{t(item.labelKey)}</span>
          </NavLink>
        ))}
      </nav>
      <div className='sidebar-footer'>
        <p className='sidebar-footer-label'>{t('sidebar.workspace')}</p>
        <p>{t('sidebar.team')}</p>
      </div>
    </aside>
  )
}
