import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { QRCodeCanvas } from 'qrcode.react'

import { createQrLoginSession, pollQrLoginSession } from '../features/auth/auth.api'
import { useAuth } from '../features/auth/useAuth'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { useTheme } from '../shared/contexts/ThemeContext'

const POLL_INTERVAL_MS = 2000
const WEB_LOGIN_QR_REQUIRED = import.meta.env.VITE_WEB_LOGIN_QR_REQUIRED === 'true'
type LoginMode = 'qr' | 'password'

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login, loginWithAccessToken } = useAuth()
  const { setLanguage, language, t } = useLanguage()
  const { theme, toggleTheme } = useTheme()

  const defaultLoginMode: LoginMode = WEB_LOGIN_QR_REQUIRED ? 'qr' : 'password'
  const [loginMode, setLoginMode] = React.useState<LoginMode>(defaultLoginMode)
  const [showMenu, setShowMenu] = React.useState(false)
  const [identifier, setIdentifier] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [isSubmitting, setIsSubmitting] = React.useState(false)
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)
  const [qrToken, setQrToken] = React.useState<string | null>(null)
  const [qrPayload, setQrPayload] = React.useState<string | null>(null)
  const [qrLoading, setQrLoading] = React.useState(false)
  const [qrExpired, setQrExpired] = React.useState(false)

  const fromPath =
    typeof (location.state as { from?: unknown } | null)?.from === 'string'
      ? ((location.state as { from: string }).from ?? '/chat')
      : '/chat'

  const alternateLoginMode: LoginMode = loginMode === 'qr' ? 'password' : 'qr'
  const loginTitle = loginMode === 'qr' ? t('auth.qrLogin') : t('auth.loginEyebrow')
  const alternateLoginTitle = alternateLoginMode === 'qr' ? t('auth.qrLogin') : t('auth.loginEyebrow')

  const initializeQr = React.useCallback(async () => {
    setQrLoading(true)
    setQrExpired(false)
    setErrorMessage(null)
    try {
      const session = await createQrLoginSession()
      setQrToken(session.token)
      setQrPayload(session.qrPayload)
    } catch {
      setErrorMessage(language === 'vi' ? 'Không thể khởi tạo QR.' : 'Could not create QR login session.')
    } finally {
      setQrLoading(false)
    }
  }, [language])

  React.useEffect(() => {
    if (loginMode === 'qr') {
      void initializeQr()
    }
  }, [initializeQr, loginMode])

  React.useEffect(() => {
    if (loginMode !== 'qr' || !qrToken || qrExpired) return undefined

    let disposed = false
    const timer = window.setInterval(async () => {
      try {
        const result = await pollQrLoginSession(qrToken)
        if (disposed) return

        if (result.accessToken) {
          await loginWithAccessToken(result.accessToken)
          navigate(fromPath, { replace: true })
          return
        }

        if (result.status === 'EXPIRED' || result.status === 'REJECTED') {
          setQrExpired(true)
          window.clearInterval(timer)
        }
      } catch {
        // Keep polling on transient network errors.
      }
    }, POLL_INTERVAL_MS)

    return () => {
      disposed = true
      window.clearInterval(timer)
    }
  }, [fromPath, loginMode, loginWithAccessToken, navigate, qrExpired, qrToken])

  const handlePasswordLogin = async (event: React.FormEvent) => {
    event.preventDefault()
    setErrorMessage(null)
    setIsSubmitting(true)
    try {
      await login({ identifier, password })
      navigate(fromPath, { replace: true })
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : (language === 'vi' ? 'Lỗi đăng nhập' : 'Login failed'))
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleSwitchMode = () => {
    setLoginMode(alternateLoginMode)
    setShowMenu(false)
    setErrorMessage(null)
  }

  return (
    <div className='auth-page'>
      <div className='auth-shell'>
        <div style={{ position: 'absolute', top: -45, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 15 }}>
          <button
            onClick={toggleTheme}
            className='auth-lang-btn'
            style={{ background: 'var(--auth-card-bg)', border: '1px solid var(--auth-border)', padding: '6px 12px', borderRadius: 20, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', color: 'var(--auth-text-main)' }}
            type='button'
          >
            {theme === 'light' ? (
              <>
                <svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2'><path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'></path></svg>
                <span>{language === 'vi' ? 'Tối' : 'Dark'}</span>
              </>
            ) : (
              <>
                <svg width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2'><circle cx='12' cy='12' r='5'></circle><line x1='12' y1='1' x2='12' y2='3'></line><line x1='12' y1='21' x2='12' y2='23'></line><line x1='4.22' y1='4.22' x2='5.64' y2='5.64'></line><line x1='18.36' y1='18.36' x2='19.78' y2='19.78'></line><line x1='1' y1='12' x2='3' y2='12'></line><line x1='21' y1='12' x2='23' y2='12'></line><line x1='4.22' y1='19.78' x2='5.64' y2='18.36'></line><line x1='18.36' y1='5.64' x2='19.78' y2='4.22'></line></svg>
                <span>{language === 'vi' ? 'Sáng' : 'Light'}</span>
              </>
            )}
          </button>
        </div>

        <header className='auth-branding'>
          <span className='auth-brand-badge'>VNALO</span>
          <h1 className='auth-brand-title'>{t('auth.loginHeroTitle')}</h1>
          <p className='auth-brand-subtitle'>{t('auth.loginHeroCopy')}</p>
        </header>

        <div className='auth-card'>
          <div className='auth-card-header' style={{ position: 'relative' }}>
            <span>{loginTitle}</span>
            <button className='auth-menu-btn' onClick={() => setShowMenu((value) => !value)} type='button' aria-label={alternateLoginTitle}>
              <svg width='20' height='20' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2' strokeLinecap='round' strokeLinejoin='round'>
                <line x1='3' y1='12' x2='21' y2='12'></line>
                <line x1='3' y1='6' x2='21' y2='6'></line>
                <line x1='3' y1='18' x2='21' y2='18'></line>
              </svg>
            </button>
            {showMenu && (
              <div className='auth-dropdown'>
                <button className='auth-dropdown-item' onClick={handleSwitchMode} type='button'>
                  {alternateLoginTitle}
                </button>
              </div>
            )}
          </div>

          <div className='auth-content'>
            {loginMode === 'qr' ? (
              <div className='auth-qr-container'>
                <div className='auth-qr-canvas-wrapper' style={{ position: 'relative', background: '#fff', padding: '15px', borderRadius: '8px', display: 'inline-block', boxShadow: '0 2px 10px rgba(0,0,0,0.1)' }}>
                  {qrLoading ? (
                    <div style={{ width: 220, height: 220, display: 'grid', placeItems: 'center', color: '#666' }}>{t('common.loading')}</div>
                  ) : qrPayload ? (
                    <>
                      <QRCodeCanvas value={qrPayload} size={220} level='H' bgColor='#ffffff' fgColor='#000000' />
                      {qrExpired && (
                        <div className='auth-qr-expired-overlay' style={{ borderRadius: '8px' }}>
                          <p style={{ fontSize: 13, marginBottom: 12, fontWeight: 500, color: '#333' }}>{language === 'vi' ? 'Mã QR hết hạn' : 'QR code expired'}</p>
                          <button className='auth-refresh-btn' onClick={initializeQr} type='button'>{language === 'vi' ? 'Lấy mã mới' : 'Get new code'}</button>
                        </div>
                      )}
                    </>
                  ) : (
                    <div style={{ color: 'red' }}>{language === 'vi' ? 'Lỗi tạo mã' : 'Could not create code'}</div>
                  )}
                </div>
                {errorMessage && <p style={{ color: 'red', fontSize: 13, textAlign: 'center' }}>{errorMessage}</p>}
                <p style={{ color: '#0068ff', fontSize: 15, marginTop: 15, fontWeight: 500 }}>{language === 'vi' ? 'Chỉ dùng để đăng nhập' : 'Only used for sign-in'}</p>
                <p style={{ fontSize: 14, color: 'var(--auth-text-main)' }}>VNALO {language === 'vi' ? 'trên máy tính' : 'on Desktop'}</p>
              </div>
            ) : (
              <form className='auth-form' onSubmit={handlePasswordLogin}>
                <input
                  required
                  type='text'
                  placeholder={t('auth.identifierPlaceholder')}
                  value={identifier}
                  onChange={(event) => setIdentifier(event.target.value)}
                />
                <input
                  required
                  type='password'
                  placeholder={t('auth.passwordPlaceholder')}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
                {errorMessage && <p style={{ color: 'red', fontSize: 13, textAlign: 'center' }}>{errorMessage}</p>}
                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.processing') : t('auth.loginButton')}
                </button>
                <div style={{ textAlign: 'center' }}>
                  <Link to='/forgot-password' style={{ color: '#0068ff', fontSize: 14, textDecoration: 'none' }}>{t('auth.forgotPassword')}?</Link>
                </div>
              </form>
            )}
          </div>
        </div>

        <div style={{ textAlign: 'center', marginTop: 20 }}>
          <p style={{ fontSize: 14 }}>{t('auth.dontHaveAccount')} <Link to='/register' style={{ color: '#0068ff', textDecoration: 'none', fontWeight: 600 }}>{t('auth.createAccountLink')}!</Link></p>
          <p className='auth-legal-consent'>
            <Link to='/legal/terms'>{t('auth.termsLinkLabel')}</Link>{' '}·{' '}
            <Link to='/legal/privacy'>{t('auth.privacyLinkLabel')}</Link>
          </p>
        </div>

        <div className='auth-lang-selector'>
          <button className={`auth-lang-btn ${language === 'vi' ? 'active' : ''}`} onClick={() => setLanguage('vi')} type='button'>
            Tiếng Việt
          </button>
          <button className={`auth-lang-btn ${language === 'en' ? 'active' : ''}`} onClick={() => setLanguage('en')} type='button'>
            English
          </button>
        </div>
      </div>
    </div>
  )
}