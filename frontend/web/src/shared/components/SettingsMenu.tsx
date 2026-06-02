import React from 'react'
import { useNavigate } from 'react-router-dom'

import { canAccessAdminMonitoring } from '../../features/auth/adminAccess'
import { useAuth } from '../../features/auth/useAuth'
import { useLanguage } from '../i18n/LanguageContext'
import { Icon } from './Icon'

type SettingsMenuProps = {
  onOpenSettings: () => void
}

export function SettingsMenu({ onOpenSettings }: SettingsMenuProps) {
  const { t } = useLanguage()
  const { accessToken, logout, user } = useAuth()
  const navigate = useNavigate()
  const canOpenDashboard = canAccessAdminMonitoring(user, accessToken)
  const [isMenuOpen, setIsMenuOpen] = React.useState(false)
  const menuRef = React.useRef<HTMLDivElement>(null)
  const buttonRef = React.useRef<HTMLButtonElement>(null)

  const handleClickOutside = React.useCallback((event: MouseEvent) => {
    if (
      menuRef.current &&
      !menuRef.current.contains(event.target as Node) &&
      buttonRef.current &&
      !buttonRef.current.contains(event.target as Node)
    ) {
      setIsMenuOpen(false)
    }
  }, [])

  React.useEffect(() => {
    if (!isMenuOpen) return

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [isMenuOpen, handleClickOutside])

  React.useEffect(() => {
    if (!isMenuOpen) return

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setIsMenuOpen(false)
    }

    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [isMenuOpen])

  const handleMenuItemClick = (action: () => void) => {
    setIsMenuOpen(false)
    action()
  }

  const handleOpenDashboard = () => {
    navigate('/admin/monitoring')
  }

  const handleLogout = () => {
    logout()
  }

  const handleButtonClick = () => {
    setIsMenuOpen((prev) => !prev)
  }

  return (
    <div className='settings-menu-wrapper'>
      <button
        ref={buttonRef}
        className='settings-menu-button'
        onClick={handleButtonClick}
        title={t('settingsMenu.title')}
        aria-expanded={isMenuOpen}
        aria-haspopup='menu'
      >
        <span aria-hidden className='settings-menu-button-icon'>
          <Icon name='settings' />
        </span>
      </button>

      {isMenuOpen ? (
        <div ref={menuRef} className='settings-menu-popover' role='menu'>
          <div className='settings-menu-items'>
            {canOpenDashboard ? (
              <>
                <button
                  className='settings-menu-item'
                  role='menuitem'
                  onClick={() => handleMenuItemClick(handleOpenDashboard)}
                >
                  <span className='settings-menu-item-icon' aria-hidden='true'>
                    <Icon name='layoutDashboard' />
                  </span>
                  <span className='settings-menu-item-label'>Dashboard</span>
                </button>

                <div className='settings-menu-divider' />
              </>
            ) : null}

            <button
              className='settings-menu-item'
              role='menuitem'
              onClick={() => handleMenuItemClick(onOpenSettings)}
            >
              <span className='settings-menu-item-icon' aria-hidden='true'>
                <Icon name='settings' />
              </span>
              <span className='settings-menu-item-label'>{t('settingsMenu.settings')}</span>
            </button>

            <div className='settings-menu-divider' />

            <button
              className='settings-menu-item settings-menu-item-logout'
              role='menuitem'
              onClick={() => handleMenuItemClick(handleLogout)}
            >
              <span className='settings-menu-item-icon' aria-hidden='true'>
                <Icon name='logout' />
              </span>
              <span className='settings-menu-item-label'>{t('settingsMenu.logout')}</span>
            </button>
          </div>
        </div>
      ) : null}
    </div>
  )
}
