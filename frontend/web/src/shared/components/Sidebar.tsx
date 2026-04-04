import { NavLink } from 'react-router-dom'

import { Icon } from './Icon'

const menuItems = [
  { to: '/chat', label: 'Chat', icon: 'chat' as const },
  { to: '/notifications', label: 'Thông báo', icon: 'bell' as const },
  { to: '/profile', label: 'Hồ sơ', icon: 'user' as const },
  { to: '/settings', label: 'Cài đặt', icon: 'settings' as const },
]

export function Sidebar() {
  return (
    <aside className='sidebar'>
      <div className='brand'>
        <span className='brand-logo'>V</span>
        <div>
          <p className='brand-title'>VNALO</p>
          <p className='brand-sub'>Web chat</p>
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
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
      <div className='sidebar-footer'>
        <p className='sidebar-footer-label'>Không gian làm việc</p>
        <p>Đội VNALO</p>
      </div>
    </aside>
  )
}
