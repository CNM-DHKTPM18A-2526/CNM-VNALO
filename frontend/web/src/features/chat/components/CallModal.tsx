import React from 'react'
import { ShieldCheck, Loader2, MicOff } from 'lucide-react'
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
    let interval: any
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
  const showLocalVideo = (type === 'video' || isCameraOn) && !isFailed
  const showLocalPiP = isConnected && showLocalVideo && localStream

  return (
    <div className="fixed inset-0 z-[500] bg-black flex flex-col overflow-hidden select-none">
      {/* ── REMOTE CONTENT (full screen) ── */}
      <div className="relative flex-1 w-full h-full flex items-center justify-center">
        {/* PremiumVideoTile handles both video AND avatar background automatically.
            Pass remoteStream: it shows video when stream+camera is on, blurred avatar otherwise. */}
        <PremiumVideoTile
          stream={isConnected ? (remoteStream || null) : null}
          displayName={peerName}
          avatarUrl={peerAvatar || undefined}
          isCameraOn={isConnected ? isRemoteCameraOn : false}
          isMicOn={true}
          statusText={isConnecting ? 'Đang đổ chuông...' : isFailed ? 'Cuộc gọi thất bại' : undefined}
          size="full"
        />

        {/* ── LOCAL VIDEO PIP (top-right, 16:9, shown only when connected) ── */}
        {showLocalPiP && (
          <div
            className="absolute top-4 right-4 z-40 rounded-2xl overflow-hidden border border-white/15 shadow-2xl"
            style={{ width: 120, height: 67.5 }}
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
            {/* Mic muted badge */}
            {!isMicOn && (
              <div className="absolute bottom-1.5 left-1.5 w-5 h-5 rounded-full bg-[#FF3B30] flex items-center justify-center shadow-lg z-50">
                <MicOff size={10} className="text-white" />
              </div>
            )}
          </div>
        )}

        {/* ── TOP STATUS BAR ── */}
        <div className="absolute top-0 left-0 right-0 z-30 flex items-center justify-center pt-5 pb-3">
          <div className="flex flex-col items-center gap-0.5">
            {isConnected ? (
              <>
                {/* Duration timer pill */}
                <div className="bg-black/50 backdrop-blur-2xl px-5 py-1.5 rounded-full border border-white/[0.08] shadow-2xl">
                  <span className="text-white font-mono text-[18px] font-semibold tracking-wider drop-shadow-lg">
                    {formatTime(seconds)}
                  </span>
                </div>
                {/* Encryption indicator */}
                <div className="flex items-center gap-1 mt-0.5">
                  <ShieldCheck size={11} className="text-white/40" />
                  <span className="text-white/40 text-[10px] uppercase tracking-widest font-medium">
                    Mã hóa đầu cuối
                  </span>
                </div>
              </>
            ) : isConnecting ? (
              <div className="flex items-center gap-2">
                <Loader2 size={14} className="text-white/50 animate-spin" />
                <span className="text-white/50 text-xs uppercase tracking-widest font-medium">
                  Đang kết nối...
                </span>
              </div>
            ) : null}
          </div>
        </div>

        {/* ── ERROR BANNER ── */}
        {error && (
          <div className="absolute top-20 left-1/2 -translate-x-1/2 z-40 bg-[#FF3B30]/95 backdrop-blur-xl px-6 py-3 rounded-2xl text-white text-sm font-semibold border border-white/10 shadow-2xl max-w-xs text-center">
            {error}
          </div>
        )}
      </div>

      {/* ── GLASSMORPHISM DOCKED BOTTOM BAR ── */}
      <div className="relative z-50 px-4 pb-6 pt-2">
        {/* Backdrop gradient */}
        <div className="absolute inset-0 -mt-4 bg-gradient-to-t from-black/90 via-black/40 to-transparent pointer-events-none rounded-t-3xl" />

        <div className="relative">
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
