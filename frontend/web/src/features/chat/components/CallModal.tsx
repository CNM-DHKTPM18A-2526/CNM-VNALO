import React from 'react'
import {
  Mic, MicOff, Video, VideoOff, PhoneOff,
  Volume2, Phone, Maximize2
} from 'lucide-react'
import {
  PremiumVideoTile,
  PremiumCallControls,
} from './PremiumCallUI'
import { resolveMediaUrl } from '../../../utils/mediaUtils'

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
  localAvatar,
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
    let interval: ReturnType<typeof setInterval>
    if (status === 'connected') {
      interval = setInterval(() => setSeconds(s => s + 1), 1000)
    } else {
      setSeconds(0)
    }
    return () => clearInterval(interval)
  }, [status])

  if (!isOpen) return null

  const formatTime = (t: number) =>
    `${Math.floor(t / 60).toString().padStart(2, '0')}:${(t % 60).toString().padStart(2, '0')}`

  const isVideo = type === 'video'
  const isConnecting = status === 'connecting'
  const isFailed = status === 'failed'

  return (
    <div className="fixed inset-0 z-[500] bg-black flex flex-col overflow-hidden select-none">

      {/* ── FULL-SCREEN BACKGROUND (Blurred avatar or video) ── */}
      <div className="absolute inset-0 z-0">
        <PremiumVideoTile
          stream={remoteStream || null}
          displayName={peerName}
          avatarUrl={peerAvatar || undefined}
          isCameraOn={status === 'connected' ? isRemoteCameraOn : false}
          isMicOn={true}
          isSpeaking={false}
          statusText={isConnecting ? 'Đang kết nối...' : undefined}
          size="full"
          showPulse={isConnecting}
        />
      </div>

      {/* ── LOCAL VIDEO PREVIEW (PiP, top-right corner) ── */}
      {isVideo && (
        <div
          className="absolute top-4 right-4 z-40 rounded-2xl overflow-hidden border border-white/15 shadow-[0_8px_32px_rgba(0,0,0,0.6)] transition-all duration-500"
          style={{ width: 140, height: 200 }}
        >
          <PremiumVideoTile
            stream={localStream || null}
            displayName="Bạn"
            avatarUrl={localAvatar || undefined}
            isCameraOn={isCameraOn}
            isMicOn={isMicOn}
            isSpeaking={false}
            isLocal={true}
            size="full"
          />
          {/* Maximize button */}
          {onMinimize && (
            <button
              onClick={onMinimize}
              className="absolute bottom-2 right-2 w-7 h-7 rounded-full bg-black/50 backdrop-blur-sm flex items-center justify-center text-white/70 hover:text-white hover:bg-black/70 transition-all"
            >
              <Maximize2 size={12} />
            </button>
          )}
        </div>
      )}

      {/* ── TOP: CALLER INFO (only during connecting) ── */}
      {isConnecting && !isVideo && (
        <div className="absolute top-16 left-1/2 -translate-x-1/2 z-30 flex flex-col items-center gap-2">
          {/* Avatar with pulse */}
          <div className="relative">
            <div className="absolute inset-0 rounded-full bg-white/10 animate-ping" style={{ width: 130, height: 130, inset: -5, animationDuration: '2s' }} />
            <div className="absolute inset-0 rounded-full bg-white/5 animate-ping" style={{ width: 160, height: 160, inset: -20, animationDuration: '2s', animationDelay: '0.6s' }} />
            <div
              className="relative rounded-full border-[1.5px] border-white/40 overflow-hidden shadow-[0_0_60px_rgba(0,0,0,0.8)] bg-[#1a1a2e] flex items-center justify-center"
              style={{ width: 120, height: 120 }}
            >
              {peerAvatar ? (
                <img src={resolveMediaUrl(peerAvatar)} alt={peerName} className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-[#0088FF] to-[#0044CC] flex items-center justify-center">
                  <span className="text-white text-[40px] font-bold">
                    {peerName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
                  </span>
                </div>
              )}
            </div>
          </div>
          {/* Name */}
          <h2 className="text-white text-[22px] font-semibold tracking-tight drop-shadow-2xl">{peerName}</h2>
          {/* Status */}
          <span className="text-white/50 text-xs font-light tracking-widest uppercase animate-pulse">
            Đang kết nối...
          </span>
        </div>
      )}

      {/* ── TOP: TIMER (when connected) ── */}
      {status === 'connected' && (
        <div className="absolute top-16 left-1/2 -translate-x-1/2 z-30">
          <div className="bg-black/50 backdrop-blur-2xl px-6 py-2.5 rounded-full border border-white/10 shadow-2xl">
            <span className="text-white font-mono text-[20px] font-medium tracking-wider">
              {formatTime(seconds)}
            </span>
          </div>
        </div>
      )}

      {/* ── TOP: ERROR ── */}
      {error && (
        <div className="absolute top-16 left-1/2 -translate-x-1/2 z-50">
          <div className="bg-[#FF3B30]/90 backdrop-blur-xl px-6 py-3 rounded-2xl border border-[#FF3B30]/50 shadow-2xl flex items-center gap-2">
            <PhoneOff size={16} className="text-white shrink-0" />
            <span className="text-white text-sm font-medium">{error}</span>
          </div>
        </div>
      )}

      {/* ── BOTTOM: ZALO-STYLE CONTROL BAR ── */}
      <div className="absolute bottom-0 left-0 right-0 z-50 pb-10 pt-4 px-6">
        {/* Glass backdrop — Zalo uses a frosted glass panel */}
        <div className="absolute inset-0 bg-black/60 backdrop-blur-2xl -z-10" />
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-transparent -z-10" />

        <div className="flex items-center justify-center gap-3">

          {/* ── LOA (Speaker) ── */}
          <div className="flex flex-col items-center gap-1">
            <button
              onClick={onToggleMic}
              className="w-14 h-14 rounded-full bg-white/10 hover:bg-white/20 active:scale-90 flex items-center justify-center transition-all border border-white/10 shadow-lg"
            >
              <Volume2 size={22} className="text-white" />
            </button>
            <span className="text-white/60 text-[10px] font-medium tracking-wide">Loa</span>
          </div>

          {/* ── END CALL (Center, Red) ── */}
          <button
            onClick={onEnd}
            className="w-16 h-16 rounded-full bg-[#FF3B30] hover:bg-[#E03328] active:scale-90 flex items-center justify-center shadow-[0_0_35px_rgba(255,59,48,0.5)] border border-white/10 transition-all mx-2"
          >
            <PhoneOff size={28} className="text-white" />
          </button>

          {/* ── MIC ── */}
          <div className="flex flex-col items-center gap-1">
            <button
              onClick={onToggleMic}
              className={`w-14 h-14 rounded-full active:scale-90 flex items-center justify-center transition-all border border-white/10 shadow-lg ${
                isMicOn ? 'bg-white/10 hover:bg-white/20' : 'bg-[#FF3B30] hover:bg-[#E03328]'
              }`}
            >
              {isMicOn ? <Mic size={22} className="text-white" /> : <MicOff size={22} className="text-white" />}
            </button>
            <span className="text-white/60 text-[10px] font-medium tracking-wide">
              {isMicOn ? 'Mic' : 'Tắt mic'}
            </span>
          </div>
        </div>

        {/* ── SECONDARY CONTROLS (Camera, Minimize) ── */}
        {isVideo && (
          <div className="flex items-center justify-center gap-3 mt-4">
            <button
              onClick={onToggleCamera}
              className={`w-12 h-12 rounded-full active:scale-90 flex items-center justify-center transition-all border border-white/10 shadow-lg ${
                isCameraOn ? 'bg-white/10 hover:bg-white/20' : 'bg-[#FF3B30] hover:bg-[#E03328]'
              }`}
            >
              {isCameraOn ? <Video size={20} className="text-white" /> : <VideoOff size={20} className="text-white" />}
            </button>

            {onMinimize && (
              <button
                onClick={onMinimize}
                className="w-12 h-12 rounded-full bg-white/10 hover:bg-white/20 active:scale-90 flex items-center justify-center transition-all border border-white/10 shadow-lg text-white/60 hover:text-white"
              >
                <Maximize2 size={18} />
              </button>
            )}
          </div>
        )}
      </div>

    </div>
  )
}
