import { useEffect, useRef, useState } from 'react'
import { createCameraStream, stopCameraStream, captureFrame, getCameraErrorMessage } from '../camera.util'
import type { CameraState } from '../camera.util'

export type FaceCaptureProps = {
  onCapture?: (blob: Blob) => void
  onCameraError?: (message: string) => void
  disabled?: boolean
  aspectRatio?: number
}

export function FaceCapture({
  onCapture,
  onCameraError,
  disabled,
  aspectRatio = 4 / 3,
}: FaceCaptureProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const isMounted = useRef<boolean>(true)
  const [cameraState, setCameraState] = useState<CameraState>('idle')
  const [cameraError, setCameraError] = useState<string | null>(null)

  useEffect(() => {
    isMounted.current = true
    if (disabled) {
      stopCameraStream(streamRef.current)
      streamRef.current = null
      setCameraState('stopped')
      return
    }

    const startCamera = async () => {
      setCameraState('requesting')
      setCameraError(null)

      try {
        const stream = await createCameraStream()
        if (!isMounted.current) {
          stopCameraStream(stream)
          return
        }

        if (!stream) {
          throw new Error('Trình duyệt không hỗ trợ camera.')
        }

        streamRef.current = stream
        setCameraState('active')

        if (videoRef.current) {
          videoRef.current.srcObject = stream
          await videoRef.current.play()
        }
      } catch (err) {
        if (!isMounted.current) return
        const msg = getCameraErrorMessage(err)
        setCameraError(msg)
        setCameraState('error')
        onCameraError?.(msg)
      }
    }

    void startCamera()

    return () => {
      isMounted.current = false
      stopCameraStream(streamRef.current)
      streamRef.current = null
      setCameraState('stopped')
    }
  }, [disabled, onCameraError])

  const handleCapture = async () => {
    if (!videoRef.current || disabled) return

    setCameraState('capturing')
    const blob = await captureFrame(videoRef.current)
    
    if (!isMounted.current) return
    
    setCameraState('active')

    if (blob) {
      onCapture?.(blob)
    } else {
      onCameraError?.('Không thể chụp ảnh. Vui lòng thử lại.')
    }
  }

  return (
    <div className='face-capture' style={{ aspectRatio: String(aspectRatio) }}>
      <div className='face-capture-viewfinder'>
        {cameraError ? (
          <div className='face-capture-error'>
            <span className='face-capture-error-icon' style={{fontSize: 24, marginBottom: 8}}>⚠️</span>
            <p style={{margin: 0}}>{cameraError}</p>
          </div>
        ) : (
          <>
            <video
              ref={videoRef}
              className='face-capture-video'
              playsInline
              muted
              autoPlay
            />
            {cameraState === 'active' || cameraState === 'capturing' ? (
              <>
                <div className='face-capture-guide-mask'>
                  {cameraState === 'active' && <div className='face-capture-scanning-line' />}
                </div>
              </>
            ) : null}
          </>
        )}
      </div>

      <p className='face-capture-hint'>
        {cameraState === 'requesting'
          ? 'Đang yêu cầu camera...'
          : cameraState === 'capturing'
            ? 'Đang phân tích...'
            : 'Đưa khuôn mặt vào trong khung'}
      </p>

      <div className='face-capture-btn-container'>
        <button
          type='button'
          className='face-capture-btn'
          onClick={handleCapture}
          disabled={disabled || cameraState !== 'active'}
          aria-label={cameraState === 'requesting' ? 'Đang yêu cầu camera...' : cameraState === 'capturing' ? 'Đang phân tích...' : 'Chụp ảnh khuôn mặt'}
        >
          <div className='face-capture-btn-inner'>
            {cameraState === 'capturing' ? (
              <div className='face-capture-btn-spinner' />
            ) : null}
          </div>
        </button>
      </div>
    </div>
  )
}
