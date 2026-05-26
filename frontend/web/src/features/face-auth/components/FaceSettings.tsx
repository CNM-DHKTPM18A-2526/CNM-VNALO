import React, { useEffect, useState } from 'react'
import { FaceCapture } from './FaceCapture'
import { enrollFace, deleteFaceEnrollment, getFaceStatus, checkLiveness } from '../face-auth.api'
import type { FaceStatusResponse } from '../face-auth.types'

export type FaceSettingsProps = {
  token: string
  onStatusChange?: (enrolled: boolean) => void
}

type FaceSettingsState = 'loading' | 'enrolled' | 'not-enrolled' | 'enrolling' | 'deleting' | 'error'

function formatDate(iso: string | null): string {
  if (!iso) return 'N/A'
  try {
    return new Intl.DateTimeFormat('vi-VN', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(iso))
  } catch {
    return iso
  }
}

export function FaceSettings({ token, onStatusChange }: FaceSettingsProps) {
  const [state, setState] = useState<FaceSettingsState>('loading')
  const [status, setStatus] = useState<FaceStatusResponse | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [showEnrollment, setShowEnrollment] = useState(false)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  const loadStatus = React.useCallback(async () => {
    setState('loading')
    setErrorMessage(null)

    try {
      const result = await getFaceStatus(token)
      setStatus(result)
      const enrolled = result.enrolled
      setState(enrolled ? 'enrolled' : 'not-enrolled')
      onStatusChange?.(enrolled)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Không thể tải trạng thái face auth.')
      setState('error')
    }
  }, [token, onStatusChange])

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadStatus()
    }, 0)

    return () => window.clearTimeout(timer)
  }, [loadStatus])

  const handleDelete = async () => {
    if (!window.confirm('Bạn có chắc muốn xóa đăng ký khuôn mặt?')) {
      return
    }

    setState('deleting')
    setErrorMessage(null)
    setSuccessMessage(null)

    try {
      await deleteFaceEnrollment(token)
      setSuccessMessage('Đã xóa đăng ký khuôn mặt thành công.')
      setStatus(null)
      setState('not-enrolled')
      onStatusChange?.(false)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Không thể xóa đăng ký.')
      setState('enrolled')
    }
  }

  const handleEnrollSuccess = (enrolledAt: string, version: number) => {
    setShowEnrollment(false)
    setStatus({
      enrolled: true,
      enrolledAt,
      version,
      errorCode: null,
      message: null,
    })
    setState('enrolled')
    setSuccessMessage('Đăng ký khuôn mặt thành công!')
    onStatusChange?.(true)
  }

  if (state === 'loading') {
    return (
      <div className='face-settings face-settings-loading' role="status" aria-live="polite">
        <div className='face-settings-spinner' aria-hidden="true" />
        <p>Đang tải trạng thái...</p>
      </div>
    )
  }

  if (showEnrollment) {
    return (
      <FaceEnrollmentPanel
        token={token}
        onSuccess={handleEnrollSuccess}
        onCancel={() => setShowEnrollment(false)}
      />
    )
  }

  return (
    <div className='face-settings'>
      <div className='face-settings-header'>
        <h3>Xác thực khuôn mặt</h3>
        <p>
          Sử dụng khuôn mặt để đăng nhập thay vì mật khẩu.
        </p>
      </div>

      {errorMessage ? (
        <div className='face-settings-error'>
          <span className='face-settings-error-icon'>⚠️</span>
          <span>{errorMessage}</span>
        </div>
      ) : null}

      {successMessage ? (
        <div className='face-settings-success'>
          <span className='face-settings-success-icon'>✓</span>
          <span>{successMessage}</span>
        </div>
      ) : null}

      {(state === 'enrolled' || state === 'deleting') && status ? (
        <div className='face-settings-enrolled'>
          <div className='face-settings-status-card face-settings-status-enrolled'>
            <div className='face-settings-status-icon face-settings-status-icon-enrolled'>
              ✓
            </div>
            <div className='face-settings-status-info'>
              <strong>Đã đăng ký</strong>
              <span>Phiên bản: {status.version != null ? status.version : '—'}</span>
              <span>Ngày đăng ký: {formatDate(status.enrolledAt)}</span>
            </div>
          </div>

          <div className='face-settings-actions'>
            <button
              type='button'
              className='btn btn-primary'
              onClick={() => setShowEnrollment(true)}
              disabled={state === 'deleting'}
            >
              Cập nhật khuôn mặt
            </button>
            <button
              type='button'
              className='btn btn-ghost'
              onClick={handleDelete}
              disabled={state === 'deleting'}
            >
              {state === 'deleting' ? 'Đang xóa...' : 'Xóa đăng ký'}
            </button>
          </div>
        </div>
      ) : state === 'not-enrolled' ? (
        <div className='face-settings-not-enrolled'>
          <div className='face-settings-status-card face-settings-status-not-enrolled'>
            <div className='face-settings-status-icon face-settings-status-icon-not-enrolled'>
              👤
            </div>
            <div className='face-settings-status-info'>
              <strong>Chưa đăng ký</strong>
              <span>Đăng ký khuôn mặt để sử dụng đăng nhập nhanh.</span>
            </div>
          </div>

          <button
            type='button'
            className='btn btn-primary'
            onClick={() => setShowEnrollment(true)}
          >
            Đăng ký khuôn mặt
          </button>
        </div>
      ) : state === 'error' ? (
        <div className='face-settings-error-state'>
          <p>{errorMessage ?? 'Đã xảy ra lỗi.'}</p>
          <button
            type='button'
            className='btn btn-ghost'
            onClick={() => { void loadStatus() }}
          >
            Thử lại
          </button>
        </div>
      ) : null}
    </div>
  )
}

