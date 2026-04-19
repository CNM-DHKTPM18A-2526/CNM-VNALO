import React, { useState, useEffect, useRef } from 'react'
import { Icon } from '../../../shared/components/Icon'
import { UserAvatar } from '../../../shared/components/UserAvatar'

interface CallModalProps {
  isOpen: boolean
  type: 'audio' | 'video'
  status: 'connecting' | 'connected' | 'failed'

  peerName: string
  peerAvatar?: string | null
  localStream?: MediaStream | null
  remoteStream?: MediaStream | null
  isMicOn?: boolean
  isCameraOn?: boolean
  hasRemoteDescription?: boolean
  error?: string | null
  onEnd: () => void
  onAnswer?: () => void
  onToggleMic?: () => void
  onToggleCamera?: () => void
}

export const CallModal: React.FC<CallModalProps> = ({
  isOpen,
  type,
  status,
  peerName,
  peerAvatar,
  localStream,
  remoteStream,
  isMicOn = true,
  isCameraOn = true,
  hasRemoteDescription = false,
  onEnd,
  onAnswer,
  onToggleMic,
  onToggleCamera,
  error,
}) => {
  const [seconds, setSeconds] = useState(0)
  const [isAnswering, setIsAnswering] = useState(false)
  const localVideoRef = useRef<HTMLVideoElement>(null)
  const remoteVideoRef = useRef<HTMLVideoElement>(null)
  const remoteAudioRef = useRef<HTMLAudioElement>(null)

  useEffect(() => {
    if (localVideoRef.current && localStream) {
      localVideoRef.current.srcObject = localStream
    }
  }, [localStream, isOpen])

  useEffect(() => {
    if (remoteStream) {
      if (remoteVideoRef.current) {
        remoteVideoRef.current.srcObject = remoteStream
        remoteVideoRef.current.play().catch(e => console.warn('[CallModal] Video play failed:', e))
      }
      if (remoteAudioRef.current) {
        remoteAudioRef.current.srcObject = remoteStream
        remoteAudioRef.current.play().catch(e => console.warn('[CallModal] Audio play failed:', e))
      }
    }
  }, [remoteStream, isOpen])

  useEffect(() => {
    let interval: any
    if (status === 'connected') {
      interval = setInterval(() => {
        setSeconds((prev) => prev + 1)
      }, 1000)
    } else {
      setSeconds(0)
    }
    return () => clearInterval(interval)
  }, [status])

  useEffect(() => {
    // Reset answering lock if connection fails, closes or error is present
    if (status === 'failed' || status === 'connected' || error) {
      setIsAnswering(false)
    }
  }, [status, error])

  if (!isOpen) return null

  const formatTime = (totalSeconds: number) => {
    const mins = Math.floor(totalSeconds / 60)
    const secs = totalSeconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  return (
    <div className='call-modal-overlay'>
      {/* REMOTE AUDIO/VIDEO (Must be in DOM even for audio-only to hear sound) */}
      <video 
        ref={remoteVideoRef} 
        autoPlay 
        playsInline 
        className={`absolute inset-0 w-full h-full object-cover z-0 transition-opacity duration-500 ${type === 'video' && remoteStream ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
      />
      
      {/* EXPLICIT AUDIO ELEMENT (Ensures audio works even if video is throttled or hidden) */}
      <audio ref={remoteAudioRef} autoPlay />

      {/* LOCAL PREVIEW */}
      <div className={`absolute top-6 right-6 w-32 h-44 rounded-xl overflow-hidden shadow-2xl z-10 border-2 border-white/20 transition-all duration-500 ${type === 'video' && localStream ? 'opacity-100 scale-100' : 'opacity-0 scale-90 pointer-events-none'}`}>
        <video 
          ref={localVideoRef} 
          autoPlay 
          playsInline 
          muted 
          className="w-full h-full object-cover mirror-mode"
        />
      </div>

      <div className='call-peer-info relative z-20'>
        <UserAvatar
          name={peerName}
          imageUrl={peerAvatar}
          size='lg'
          className='call-peer-avatar'
        />
        <h2 className='call-peer-name'>{peerName}</h2>
        <p className={`call-status ${(error || status === 'failed') ? 'text-red-400 font-medium' : ''}`}>
          {status === 'failed' ? 'Kết nối thất bại' : (error ? error : (status === 'connecting' ? 'Đang nối máy...' : formatTime(seconds)))}
        </p>
      </div>

      <div className='flex flex-col items-center gap-8 relative z-20'>
        {status === 'connecting' && onAnswer && (
          <button 
            className={`bg-green-500 hover:bg-green-600 text-white px-6 py-2 rounded-full font-medium transition-colors mb-4 ${(isAnswering || !hasRemoteDescription) ? 'opacity-50 cursor-not-allowed' : ''}`}
            onClick={() => {
              if (isAnswering || !hasRemoteDescription) return
              setIsAnswering(true)
              onAnswer?.()
            }}
            disabled={isAnswering || !hasRemoteDescription}
          >
            {isAnswering ? 'Đang trả lời...' : (!hasRemoteDescription ? 'Đang khởi tạo...' : 'Trả lời')}
          </button>
        )}

        <div className='call-controls'>
          {type === 'video' && (
            <button 
              className={`call-control-btn ${isCameraOn ? 'call-control-btn-active' : ''}`}
              onClick={onToggleCamera}
              title={isCameraOn ? 'Tắt Camera' : 'Bật Camera'}
            >
              <Icon name={isCameraOn ? 'video' : 'cameraOff'} size={24} />
            </button>
          )}

          <button className='call-end-btn' onClick={() => onEnd()} title='Kết thúc cuộc gọi'>
            <Icon name='phoneOff' size={32} />
          </button>

          <button 
            className={`call-control-btn ${isMicOn ? 'call-control-btn-active' : ''}`}
            onClick={onToggleMic}
            title={isMicOn ? 'Tắt tiếng' : 'Mở tiếng'}
          >
            <Icon name={isMicOn ? 'mic' : 'micOff'} size={24} />
          </button>
        </div>
      </div>
    </div>
  )
}
