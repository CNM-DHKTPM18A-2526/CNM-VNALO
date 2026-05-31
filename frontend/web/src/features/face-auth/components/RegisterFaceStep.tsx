import { useEffect, useRef, useState } from 'react'
import { FaceCapture } from './FaceCapture'
import { enrollFace, withTimeout } from '../face-auth.api'

type RegisterFaceStepProps = {
  token: string
  onComplete: (enrolled: boolean) => void
}

type FaceStep = 'terms' | 'capture' | 'confirm' | 'processing' | 'success' | 'error'

export function RegisterFaceStep({ token, onComplete }: RegisterFaceStepProps) {
  const [step, setStep] = useState<FaceStep>('terms')
  const [capturedBlob, setCapturedBlob] = useState<Blob | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const isMounted = useRef<boolean>(true)

  useEffect(() => {
    isMounted.current = true
    return () => {
      isMounted.current = false
      if (preview) {
        URL.revokeObjectURL(preview)
      }
    }
  }, [preview])

  const handleCapture = (blob: Blob) => {
    setCapturedBlob(blob)
    setPreview(URL.createObjectURL(blob))
    setStep('confirm')
  }

  const handleRetake = () => {
    if (preview) URL.revokeObjectURL(preview)
    setCapturedBlob(null)
    setPreview(null)
    setErrorMsg(null)
    setStep('capture')
  }

  const handleConfirm = async () => {
    if (!capturedBlob) return

    setStep('processing')
    setErrorMsg(null)

    try {
      // Server enforces liveness — send image, let backend decide
      const deviceInfo = JSON.stringify({ platform: 'WEB', source: 'REGISTRATION' })
      const result = await withTimeout(
        enrollFace(token, capturedBlob, { deviceInfo }),
        20_000,
        'Đăng ký khuôn mặt'
      )

      if (!isMounted.current) return

      if (result.success) {
        setStep('success')
        setTimeout(() => {
          if (isMounted.current) onComplete(true)
        }, 1200)
      } else {
        setErrorMsg(result.message ?? 'Đăng ký khuôn mặt thất bại.')
        setStep('error')
      }
    } catch (err) {
      if (!isMounted.current) return
      setErrorMsg(err instanceof Error ? err.message : 'Đã xảy ra lỗi.')
      setStep('error')
    }
  }

  return (
    <div className='register-face-step'>
      {step === 'terms' && (
        <div className='register-face-terms'>
          <div className='register-face-header'>
            <h3>Điều khoản bảo mật</h3>
            <p>Vui lòng đọc kỹ trước khi đăng ký khuôn mặt.</p>
          </div>
          <div className='register-face-terms-content' style={{ background: 'var(--auth-bg)', padding: '16px', borderRadius: '8px', fontSize: '14px', lineHeight: '1.6', marginBottom: '24px', textAlign: 'left', color: 'var(--auth-text-sub)' }}>
            <p style={{ marginBottom: '8px' }}>
              <strong>1. Mục đích thu thập:</strong> Dữ liệu khuôn mặt của bạn chỉ được sử dụng duy nhất cho mục đích xác thực và bảo mật tài khoản (đăng nhập không cần mật khẩu).
            </p>
            <p style={{ marginBottom: '8px' }}>
              <strong>2. Cam kết phi thương mại:</strong> Vnalo cam kết tuyệt đối không sử dụng dữ liệu sinh trắc học của bạn cho bất kỳ mục đích thương mại, quảng cáo hay chia sẻ cho bên thứ ba nào.
            </p>
            <p style={{ marginBottom: '8px' }}>
              <strong>3. Lưu trữ & mã hóa:</strong> Dữ liệu được mã hóa AES-256 và lưu trữ cho đến khi bạn chủ động xóa hoặc vô hiệu hóa tài khoản.
            </p>
            <p style={{ marginBottom: '8px' }}>
              <strong>4. Quyền rút lại đồng ý:</strong> Bạn có quyền xóa dữ liệu khuôn mặt bất cứ lúc nào trong phần Cài đặt {'>'} Bảo mật. Sau khi xóa, bạn sẽ không thể đăng nhập bằng khuôn mặt cho đến khi đăng ký lại.
            </p>
            <p>
              <strong>5. Tuân thủ pháp luật:</strong> Việc xử lý dữ liệu tuân thủ nghiêm ngặt các quy định pháp luật về bảo vệ dữ liệu cá nhân. Mọi thắc mắc hoặc khiếu nại, vui lòng liên hệ: <strong>support@vnalo.fit</strong>
            </p>
          </div>
          <div className='register-face-actions'>
            <button
              type='button'
              className='btn btn-primary'
              onClick={() => setStep('capture')}
            >
              Đồng ý và Tiếp tục
            </button>
            <button
              type='button'
              className='btn btn-ghost'
              onClick={() => onComplete(false)}
            >
              Bỏ qua
            </button>
          </div>
        </div>
      )}

      {step === 'capture' && (
        <>
          <div className='register-face-header'>
            <h3>Đăng ký khuôn mặt</h3>
            <p>Đăng nhập nhanh bằng khuôn mặt thay vì nhập mật khẩu.</p>
          </div>
          <div className='register-face-capture-wrapper'>
            <FaceCapture
              onCapture={handleCapture}
            />
          </div>
          <div className='register-face-actions'>
            <button
              type='button'
              className='btn btn-ghost'
              onClick={() => onComplete(false)}
            >
              Bỏ qua
            </button>
          </div>
        </>
      )}

      {step === 'confirm' && preview && (
        <>
          <div className='register-face-header'>
            <h3>Xác nhận khuôn mặt</h3>
            <p>Xem lại ảnh trước khi đăng ký.</p>
          </div>
          <div className='register-face-preview'>
            <img src={preview} alt='Preview' className='register-face-preview-img' />
          </div>
          <div className='register-face-actions'>
            <button
              type='button'
              className='btn btn-primary'
              onClick={() => { void handleConfirm() }}
            >
              Xác nhận đăng ký
            </button>
            <button
              type='button'
              className='btn btn-ghost'
              onClick={handleRetake}
            >
              Chụp lại
            </button>
          </div>
        </>
      )}

      {step === 'processing' && (
        <div className='register-face-processing'>
          <div className='register-face-spinner' />
          <p>Đang xử lý đăng ký khuôn mặt...</p>
          <p className='register-face-processing-hint'>Vui lòng chờ trong giây lát.</p>
        </div>
      )}

      {step === 'success' && (
        <div className='register-face-success' role='status' aria-live='polite'>
          <div className='register-face-success-icon'>
            <svg width='40' height='40' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2' aria-hidden='true'>
              <circle cx='12' cy='12' r='10' />
              <polyline points='9,12 12,15 16,10' />
            </svg>
          </div>
          <h3>Đăng ký khuôn mặt thành công!</h3>
          <p>Bạn có thể đăng nhập bằng khuôn mặt từ lần sau.</p>
        </div>
      )}

      {step === 'error' && (
        <>
          <div className='register-face-header'>
            <h3>Đăng ký thất bại</h3>
            <p>{errorMsg ?? 'Đã xảy ra lỗi. Vui lòng thử lại.'}</p>
          </div>
          <div className='register-face-actions'>
            <button
              type='button'
              className='btn btn-primary'
              onClick={handleRetake}
            >
              Thử lại
            </button>
            <button
              type='button'
              className='btn btn-ghost'
              onClick={() => onComplete(false)}
            >
              Bỏ qua
            </button>
          </div>
        </>
      )}
    </div>
  )
}
