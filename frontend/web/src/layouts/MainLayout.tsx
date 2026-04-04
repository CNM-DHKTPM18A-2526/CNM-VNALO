import { useMemo } from 'react'
import { Outlet, useLocation } from 'react-router-dom'

import { Sidebar } from '../shared/components/Sidebar'
import { Topbar } from '../shared/components/Topbar'
import { useAuth } from '../features/auth/useAuth'

const titleMap: Record<string, string> = {
  '/chat': 'Tin nhắn',
  '/notifications': 'Thông báo',
  '/profile': 'Hồ sơ',
  '/settings': 'Cài đặt',
}

export function MainLayout() {
  const location = useLocation()
  const { user, logout } = useAuth()

  const title = useMemo(() => {
    if (location.pathname === '/') {
      return 'Tin nhắn'
    }

    return titleMap[location.pathname] ?? 'VNALO'
  }, [location.pathname])

  return (
    <div className='app-shell'>
      <Sidebar />
      <section className='workspace'>
        <Topbar
          title={title}
          userName={user?.name ?? user?.email ?? 'VNALO User'}
          onLogout={logout}
        />
        <main className='workspace-main page-enter' key={location.pathname}>
          <Outlet />
        </main>
      </section>
    </div>
  )
}
