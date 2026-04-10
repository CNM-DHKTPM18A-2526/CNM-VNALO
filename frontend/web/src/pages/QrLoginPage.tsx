import { useEffect, useState } from 'react'
import { QRCodeCanvas } from 'qrcode.react'
import { Link, useNavigate } from 'react-router-dom'

import { createQrLoginSession, pollQrLoginSession } from '../features/auth/auth.api'
import { useAuth } from '../features/auth/useAuth'
import { AuthPageControls } from '../shared/components/AuthPageControls'

const POLL_INTERVAL_MS = 2000

export function QrLoginPage() {
  const navigate = useNavigate()
  const { loginWithAccessToken } = useAuth()

  const [token, setToken] = useState<string | null>(null)
  const [qrPayload, setQrPayload] = useState<string | null>(null)
  const [expiresAt, setExpiresAt] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)


  useEffect(() => {
    let disposed = false

    const initialize = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const session = await createQrLoginSession()
        if (disposed) {
          return
        }

        setToken(session.token)
        setQrPayload(session.qrPayload)
        setExpiresAt(session.expiresAt)
      } catch (err) {
        if (disposed) {
          return
        }
        const message = err instanceof Error ? err.message : 'Không thể khởi tạo QR login.'
        setError(message)
      } finally {
        if (!disposed) {
          setIsLoading(false)
        }
      }
    }

    void initialize()

    return () => {
      disposed = true
    }
  }, [])

  useEffect(() => {
    if (!token || error) {
      return
    }

    let disposed = false
    const timer = window.setInterval(async () => {
      try {
        const result = await pollQrLoginSession(token)
        if (disposed) {
          return
        }

        if (result.accessToken) {
          await loginWithAccessToken(result.accessToken)
          navigate('/chat', { replace: true })
          return
        }

        if (result.status === 'EXPIRED' || result.status === 'REJECTED') {
          setError('Phiên QR đã hết hạn hoặc bị từ chối. Vui lòng tạo mã mới.')
          window.clearInterval(timer)
        }
      } catch (err) {
        if (disposed) {
          return
        }
        const message = err instanceof Error ? err.message : 'Lỗi kiểm tra trạng thái QR login.'
        setError(message)
        window.clearInterval(timer)
      }
    }, POLL_INTERVAL_MS)

    return () => {
      disposed = true
      window.clearInterval(timer)
    }
  }, [error, loginWithAccessToken, navigate, token])

  return (
    <div className='auth-page'>
      <AuthPageControls />
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>VNALO</span>
          <h1 className='auth-brand-title'>Đăng nhập bằng QR</h1>
          <p className='auth-brand-subtitle'>Mở VNALO trên điện thoại và quét mã để đăng nhập web an toàn.</p>
        </header>

        <div className='auth-card'>
          <section className='auth-content auth-content-login'>
            {isLoading ? <p>Đang tạo mã QR...</p> : null}
            {!isLoading && qrPayload ? (
              <div style={{ background: 'white', padding: 12, borderRadius: 12, display: 'inline-block' }}>
                <QRCodeCanvas 
                  value={qrPayload} 
                  size={320} 
                  level="H"
                  includeMargin={false}
                />
              </div>
            ) : null}
            {expiresAt ? <p style={{ marginTop: 12 }}>Hết hạn lúc: {new Date(expiresAt).toLocaleTimeString()}</p> : null}
            {error ? <p className='auth-form-error'>{error}</p> : null}
            <div className='auth-inline-actions'>
              <button type='button' className='auth-text-action' onClick={() => window.location.reload()}>
                Tạo mã mới
              </button>
              <Link to='/login' className='auth-text-action'>
                Quay lại đăng nhập mật khẩu
              </Link>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
