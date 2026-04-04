import { useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'

import { useAuth } from '../features/auth/useAuth'

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login } = useAuth()

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
          <p className='auth-brand'>VNALO</p>
          <h1>Đăng nhập VNALO</h1>
          <p className='auth-copy'>
            Kết nối nhanh bằng email hoặc số điện thoại, đồng bộ tối ưu cho luồng chat và thông báo.
          </p>

          <div className='auth-points'>
            <div>
              <span className='auth-point-kicker'>01</span>
              <p>Phiên đăng nhập an toàn với JWT và hồ sơ người dùng.</p>
            </div>
            <div>
              <span className='auth-point-kicker'>02</span>
              <p>Giao diện desktop rõ ràng, điều hướng và menu tài khoản tiện dụng.</p>
            </div>
            <div>
              <span className='auth-point-kicker'>03</span>
              <p>Phù hợp cho đội nhóm làm việc hằng ngày và thông báo thời gian thực.</p>
            </div>
          </div>
        </section>

        <section className='auth-content'>
          <div className='auth-copy-block'>
            <p className='auth-eyebrow'>Đăng nhập với mật khẩu</p>
            <h2>Xin chào</h2>
            <p>Nhập thông tin tài khoản VNALO.</p>
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
                setErrorMessage('Số điện thoại hoặc mật khẩu không chính xác')
              } finally {
                setIsSubmitting(false)
              }
            }}
          >
            <label>
              Số điện thoại
              <input
                required
                type='text'
                placeholder='0917949410 hoặc +84917949410'
                value={identifier}
                onChange={(event) => setIdentifier(event.target.value)}
                autoComplete='username'
              />
            </label>
            <label>
              Mật khẩu
              <input
                required
                type='password'
                placeholder='Mật khẩu'
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete='current-password'
              />
            </label>
            {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
            <button type='submit' disabled={isSubmitting}>
              {isSubmitting ? 'Đang xử lý...' : 'Đăng nhập'}
            </button>
          </form>
        </section>
      </div>
    </div>
  )
}
