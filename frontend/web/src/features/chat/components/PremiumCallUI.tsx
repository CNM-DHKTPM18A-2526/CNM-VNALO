import React from 'react'
import {
  Mic, MicOff, Video, VideoOff, PhoneOff,
  Volume2, Phone, X, ShieldCheck
} from 'lucide-react'
import { resolveMediaUrl } from '../../../utils/mediaUtils'

// ─────────────────────────────────────────────────────────────────
// 1. PREMIUM VIDEO TILE
// Renders: blurred avatar background, video stream, or avatar overlay.
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
  showPulse?: boolean     // show concentric pulse rings on avatar
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
  statusText,
  showPulse = false
}) => {
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const resolvedAvatar = avatarUrl ? resolveMediaUrl(avatarUrl) : null

  React.useEffect(() => {
    if (videoRef.current && stream && isCameraOn) {
      videoRef.current.srcObject = stream
    }
  }, [stream, isCameraOn])

  const initials = displayName
    .split(' ')
    .map(n => n[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()

  // 120px avatar — Zalo standard for call screens
  const AVATAR_SIZE = 120

  return (
    <div className="relative w-full h-full overflow-hidden bg-[#0a0a0b] flex items-center justify-center select-none">
      {/* ── PERSISTENT BLURRED BACKGROUND ── */}
      <div className="absolute inset-0 z-0 overflow-hidden">
        {resolvedAvatar ? (
          <div className="relative w-full h-full">
            <img
              src={resolvedAvatar}
              alt=""
              className="w-full h-full object-cover blur-[120px] opacity-50 scale-150 transform-gpu"
            />
            <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-black/20 to-black/60" />
          </div>
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-[#1a1a2e] via-[#0f0f1a] to-[#0a0a0b]" />
        )}
      </div>

      {/* ── VIDEO CONTENT ── */}
      {isCameraOn && stream && (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted={isLocal}
          className={`absolute inset-0 w-full h-full object-cover z-10 ${
            isLocal ? 'scale-x-[-1]' : ''
          }`}
        />
      )}

      {/* ── AVATAR + NAME OVERLAY ── */}
      {(!isCameraOn || !stream) && (
        <div className="relative z-20 flex flex-col items-center justify-center">
          {/* Pulse rings */}
          {showPulse && (
            <>
              <div
                className="absolute rounded-full border border-white/[0.05] animate-ping"
                style={{
                  width: AVATAR_SIZE + 40,
                  height: AVATAR_SIZE + 40,
                  inset: '-20px',
                  animationDuration: '2.4s',
                }}
              />
              <div
                className="absolute rounded-full border border-white/[0.03] animate-ping"
                style={{
                  width: AVATAR_SIZE + 72,
                  height: AVATAR_SIZE + 72,
                  inset: '-36px',
                  animationDuration: '2.4s',
                  animationDelay: '0.8s',
                }}
              />
              <div
                className="absolute rounded-full border border-white/[0.02] animate-ping"
                style={{
                  width: AVATAR_SIZE + 104,
                  height: AVATAR_SIZE + 104,
                  inset: '-52px',
                  animationDuration: '2.4s',
                  animationDelay: '1.6s',
                }}
              />
            </>
          )}

          {/* Avatar: 120px, 1.5px white border, deep shadow */}
          <div
            className="rounded-full border-[1.5px] border-white/40 overflow-hidden shadow-[0_0_60px_rgba(0,0,0,0.8),0_8px_32px_rgba(0,0,0,0.5)] relative z-10 bg-[#1a1a2e] flex items-center justify-center"
            style={{ width: AVATAR_SIZE, height: AVATAR_SIZE }}
          >
            {resolvedAvatar ? (
              <img src={resolvedAvatar} alt={displayName} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full bg-gradient-to-br from-[#0088FF] to-[#0044CC] flex items-center justify-center">
                <span className="text-white text-[40px] font-bold tracking-tight">{initials}</span>
              </div>
            )}
          </div>

          {/* Name */}
          <h3 className="text-white text-[22px] font-semibold mt-6 tracking-tight drop-shadow-2xl">
            {isLocal ? 'Bạn' : displayName}
          </h3>

          {/* Status */}
          {statusText ? (
            <div className="flex items-center gap-1.5 mt-1.5">
              <ShieldCheck size={12} className="text-white/40" />
              <span className="text-white/50 text-xs font-light tracking-widest uppercase animate-pulse">
                {statusText}
              </span>
            </div>
          ) : (
            <div className="flex items-center gap-1.5 mt-1.5">
              <ShieldCheck size={12} className="text-white/30" />
              <span className="text-white/30 text-xs font-light tracking-widest uppercase">
                Mã hóa đầu cuối
              </span>
            </div>
          )}
        </div>
      )}

      {/* ── NAME + MIC BADGE (visible when video is on) ── */}
      {isCameraOn && stream && (
        <div className="absolute bottom-8 left-8 z-30 flex items-center gap-2.5 bg-black/50 backdrop-blur-2xl px-4 py-2 rounded-2xl border border-white/[0.08] shadow-2xl">
          {!isMicOn && (
            <div className="w-5 h-5 rounded-full bg-[#FF3B30] flex items-center justify-center">
              <MicOff size={10} className="text-white" />
            </div>
          )}
          <span className="text-white text-sm font-medium drop-shadow-lg">
            {isLocal ? 'Bạn' : displayName}
          </span>
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 2. PREMIUM CALL CONTROLS (Zalo Glass Panel)
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

// 44px touch target (Apple HIG / Zalo standard)
const BTN = 44

export const PremiumCallControls: React.FC<PremiumCallControlsProps> = ({
  isMicOn,
  isCameraOn,
  isAudioOnly = false,
  onToggleMic,
  onToggleCamera,
  onEnd,
  onMinimize,
}) => {
  const micOff = !isMicOn
  const camOff = !isCameraOn

  return (
    <div className="flex items-center justify-center gap-4">
      {/* Speaker / Audio output toggle */}
      <button
        onClick={onToggleMic}
        title={isMicOn ? 'Tắt micro' : 'Bật micro'}
        className={`relative flex items-center justify-center rounded-full transition-all active:scale-90 ${
          micOff ? 'bg-[#FF3B30] hover:bg-[#E03328]' : 'bg-white/15 hover:bg-white/25'
        } border border-white/10 shadow-lg`}
        style={{ width: BTN, height: BTN }}
      >
        {isMicOn ? <Mic size={20} className="text-white" /> : <MicOff size={20} className="text-white" />}
      </button>

      {/* END CALL — red, largest */}
      <button
        onClick={onEnd}
        title="Kết thúc"
        className="rounded-full bg-[#FF3B30] hover:bg-[#E03328] active:scale-90 flex items-center justify-center shadow-[0_0_30px_rgba(255,59,48,0.5)] border border-white/10 transition-all"
        style={{ width: BTN + 16, height: BTN + 16 }}
      >
        <PhoneOff size={26} className="text-white" />
      </button>

      {/* Camera toggle */}
      {!isAudioOnly && (
        <button
          onClick={onToggleCamera}
          title={isCameraOn ? 'Tắt camera' : 'Bật camera'}
          className={`relative flex items-center justify-center rounded-full transition-all active:scale-90 ${
            camOff ? 'bg-[#FF3B30] hover:bg-[#E03328]' : 'bg-white/15 hover:bg-white/25'
          } border border-white/10 shadow-lg`}
          style={{ width: BTN, height: BTN }}
        >
          {isCameraOn ? <Video size={20} className="text-white" /> : <VideoOff size={20} className="text-white" />}
        </button>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 3. INCOMING CALL BANNER (Zalo Design — Toast, bottom-right)
// ─────────────────────────────────────────────────────────────────

interface IncomingCallBannerProps {
  peerName: string
  peerAvatar?: string | null
  isGroup?: boolean
  conversationName?: string
  isAudioOnly?: boolean
  onAnswer: (audioOnly?: boolean) => void
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
  const initials = peerName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()
  const displayName = isGroup && conversationName ? conversationName : peerName

  // Play ringtone using Web Audio API
  React.useEffect(() => {
    let audioCtx: AudioContext | null = null
    let gainNode: GainNode | null = null
    let interval: ReturnType<typeof setInterval>
    let isHigh = true

    try {
      audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)()
      gainNode = audioCtx.createGain()
      gainNode.gain.setValueAtTime(0, audioCtx.currentTime)
      gainNode.connect(audioCtx.destination)
      gainNode.gain.linearRampToValueAtTime(0.12, audioCtx.currentTime + 0.05)

      const playTone = (freq: number) => {
        if (!audioCtx || !gainNode) return
        const osc = audioCtx.createOscillator()
        osc.type = 'sine'
        osc.frequency.value = freq
        osc.connect(gainNode)
        osc.start()
        osc.stop(audioCtx.currentTime + 0.18)
      }

      interval = setInterval(() => {
        playTone(isHigh ? 440 : 523)
        isHigh = !isHigh
      }, 280)

      if ('vibrate' in navigator) {
        navigator.vibrate([200, 100, 200, 100, 200])
      }
    } catch (_) {}

    return () => {
      clearInterval(interval)
      try { audioCtx?.close() } catch (_) {}
    }
  }, [])

  return (
    <div className="fixed bottom-6 right-6 z-[1000] w-[300px] animate-in slide-in-from-bottom-10 duration-300 ease-out">
      <div className="bg-[#0068FF] rounded-2xl overflow-hidden shadow-[0_8px_40px_rgba(0,104,255,0.4)]">

        {/* Header */}
        <div className="px-4 pt-4 pb-3 flex items-center gap-3">
          {/* Pulse avatar */}
          <div className="relative shrink-0">
            <div className="absolute inset-0 rounded-full bg-white/20 animate-ping" style={{ animationDuration: '1.5s' }} />
            <div className="absolute inset-0 rounded-full bg-white/10 animate-ping" style={{ animationDuration: '1.5s', animationDelay: '0.5s' }} />
            <div className="relative w-14 h-14 rounded-full border-2 border-white/40 overflow-hidden shadow-lg bg-white/20">
              {resolvedAvatar ? (
                <img src={resolvedAvatar} alt="" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-white/30 to-white/10 flex items-center justify-center">
                  <span className="text-white text-xl font-bold">{initials}</span>
                </div>
              )}
            </div>
          </div>

          {/* Name + subtitle */}
          <div className="flex-1 overflow-hidden">
            <p className="text-white font-semibold truncate text-[15px] leading-tight">{displayName}</p>
            <p className="text-white/70 text-[12px] truncate mt-0.5">
              {isGroup ? `Nhóm • ${peerName}` : isAudioOnly ? 'Cuộc gọi thoại đến...' : 'Cuộc gọi video đến...'}
            </p>
          </div>

          {/* Close button */}
          <button
            onClick={onDecline}
            className="w-7 h-7 shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 active:scale-90 transition-all text-white/80 hover:text-white"
          >
            <X size={16} />
          </button>
        </div>

        {/* Action buttons */}
        <div className="px-4 pb-4 flex items-center justify-center gap-3">
          {/* Decline */}
          <button
            onClick={onDecline}
            className="w-14 h-14 rounded-full bg-[#FF3B30] hover:bg-[#E03328] active:scale-90 flex items-center justify-center text-white shadow-lg transition-all"
          >
            <PhoneOff size={22} />
          </button>

          {/* Answer without camera */}
          {!isAudioOnly && (
            <button
              onClick={() => onAnswer(true)}
              className="h-14 px-4 rounded-full bg-white/15 hover:bg-white/25 active:scale-95 flex items-center gap-2 text-white transition-all"
            >
              <VideoOff size={20} />
              <span className="text-sm font-medium">Không camera</span>
            </button>
          )}

          {/* Accept */}
          <button
            onClick={() => onAnswer(false)}
            className="w-14 h-14 rounded-full bg-white hover:bg-white/90 active:scale-90 flex items-center justify-center text-[#0068FF] shadow-lg transition-all"
          >
            <Phone size={22} className="fill-[#0068FF]" />
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
    <div className="fixed bottom-6 right-6 z-[600] w-48 h-72 rounded-3xl overflow-hidden bg-black border border-[#0068FF]/20 shadow-[0_20px_50px_rgba(0,0,0,0.6)] group transition-transform hover:scale-105">
      {isCameraOn && stream ? (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          className="w-full h-full object-cover"
        />
      ) : (
        <div className="w-full h-full flex flex-col items-center justify-center gap-3 bg-gradient-to-b from-[#131313] to-black">
          {resolvedAvatar ? (
            <img src={resolvedAvatar} alt="" className="w-16 h-16 rounded-full border-2 border-white/10 shadow-lg" />
          ) : (
            <div className="w-16 h-16 rounded-full bg-[#0068FF] flex items-center justify-center text-white text-xl font-bold shadow-md">
              {peerName[0].toUpperCase()}
            </div>
          )}
          <span className="text-[#0088FF]/60 text-[10px] font-bold truncate px-4 tracking-widest uppercase">{peerName}</span>
        </div>
      )}

      <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-4">
        <button
          onClick={onMaximize}
          className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white hover:bg-white/30"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7" />
          </svg>
        </button>
        <button
          onClick={onEnd}
          className="w-10 h-10 rounded-full bg-[#FF3B30] flex items-center justify-center text-white hover:bg-[#E03328]"
        >
          <PhoneOff size={18} />
        </button>
      </div>
    </div>
  )
}
