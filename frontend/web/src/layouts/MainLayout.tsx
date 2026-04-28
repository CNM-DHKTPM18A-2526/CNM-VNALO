import { useMemo, useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'

import { Sidebar } from '../shared/components/Sidebar'
import { Topbar } from '../shared/components/Topbar'
import { SettingsModal } from '../features/settings/SettingsModal'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'

export function MainLayout() {
  const location = useLocation()
  const { user, logout } = useAuth()
  const { t } = useLanguage()
  const isChatWorkspace = location.pathname === '/' || location.pathname.startsWith('/chat')
  const isContactsPage = location.pathname.startsWith('/contacts')
  const isDocumentsPage = location.pathname.startsWith('/documents')
  const shouldShowTopbar = !isChatWorkspace && !isContactsPage && !isDocumentsPage
  const [isSettingsModalOpen, setIsSettingsModalOpen] = useState(false)

  const title = useMemo(() => {
    const titleMap: Record<string, string> = {
      '/chat': t('pages.chat.title'),
      '/contacts': t('pages.contacts.title'),
      '/profile': t('pages.profile.title'),
    }

    if (location.pathname === '/') {
      return t('pages.chat.title')
    }

    if (location.pathname.startsWith('/chat')) {
      return t('pages.chat.title')
    }

    return titleMap[location.pathname] ?? t('common.appName')
  }, [location.pathname, t])

  const handleOpenSettings = () => {
    setIsSettingsModalOpen(true)
  }

  const handleCloseSettings = () => {
    setIsSettingsModalOpen(false)
  }

  const handleChangePasswordSuccess = () => {
    setIsSettingsModalOpen(false)
    logout()
  }

  return (
    <div className='app-shell'>
      <Sidebar onOpenSettingsModal={handleOpenSettings} />
      <section className='workspace'>
        {shouldShowTopbar ? (
          <Topbar
            title={title}
            userAvatarUrl={user?.avatarUrl}
            userName={user?.name ?? user?.email ?? 'VNALO User'}
            onLogout={logout}
            onOpenSettingsModal={handleOpenSettings}
          />
        ) : null}
        <main className={
          isChatWorkspace 
            ? 'workspace-main workspace-main-chat page-enter' 
            : isContactsPage 
              ? 'workspace-main workspace-main-contacts page-enter'
              : isDocumentsPage
                ? 'workspace-main workspace-main-documents page-enter'
                : 'workspace-main page-enter'
        }>
          <Outlet />
        </main>
      </section>

      <SettingsModal isOpen={isSettingsModalOpen} onClose={handleCloseSettings} onChangePasswordSuccess={handleChangePasswordSuccess} />
    </div>
  )
}
