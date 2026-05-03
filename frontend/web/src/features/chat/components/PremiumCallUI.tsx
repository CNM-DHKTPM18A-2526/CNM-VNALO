import React, { useEffect, useRef } from 'react'
import { 
  Mic, MicOff, Video, VideoOff, PhoneOff, 
  Maximize2, Minimize2, 
  PhoneIncoming
} from 'lucide-react'
import { resolveMediaUrl } from '../../../utils/mediaUtils'

// ─────────────────────────────────────────────────────────────────
// 1. PREMIUM VIDEO TILE
// ─────────────────────────────────────────────────────────────────

interface PremiumVideoTileProps {
  stream: MediaStream | null
  displayName: string
  avatarUrl?: string | null
  isMicOn: boolean
  isCameraOn: boolean
  isLocal?: boolean
  isSpeaking?: boolean
  size?: 'sm' | 'md' | 'lg' | 'full'
}

export const PremiumVideoTile: React.FC<PremiumVideoTileProps> = ({
  stream,
  displayName,
  avatarUrl,
  isMicOn,
  isCameraOn,
  isLocal = false,
  isSpeaking = false,
  size = 'md'
}) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const resolvedAvatar = avatarUrl ? resolveMediaUrl(avatarUrl) : null

  useEffect(() => {
    if (videoRef.current && stream && isCameraOn) {
      videoRef.current.srcObject = stream
    }
  }, [stream, isCameraOn])

  const initials = displayName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()

  return (
    <div className={`relative overflow-hidden rounded-3xl bg-[#131313]/60 backdrop-blur-md border border-white/10 shadow-2xl transition-all duration-500 ${isSpeaking ? 'ring-2 ring-[#22C55E] shadow-[0_0_30px_rgba(34,197,94,0.3)]' : ''} ${size === 'full' ? 'w-full h-full' : 'aspect-[3/4] sm:aspect-video'}`}>
      {/* Background Blur */}
      {!isCameraOn && (
        <div className="absolute inset-0 z-0">
          {resolvedAvatar ? (
            <img src={resolvedAvatar} alt="" className="w-full h-full object-cover blur-2xl opacity-40 scale-110" />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-[#131313] to-[#000000]" />
          )}
          <div className="absolute inset-0 bg-black/20" />
        </div>
      )}

      {/* Video Content */}
      {isCameraOn && stream ? (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted={isLocal}
          className={`absolute inset-0 w-full h-full object-cover z-10 ${isLocal ? 'scale-x-[-1]' : ''}`}
        />
      ) : (
        <div className="relative z-20 flex flex-col items-center justify-center h-full gap-4">
          <div className="relative">
            {resolvedAvatar ? (
              <img src={resolvedAvatar} alt={displayName} className="w-24 h-24 rounded-full object-cover border-4 border-white/20 shadow-2xl" />
            ) : (
              <div className="w-24 h-24 rounded-full bg-gradient-to-br from-[#007BFF] to-[#0050CC] flex items-center justify-center text-white text-3xl font-bold border-4 border-white/20 shadow-2xl">
                {initials}
              </div>
            )}
            {isSpeaking && (
               <div className="absolute -inset-2 rounded-full border-2 border-[#22C55E] animate-ping opacity-50" />
            )}
          </div>
        </div>
      )}

      {/* Info Overlay */}
      <div className="absolute bottom-4 left-4 right-4 z-30 flex items-center justify-between">
        <div className="px-3 py-1.5 rounded-full bg-black/40 backdrop-blur-md border border-white/10 flex items-center gap-2">
          <span className="text-white text-xs font-semibold">{isLocal ? 'Bạn' : displayName}</span>
          {!isMicOn && <MicOff size={12} className="text-red-400" />}
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 2. PREMIUM CALL CONTROLS
// ─────────────────────────────────────────────────────────────────

interface PremiumCallControlsProps {
  isMicOn: boolean
  isCameraOn: boolean
  isAudioOnly?: boolean
  isMinimized?: boolean
  onToggleMic: () => void
  onToggleCamera: () => void
  onEnd: () => void
  onMinimize?: () => void
  onMaximize?: () => void
}

export const PremiumCallControls: React.FC<PremiumCallControlsProps> = ({
  isMicOn,
  isCameraOn,
  isAudioOnly = false,
  isMinimized = false,
  onToggleMic,
  onToggleCamera,
  onEnd,
  onMinimize,
  onMaximize
}) => {
  return (
    <div className={`flex items-center gap-4 px-6 py-4 rounded-full backdrop-blur-2xl bg-black/40 border border-white/10 shadow-[0_20px_50px_rgba(0,0,0,0.5)] transition-all duration-500 ${isMinimized ? 'scale-75' : ''}`}>
      {!isAudioOnly && (
        <button
          onClick={onToggleCamera}
          className={`p-4 rounded-full transition-all duration-300 ${
            !isCameraOn ? 'bg-[#EF4444] text-white' : 'bg-white/10 hover:bg-white/20 text-white'
          } border border-white/5 shadow-lg active:scale-90`}
          title={isCameraOn ? 'Tắt camera' : 'Bật camera'}
        >
          {isCameraOn ? <Video size={24} /> : <VideoOff size={24} />}
        </button>
      )}

      <button
        onClick={onToggleMic}
        className={`p-4 rounded-full transition-all duration-300 ${
          !isMicOn ? 'bg-[#EF4444] text-white' : 'bg-white/10 hover:bg-white/20 text-white'
        } border border-white/5 shadow-lg active:scale-90`}
        title={isMicOn ? 'Tắt mic' : 'Bật mic'}
      >
        {isMicOn ? <Mic size={24} /> : <MicOff size={24} />}
      </button>

      <button
        onClick={onEnd}
        className="p-4 rounded-full bg-[#EF4444] hover:bg-[#D32F2F] text-white transition-all duration-300 shadow-[0_10px_30px_rgba(239,68,68,0.4)] active:scale-90"
        title="Kết thúc cuộc gọi"
      >
        <PhoneOff size={24} />
      </button>

      {onMinimize && !isMinimized && (
        <button
          onClick={onMinimize}
          className="w-12 h-12 rounded-full bg-white/10 text-white flex items-center justify-center hover:bg-white/20 transition-all"
          title="Thu nhỏ"
        >
          <Minimize2 size={20} />
        </button>
      )}

      {onMaximize && isMinimized && (
        <button
          onClick={onMaximize}
          className="w-12 h-12 rounded-full bg-white/10 text-white flex items-center justify-center hover:bg-white/20 transition-all"
          title="Phóng to"
        >
          <Maximize2 size={20} />
        </button>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 3. INCOMING CALL BANNER (NON-DISRUPTIVE)
// ─────────────────────────────────────────────────────────────────

interface IncomingCallBannerProps {
  peerName: string
  peerAvatar?: string | null
  isGroup?: boolean
  conversationName?: string
  isAudioOnly?: boolean
  onAnswer: () => void
  onDecline: () => void
}

export const IncomingCallBanner: React.FC<IncomingCallBannerProps> = ({
  peerName,
  peerAvatar,
  isGroup = false,
  conversationName,
  isAudioOnly = false,
  onAnswer,
  onDecline
}) => {
  const resolvedAvatar = peerAvatar ? resolveMediaUrl(peerAvatar) : null

  return (
    <div className="fixed top-6 right-6 z-[1000] w-80 animate-in fade-in slide-in-from-right-10 duration-500">
      <div className="bg-[#131313]/95 backdrop-blur-2xl border border-[#007BFF]/40 rounded-3xl p-5 shadow-[0_20px_50px_rgba(0,0,0,0.6)] flex flex-col gap-4">
        <div className="flex items-center gap-4">
          <div className="relative">
            {resolvedAvatar ? (
              <img src={resolvedAvatar} alt="" className="w-14 h-14 rounded-full object-cover border-2 border-[#007BFF]/30" />
            ) : (
              <div className="w-14 h-14 rounded-full bg-gradient-to-br from-[#007BFF] to-[#0050CC] flex items-center justify-center text-white font-bold shadow-lg">
                {peerName[0].toUpperCase()}
              </div>
            )}
            <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-[#22C55E] rounded-full flex items-center justify-center border-2 border-[#131313] shadow-sm">
               <PhoneIncoming size={12} className="text-white animate-pulse" />
            </div>
          </div>
          
          <div className="flex-1 overflow-hidden">
            <p className="text-white font-bold truncate text-lg tracking-tight">{isGroup ? conversationName : peerName}</p>
            <p className="text-[#00A2ED] text-xs font-semibold uppercase tracking-widest opacity-90">
              {isGroup ? `Nhóm • ${peerName}` : isAudioOnly ? 'Cuộc gọi thoại...' : 'Cuộc gọi video...'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={onDecline}
            className="flex-1 py-3 rounded-2xl bg-[#EF4444]/15 hover:bg-[#EF4444]/25 text-[#EF4444] text-sm font-bold transition-all border border-[#EF4444]/20 active:scale-95"
          >
            Từ chối
          </button>
          <button
            onClick={onAnswer}
            className="flex-[1.5] py-3 px-6 rounded-2xl bg-[#22C55E] hover:bg-[#1eb354] text-white text-sm font-extrabold transition-all shadow-[0_8px_20px_rgba(34,197,94,0.4)] animate-pulse hover:animate-none active:scale-95"
          >
            Trả lời
          </button>
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 4. MINI CALL WINDOW (PiP MODE)
// ─────────────────────────────────────────────────────────────────

interface MiniCallWindowProps {
  stream: MediaStream | null
  peerName: string
  peerAvatar?: string | null
  isCameraOn: boolean
  onMaximize: () => void
  onEnd: () => void
}

export const MiniCallWindow: React.FC<MiniCallWindowProps> = ({
  stream,
  peerName,
  peerAvatar,
  isCameraOn,
  onMaximize,
  onEnd
}) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const resolvedAvatar = peerAvatar ? resolveMediaUrl(peerAvatar) : null

  useEffect(() => {
    if (videoRef.current && stream && isCameraOn) {
      videoRef.current.srcObject = stream
    }
  }, [stream, isCameraOn])

  return (
    <div className="fixed bottom-6 right-6 z-[600] w-48 h-72 rounded-3xl overflow-hidden bg-[#000000] border border-[#007BFF]/20 shadow-[0_20px_50px_rgba(0,0,0,0.6)] group transition-transform hover:scale-105">
      {isCameraOn && stream ? (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          className="w-full h-full object-cover"
        />
      ) : (
        <div className="w-full h-full flex flex-col items-center justify-center gap-3 bg-gradient-to-b from-[#131313] to-[#000000]">
           {resolvedAvatar ? (
             <img src={resolvedAvatar} alt="" className="w-16 h-16 rounded-full border-2 border-white/5 shadow-lg" />
           ) : (
             <div className="w-16 h-16 rounded-full bg-[#007BFF] flex items-center justify-center text-white text-xl font-bold shadow-md">
               {peerName[0].toUpperCase()}
             </div>
           )}
           <span className="text-[#00A2ED]/70 text-[10px] font-bold truncate px-4 tracking-widest uppercase">{peerName}</span>
        </div>
      )}

      {/* Overlays */}
      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-4">
        <button onClick={onMaximize} className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white hover:bg-white/30">
          <Maximize2 size={18} />
        </button>
        <button onClick={onEnd} className="w-10 h-10 rounded-full bg-red-500 flex items-center justify-center text-white hover:bg-red-600">
          <PhoneOff size={18} />
        </button>
      </div>
    </div>
  )
}
