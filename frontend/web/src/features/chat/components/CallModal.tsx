import React, { useState, useEffect, useRef } from 'react'
import { Icon } from '../../../shared/components/Icon'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { resolveMediaUrl } from '../../../utils/mediaUtils'

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
  isRemoteCameraOn?: boolean
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
  isRemoteCameraOn = true,
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

  const resolvedPeerAvatar = peerAvatar ? resolveMediaUrl(peerAvatar) : null

  // Attach local stream
  useEffect(() => {
    if (localVideoRef.current && localStream) {
      localVideoRef.current.srcObject = localStream
    }
  }, [localStream, isOpen])

  // Attach remote stream to audio (always) and video (when camera on)
  useEffect(() => {
    if (!remoteStream) return

    // Always attach to audio element
    if (remoteAudioRef.current) {
      remoteAudioRef.current.srcObject = remoteStream
      remoteAudioRef.current.play().catch(e => console.warn('[CallModal] Audio play failed:', e))
    }

    // Attach to video element always — visibility is controlled by CSS opacity
    if (remoteVideoRef.current) {
      remoteVideoRef.current.srcObject = remoteStream
      remoteVideoRef.current.play().catch(e => console.warn('[CallModal] Video play failed:', e))
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

  // Show avatar when:
  // - it's an audio call, OR
  // - remote camera is off, OR
  // - still connecting (no video yet)
  const showAvatar = type === 'audio' || !isRemoteCameraOn || status === 'connecting'

  return (
    <div className='call-modal-overlay overflow-hidden'>
      {/* ── BACKGROUND ── */}
      <div className="absolute inset-0 bg-slate-900 z-0">
        {/* Blurred avatar background — visible when no remote video */}
        <div
          className="absolute inset-0 transition-opacity duration-500"
          style={{ opacity: showAvatar ? 1 : 0 }}
        >
          {resolvedPeerAvatar ? (
            <img
              src={resolvedPeerAvatar}
              alt=""
              className="w-full h-full object-cover blur-3xl scale-110"
              style={{ opacity: 0.35 }}
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-slate-800 to-slate-950" />
          )}
          <div className="absolute inset-0 bg-black/50" />
        </div>

        {/* Remote video — always mounted, opacity controls visibility */}
        <video
          ref={remoteVideoRef}
          autoPlay
          playsInline
          className="absolute inset-0 w-full h-full object-cover z-10 transition-opacity duration-500"
          style={{ opacity: !showAvatar && remoteStream ? 1 : 0 }}
        />
      </div>

      {/* Audio element (always hidden) */}
      <audio ref={remoteAudioRef} autoPlay />

      {/* Local preview (PiP) */}
      <div
        className="absolute top-6 right-6 w-32 h-44 rounded-2xl overflow-hidden shadow-2xl z-50 border-2 border-white/20 transition-all duration-500"
        style={{ opacity: type === 'video' && localStream && isCameraOn ? 1 : 0, pointerEvents: type === 'video' && localStream && isCameraOn ? 'auto' : 'none' }}
      >
        <video
          ref={localVideoRef}
          autoPlay
          playsInline
          muted
          className="w-full h-full object-cover mirror-mode"
        />
      </div>

      {/* Peer info / avatar — shown when no remote video */}
      <div className="absolute inset-0 flex flex-col items-center justify-center z-30 pointer-events-none">
        <div
          className="flex flex-col items-center transition-all duration-500"
          style={{ opacity: showAvatar ? 1 : 0, transform: showAvatar ? 'scale(1)' : 'scale(0.95)' }}
        >
          <div className="relative mb-8">
            <UserAvatar
              name={peerName}
              imageUrl={peerAvatar}
              size='xl'
              className='border-4 border-white/10 shadow-2xl'
              style={{ width: 120, height: 120 } as any}
            />
            {status === 'connecting' && (
              <div className="absolute inset-[-16px] rounded-full border-4 border-green-400 border-t-transparent animate-spin opacity-60" />
            )}
          </div>

          <h2 className='text-3xl font-bold text-white mb-2 drop-shadow-xl'>{peerName}</h2>
          <p className={`text-lg transition-colors duration-300 ${(error || status === 'failed') ? 'text-red-400 font-bold' : 'text-slate-200 opacity-80'}`}>
            {status === 'failed'
              ? 'Kết nối thất bại'
              : error
              ? error
              : status === 'connecting'
              ? 'Đang nối máy...'
              : formatTime(seconds)}
          </p>
        </div>
      </div>

      {/* Controls — always fixed at bottom */}
      <div className="absolute bottom-10 left-0 right-0 flex flex-col items-center gap-6 z-40">
        {/* Answer button (for incoming calls) */}
        {status === 'connecting' && onAnswer && (
          <button
            className={`bg-green-500 hover:bg-green-600 text-white px-10 py-3 rounded-full font-bold text-lg transition-all shadow-xl shadow-green-500/30 ${isAnswering || !hasRemoteDescription ? 'opacity-50 cursor-not-allowed' : 'hover:scale-105 active:scale-95'}`}
            onClick={() => {
              if (isAnswering || !hasRemoteDescription) return
              setIsAnswering(true)
              onAnswer?.()
            }}
            disabled={isAnswering || !hasRemoteDescription}
          >
            {isAnswering ? 'Đang nhận...' : !hasRemoteDescription ? 'Đang tải...' : 'Trả lời'}
          </button>
        )}

        <div className="flex items-center gap-5 px-6 py-4 rounded-3xl backdrop-blur-xl bg-white/5 border border-white/10 shadow-2xl">
          {type === 'video' && (
            <button
              className={`w-12 h-12 rounded-full flex items-center justify-center transition-all ${isCameraOn ? 'bg-white/10 text-white hover:bg-white/20' : 'bg-red-500 text-white shadow-lg shadow-red-500/30'}`}
              onClick={onToggleCamera}
              title={isCameraOn ? 'Tắt camera' : 'Bật camera'}
            >
              <Icon name={isCameraOn ? 'video' : 'cameraOff'} size={22} />
            </button>
          )}

          <button
            className="w-16 h-16 rounded-full bg-red-500 text-white flex items-center justify-center hover:bg-red-600 transition-all shadow-xl shadow-red-500/40 hover:scale-110 active:scale-90"
            onClick={onEnd}
            title="Kết thúc"
          >
            <Icon name="phoneOff" size={30} />
          </button>

          <button
            className={`w-12 h-12 rounded-full flex items-center justify-center transition-all ${isMicOn ? 'bg-white/10 text-white hover:bg-white/20' : 'bg-red-500 text-white shadow-lg shadow-red-500/30'}`}
            onClick={onToggleMic}
            title={isMicOn ? 'Tắt mic' : 'Bật mic'}
          >
            <Icon name={isMicOn ? 'mic' : 'micOff'} size={22} />
          </button>
        </div>
      </div>
    </div>
  )
}
