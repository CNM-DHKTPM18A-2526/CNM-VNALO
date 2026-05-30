import React, { type KeyboardEvent } from 'react'

import { useLanguage } from '../i18n/LanguageContext'
import { Icon } from './Icon'
import { UserAvatar } from './UserAvatar'

type TopbarProps = {
  title: string
  userName: string
  userAvatarUrl?: string | null
  onLogout: () => void
  onOpenSettingsModal?: () => void
  onOpenAccountModal?: () => void
}

export function Topbar({ title, userName, userAvatarUrl, onLogout, onOpenSettingsModal, onOpenAccountModal }: TopbarProps) {
  const [isMenuOpen, setIsMenuOpen] = React.useState(false)
  const menuRef = React.useRef<HTMLDivElement | null>(null)
  const menuItemRefs = React.useRef<Array<HTMLButtonElement | null>>([])
  const { t } = useLanguage()

  const menuItems = [
    {
      key: 'profile',
      label: t('topbar.menuProfile'),
      icon: 'user' as const,
      onSelect: () => onOpenAccountModal?.(),
    },
    {
      key: 'settings',
      label: t('topbar.menuSettings'),
      icon: 'settings' as const,
      onSelect: () => onOpenSettingsModal?.(),
    },
    {
      key: 'logout',
      label: t('topbar.menuLogout'),
      icon: 'logout' as const,
      danger: true,
      onSelect: onLogout,
    },
  ]

  const focusMenuItem = (index: number) => {
    const clamped = (index + menuItems.length) % menuItems.length
    menuItemRefs.current[clamped]?.focus()
  }

  React.useEffect(() => {
    const handleOutsideClick = (event: PointerEvent) => {
      if (!menuRef.current) {
        return
      }

      if (!menuRef.current.contains(event.target as Node)) {
        setIsMenuOpen(false)
      }
    }

    window.addEventListener('pointerdown', handleOutsideClick)
    return () => {
      window.removeEventListener('pointerdown', handleOutsideClick)
    }
  }, [])

  React.useEffect(() => {
    if (!isMenuOpen) {
      return
    }

    const timeoutId = window.setTimeout(() => {
      menuItemRefs.current[0]?.focus()
    }, 0)

    return () => {
      window.clearTimeout(timeoutId)
    }
  }, [isMenuOpen])

  const handleMenuAction = (action: () => void) => {
    setIsMenuOpen(false)
    action()
  }

  const handleTriggerKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (event.key === 'ArrowDown' || event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      setIsMenuOpen(true)
      return
    }

    if (event.key === 'Escape') {
      setIsMenuOpen(false)
    }
  }

  const handleMenuKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const activeIndex = menuItemRefs.current.findIndex((item) => item === document.activeElement)

    if (event.key === 'Escape') {
      event.preventDefault()
      setIsMenuOpen(false)
      return
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault()
      focusMenuItem(activeIndex + 1)
      return
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault()
      focusMenuItem(activeIndex - 1)
      return
    }

    if (event.key === 'Home') {
      event.preventDefault()
      focusMenuItem(0)
      return
    }

    if (event.key === 'End') {
      event.preventDefault()
      focusMenuItem(menuItems.length - 1)
    }
  }

  return (
    <header className='topbar'>
      <div className='topbar-heading'>
        <h1>{title}</h1>
        <p>{t('topbar.subtitle')}</p>
      </div>
      <div className='topbar-actions'>
        <div className='avatar-menu' ref={menuRef}>
          <button
            aria-expanded={isMenuOpen}
            aria-haspopup='menu'
            className='avatar-menu-btn'
            onClick={() => setIsMenuOpen((prev) => !prev)}
            onKeyDown={handleTriggerKeyDown}
            type='button'
          >
            <UserAvatar imageUrl={userAvatarUrl} name={userName} size='md' />
            <span className='avatar-menu-name'>{userName}</span>
            <span aria-hidden className='avatar-menu-caret'>
              <Icon name='chevronDown' />
            </span>
          </button>

          {isMenuOpen ? (
            <div className='topbar-menu' onKeyDown={handleMenuKeyDown} role='menu'>
              {menuItems.map((item, index) => (
                <button
                  key={item.key}
                  className={item.danger ? 'topbar-menu-item topbar-menu-item-danger' : 'topbar-menu-item'}
                  onClick={() => handleMenuAction(item.onSelect)}
                  ref={(node) => {
                    menuItemRefs.current[index] = node
                  }}
                  role='menuitem'
                  tabIndex={0}
                  type='button'
                >
                  <Icon name={item.icon} />
                  <span>{item.label}</span>
                </button>
              ))}
            </div>
          ) : null}
        </div>
      </div>
    </header>
  )
}
