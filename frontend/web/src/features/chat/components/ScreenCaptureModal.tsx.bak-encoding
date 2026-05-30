import React from 'react'
import { Modal } from '../../../shared/components/ui/Modal'
import { Button } from '../../../shared/components/ui/Button'
import { Icon } from '../../../shared/components/Icon'

type ScreenCaptureModalProps = {
  isOpen: boolean
  onClose: () => void
  onSend?: (file: File) => void
}

export function ScreenCaptureModal({ isOpen, onClose, onSend }: ScreenCaptureModalProps) {
  const [capturedImage, setCapturedImage] = React.useState<string | null>(null)
  const [isCapturing, setIsCapturing] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const canvasRef = React.useRef<HTMLCanvasElement>(null)

  const handleStartCapture = async () => {
    setIsCapturing(true)
    setError(null)
    setCapturedImage(null)

    try {
      // Step 1: Get display media
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: 'always' } as any,
        audio: false,
      })

      // Step 2: Show in a hidden video element to capture a frame
      if (videoRef.current) {
        videoRef.current.srcObject = stream
        videoRef.current.onloadedmetadata = () => {
          videoRef.current?.play()
          
          // Small delay to ensure video is playing
          setTimeout(() => {
            captureFrame(stream)
          }, 500)
        }
      }
    } catch (err: any) {
      console.error('Error capturing screen:', err)
      setError('Không thể truy cập màn hình. Vui lòng kiểm tra quyền trình duyệt.')
      setIsCapturing(false)
    }
  }

  const captureFrame = (stream: MediaStream) => {
    const video = videoRef.current
    const canvas = canvasRef.current

    if (video && canvas) {
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight
      const ctx = canvas.getContext('2d')
      if (ctx) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
        const dataUrl = canvas.toDataURL('image/png')
        setCapturedImage(dataUrl)
      }
    }

    // Stop all tracks to end capture
    stream.getTracks().forEach(track => track.stop())
    setIsCapturing(false)
  }

  const handleSend = () => {
    if (capturedImage && onSend) {
      // Convert dataUrl to File
      fetch(capturedImage)
        .then(res => res.blob())
        .then(blob => {
          const file = new File([blob], `capture_${Date.now()}.png`, { type: 'image/png' })
          onSend(file)
          onClose()
          setCapturedImage(null)
        })
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Chụp màn hình"
      description="Chọn cửa sổ hoặc màn hình bạn muốn chụp giống như Zalo."
    >
      <div className="capture-content" style={{ display: 'flex', flexDirection: 'column', gap: '16px', alignItems: 'center', padding: '20px' }}>
        {!capturedImage ? (
          <div className="capture-placeholder" style={{ 
            width: '100%', 
            height: '240px', 
            background: 'var(--surface-muted)', 
            borderRadius: '12px', 
            display: 'flex', 
            flexDirection: 'column',
            alignItems: 'center', 
            justifyContent: 'center',
            border: '2px dashed var(--border)',
            color: 'var(--muted)'
          }}>
            {isCapturing ? (
              <div style={{ textAlign: 'center' }}>
                <div className="loading-spinner" style={{ marginBottom: '12px' }}>⏳</div>
                <p>Đang chuẩn bị chụp...</p>
              </div>
            ) : (
              <>
                <Icon name="capture" size={48} />
                <p style={{ marginTop: '12px' }}>Bấm nút bên dưới để bắt đầu chụp</p>
                {error && <p style={{ color: 'var(--danger)', fontSize: '13px', marginTop: '8px' }}>{error}</p>}
              </>
            )}
          </div>
        ) : (
          <div className="capture-preview" style={{ width: '100%', position: 'relative' }}>
            <img 
              src={capturedImage} 
              alt="Captured screen" 
              style={{ width: '100%', borderRadius: '8px', border: '1px solid var(--border)', boxShadow: 'var(--shadow-soft)' }} 
            />
            <button 
              onClick={() => setCapturedImage(null)}
              style={{ 
                position: 'absolute', 
                top: '8px', 
                right: '8px', 
                background: 'rgba(0,0,0,0.5)', 
                color: 'white', 
                border: 'none', 
                borderRadius: '50%', 
                width: '24px', 
                height: '24px', 
                cursor: 'pointer' 
              }}
            >
              ×
            </button>
          </div>
        )}

        <div className="capture-actions" style={{ display: 'flex', gap: '12px', width: '100%' }}>
          {!capturedImage ? (
            <Button 
              onClick={handleStartCapture} 
              fullWidth 
              variant="primary" 
              disabled={isCapturing}
              style={{ height: '48px', gap: '8px' }}
            >
              <Icon name="capture" size={20} />
              Bắt đầu chụp
            </Button>
          ) : (
            <>
              <Button onClick={() => setCapturedImage(null)} variant="ghost" fullWidth>
                Chụp lại
              </Button>
              <Button onClick={handleSend} variant="primary" fullWidth>
                Gửi ảnh này
              </Button>
            </>
          )}
        </div>

        {/* Hidden elements for processing */}
        <video ref={videoRef} style={{ display: 'none' }} />
        <canvas ref={canvasRef} style={{ display: 'none' }} />
      </div>
    </Modal>
  )
}
