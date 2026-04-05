import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useLocation, useNavigate } from 'react-router-dom'

import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login } = useAuth()
  const { t } = useLanguage()

  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const fromPath =
    typeof (location.state as { from?: unknown } | null)?.from === 'string'
      ? ((location.state as { from: string }).from ?? '/chat')
      : '/chat'

  return (
    <div className='auth-page'>
      <div className='auth-card'>
        <section className='auth-visual'>
          <p className='auth-brand'>{t('common.appName')}</p>
          <h1>{t('auth.loginHeroTitle')}</h1>
          <p className='auth-copy'>{t('auth.loginHeroCopy')}</p>

          <div className='auth-points'>
            <div>
              <span className='auth-point-kicker'>01</span>
              <p>{t('auth.loginPoint1')}</p>
            </div>
            <div>
              <span className='auth-point-kicker'>02</span>
              <p>{t('auth.loginPoint2')}</p>
            </div>
            <div>
              <span className='auth-point-kicker'>03</span>
              <p>{t('auth.loginPoint3')}</p>
            </div>
          </div>
        </section>

        <section className='auth-content'>
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
              <input
                required
                type='password'
                placeholder={t('auth.passwordPlaceholder')}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete='current-password'
              />
            </label>
            {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
            <button type='submit' disabled={isSubmitting}>
              {isSubmitting ? t('auth.processing') : t('auth.loginButton')}
            </button>

            <p className='auth-switch-copy'>
              {t('auth.dontHaveAccount')} <Link to='/register'>{t('auth.createAccountLink')}</Link>
            </p>
          </form>
        </section>
      </div>
    </div>
  )
}
