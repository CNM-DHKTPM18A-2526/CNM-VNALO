import React from 'react'
import { 
  Mic, MicOff, Video, VideoOff, PhoneOff, 
  Maximize2, Minimize2, 
  Phone
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
  statusText?: string
}

export const PremiumVideoTile: React.FC<PremiumVideoTileProps> = ({
  stream,
  displayName,
  avatarUrl,
  isMicOn,
  isCameraOn,
  isLocal = false,
  isSpeaking = false,
  size = 'md',
  statusText
}) => {
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const resolvedAvatar = avatarUrl ? resolveMediaUrl(avatarUrl) : null

  React.useEffect(() => {
    if (videoRef.current && stream && isCameraOn) {
      videoRef.current.srcObject = stream
    }
  }, [stream, isCameraOn])

  const initials = displayName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()

  return (
    <div className={`relative overflow-hidden bg-[#1C1C2E] transition-all duration-500 ${isSpeaking ? 'ring-2 ring-[#22C55E]' : ''} ${size === 'full' ? 'w-full h-full' : 'w-full h-full'}`}>
      {/* Background Blur */}
      {!isCameraOn && (
        <div className="absolute inset-0 z-0 bg-[#1C1C2E]">
          {resolvedAvatar ? (
            <img src={resolvedAvatar} alt="" className="w-full h-full object-cover blur-2xl opacity-40 scale-110" />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-[#1C1C2E] to-[#131313]" />
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
              <img src={resolvedAvatar} alt={displayName} className="w-24 h-24 rounded-full object-cover shadow-2xl" />
            ) : (
              <div className="w-24 h-24 rounded-full bg-gradient-to-br from-[#007BFF] to-[#0050CC] flex items-center justify-center text-white text-3xl font-bold shadow-2xl">
                {initials}
              </div>
            )}
            {isSpeaking && (
               <div className="absolute -inset-2 rounded-full border-2 border-[#22C55E] animate-ping opacity-50" />
            )}
          </div>
          {statusText && (
            <span className="text-white/80 text-sm font-medium animate-pulse drop-shadow-md">
              {statusText}
            </span>
          )}
        </div>
      )}

      {/* Info Overlay */}
      <div className="absolute bottom-4 left-4 right-4 z-30 flex flex-col gap-1">
        <div className="flex items-center gap-2">
          <span className="text-white text-sm font-semibold drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]">
            {isLocal ? 'Bạn' : displayName}
          </span>
          {!isMicOn && <MicOff size={14} className="text-red-500 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]" />}
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
    <div className="fixed bottom-5 right-5 z-[1000] w-[320px] animate-in slide-in-from-bottom-10 duration-300 ease-out">
      <div className="bg-[#1C1C2E]/98 backdrop-blur-xl rounded-2xl p-4 shadow-[0_8px_32px_rgba(0,0,0,0.6)] flex flex-col gap-4 border border-white/5">
        
        {/* Header - Avatar & Info */}
        <div className="flex items-center gap-3">
          <div className="relative">
            {resolvedAvatar ? (
              <img src={resolvedAvatar} alt="" className="w-12 h-12 rounded-full object-cover" />
            ) : (
              <div className="w-12 h-12 rounded-full bg-blue-500 flex items-center justify-center text-white text-lg font-semibold">
                {peerName[0].toUpperCase()}
              </div>
            )}
          </div>
          
          <div className="flex-1 overflow-hidden">
            <p className="text-white font-semibold truncate text-[14px]">
              {isGroup && conversationName ? conversationName : peerName}
            </p>
            <p className="text-gray-400 text-[12px] truncate">
              {isGroup ? `Nhóm • ${peerName}` : isAudioOnly ? 'Cuộc gọi thoại đến...' : 'Cuộc gọi video đến...'}
            </p>
          </div>

          <button onClick={onDecline} className="w-6 h-6 flex items-center justify-center rounded-full bg-white/10 text-gray-400 hover:text-white hover:bg-white/20 transition-colors">
            <span className="text-lg leading-none mt-[-2px]">&times;</span>
          </button>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center justify-center gap-4 mt-2">
          <button
            onClick={onDecline}
            className="w-12 h-12 rounded-full bg-[#FF3B30] hover:bg-[#e03328] flex items-center justify-center text-white transition-transform active:scale-90"
            title="Từ chối"
          >
            <PhoneOff size={22} />
          </button>

          {!isAudioOnly && (
            <button
              onClick={() => {
                // If we need a 'no camera' option, it should technically set camera off before answering.
                // For now, it invokes onAnswer. We might need to pass an additional callback later.
                onAnswer()
              }}
              className="w-12 h-12 rounded-full bg-[#3A3A3C] hover:bg-[#4a4a4d] flex items-center justify-center text-white transition-transform active:scale-90"
              title="Trả lời không có camera"
            >
              <VideoOff size={22} />
            </button>
          )}

          <button
            onClick={onAnswer}
            className="w-12 h-12 rounded-full bg-[#34C759] hover:bg-[#2eaa4e] flex items-center justify-center text-white transition-transform active:scale-90"
            title="Trả lời"
          >
            <Phone size={22} />
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
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const resolvedAvatar = peerAvatar ? resolveMediaUrl(peerAvatar) : null

  React.useEffect(() => {
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
