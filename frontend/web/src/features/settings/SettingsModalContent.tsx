import React, { type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'

import { changePassword } from '../auth/auth.api'
import { useAuth } from '../auth/useAuth'
import { validatePassword } from '../auth/password.util'
import { Icon } from '../../shared/components/Icon'
import { SegmentedControl, ToggleSwitch } from '../../shared/components/SettingsControls'
import { useTheme } from '../../shared/contexts/ThemeContext'
import { useLanguage } from '../../shared/i18n/LanguageContext'
import { useNotifications } from '../../shared/contexts/NotificationsContext'
import type { Language } from '../../shared/i18n/translations'

export function PasswordToggleIcon({ visible }: { visible: boolean }) {
  if (visible) {
    return (
      <svg viewBox='0 0 24 24' aria-hidden='true'>
        <path
          d='M3 3l18 18M10.6 10.6a2 2 0 102.8 2.8M9.9 4.2A10.7 10.7 0 0112 4c5.5 0 9.8 4.1 10.9 7.8a1 1 0 010 .4 12 12 0 01-3.6 5.1M6.7 6.7A12.3 12.3 0 001.1 12a1 1 0 000 .4C2.2 16.1 6.5 20.2 12 20.2c1.7 0 3.2-.4 4.6-1.1'
          fill='none'
          stroke='currentColor'
          strokeWidth='1.8'
          strokeLinecap='round'
          strokeLinejoin='round'
        />
      </svg>
    )
  }

  return (
    <svg viewBox='0 0 24 24' aria-hidden='true'>
      <path
        d='M1.1 12.2a1 1 0 010-.4C2.2 8.1 6.5 4 12 4s9.8 4.1 10.9 7.8a1 1 0 010 .4C21.8 15.9 17.5 20 12 20S2.2 15.9 1.1 12.2z'
        fill='none'
        stroke='currentColor'
        strokeWidth='1.8'
      />
      <circle cx='12' cy='12' r='3' fill='none' stroke='currentColor' strokeWidth='1.8' />
    </svg>
  )
}

type SettingsModalContentProps = {
  onChangePasswordSuccess?: () => void
  showChangePasswordButton?: boolean
}

type ActiveTab = 'general' | 'appearance' | 'language' | 'security'

type SettingsRowProps = {
  title: string
  description: string
  action: ReactNode
  className?: string
}

function SettingsRow({ title, description, action, className = '' }: SettingsRowProps) {
  return (
    <div className={`settings-window-row ${className}`.trim()}>
      <div className='settings-window-row-copy'>
        <h5>{title}</h5>
        <p>{description}</p>
      </div>
      <div className='settings-window-row-control'>{action}</div>
    </div>
  )
}

export function SettingsModalContent({
  onChangePasswordSuccess,
  showChangePasswordButton = true,
}: SettingsModalContentProps) {
  const { accessToken, logout } = useAuth()
  const navigate = useNavigate()
  const { theme, toggleTheme } = useTheme()
  const { language, setLanguage, t } = useLanguage()
  const { notificationsEnabled, toggleNotifications } = useNotifications()
  const [activeTab, setActiveTab] = React.useState<ActiveTab>('general')
  const [showChangePasswordModal, setShowChangePasswordModal] = React.useState(false)
  const [currentPassword, setCurrentPassword] = React.useState('')
  const [newPassword, setNewPassword] = React.useState('')
  const [confirmPassword, setConfirmPassword] = React.useState('')
  const [showCurrentPassword, setShowCurrentPassword] = React.useState(false)
  const [showNewPassword, setShowNewPassword] = React.useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = React.useState(false)
  const [isSubmitting, setIsSubmitting] = React.useState(false)
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)
  const [successMessage, setSuccessMessage] = React.useState<string | null>(null)

  const openAdminDashboard = () => {
    navigate('/admin/monitoring')
  }

  const closeChangePasswordModal = () => {
    if (isSubmitting) {
      return
    }

    setShowChangePasswordModal(false)
    setCurrentPassword('')
    setNewPassword('')
    setConfirmPassword('')
    setShowCurrentPassword(false)
    setShowNewPassword(false)
    setShowConfirmPassword(false)
    setErrorMessage(null)
    setSuccessMessage(null)
  }

  const submitChangePassword = async () => {
    if (!accessToken) {
      setErrorMessage(t('settings.securitySessionExpired'))
      return
    }

    setErrorMessage(null)
    setSuccessMessage(null)

    if (!currentPassword) {
      setErrorMessage(t('settings.securityCurrentPasswordRequired'))
      return
    }

    const passwordError = validatePassword(newPassword)
    if (passwordError) {
      setErrorMessage(passwordError)
      return
    }

    if (!confirmPassword) {
      setErrorMessage(t('settings.securityConfirmPasswordRequired'))
      return
    }

    if (confirmPassword !== newPassword) {
      setErrorMessage(t('settings.securityConfirmPasswordMismatch'))
      return
    }

    if (currentPassword === newPassword) {
      setErrorMessage(t('settings.securitySamePassword'))
      return
    }

    setIsSubmitting(true)

    try {
      await changePassword(accessToken, {
        currentPassword,
        newPassword,
      })

      setSuccessMessage(t('settings.securityPasswordChanged'))
      onChangePasswordSuccess?.()

      setTimeout(() => {
        logout()
      }, 900)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('settings.securityChangeFailed'))
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <>
      <div className='settings-window'>
        <aside className='settings-window-nav'>
          <button
            className={`settings-window-nav-item ${activeTab === 'general' ? 'settings-window-nav-item-active' : ''}`}
            type='button'
            onClick={() => setActiveTab('general')}
          >
            <span className='settings-window-nav-icon' aria-hidden='true'>
              <Icon name='settings' />
            </span>
            {t('settings.navGeneral')}
          </button>
          <button
            className={`settings-window-nav-item ${activeTab === 'appearance' ? 'settings-window-nav-item-active' : ''}`}
            type='button'
            onClick={() => setActiveTab('appearance')}
          >
            <span className='settings-window-nav-icon' aria-hidden='true'>
              <Icon name='spark' />
            </span>
            {t('settings.navAppearance')}
          </button>
          <button
            className={`settings-window-nav-item ${activeTab === 'language' ? 'settings-window-nav-item-active' : ''}`}
            type='button'
            onClick={() => setActiveTab('language')}
          >
            <span className='settings-window-nav-icon' aria-hidden='true'>
              <Icon name='settings' />
            </span>
            {t('settings.navLanguage')}
          </button>
          <button
            className={`settings-window-nav-item ${activeTab === 'security' ? 'settings-window-nav-item-active' : ''}`}
            type='button'
            onClick={() => setActiveTab('security')}
          >
            <span className='settings-window-nav-icon' aria-hidden='true'>
              <Icon name='user' />
            </span>
            {t('settings.navSecurity')}
          </button>
        </aside>

        <div className='settings-window-content'>
          {/* General Tab */}
          {activeTab === 'general' && (
            <section className='settings-window-section'>
              <div className='settings-window-section-head'>
                <h4>{t('settings.sectionGeneral')}</h4>
              </div>
              <SettingsRow
                title={t('settings.notifications')}
                description={t('settings.notificationsDesc')}
                action={<ToggleSwitch enabled={notificationsEnabled} onChange={toggleNotifications} />}
              />

              <SettingsRow
                title={t('settings.addressBook')}
                description={t('settings.addressBookDesc')}
                action={<span className='settings-window-pill'>{t('settings.comingSoon')}</span>}
              />

              <SettingsRow
                title={t('settings.startup')}
                description={t('settings.startupDesc')}
                action={<span className='settings-window-pill'>{t('settings.comingSoon')}</span>}
              />

              <SettingsRow
                title={t('settings.adminDashboard')}
                description={t('settings.adminDashboardDesc')}
                action={
                  <button className='settings-window-action-btn' type='button' onClick={openAdminDashboard}>
                    <span aria-hidden='true'>↗</span>
                    {t('settings.openDashboard')}
                  </button>
                }
              />
            </section>
          )}

          {/* Appearance Tab */}
          {activeTab === 'appearance' && (
            <section className='settings-window-section'>
              <div className='settings-window-section-head'>
                <h4>{t('settings.navAppearance')}</h4>
              </div>
              <SettingsRow
                title={t('settings.theme')}
                description={t('settings.themeDesc')}
                action={
                  <SegmentedControl
                    options={[
                      { label: t('settings.lightMode'), value: 'light' },
                      { label: t('settings.darkMode'), value: 'dark' },
                    ]}
                    value={theme}
                    onChange={(newTheme: string) => {
                      if (newTheme !== theme) {
                        toggleTheme()
                      }
                    }}
                  />
                }
              />
            </section>
          )}

          {/* Language Tab */}
          {activeTab === 'language' && (
            <section className='settings-window-section'>
              <div className='settings-window-section-head'>
                <h4>{t('settings.navLanguage')}</h4>
              </div>
              <SettingsRow
                title={t('settings.language')}
                description={t('settings.languageDesc')}
                action={
                  <SegmentedControl
                    options={[
                      { label: 'Tiếng Việt', value: 'vi' },
                      { label: 'English', value: 'en' },
                    ]}
                    value={language}
                    onChange={(lang: string) => setLanguage(lang as Language)}
                  />
                }
              />
            </section>
          )}

          {/* Security Tab */}
          {activeTab === 'security' && showChangePasswordButton && (
            <section className='settings-window-section'>
              <div className='settings-window-section-head'>
                <h4>{t('settings.navSecurity')}</h4>
              </div>
              <SettingsRow
                title={t('settings.security')}
                description={t('settings.securityDesc')}
                action={
                  <button
                    className='btn btn-primary settings-security-action'
                    type='button'
                    onClick={() => setShowChangePasswordModal(true)}
                  >
                    <span className='settings-security-action-icon' aria-hidden='true'>
                      <Icon name='settings' />
                    </span>
                    {t('settings.securityChangeButton')}
                  </button>
                }
              />
            </section>
          )}
        </div>
      </div>

      {showChangePasswordModal ? (
        <div className='modal-overlay' role='dialog' aria-modal='true' aria-labelledby='change-password-title'>
          <div className='modal-card'>
            <div className='modal-header'>
              <div>
                <h3 id='change-password-title'>{t('settings.securityModalTitle')}</h3>
                <p>{t('settings.securityModalSubtitle')}</p>
              </div>
              <button className='modal-close-btn' type='button' onClick={closeChangePasswordModal} aria-label={t('settings.securityClose')}>
                ×
              </button>
            </div>

            <div className='modal-body'>
              <label className='modal-field'>
                {t('settings.securityCurrentPassword')}
                <div className='settings-password-wrap'>
                  <input
                    type={showCurrentPassword ? 'text' : 'password'}
                    value={currentPassword}
                    onChange={(event) => setCurrentPassword(event.target.value)}
                    autoComplete='current-password'
                    disabled={isSubmitting}
                  />
                  <button
                    type='button'
                    className='settings-password-toggle'
                    onClick={() => setShowCurrentPassword((prev) => !prev)}
                    aria-label={showCurrentPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    title={showCurrentPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    disabled={isSubmitting}
                  >
                    <PasswordToggleIcon visible={showCurrentPassword} />
                  </button>
                </div>
              </label>

              <label className='modal-field'>
                {t('settings.securityNewPassword')}
                <div className='settings-password-wrap'>
                  <input
                    type={showNewPassword ? 'text' : 'password'}
                    value={newPassword}
                    onChange={(event) => setNewPassword(event.target.value)}
                    autoComplete='new-password'
                    disabled={isSubmitting}
                  />
                  <button
                    type='button'
                    className='settings-password-toggle'
                    onClick={() => setShowNewPassword((prev) => !prev)}
                    aria-label={showNewPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    title={showNewPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    disabled={isSubmitting}
                  >
                    <PasswordToggleIcon visible={showNewPassword} />
                  </button>
                </div>
              </label>

              <label className='modal-field'>
                {t('settings.securityConfirmPassword')}
                <div className='settings-password-wrap'>
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(event) => setConfirmPassword(event.target.value)}
                    autoComplete='new-password'
                    disabled={isSubmitting}
                  />
                  <button
                    type='button'
                    className='settings-password-toggle'
                    onClick={() => setShowConfirmPassword((prev) => !prev)}
                    aria-label={showConfirmPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    title={showConfirmPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    disabled={isSubmitting}
                  >
                    <PasswordToggleIcon visible={showConfirmPassword} />
                  </button>
                </div>
              </label>

              {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
              {successMessage ? <p className='auth-form-success'>{successMessage}</p> : null}
            </div>

            <div className='modal-footer'>
              <button className='btn btn-ghost' type='button' onClick={closeChangePasswordModal} disabled={isSubmitting}>
                {t('profile.cancel')}
              </button>
              <button className='btn btn-primary' type='button' onClick={() => void submitChangePassword()} disabled={isSubmitting}>
                {isSubmitting ? t('settings.securityChanging') : t('settings.securityChangeButton')}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  )
}
