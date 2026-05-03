import React from 'react'
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
  error,
}) => {
  const [seconds, setSeconds] = React.useState(0)

  React.useEffect(() => {
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

  return (
    <div className="fixed inset-0 z-[500] bg-black flex flex-col overflow-hidden select-none">
      {/* ── IMMERSIVE BACKGROUND & VIDEO ── */}
      <div className="relative flex-1 w-full h-full flex items-center justify-center">
        {/* Remote Content (Video or Blurred Avatar) */}
        <PremiumVideoTile
          stream={remoteStream || null}
          displayName={peerName}
          avatarUrl={peerAvatar || undefined}
          isCameraOn={status === 'connected' ? isRemoteCameraOn : false}
          isMicOn={true}
          isSpeaking={false}
          statusText={status === 'connecting' ? 'Đang đổ chuông...' : undefined}
          size="full"
        />

        {/* Local Video Overlay (Zalo style: top-right) */}
        {status === 'connected' && (
          <div className="absolute top-10 right-10 w-44 h-64 z-40 rounded-2xl overflow-hidden border border-white/10 shadow-2xl animate-in fade-in zoom-in duration-700">
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

        {/* Top Centered Status/Time Info */}
        <div className="absolute top-12 left-1/2 -translate-x-1/2 z-30 flex flex-col items-center gap-3">
          {status === 'connected' ? (
            <div className="bg-black/30 backdrop-blur-xl px-5 py-2 rounded-full border border-white/10 text-white font-mono text-xl shadow-lg animate-fade-in">
              {formatTime(seconds)}
            </div>
          ) : (
             <div className="flex flex-col items-center animate-pulse">
                <span className="text-white/40 text-xs font-bold uppercase tracking-[0.2em] mb-1">Mã hóa đầu cuối</span>
                <span className="text-white/60 text-[10px]">Cuộc gọi đang được bảo mật</span>
             </div>
          )}
          {error && (
            <div className="bg-red-500/90 backdrop-blur-xl px-6 py-3 rounded-xl text-white text-sm font-semibold border border-red-400/30 shadow-2xl">
              {error}
            </div>
          )}
        </div>
      </div>

      {/* ── DOCKED TRANSLUCENT BOTTOM BAR ── */}
      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-black/90 via-black/40 to-transparent flex items-center justify-center z-50 pb-8 px-10">
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
