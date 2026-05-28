import { useState } from 'react'
import { FaceCapture } from './FaceCapture'
import { enrollFace } from '../face-auth.api'

export type FaceEnrollmentProps = {
  token: string
  onSuccess?: (enrolledAt: string, version: number) => void
  onError?: (message: string) => void
  onCancel?: () => void
}

type EnrollmentStep = 'capture' | 'confirm' | 'processing' | 'success' | 'error'

export function FaceEnrollment({ token, onSuccess, onError, onCancel }: FaceEnrollmentProps) {
  const [step, setStep] = useState<EnrollmentStep>('capture')
  const [capturedBlob, setCapturedBlob] = useState<Blob | null>(null)
  const [capturedPreview, setCapturedPreview] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const handleCapture = async (blob: Blob) => {
    setCapturedBlob(blob)
    const preview = URL.createObjectURL(blob)
    setCapturedPreview(preview)

    setStep('confirm')
  }

  const handleConfirm = async () => {
    if (!capturedBlob) return

    setStep('processing')
    setErrorMessage(null)

    try {
      const deviceInfo = JSON.stringify({
        platform: 'WEB',
        userAgent: navigator.userAgent,
        timestamp: new Date().toISOString(),
      })

      // Server enforces liveness — just enroll
      const result = await enrollFace(token, capturedBlob, {
        deviceInfo,
      })

      if (result.success) {
        setStep('success')
        onSuccess?.(result.enrolledAt ?? new Date().toISOString(), result.version ?? 1)
      } else {
        setStep('error')
        setErrorMessage(result.message ?? 'Đăng ký khuôn mặt thất bại.')
        onError?.(result.message ?? 'Đăng ký khuôn mặt thất bại.')
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Đã xảy ra lỗi không xác định.'
      setStep('error')
      setErrorMessage(msg)
      onError?.(msg)
    }
  }

  const handleRetake = () => {
    if (capturedPreview) {
      URL.revokeObjectURL(capturedPreview)
    }
    setCapturedBlob(null)
    setCapturedPreview(null)
    setStep('capture')
    setErrorMessage(null)
  }

  const handleCancel = () => {
    if (capturedPreview) {
      URL.revokeObjectURL(capturedPreview)
    }
    onCancel?.()
  }

  return (
    <div className='face-enrollment'>
      {step === 'capture' && (
        <>
          <div className='face-enrollment-header'>
            <h3>Đăng ký khuôn mặt</h3>
            <p>Đưa khuôn mặt vào khung hình và chụp ảnh để đăng ký.</p>
          </div>
          <FaceCapture
            onCapture={handleCapture}
            onCameraError={(msg) => setErrorMessage(msg)}
          />
          {errorMessage ? (
            <p className='face-enrollment-error'>{errorMessage}</p>
          ) : null}
        </>
      )}

      {step === 'confirm' && capturedPreview && (
        <>
          <div className='face-enrollment-header'>
            <h3>Xác nhận khuôn mặt</h3>
            <p>Xem lại ảnh đã chụp trước khi đăng ký.</p>
          </div>
          <div className='face-enrollment-preview'>
            <img
              src={capturedPreview}
              alt='Khuôn mặt đã chụp'
              className='face-enrollment-preview-image'
            />
          </div>
          {/* No liveness score display — internal info, not for users */}
          <div className='face-enrollment-actions'>
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
            <button
              type='button'
              className='btn btn-text'
              onClick={handleCancel}
            >
              Hủy
            </button>
          </div>
        </>
      )}

      {step === 'processing' && (
        <div className='face-enrollment-processing'>
          <div className='face-enrollment-spinner' />
          <p>Đang xử lý...</p>
          <p className='face-enrollment-processing-hint'>Vui lòng chờ trong giây lát.</p>
        </div>
      )}

      {step === 'success' && (
        <div className='face-enrollment-success' role='status' aria-live='polite'>
          <span className='face-enrollment-success-icon' aria-hidden='true'>
            <svg width='36' height='36' viewBox='0 0 24 24' fill='none' stroke='currentColor' strokeWidth='2'>
              <circle cx='12' cy='12' r='10' />
              <polyline points='9,12 12,15 16,10' />
            </svg>
          </span>
          <h3>Đăng ký thành công!</h3>
          <p>Khuôn mặt của bạn đã được đăng ký thành công.</p>
        </div>
      )}

      {step === 'error' && (
        <>
          <div className='face-enrollment-error-state'>
            <span className='face-enrollment-error-icon'>✕</span>
            <h3>Đăng ký thất bại</h3>
            <p>{errorMessage ?? 'Đã xảy ra lỗi. Vui lòng thử lại.'}</p>
          </div>
          <div className='face-enrollment-actions'>
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
              onClick={handleCancel}
            >
              Hủy
            </button>
          </div>
        </>
      )}
    </div>
  )
}