// Inline enrollment panel component
function FaceEnrollmentPanel({
  token,
  onSuccess,
  onCancel,
}: {
  token: string
  onSuccess: (enrolledAt: string, version: number) => void
  onCancel: () => void
}) {
  const [blob, setBlob] = React.useState<Blob | null>(null)
  const [preview, setPreview] = React.useState<string | null>(null)
  const [step, setStep] = React.useState<'capture' | 'processing' | 'done'>('capture')
  const [errorMsg, setErrorMsg] = React.useState<string | null>(null)

  const handleCapture = (b: Blob) => {
    setBlob(b)
    setPreview(URL.createObjectURL(b))
  }

  const handleSubmit = async () => {
    if (!blob) return

    setStep('processing')
    setErrorMsg(null)

    try {
      let livenessScore = 1.0
      try {
        const liveness = await checkLiveness(blob)
        livenessScore = liveness.score
        if (!liveness.pass) {
          setErrorMsg('Khuôn mặt không hợp lệ (liveness check failed).')
          setStep('capture')
          return
        }
      } catch {
        // optional
      }

      const deviceInfo = JSON.stringify({ platform: 'WEB', userAgent: navigator.userAgent })
      const result = await enrollFace(token, blob, { livenessScore, deviceInfo })

      if (result.success) {
        setStep('done')
        setTimeout(() => onSuccess(result.enrolledAt ?? new Date().toISOString(), result.version ?? 1), 1500)
      } else {
        setErrorMsg(result.message ?? 'Đăng ký thất bại.')
        setStep('capture')
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Đã xảy ra lỗi.')
      setStep('capture')
    }
  }

  const handleRetake = () => {
    if (preview) URL.revokeObjectURL(preview)
    setBlob(null)
    setPreview(null)
    setStep('capture')
    setErrorMsg(null)
  }

  return (
    <div className='face-settings face-settings-enrolling'>
      {step === 'capture' && (
        <>
          <div className='face-settings-enroll-header'>
            <h3>Đăng ký khuôn mặt</h3>
            <button type='button' className='btn btn-ghost' onClick={onCancel}>
              ← Quay lại
            </button>
          </div>
          <p className='face-settings-enroll-hint'>
            Đưa khuôn mặt vào khung hình và nhấn chụp.
          </p>
          <FaceCapture onCapture={handleCapture} />
          {preview && (
            <div className='face-settings-preview-wrap'>
              <img src={preview} alt='Preview' className='face-settings-preview-img' />
              <button type='button' className='btn btn-ghost' onClick={handleRetake}>
                Chụp lại
              </button>
              <button type='button' className='btn btn-primary' onClick={() => { void handleSubmit() }}>
                Xác nhận đăng ký
              </button>
            </div>
          )}
          {errorMsg ? <p className='face-settings-error'>{errorMsg}</p> : null}
        </>
      )}
      {step === 'processing' && (
        <div className='face-settings-processing'>
          <div className='face-settings-spinner' />
          <p>Đang xử lý đăng ký...</p>
        </div>
      )}
      {step === 'done' && (
        <div className='face-settings-success-state'>
          <span className='face-settings-success-icon'>✓</span>
          <h3>Đăng ký thành công!</h3>
        </div>
      )}
    </div>
  )
}
