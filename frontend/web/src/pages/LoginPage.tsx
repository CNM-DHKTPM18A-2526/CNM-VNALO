import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { QRCodeCanvas } from 'qrcode.react'

import { useAuth } from '../features/auth/useAuth'
import { createQrLoginSession, pollQrLoginSession } from '../features/auth/auth.api'

import { useLanguage } from '../shared/i18n/LanguageContext'
import { useTheme } from '../shared/contexts/ThemeContext'

const POLL_INTERVAL_MS = 2000
const WEB_LOGIN_QR_REQUIRED = import.meta.env.VITE_WEB_LOGIN_QR_REQUIRED === 'true'

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login, loginWithAccessToken } = useAuth()
  const { setLanguage, language, t } = useLanguage()
  const { theme, toggleTheme } = useTheme()

  const [loginMode, setLoginMode] = React.useState<'qr' | 'password'>(WEB_LOGIN_QR_REQUIRED ? 'qr' : 'password')
  const [showMenu, setShowMenu] = React.useState(false)
  
  // Password login states
  const [identifier, setIdentifier] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [isSubmitting, setIsSubmitting] = React.useState(false)
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)

  // QR States
  const [qrToken, setQrToken] = React.useState<string | null>(null)
  const [qrPayload, setQrPayload] = React.useState<string | null>(null)
  const [qrLoading, setQrLoading] = React.useState(false)
  const [qrExpired, setQrExpired] = React.useState(false)

  const fromPath =
    typeof (location.state as { from?: unknown } | null)?.from === 'string'
      ? ((location.state as { from: string }).from ?? '/chat')
      : '/chat'

  // Initialize QR Session
  const initializeQr = async () => {
    setQrLoading(true)
    setQrExpired(false)
    setErrorMessage(null)
    try {
      const session = await createQrLoginSession()
      setQrToken(session.token)
      setQrPayload(session.qrPayload)
    } catch {
      setErrorMessage('Không thể khởi tạo QR.')
    } finally {
      setQrLoading(false)
    }
  }

  React.useEffect(() => {
    if (loginMode === 'qr') {
        void initializeQr()
    }
  }, [loginMode])

  // Poll QR Session
  React.useEffect(() => {
    if (loginMode !== 'qr' || !qrToken || qrExpired) return

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
        // Silently continue polling; transient network errors will be retried on next tick.
      }
    }, POLL_INTERVAL_MS)

    return () => {
      disposed = true
      window.clearInterval(timer)
    }
  }, [loginMode, qrToken, qrExpired, navigate, fromPath, loginWithAccessToken])

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    setIsSubmitting(true)
    try {
      await login({ identifier, password })
      navigate(fromPath, { replace: true })
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Lỗi đăng nhập')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className='auth-page'>
      <div className='auth-shell'>
        <div style={{ position: 'absolute', top: -45, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 15 }}>
            <button 
                onClick={toggleTheme} 
                className='auth-lang-btn'
                style={{ background: 'var(--auth-card-bg)', border: '1px solid var(--auth-border)', padding: '6px 12px', borderRadius: 20, display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', color: 'var(--auth-text-main)' }}
            >
                {theme === 'light' ? (
                    <>
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>
                        <span>Tối</span>
                    </>
                ) : (
                    <>
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>
                        <span>Sáng</span>
                    </>
                )}
            </button>
        </div>

        <header className='auth-branding'>
          <span className='auth-brand-badge'>Vnalo</span>
          <p className='auth-brand-subtitle'>
            {t('auth.loginHeroTitle')}<br/>{t('sidebar.brandSub')}
          </p>
        </header>

        <div className='auth-card'>
          <div className='auth-header-top'>
            <span className='auth-header-title'>
                {loginMode === 'qr' ? t('auth.qrLogin') : t('auth.loginEyebrow')}
            </span>
            <button className='auth-menu-btn' onClick={() => setShowMenu(!showMenu)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <line x1="3" y1="12" x2="21" y2="12"></line>
                    <line x1="3" y1="6" x2="21" y2="6"></line>
                    <line x1="3" y1="18" x2="21" y2="18"></line>
                </svg>
            </button>
            {showMenu && (
                <div className='auth-dropdown'>
                    <div className='auth-dropdown-item' onClick={() => {
                        setLoginMode(loginMode === 'qr' ? 'password' : 'qr');
                        setShowMenu(false);
                    }}>
                        {loginMode === 'qr' ? t('auth.loginEyebrow') : t('auth.qrLogin')}
                    </div>
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
                        <QRCodeCanvas value={qrPayload} size={220} level="H" bgColor="#ffffff" fgColor="#000000" />
                        {qrExpired && (
                            <div className='auth-qr-expired-overlay' style={{ borderRadius: '8px' }}>
                                <p style={{ fontSize: 13, marginBottom: 12, fontWeight: 500, color: '#333' }}>Mã QR hết hạn</p>
                                <button className='auth-refresh-btn' onClick={initializeQr}>Lấy mã mới</button>
                            </div>
                        )}
                    </>
                  ) : (
                    <div style={{ color: 'red' }}>Lỗi tạo mã</div>
                  )}
                </div>
                <p style={{ color: '#0068ff', fontSize: 15, marginTop: 15, fontWeight: 500 }}>Chỉ dùng để đăng nhập</p>
                <p style={{ fontSize: 14, color: 'var(--auth-text-main)' }}>Vnalo {t('auth.loginHeroCopy').includes('Optimized') ? 'on Desktop' : 'trên máy tính'}</p>
              </div>
            ) : (
              <form className='auth-form' onSubmit={handlePasswordLogin}>
                <input
                  required
                  type='text'
                  placeholder={t('auth.identifierPlaceholder')}
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                />
                <input
                  required
                  type='password'
                  placeholder={t('auth.passwordPlaceholder')}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
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
          <button 
            className={`auth-lang-btn ${language === 'vi' ? 'active' : ''}`}
            onClick={() => setLanguage('vi')}
          >
            Tiếng Việt
          </button>
          <button 
            className={`auth-lang-btn ${language === 'en' ? 'active' : ''}`}
            onClick={() => setLanguage('en')}
          >
            English
          </button>
      </div>
      </div>
    </div>
  )
}
