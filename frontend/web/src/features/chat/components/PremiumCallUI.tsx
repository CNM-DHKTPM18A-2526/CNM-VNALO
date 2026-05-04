import React from 'react'
import {
  Mic, MicOff, Video, VideoOff,
  Maximize2, Minimize2,
  Phone, PhoneOff, Settings, ChevronUp, ShieldCheck
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
  hideCentralIdentity?: boolean
}

export const PremiumVideoTile: React.FC<PremiumVideoTileProps> = ({
  stream,
  displayName,
  avatarUrl,
  isMicOn,
  isCameraOn,
  isLocal = false,
  statusText,
  hideCentralIdentity = false
}) => {
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const resolvedAvatar = avatarUrl ? resolveMediaUrl(avatarUrl) : null

  React.useEffect(() => {
    if (videoRef.current && stream && isCameraOn) {
      videoRef.current.srcObject = stream
    }
  }, [stream, isCameraOn])

  const initials = displayName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()

  // Avatar size: 90px (Zalo standard)
  const AVATAR_SIZE = 90

  return (
    <div className={`relative w-full h-full overflow-hidden bg-[#0a0a0b] flex items-center justify-center select-none`}>
      {/* ── PERSISTENT BLURRED BACKGROUND (Always visible — NEVER black screen) ── */}
      <div className="absolute inset-0 z-0 overflow-hidden">
        {resolvedAvatar ? (
          <div className="relative w-full h-full">
            <img
              src={resolvedAvatar}
              alt=""
              className="w-full h-full object-cover blur-[120px] opacity-50 scale-150 transform-gpu"
            />
            <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-black/20 to-black/60" />
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
          className={`absolute inset-0 w-full h-full object-cover z-10 animate-in fade-in duration-1000 ${isLocal ? 'scale-x-[-1]' : ''}`}
        />
      )}

      {/* ── AVATAR + NAME OVERLAY (Visible when camera is off OR stream unavailable) ── */}
      {(!isCameraOn || !stream) && (
        <div className={`relative z-20 flex flex-col items-center justify-center animate-in fade-in zoom-in duration-500 ${hideCentralIdentity && stream ? 'hidden' : ''}`}>
          {/* Zalo-style concentric pulse rings */}
          <div className="relative mb-6">
            <div
              className="absolute rounded-full border border-white/[0.06] animate-ping"
              style={{
                width: AVATAR_SIZE + 32,
                height: AVATAR_SIZE + 32,
                inset: '-16px',
                animationDuration: '2.5s',
                animationIterationCount: 'infinite',
              }}
            />
            <div
              className="absolute rounded-full border border-white/[0.04] animate-ping"
              style={{
                width: AVATAR_SIZE + 56,
                height: AVATAR_SIZE + 56,
                inset: '-28px',
                animationDuration: '2.5s',
                animationDelay: '0.8s',
                animationIterationCount: 'infinite',
              }}
            />
            <div
              className="absolute rounded-full border border-white/[0.02] animate-ping"
              style={{
                width: AVATAR_SIZE + 80,
                height: AVATAR_SIZE + 80,
                inset: '-40px',
                animationDuration: '2.5s',
                animationDelay: '1.6s',
                animationIterationCount: 'infinite',
              }}
            />

            {/* Main Avatar — 90px with 1.5px white border + deep shadow */}
            <div
              className="rounded-full border-[1.5px] border-white/40 overflow-hidden shadow-[0_0_60px_rgba(0,0,0,0.7),0_8px_32px_rgba(0,0,0,0.5)] relative z-10 bg-[#1a1a2e] flex items-center justify-center"
              style={{ width: AVATAR_SIZE, height: AVATAR_SIZE }}
            >
              {resolvedAvatar ? (
                <img src={resolvedAvatar} alt={displayName} className="w-full h-full object-cover scale-105" />
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-[#0088FF] to-[#0044CC] flex items-center justify-center">
                  <span className="text-white text-[32px] font-bold tracking-tight">{initials}</span>
                </div>
              )}
            </div>
          </div>

          {/* Name + Status */}
          <div className="flex flex-col items-center gap-1.5">
            <h3 className="text-white text-xl font-semibold tracking-tight drop-shadow-2xl">
              {isLocal ? 'Bạn' : displayName}
            </h3>
            {statusText ? (
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={12} className="text-white/40" />
                <span className="text-white/50 text-xs font-light tracking-widest uppercase animate-pulse">
                  {statusText}
                </span>
              </div>
            ) : (
              <div className="flex items-center gap-1.5">
                <ShieldCheck size={12} className="text-white/30" />
                <span className="text-white/30 text-xs font-light tracking-widest uppercase">
                  Mã hóa đầu cuối
                </span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── NAME + MIC BADGE OVERLAY (Bottom-left, visible only when video is on) ── */}
      {isCameraOn && stream && (
        <div className="absolute bottom-10 left-8 z-30 flex items-center gap-2.5 bg-black/50 backdrop-blur-2xl px-4 py-2 rounded-2xl border border-white/[0.08] shadow-2xl">
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
// 2. PREMIUM CALL CONTROLS (Zalo Glassmorphism Bar)
// ─────────────────────────────────────────────────────────────────

interface PremiumCallControlsProps {
  isMicOn: boolean
  isCameraOn: boolean
  isAudioOnly?: boolean
  onToggleMic: () => void
  onToggleCamera: () => void
  onEnd: () => void
  onMinimize?: () => void
}

// Standard 44px touch target (Apple HIG / Zalo standard)
const CONTROL_SIZE = 44
const END_CALL_SIZE = 56

export const PremiumCallControls: React.FC<PremiumCallControlsProps> = ({
  isMicOn,
  isCameraOn,
  isAudioOnly = false,
  onToggleMic,
  onToggleCamera,
  onEnd,
  onMinimize
}) => {
  const isOff = (on: boolean) => !on

  return (
    <div className="w-full flex items-center justify-between px-6">
      {/* Spacer to balance settings icon on right */}
      <div className="hidden md:block" style={{ width: CONTROL_SIZE }} />

      {/* Main Controls Group */}
      <div className="flex items-center justify-center gap-6">

        {/* Camera Toggle */}
        {!isAudioOnly && (
          <button
            onClick={onToggleCamera}
            title={isCameraOn ? 'Tắt camera' : 'Bật camera'}
            className={`relative flex items-center justify-center rounded-full transition-all active:scale-90 ${
              isOff(isCameraOn)
                ? 'bg-[#FF3B30] hover:bg-[#E03328]'
                : 'bg-white/[0.12] hover:bg-white/[0.20]'
            } border border-white/[0.08] shadow-lg`}
            style={{ width: CONTROL_SIZE, height: CONTROL_SIZE }}
          >
            {isCameraOn
              ? <Video size={18} className="text-white" />
              : <VideoOff size={18} className="text-white" />
            }
            {/* Zalo-style chevron indicator (device selection menu) */}
            <div className="absolute -bottom-1.5 -right-1.5 w-5 h-5 bg-black/50 backdrop-blur-xl rounded-full flex items-center justify-center border border-white/[0.15]">
              <ChevronUp size={10} className="text-white/80" />
            </div>
          </button>
        )}

        {/* End Call — red, largest, center */}
        <button
          onClick={onEnd}
          title="Kết thúc"
          className="rounded-full bg-[#FF3B30] hover:bg-[#E03328] active:scale-90 flex items-center justify-center shadow-[0_0_30px_rgba(255,59,48,0.4)] border border-white/10 transition-all group"
          style={{ width: END_CALL_SIZE, height: END_CALL_SIZE }}
        >
          {/* Rotate Phone icon to look like a hangup handset, no slash as requested */}
          <Phone size={24} className="text-white fill-white rotate-[135deg] transform-gpu" />
        </button>

        {/* Mic Toggle */}
        <button
          onClick={onToggleMic}
          title={isMicOn ? 'Tắt mic' : 'Bật mic'}
          className={`relative flex items-center justify-center rounded-full transition-all active:scale-90 ${
            isOff(isMicOn)
              ? 'bg-[#FF3B30] hover:bg-[#E03328]'
              : 'bg-white/[0.12] hover:bg-white/[0.20]'
          } border border-white/[0.08] shadow-lg`}
          style={{ width: CONTROL_SIZE, height: CONTROL_SIZE }}
        >
          {isMicOn
            ? <Mic size={18} className="text-white" />
            : <MicOff size={18} className="text-white" />
          }
          {/* Zalo-style chevron indicator */}
          <div className="absolute -bottom-1.5 -right-1.5 w-5 h-5 bg-black/50 backdrop-blur-xl rounded-full flex items-center justify-center border border-white/[0.15]">
            <ChevronUp size={10} className="text-white/80" />
          </div>
        </button>
      </div>

      {/* Settings + Minimize (Far Right) */}
      <div className="flex items-center gap-2">
        {onMinimize && (
          <button
            onClick={onMinimize}
            title="Thu nhỏ"
            className="flex items-center justify-center rounded-full hover:bg-white/[0.10] active:scale-90 transition-colors text-white/40 hover:text-white/70"
            style={{ width: CONTROL_SIZE, height: CONTROL_SIZE }}
          >
            <Minimize2 size={18} />
          </button>
        )}
        <button
          title="Cài đặt cuộc gọi"
          className="flex items-center justify-center rounded-full hover:bg-white/[0.10] active:scale-90 transition-colors text-white/60 hover:text-white/80"
          style={{ width: CONTROL_SIZE, height: CONTROL_SIZE }}
        >
          <Settings size={20} />
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// 3. INCOMING CALL BANNER (Zalo Design — Toast style, bottom-right)
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

  // ── SOUND: Play a ringtone using Web Audio API (no audio files needed) ──
  React.useEffect(() => {
    let audioCtx: AudioContext | null = null
    let gainNode: GainNode | null = null
    let interval: ReturnType<typeof setInterval>

    try {
      // Simple synthesized "ringing" tone (two alternating frequencies)
      let isHigh = true
      const RING_FREQ_HIGH = 440  // A4
      const RING_FREQ_LOW  = 523  // C5

      audioCtx = new (window.AudioContext || (window as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext)() as AudioContext
      gainNode = audioCtx.createGain()
      gainNode.gain.setValueAtTime(0, audioCtx.currentTime)
      gainNode.connect(audioCtx.destination)

      const playTone = (freq: number) => {
        if (!audioCtx || !gainNode) return
        const osc = audioCtx.createOscillator()
        osc.type = 'sine'
        osc.frequency.value = freq
        osc.connect(gainNode)
        osc.start()
        osc.stop(audioCtx.currentTime + 0.2)
      }

      // Fade in on first tone
      gainNode.gain.setValueAtTime(0, audioCtx.currentTime)
      gainNode.gain.linearRampToValueAtTime(0.15, audioCtx.currentTime + 0.05)

      // Play ringtone pattern: high, low, high, low, pause...
      interval = setInterval(() => {
        if (!audioCtx || !gainNode) return
        playTone(isHigh ? RING_FREQ_HIGH : RING_FREQ_LOW)
        isHigh = !isHigh
      }, 300)

      // ── VIBRATION: Mobile browsers ──
      if ('vibrate' in navigator) {
        navigator.vibrate([200, 100, 200, 100, 200])
      }
    } catch {
      // Audio not supported — silent fallback
    }

    return () => {
      clearInterval(interval)
      try { audioCtx?.close(); } catch { /* ignore */ }
    }
  }, [])

  return (
    <div className="fixed bottom-6 right-6 z-[1000] w-[320px] animate-in slide-in-from-bottom-10 duration-300 ease-out">
      <div className="bg-[#0068FF] rounded-2xl overflow-hidden shadow-[0_8px_40px_rgba(0,104,255,0.4)] flex flex-col">

        {/* ── ZALO BLUE HEADER ── */}
        <div className="px-4 pt-4 pb-3 flex items-center gap-3">
          {/* Animated pulse rings + Avatar */}
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

          {/* Name + Description */}
          <div className="flex-1 overflow-hidden">
            <p className="text-white font-semibold truncate text-[15px] leading-tight">
              {displayName}
            </p>
            <p className="text-white/75 text-[12px] truncate mt-0.5">
              {isGroup
                ? `Nhóm • ${peerName}`
                : isAudioOnly ? 'Cuộc gọi thoại đến...' : 'Cuộc gọi video đến...'}
            </p>
          </div>

          {/* Close (X) Button */}
          <button
            onClick={onDecline}
            title="Đóng"
            className="w-7 h-7 shrink-0 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 active:scale-90 transition-all text-white/80 hover:text-white"
          >
            <span className="text-base leading-none font-light select-none">&times;</span>
          </button>
        </div>

        {/* ── ACTION BUTTONS ── */}
        <div className="px-4 pb-3 flex items-center justify-center gap-3">
          {/* Decline */}
          <button
            onClick={onDecline}
            className="w-14 h-14 rounded-full bg-[#FF3B30] hover:bg-[#E03328] active:scale-90 flex items-center justify-center text-white shadow-lg transition-all"
            title="Từ chối"
          >
            <PhoneOff size={22} />
          </button>

          {/* Answer without camera (audio-only) */}
          {!isAudioOnly && (
            <button
              onClick={() => onAnswer(true)}
              className="h-14 px-4 rounded-full bg-white/15 hover:bg-white/25 active:scale-95 flex items-center gap-2 text-white transition-all"
              title="Trả lời không mở camera"
            >
              <VideoOff size={20} />
              <span className="text-sm font-medium whitespace-nowrap">Không camera</span>
            </button>
          )}

          {/* Accept */}
          <button
            onClick={() => onAnswer(false)}
            className="w-14 h-14 rounded-full bg-white hover:bg-white/90 active:scale-90 flex items-center justify-center text-[#0068FF] shadow-lg transition-all"
            title="Trả lời"
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
