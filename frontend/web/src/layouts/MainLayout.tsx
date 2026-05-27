import { useMemo, useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'

import { Sidebar } from '../shared/components/Sidebar'
import { Topbar } from '../shared/components/Topbar'
import { SettingsModal } from '../features/settings/SettingsModal'
import { ScreenCaptureModal } from '../features/chat/components/ScreenCaptureModal'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'

export function MainLayout() {
  const location = useLocation()
  const { user, logout } = useAuth()
  const { t } = useLanguage()
  const isChatWorkspace =
    location.pathname === '/' ||
    location.pathname.startsWith('/chat') ||
    location.pathname.startsWith('/chat-ai')
  const isContactsPage = location.pathname.startsWith('/contacts')
  const isSocialPage = location.pathname.startsWith('/social')
  const shouldShowTopbar = !isChatWorkspace && !isContactsPage && !isSocialPage
  const [isSettingsModalOpen, setIsSettingsModalOpen] = useState(false)
  const [isCaptureModalOpen, setIsCaptureModalOpen] = useState(false)

  const title = useMemo(() => {
    const titleMap: Record<string, string> = {
      '/chat': t('pages.chat.title'),
      '/chat-ai': 'AI Assistant',
      '/contacts': t('pages.contacts.title'),
      '/profile': t('pages.profile.title'),
    }

    if (location.pathname === '/') {
      return t('pages.chat.title')
    }

    if (location.pathname.startsWith('/chat-ai')) {
      return 'AI Assistant'
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

  const handleOpenCapture = () => {
    setIsCaptureModalOpen(true)
  }

  const handleSendCapture = (file: File) => {
    console.log('Capture file to send:', file)
    // Here we would ideally find the current chat and send the file
    // For now, we just show a placeholder log
  }

  return (
    <div className='app-shell'>
      <Sidebar onOpenSettingsModal={handleOpenSettings} onOpenCaptureModal={handleOpenCapture} />
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
              : isSocialPage
                ? 'workspace-main workspace-main-social page-enter'
                : 'workspace-main page-enter'
        }>
          <Outlet />
        </main>
      </section>

      <SettingsModal isOpen={isSettingsModalOpen} onClose={handleCloseSettings} onChangePasswordSuccess={handleChangePasswordSuccess} />
      <ScreenCaptureModal isOpen={isCaptureModalOpen} onClose={() => setIsCaptureModalOpen(false)} onSend={handleSendCapture} />
    </div>
  )
}

