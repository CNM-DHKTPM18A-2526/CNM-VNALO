import React, { useState, useEffect, useRef } from 'react'
import { resolveMediaUrl } from '../../../utils/mediaUtils'
import { PremiumVideoTile, PremiumCallControls } from './PremiumCallUI'

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
  onMinimize?: () => void
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
  onEnd,
  onAnswer,
  onToggleMic,
  onToggleCamera,
  onMinimize,
  error,
}) => {
  const [seconds, setSeconds] = useState(0)

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

  if (!isOpen) return null

  const formatTime = (totalSeconds: number) => {
    const mins = Math.floor(totalSeconds / 60)
    const secs = totalSeconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const resolvedPeerAvatar = peerAvatar ? resolveMediaUrl(peerAvatar) : null

  return (
    <div className="fixed inset-0 z-[500] bg-[#000000] flex flex-col items-center justify-center overflow-hidden">
      {/* ── BACKGROUND BACKDROP (Blurred Avatar) ── */}
      <div className="absolute inset-0 z-0">
        {resolvedPeerAvatar ? (
          <img
            src={resolvedPeerAvatar}
            alt=""
            className="w-full h-full object-cover blur-3xl opacity-20 scale-110"
          />
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-[#001A33] via-[#000000] to-black" />
        )}
        <div className="absolute inset-0 bg-[#000000]/40" />
      </div>

      {/* ── MAIN CONTENT ── */}
      <div className="relative z-10 w-full max-w-6xl h-full flex flex-col p-4 sm:p-8">
        {/* Header Info */}
        <div className="flex flex-col items-center mb-8 animate-fade-in">
           {status === 'connecting' ? (
             <div className="bg-blue-500/20 text-blue-400 px-4 py-1.5 rounded-full backdrop-blur-md border border-blue-500/30 text-sm font-medium animate-pulse mb-4">
               {type === 'audio' ? 'Đang kết nối cuộc gọi thoại...' : 'Đang kết nối cuộc gọi video...'}
             </div>
           ) : (
             <div className="bg-green-500/20 text-green-400 px-4 py-1.5 rounded-full backdrop-blur-md border border-green-500/30 text-sm font-mono font-bold mb-4">
               {formatTime(seconds)}
             </div>
           )}
           {error && <div className="text-red-400 text-sm font-medium mb-4 bg-red-500/10 px-4 py-2 rounded-lg border border-red-500/20">{error}</div>}
        </div>

        {/* Video Grid */}
        <div className="flex-1 flex items-center justify-center gap-4 sm:gap-8 flex-col md:flex-row w-full h-full">
           {/* Remote User */}
           <div className="flex-1 w-full h-full max-h-[70vh]">
             <PremiumVideoTile
                stream={remoteStream || null}
                displayName={peerName}
                avatarUrl={peerAvatar || undefined}
                isCameraOn={status === 'connected' ? isRemoteCameraOn : false}
                isMicOn={true} // We don't have remote mic state in 1-1 props currently
                isSpeaking={false}
             />
           </div>

           {/* Local User (Smaller on mobile, side-by-side or overlay on desktop) */}
           {type === 'video' && (
             <div className="w-full md:w-1/3 h-48 md:h-full md:max-h-[70vh] animate-fade-in delay-300">
                <PremiumVideoTile
                  stream={localStream || null}
                  displayName="Bạn"
                  isCameraOn={isCameraOn}
                  isMicOn={isMicOn}
                  isSpeaking={false}
                  isLocal={true}
                />
             </div>
           )}
        </div>

        {/* Controls */}
        <div className="mt-auto py-8">
          <PremiumCallControls
             isMicOn={isMicOn}
             isCameraOn={isCameraOn}
             isAudioOnly={type === 'audio'}
             onToggleMic={onToggleMic || (() => {})}
             onToggleCamera={onToggleCamera || (() => {})}
             onEnd={onEnd}
             onMinimize={onMinimize}
          />
        </div>
      </div>
    </div>
  )
}
  )
}
