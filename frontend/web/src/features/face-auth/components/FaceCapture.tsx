import { useEffect, useRef, useState, useCallback } from 'react'
import { createCameraStream, stopCameraStream, captureFrame, getCameraErrorMessage } from '../camera.util'
import type { CameraState } from '../camera.util'
import { FaceDetector, FilesetResolver } from '@mediapipe/tasks-vision'

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
  const faceDetectorRef = useRef<FaceDetector | null>(null)
  const isMounted = useRef<boolean>(true)

  const [cameraState, setCameraState] = useState<CameraState>('idle')
  const [cameraError, setCameraError] = useState<string | null>(null)
  const [hintText, setHintText] = useState('Đang khởi tạo AI...')
  const [borderColor, setBorderColor] = useState('rgba(255, 255, 255, 0.7)')
  // BUG-5 FIX: Use state instead of ref for overlay reactivity
  const [isValidFace, setIsValidFace] = useState(false)

  const validFramesRef = useRef(0)
  const isProcessingRef = useRef(false)
  const requestRef = useRef<number>()
  const hasAutoCapturedRef = useRef(false)

  // Required consecutive valid frames (~1 sec at ~15fps)
  const REQUIRED_VALID_FRAMES = 15

  // BUG-2 FIX: Load WASM from the installed npm package instead of a hardcoded CDN version.
  // @mediapipe/tasks-vision ships its own wasm files under node_modules.
  // jsdelivr dynamically resolves "latest" if we omit the version pinning,
  // but the safest approach is to let it resolve from the installed package.
  useEffect(() => {
    let cancelled = false

    const initFaceDetector = async () => {
      try {
        const vision = await FilesetResolver.forVisionTasks(
          "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision/wasm"
        )
        if (cancelled) return

        faceDetectorRef.current = await FaceDetector.createFromOptions(vision, {
          baseOptions: {
            modelAssetPath:
              "https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/1/blaze_face_short_range.tflite",
            delegate: "GPU",
          },
          runningMode: "VIDEO",
          minDetectionConfidence: 0.7,
        })

        if (!cancelled && !disabled) {
          setHintText('Đưa khuôn mặt vào trong khung')
        }
      } catch (err) {
        console.error('Failed to init face detector:', err)
        if (!cancelled) {
          setHintText('Không thể khởi tạo AI nhận diện. Vui lòng tải lại trang.')
        }
      }
    }

    void initFaceDetector()

    return () => {
      cancelled = true
      faceDetectorRef.current?.close()
      faceDetectorRef.current = null
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // BUG-3 FIX: Use a single ref-stable callback for the detection loop to avoid stale closures.
  // All mutable values are accessed via refs, not closures over state.
  const onCaptureRef = useRef(onCapture)
  const onCameraErrorRef = useRef(onCameraError)
  useEffect(() => { onCaptureRef.current = onCapture }, [onCapture])
  useEffect(() => { onCameraErrorRef.current = onCameraError }, [onCameraError])

  const runDetectionLoop = useCallback(() => {
    const detect = () => {
      if (!isMounted.current || hasAutoCapturedRef.current) return

      const video = videoRef.current
      const detector = faceDetectorRef.current

      if (!video || !detector || isProcessingRef.current || video.readyState < 2) {
        requestRef.current = requestAnimationFrame(detect)
        return
      }

      isProcessingRef.current = true

      try {
        const detections = detector.detectForVideo(video, performance.now())
        const faces = detections.detections

        if (faces.length === 0) {
          setHintText('Đưa khuôn mặt vào trong khung')
          setBorderColor('rgba(255, 255, 255, 0.7)')
          setIsValidFace(false)
          validFramesRef.current = 0
        } else if (faces.length > 1) {
          setHintText('Chỉ một khuôn mặt trong khung')
          setBorderColor('red')
          setIsValidFace(false)
          validFramesRef.current = 0
        } else {
          const face = faces[0]
          const box = face.boundingBox
          if (!box) {
            validFramesRef.current = 0
            setIsValidFace(false)
          } else {
            const faceWidthRatio = box.width / video.videoWidth
            const faceHeightRatio = box.height / video.videoHeight

            if (faceWidthRatio < 0.2 || faceHeightRatio < 0.2) {
              setHintText('Tiến lại gần hơn')
              setBorderColor('orange')
              setIsValidFace(false)
              validFramesRef.current = 0
            } else if (faceWidthRatio > 0.85) {
              setHintText('Lùi ra xa hơn một chút')
              setBorderColor('orange')
              setIsValidFace(false)
              validFramesRef.current = 0
            } else {
              // Check face is roughly centered (within central 60% of frame)
              const faceCenterX = (box.originX + box.width / 2) / video.videoWidth
              const faceCenterY = (box.originY + box.height / 2) / video.videoHeight
              if (Math.abs(faceCenterX - 0.5) > 0.25 || Math.abs(faceCenterY - 0.5) > 0.25) {
                setHintText('Đưa mặt vào giữa khung')
                setBorderColor('orange')
                setIsValidFace(false)
                validFramesRef.current = 0
              } else {
                // All checks passed
                setHintText('Giữ nguyên...')
                setBorderColor('#22c55e')
                setIsValidFace(true)
                validFramesRef.current += 1

                if (validFramesRef.current >= REQUIRED_VALID_FRAMES) {
                  hasAutoCapturedRef.current = true
                  isProcessingRef.current = false
                  void doAutoCapture()
                  return // stop the loop
                }
              }
            }
          }
        }
      } catch {
        // ignore detection errors
      }

      isProcessingRef.current = false
      requestRef.current = requestAnimationFrame(detect)
    }

    requestRef.current = requestAnimationFrame(detect)
  }, [])

  const doAutoCapture = async () => {
    const video = videoRef.current
    if (!video) return

    setCameraState('capturing')
    setHintText('Đang phân tích...')
    setBorderColor('#0068ff')
    setIsValidFace(false)

    const blob = await captureFrame(video)

    if (!isMounted.current) return

    if (blob) {
      onCaptureRef.current?.(blob)
    } else {
      onCameraErrorRef.current?.('Không thể chụp ảnh. Vui lòng thử lại.')
      // Reset and restart detection
      setCameraState('active')
      setIsValidFace(false)
      validFramesRef.current = 0
      hasAutoCapturedRef.current = false
      runDetectionLoop()
    }
  }

  useEffect(() => {
    isMounted.current = true
    hasAutoCapturedRef.current = false

    if (disabled) {
      stopCameraStream(streamRef.current)
      streamRef.current = null
      setCameraState('stopped')
      if (requestRef.current) cancelAnimationFrame(requestRef.current)
      return
    }

    const startCamera = async () => {
      setCameraState('requesting')
      setCameraError(null)
      validFramesRef.current = 0

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
          runDetectionLoop()
        }
      } catch (err) {
        if (!isMounted.current) return
        const msg = getCameraErrorMessage(err)
        setCameraError(msg)
        setCameraState('error')
        onCameraErrorRef.current?.(msg)
      }
    }

    void startCamera()

    return () => {
      isMounted.current = false
      stopCameraStream(streamRef.current)
      streamRef.current = null
      setCameraState('stopped')
      if (requestRef.current) cancelAnimationFrame(requestRef.current)
    }
  }, [disabled, runDetectionLoop])

  return (
    <div className='face-capture' style={{ aspectRatio: String(aspectRatio) }}>
      <div className='face-capture-viewfinder' style={{ position: 'relative', overflow: 'hidden' }}>
        {cameraError ? (
          <div className='face-capture-error'>
            <span className='face-capture-error-icon' style={{ fontSize: 24, marginBottom: 8 }}>⚠️</span>
            <p style={{ margin: 0 }}>{cameraError}</p>
          </div>
        ) : (
          <>
            <video
              ref={videoRef}
              className='face-capture-video'
              playsInline
              muted
              autoPlay
              style={{ objectFit: 'cover', width: '100%', height: '100%', transform: 'scaleX(-1)' }}
            />
            {(cameraState === 'active' || cameraState === 'capturing') && (
              /* BUG-4 FIX: Use only SVG mask, no clipPath on wrapper div */
              <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
                <svg width="100%" height="100%" style={{ position: 'absolute', top: 0, left: 0 }}>
                  <defs>
                    <mask id="faceCaptureOvalMask">
                      <rect width="100%" height="100%" fill="white" />
                      <ellipse cx="50%" cy="50%" rx="35%" ry="45%" fill="black" />
                    </mask>
                  </defs>
                  {/* BUG-5 FIX: isValidFace is state, so changes trigger re-render */}
                  <rect
                    width="100%"
                    height="100%"
                    fill={isValidFace ? 'rgba(0, 200, 80, 0.12)' : 'rgba(0, 0, 0, 0.7)'}
                    mask="url(#faceCaptureOvalMask)"
                  />
                  <ellipse
                    cx="50%"
                    cy="50%"
                    rx="35%"
                    ry="45%"
                    fill="transparent"
                    stroke={borderColor}
                    strokeWidth="3"
                    style={{ transition: 'stroke 0.2s ease' }}
                  />
                </svg>
                {cameraState === 'active' && !isValidFace && (
                  <div
                    className='face-capture-scanning-line'
                    style={{
                      position: 'absolute',
                      top: '50%',
                      left: '15%',
                      right: '15%',
                      height: 2,
                      background: '#0068ff',
                      boxShadow: '0 0 10px #0068ff',
                      animation: 'faceScanLine 2s ease-in-out infinite alternate',
                    }}
                  />
                )}
              </div>
            )}
          </>
        )}
      </div>

      <p
        className='face-capture-hint'
        style={{
          color: borderColor === 'rgba(255, 255, 255, 0.7)' ? 'var(--auth-text-main, #333)' : borderColor,
          fontWeight: 600,
          marginTop: 16,
          textAlign: 'center',
          transition: 'color 0.2s ease',
        }}
      >
        {hintText}
      </p>

      {cameraState === 'capturing' && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 10 }}>
          <div
            style={{
              width: 24,
              height: 24,
              border: '3px solid #0068ff',
              borderTopColor: 'transparent',
              borderRadius: '50%',
              animation: 'spin 1s linear infinite',
            }}
          />
        </div>
      )}
    </div>
  )
}
