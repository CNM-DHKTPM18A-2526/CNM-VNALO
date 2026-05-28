import { useEffect, useRef, useState } from 'react'
import { FaceCapture } from './FaceCapture'
import { enrollFace } from '../face-auth.api'

type RegisterFaceStepProps = {
  token: string
  onComplete: (enrolled: boolean) => void
}

type FaceStep = 'capture' | 'confirm' | 'processing' | 'success' | 'error'

export function RegisterFaceStep({ token, onComplete }: RegisterFaceStepProps) {
  const [step, setStep] = useState<FaceStep>('capture')
  const [capturedBlob, setCapturedBlob] = useState<Blob | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const streamRef = useRef<MediaStream | null>(null)

  useEffect(() => {
    const stream = streamRef.current
    return () => {
      if (stream) {
        stream.getTracks().forEach(t => t.stop())
      }
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
      const result = await enrollFace(token, capturedBlob, { deviceInfo })

      if (result.success) {
        setStep('success')
        setTimeout(() => onComplete(true), 1200)
      } else {
        setErrorMsg(result.message ?? 'Đăng ký khuôn mặt thất bại.')
        setStep('error')
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Đã xảy ra lỗi.')
      setStep('error')
    }
  }

  return (
    <div className='register-face-step'>
      {step === 'capture' && (
        <>
          <div className='register-face-header'>
            <h3>Đăng ký khuôn mặt</h3>
            <p>Đăng nhập nhanh bằng khuôn mặt thay vì nhập mật khẩu.</p>
          </div>
          <div className='register-face-capture-wrapper'>
            <FaceCapture
              onCapture={handleCapture}
              onCameraError={(msg) => setErrorMsg(msg)}
            />
          </div>
          {errorMsg && (
            <p className='register-face-error'>{errorMsg}</p>
          )}
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
