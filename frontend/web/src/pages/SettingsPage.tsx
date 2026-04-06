import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { changePassword } from '../features/auth/auth.api'
import { useAuth } from '../features/auth/useAuth'
import { validatePassword } from '../features/auth/password.util'
import { Icon } from '../shared/components/Icon'
import { Card } from '../shared/components/ui/Card'
import { SegmentedControl, ToggleSwitch } from '../shared/components/SettingsControls'
import { useTheme } from '../shared/contexts/ThemeContext'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { useNotifications } from '../shared/contexts/NotificationsContext'
import type { Language } from '../shared/i18n/translations'

function PasswordToggleIcon({ visible }: { visible: boolean }) {
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

export function SettingsPage() {
  const navigate = useNavigate()
  const { accessToken, logout } = useAuth()
  const { theme, toggleTheme } = useTheme()
  const { language, setLanguage, t } = useLanguage()
  const { notificationsEnabled, toggleNotifications } = useNotifications()
  const [showChangePasswordModal, setShowChangePasswordModal] = useState(false)
  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showCurrentPassword, setShowCurrentPassword] = useState(false)
  const [showNewPassword, setShowNewPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

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

      setTimeout(() => {
        logout()
        navigate('/login', { replace: true })
      }, 900)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('settings.securityChangeFailed'))
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <section className='panel-page'>
      <h2>{t('pages.settings.title')}</h2>
      <p className='panel-subtitle'>{t('pages.settings.subtitle')}</p>
      <div className='settings-grid'>
        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='bell' />
                </span>
                {t('settings.notifications')}
              </h3>
              <p>{t('settings.notificationsDesc')}</p>
            </div>
            <ToggleSwitch enabled={notificationsEnabled} onChange={toggleNotifications} />
          </div>
        </Card>

        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='spark' />
                </span>
                {t('settings.theme')}
              </h3>
              <p>{t('settings.themeDesc')}</p>
            </div>
          </div>
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
        </Card>

        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='settings' />
                </span>
                {t('settings.language')}
              </h3>
              <p>{t('settings.languageDesc')}</p>
            </div>
          </div>
          <SegmentedControl
            options={[
              { label: 'Tiếng Việt', value: 'vi' },
              { label: 'English', value: 'en' },
            ]}
            value={language}
            onChange={(lang: string) => setLanguage(lang as Language)}
          />
        </Card>

        <Card as='article' className='settings-card settings-card-interactive settings-card-security'>
          <div className='settings-security-head'>
            <div className='settings-security-copy'>
              <div className='settings-security-title-row'>
                <h3>
                  <span className='settings-icon'>
                    <Icon name='settings' />
                  </span>
                  {t('settings.security')}
                </h3>
                <button className='btn btn-primary settings-security-action' type='button' onClick={() => setShowChangePasswordModal(true)}>
                  <span className='settings-security-action-icon' aria-hidden='true'>
                    <Icon name='settings' />
                  </span>
                  {t('settings.securityChangeButton')}
                </button>
              </div>
              <p>{t('settings.securityDesc')}</p>
            </div>
          </div>
        </Card>
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
    </section>
  )
}
