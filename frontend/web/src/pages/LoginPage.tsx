import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useLocation, useNavigate } from 'react-router-dom'

import { useAuth } from '../features/auth/useAuth'
import { AuthPageControls } from '../shared/components/AuthPageControls'
import { useLanguage } from '../shared/i18n/LanguageContext'

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

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login } = useAuth()
  const { t } = useLanguage()

  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const fromPath =
    typeof (location.state as { from?: unknown } | null)?.from === 'string'
      ? ((location.state as { from: string }).from ?? '/chat')
      : '/chat'

  return (
    <div className='auth-page'>
      <AuthPageControls />
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>{t('common.appName')}</span>
          <h1 className='auth-brand-title'>{t('auth.loginHeroTitle')}</h1>
          <p className='auth-brand-subtitle'>{t('auth.loginHeroCopy')}</p>
        </header>

        <div className='auth-card'>
          <section className='auth-content auth-content-login'>
            <div className='auth-copy-block'>
              <p className='auth-eyebrow'>{t('auth.loginEyebrow')}</p>
              <h2>{t('auth.loginWelcome')}</h2>
              <p>{t('auth.loginSubtitle')}</p>
            </div>

            <form
              className='auth-form'
              onSubmit={async (event) => {
                event.preventDefault()

                setErrorMessage(null)
                setIsSubmitting(true)

                try {
                  await login({ identifier, password })
                  navigate(fromPath, { replace: true })
                } catch {
                  setErrorMessage(t('auth.loginError'))
                } finally {
                  setIsSubmitting(false)
                }
              }}
            >
              <label>
                {t('auth.identifierLabel')}
                <input
                  required
                  type='text'
                  placeholder={t('auth.identifierPlaceholder')}
                  value={identifier}
                  onChange={(event) => setIdentifier(event.target.value)}
                  autoComplete='username'
                />
              </label>
              <label>
                {t('auth.passwordLabel')}
                <div className='auth-password-wrap'>
                  <input
                    required
                    type={showPassword ? 'text' : 'password'}
                    placeholder={t('auth.passwordPlaceholder')}
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    autoComplete='current-password'
                  />
                  <button
                    type='button'
                    className='auth-password-toggle'
                    onClick={() => setShowPassword((prev) => !prev)}
                    aria-label={showPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    title={showPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                  >
                    <PasswordToggleIcon visible={showPassword} />
                  </button>
                </div>
              </label>

              {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}

              <button type='submit' disabled={isSubmitting}>
                {isSubmitting ? t('auth.processing') : t('auth.loginButton')}
              </button>

              <div className='auth-inline-actions'>
                <button type='button' className='auth-text-action'>
                  {t('auth.forgotPassword')}
                </button>
                <button type='button' className='auth-text-action'>
                  {t('auth.qrLogin')}
                </button>
              </div>

              <p className='auth-switch-copy'>
                {t('auth.dontHaveAccount')} <Link to='/register'>{t('auth.createAccountLink')}</Link>
              </p>
            </form>
          </section>
        </div>
      </div>
    </div>
  )
}
