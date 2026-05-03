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
    <div className="fixed inset-0 z-[500] bg-black flex flex-col overflow-hidden">
      {/* ── MAIN CONTENT (Immersive Video) ── */}
      <div className="relative flex-1 w-full h-full">
        {/* Remote Video Tile (Full Screen) */}
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
        {type === 'video' && status === 'connected' && (
          <div className="absolute top-8 right-8 w-40 h-60 z-40 rounded-xl overflow-hidden border border-white/20 shadow-2xl animate-in fade-in zoom-in duration-500">
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

        {/* Top Info (Time/Status) */}
        <div className="absolute top-10 left-1/2 -translate-x-1/2 z-30 flex flex-col items-center gap-2">
          {status === 'connected' && (
            <div className="bg-black/20 backdrop-blur-md px-4 py-1 rounded-full border border-white/10 text-white font-mono text-lg">
              {formatTime(seconds)}
            </div>
          )}
          {error && (
            <div className="bg-red-500/80 backdrop-blur-md px-4 py-2 rounded-lg text-white text-sm font-medium border border-red-400/50">
              {error}
            </div>
          )}
        </div>
      </div>

      {/* ── DOCKED BOTTOM BAR ── */}
      <div className="h-[110px] bg-[#131313] border-t border-white/5 flex items-center justify-center relative z-50">
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
