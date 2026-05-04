import React from 'react'
import { ShieldCheck, MicOff } from 'lucide-react'
import { PremiumVideoTile, PremiumCallControls } from './PremiumCallUI'

interface CallModalProps {
  isOpen: boolean
  type: 'audio' | 'video'
  status: 'connecting' | 'connected' | 'failed'
  peerName: string
  peerAvatar?: string | null
  localAvatar?: string | null
  localStream?: MediaStream | null
  remoteStream?: MediaStream | null
  isMicOn?: boolean
  isCameraOn?: boolean
  isRemoteCameraOn?: boolean
  hasRemoteDescription?: boolean
  error?: string | null
  onEnd: () => void
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
  onToggleMic,
  onToggleCamera,
  onMinimize,
  localAvatar,
  error,
}) => {
  const [seconds, setSeconds] = React.useState(0)

  React.useEffect(() => {
    let interval: ReturnType<typeof setInterval> | undefined
    if (status === 'connected') {
      interval = setInterval(() => setSeconds((prev) => prev + 1), 1000)
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

  const isConnecting = status === 'connecting'
  const isConnected = status === 'connected'
  const isFailed = status === 'failed'
  const isVideoCall = type === 'video'
  
  // Show local PiP only if it's a video call AND we are connected
  const showLocalPiP = isConnected && isVideoCall && localStream

  return (
    <div className="fixed inset-0 z-[500] bg-black flex flex-col overflow-hidden select-none">
      {/* ── MAIN CONTENT AREA ── */}
      <div className="relative flex-1 w-full h-full flex items-center justify-center">
        {/* 
            BACKGROUND LOGIC:
            - Connecting + Video: Show local camera (to check yourself)
            - Connected + Video: Show remote camera
            - Audio Call: Show blurred avatar
        */}
        <PremiumVideoTile
          stream={
            isConnected 
              ? (remoteStream || null) 
              : (isConnecting && isVideoCall ? (localStream || null) : null)
          }
          displayName={peerName}
          avatarUrl={peerAvatar || undefined}
          isCameraOn={
            isConnected 
              ? isRemoteCameraOn 
              : (isConnecting && isVideoCall ? isCameraOn : false)
          }
          isMicOn={true}
          isLocal={isConnecting && isVideoCall} // Mirror if showing local cam as background
          statusText={isFailed ? 'Cuộc gọi thất bại' : undefined}
          size="full"
          hideCentralIdentity={isConnecting && isVideoCall} // New prop to hide center info
        />

        {/* ── TOP CENTER IDENTITY (For Video Call Connecting state) ── */}
        {isConnecting && isVideoCall && (
          <div className="absolute top-12 left-1/2 -translate-x-1/2 z-40 flex flex-col items-center gap-2 animate-in fade-in slide-in-from-top-4 duration-700">
            <div className="w-16 h-16 rounded-full border-2 border-white/20 overflow-hidden shadow-2xl">
              {peerAvatar ? (
                <img src={peerAvatar} alt="" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-blue-500 to-blue-700 flex items-center justify-center text-white text-xl font-bold">
                  {peerName[0].toUpperCase() || 'P'}
                </div>
              )}
            </div>
            <span className="text-white text-sm font-medium drop-shadow-lg animate-pulse">
              Đang đổ chuông...
            </span>
          </div>
        )}

        {/* ── LOCAL VIDEO PIP (For Connected Video Calls) ── */}
        {showLocalPiP && (
          <div
            className="absolute top-6 right-6 z-40 rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-black"
            style={{ width: 140, height: 210 }}
          >
            <PremiumVideoTile
              stream={localStream || null}
              displayName="Bạn"
              avatarUrl={localAvatar}
              isCameraOn={isCameraOn}
              isMicOn={isMicOn}
              isLocal={true}
              size="full"
            />
            {!isMicOn && (
              <div className="absolute bottom-2 left-2 w-6 h-6 rounded-full bg-[#FF3B30] flex items-center justify-center shadow-lg z-50">
                <MicOff size={12} className="text-white" />
              </div>
            )}
          </div>
        )}

        {/* ── TOP OVERLAY (Timer & Encryption - Visible when connected) ── */}
        <div className="absolute top-0 left-0 right-0 z-30 flex flex-col items-center pt-8">
          {isConnected && (
            <div className="flex flex-col items-center gap-1">
              <div className="bg-black/20 backdrop-blur-md px-4 py-1 rounded-full border border-white/5">
                <span className="text-white font-mono text-lg font-medium tracking-tight">
                  {formatTime(seconds)}
                </span>
              </div>
              <div className="flex items-center gap-1 opacity-40">
                <ShieldCheck size={10} className="text-white" />
                <span className="text-white text-[9px] uppercase tracking-widest font-bold">
                  Mã hóa đầu cuối
                </span>
              </div>
            </div>
          )}
        </div>

        {/* ── ERROR OVERLAY ── */}
        {error && (
          <div className="absolute top-24 left-1/2 -translate-x-1/2 z-40 bg-[#FF3B30]/90 backdrop-blur-xl px-6 py-3 rounded-2xl text-white text-sm font-semibold shadow-2xl border border-white/10">
            {error}
          </div>
        )}
      </div>

      {/* ── CONTROL BAR ── */}
      <div className="relative z-50 px-6 pb-8 pt-4 bg-gradient-to-t from-black/80 to-transparent">
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
  )
}
