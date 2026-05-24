import React, { useEffect, useRef, useState } from 'react'
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
  const [cameraState, setCameraState] = useState<CameraState>('idle')
  const [cameraError, setCameraError] = useState<string | null>(null)

  useEffect(() => {
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
        const stream = createCameraStream()
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
        const msg = getCameraErrorMessage(err)
        setCameraError(msg)
        setCameraState('error')
        onCameraError?.(msg)
      }
    }

    void startCamera()

    return () => {
      stopCameraStream(streamRef.current)
      streamRef.current = null
      setCameraState('stopped')
    }
  }, [disabled, onCameraError])

  const handleCapture = async () => {
    if (!videoRef.current || disabled) return

    setCameraState('capturing')
    const blob = await captureFrame(videoRef.current)
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
            <span className='face-capture-error-icon'>⚠️</span>
            <p>{cameraError}</p>
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
            <div className='face-capture-overlay'>
              <div className='face-capture-guide' />
            </div>
          </>
        )}
      </div>

      <button
        type='button'
        className='face-capture-btn'
        onClick={handleCapture}
        disabled={disabled || cameraState !== 'active'}
        aria-label={cameraState === 'requesting' ? 'Đang yêu cầu quyền camera...' : cameraState === 'capturing' ? 'Đang chụp ảnh...' : 'Chụp ảnh khuôn mặt'}
      >
        <span className='face-capture-btn-ring'>
          {cameraState === 'capturing' ? (
            <span className='face-capture-btn-spinner' />
          ) : null}
        </span>
      </button>

      <p className='face-capture-hint'>
        {cameraState === 'requesting'
          ? 'Đang yêu cầu quyền camera...'
          : cameraState === 'capturing'
            ? 'Đang chụp...'
            : 'Đưa khuôn mặt vào khung hình'}
      </p>
    </div>
  )
}
