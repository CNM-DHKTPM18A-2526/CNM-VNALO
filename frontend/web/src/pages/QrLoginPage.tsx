import React from 'react'
import { QRCodeCanvas } from 'qrcode.react'
import { Link, useNavigate } from 'react-router-dom'

import { createQrLoginSession, pollQrLoginSession } from '../features/auth/auth.api'
import { useAuth } from '../features/auth/useAuth'
import { AuthPageControls } from '../shared/components/AuthPageControls'
import { useLanguage } from '../shared/i18n/LanguageContext'

const POLL_INTERVAL_MS = 2000

export function QrLoginPage() {
  const navigate = useNavigate()
  const { loginWithAccessToken } = useAuth()
  const { language } = useLanguage()

  const [token, setToken] = React.useState<string | null>(null)
  const [qrPayload, setQrPayload] = React.useState<string | null>(null)
  const [expiresAt, setExpiresAt] = React.useState<string | null>(null)
  const [error, setError] = React.useState<string | null>(null)
  const [isLoading, setIsLoading] = React.useState(true)

  const labels = language === 'vi'
    ? {
        title: 'Đăng nhập bằng QR',
        subtitle: 'Mở VNALO trên điện thoại và quét mã để đăng nhập web an toàn.',
        loading: 'Đang tạo mã QR...',
        createError: 'Không thể khởi tạo QR login.',
        expiredError: 'Phiên QR đã hết hạn hoặc bị từ chối. Vui lòng tạo mã mới.',
        pollError: 'Lỗi kiểm tra trạng thái QR login.',
        expiresAt: 'Hết hạn lúc',
        refresh: 'Tạo mã mới',
        backToPassword: 'Quay lại đăng nhập mật khẩu',
      }
    : {
        title: 'Sign in with QR',
        subtitle: 'Open VNALO on your phone and scan this code to sign in securely on web.',
        loading: 'Creating QR code...',
        createError: 'Could not create QR login session.',
        expiredError: 'QR session expired or was rejected. Please create a new code.',
        pollError: 'Could not check QR login status.',
        expiresAt: 'Expires at',
        refresh: 'Create new code',
        backToPassword: 'Back to password sign-in',
      }

  const initialize = React.useCallback(async () => {
    setIsLoading(true)
    setError(null)
    setToken(null)
    setQrPayload(null)
    setExpiresAt(null)

    try {
      const session = await createQrLoginSession()
      setToken(session.token)
      setQrPayload(session.qrPayload)
      setExpiresAt(session.expiresAt)
    } catch (err) {
      setError(err instanceof Error ? err.message : labels.createError)
    } finally {
      setIsLoading(false)
    }
  }, [labels.createError])

  React.useEffect(() => {
    void initialize()
  }, [initialize])

  React.useEffect(() => {
    if (!token || error) return undefined

    let disposed = false
    const timer = window.setInterval(async () => {
      try {
        const result = await pollQrLoginSession(token)
        if (disposed) return

        if (result.accessToken) {
          await loginWithAccessToken(result.accessToken)
          navigate('/chat', { replace: true })
          return
        }

        if (result.status === 'EXPIRED' || result.status === 'REJECTED') {
          setError(labels.expiredError)
          window.clearInterval(timer)
        }
      } catch (err) {
        if (disposed) return
        setError(err instanceof Error ? err.message : labels.pollError)
        window.clearInterval(timer)
      }
    }, POLL_INTERVAL_MS)

    return () => {
      disposed = true
      window.clearInterval(timer)
    }
  }, [error, labels.expiredError, labels.pollError, loginWithAccessToken, navigate, token])

  return (
    <div className='auth-page'>
      <AuthPageControls />
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>VNALO</span>
          <h1 className='auth-brand-title'>{labels.title}</h1>
          <p className='auth-brand-subtitle'>{labels.subtitle}</p>
        </header>

        <div className='auth-card'>
          <section className='auth-content auth-content-login'>
            {isLoading ? <p>{labels.loading}</p> : null}
            {!isLoading && qrPayload ? (
              <div style={{ background: 'white', padding: 12, borderRadius: 12, display: 'inline-block' }}>
                <QRCodeCanvas value={qrPayload} size={320} level='H' includeMargin={false} />
              </div>
            ) : null}
            {expiresAt ? <p style={{ marginTop: 12 }}>{labels.expiresAt}: {new Date(expiresAt).toLocaleTimeString()}</p> : null}
            {error ? <p className='auth-form-error'>{error}</p> : null}
            <div className='auth-inline-actions'>
              <button type='button' className='auth-text-action' onClick={() => void initialize()}>
                {labels.refresh}
              </button>
              <Link to='/login' className='auth-text-action'>
                {labels.backToPassword}
              </Link>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}