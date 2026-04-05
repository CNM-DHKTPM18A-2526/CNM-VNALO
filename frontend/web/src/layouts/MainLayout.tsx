import { useMemo } from 'react'
import { Outlet, useLocation } from 'react-router-dom'

import { Sidebar } from '../shared/components/Sidebar'
import { Topbar } from '../shared/components/Topbar'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'

export function MainLayout() {
  const location = useLocation()
  const { user, logout } = useAuth()
  const { t } = useLanguage()

  const title = useMemo(() => {
    const titleMap: Record<string, string> = {
      '/chat': t('pages.chat.title'),
      '/contacts': t('pages.contacts.title'),
      '/profile': t('pages.profile.title'),
      '/settings': t('pages.settings.title'),
    }

    if (location.pathname === '/') {
      return t('pages.chat.title')
    }

    return titleMap[location.pathname] ?? t('common.appName')
  }, [location.pathname, t])

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
