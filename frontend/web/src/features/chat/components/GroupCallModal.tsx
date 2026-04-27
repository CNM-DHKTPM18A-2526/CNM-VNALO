/**
 * GroupCallModal.tsx + useGroupCall hook
 *
 * 🆕 Tách biệt hoàn toàn với CallModal.tsx (1-1 call).
 *
 * Flow:
 *   Caller  → startGroupCall() → modal mở, broadcast group-call:started
 *   Others  → nhận group-call:started → IncomingGroupCallBanner hiện lên
 *   Others  → bấm "Tham gia" → joinGroupCall() → modal mở + join mesh
 */

import React, { useEffect, useRef, useCallback, useState } from 'react'
import { Mic, MicOff, Video, VideoOff, PhoneOff, Users, Phone, PhoneIncoming } from 'lucide-react'
import type { GroupCallSnapshot, GroupPeerState, IncomingGroupCallInfo } from '../webrtcGroupCallService'
import { WebRtcGroupCallService } from '../webrtcGroupCallService'
import type { Socket } from 'socket.io-client'

// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────

function getGridCols(totalTiles: number): string {
  if (totalTiles <= 1) return 'grid-cols-1'
  if (totalTiles <= 2) return 'grid-cols-2'
  if (totalTiles <= 4) return 'grid-cols-2'
  return 'grid-cols-3'
}

function formatTime(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600)
  const m = Math.floor((totalSeconds % 3600) / 60)
  const s = totalSeconds % 60
  return [h > 0 ? h : null, m, s]
    .filter((v) => v !== null)
    .map((v) => String(v!).padStart(2, '0'))
    .join(':')
}

// ─────────────────────────────────────────────────────────────────
// VIDEO TILE
// ─────────────────────────────────────────────────────────────────

interface VideoTileProps {
  stream: MediaStream | null
  displayName: string
  avatarUrl?: string
  isSpeaking: boolean
  isMicOn: boolean
  isCameraOn: boolean
  isLocal?: boolean
}

const VideoTile: React.FC<VideoTileProps> = ({
  stream,
  displayName,
  avatarUrl,
  isSpeaking,
  isMicOn,
  isCameraOn,
  isLocal = false,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const audioRef = useRef<HTMLAudioElement>(null)

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream
    }
    if (!isLocal && audioRef.current && stream) {
      audioRef.current.srcObject = stream
      audioRef.current.play().catch(() => {})
    }
  }, [stream, isLocal])

  const initials = displayName
    .split(' ')
    .map((w) => w[0] ?? '')
    .join('')
    .slice(0, 2)
    .toUpperCase()

  return (
    <div
      className={`
        relative flex items-center justify-center rounded-2xl overflow-hidden bg-slate-800 select-none
        transition-all duration-300
        ${isSpeaking ? 'ring-4 ring-green-400 scale-[1.02] shadow-lg shadow-green-400/30' : 'ring-1 ring-white/10'}
      `}
      style={{ minHeight: '120px', aspectRatio: '16/10' }}
    >
      {!isLocal && <audio ref={audioRef} autoPlay className="hidden" />}

      {stream && isCameraOn ? (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted={isLocal}
          className={`absolute inset-0 w-full h-full object-cover ${isLocal ? 'scale-x-[-1]' : ''}`}
        />
      ) : (
        <div className="flex flex-col items-center gap-2 z-10">
          {avatarUrl ? (
            <img src={avatarUrl} alt={displayName}
              className="w-16 h-16 rounded-full object-cover border-2 border-white/20" />
          ) : (
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-xl font-bold border-2 border-white/20">
              {initials}
            </div>
          )}
        </div>
      )}

      <div className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-black/70 to-transparent z-10 pointer-events-none" />

      <div className="absolute bottom-2 left-3 right-3 flex items-center justify-between z-20">
        <span className="text-white text-xs font-semibold truncate drop-shadow">
          {isLocal ? 'Bạn' : displayName}
        </span>
        <span className={`ml-2 flex-shrink-0 ${isMicOn ? 'text-white/70' : 'text-red-400'}`}>
          {isMicOn ? <Mic size={14} /> : <MicOff size={14} />}
        </span>
      </div>

      {isSpeaking && (
        <div className="absolute top-2 left-2 z-20 bg-green-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full shadow">
          Đang nói
        </div>
      )}

      {isLocal && (
        <div className="absolute top-2 right-2 z-20 bg-blue-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
          Bạn
        </div>
      )}
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// INCOMING GROUP CALL BANNER
// ─────────────────────────────────────────────────────────────────

interface IncomingGroupCallBannerProps {
  info: IncomingGroupCallInfo
  onJoin: () => void
  onDecline: () => void
}

export const IncomingGroupCallBanner: React.FC<IncomingGroupCallBannerProps> = ({
  info,
  onJoin,
  onDecline,
}) => {
  const initials = info.callerName.split(' ').map(w => w[0] ?? '').join('').slice(0, 2).toUpperCase()

  return (
    <div
      className="fixed top-6 right-6 z-[300] flex items-center gap-4 bg-gray-900/95 backdrop-blur-md text-white rounded-2xl shadow-2xl px-5 py-4 w-[360px] border border-white/10"
      style={{ animation: 'slideInRight 0.3s ease-out' }}
    >
      <style>{`
        @keyframes slideInRight {
          from { transform: translateX(120%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        @keyframes pulseRing {
          0% { transform: scale(1); opacity: 0.8; }
          100% { transform: scale(1.6); opacity: 0; }
        }
      `}</style>

      {/* Avatar with pulse ring */}
      <div className="relative flex-shrink-0">
        <div className="absolute inset-0 rounded-full bg-green-500 opacity-0"
          style={{ animation: 'pulseRing 1.5s ease-out infinite' }} />
        {info.callerAvatar ? (
          <img src={info.callerAvatar} alt={info.callerName}
            className="w-12 h-12 rounded-full object-cover border-2 border-green-400" />
        ) : (
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white font-bold text-sm border-2 border-green-400">
            {initials}
          </div>
        )}
        <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-green-500 rounded-full flex items-center justify-center">
          <PhoneIncoming size={11} />
        </div>
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-xs text-slate-400 font-medium truncate">{info.conversationName}</p>
        <p className="text-sm font-bold truncate">{info.callerName} đang gọi</p>
        <p className="text-xs text-slate-400">{info.audioOnly ? '🎙️ Cuộc gọi thoại' : '📹 Cuộc gọi video'} nhóm</p>
      </div>

      {/* Buttons */}
      <div className="flex gap-2 flex-shrink-0">
        <button
          onClick={onDecline}
          className="w-11 h-11 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center transition-all active:scale-90"
          title="Từ chối"
        >
          <PhoneOff size={18} />
        </button>
        <button
          onClick={onJoin}
          className="w-11 h-11 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center transition-all active:scale-90"
          title="Tham gia"
        >
          <Phone size={18} />
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// MAIN GROUP CALL MODAL
// ─────────────────────────────────────────────────────────────────

interface GroupCallModalProps {
  isOpen: boolean
  snapshot: GroupCallSnapshot
  localUserName: string
  localUserAvatar?: string
  onLeave: () => void
  onToggleMic: () => void
  onToggleCamera: () => void
  elapsedSeconds?: number
}

export const GroupCallModal: React.FC<GroupCallModalProps> = ({
  isOpen,
  snapshot,
  localUserName,
  localUserAvatar,
  onLeave,
  onToggleMic,
  onToggleCamera,
  elapsedSeconds = 0,
}) => {
  if (!isOpen) return null

  const totalTiles = 1 + snapshot.peers.length
  const gridCols = getGridCols(totalTiles)

  return (
    <div className="fixed inset-0 z-[200] flex flex-col bg-slate-900">
      {/* ── HEADER ── */}
      <div className="flex items-center justify-between px-6 py-3 bg-black/30 backdrop-blur-sm border-b border-white/10">
        <div className="flex items-center gap-2 text-white">
          <Users size={18} className="text-blue-400" />
          <span className="font-semibold text-sm">Cuộc gọi nhóm</span>
          <span className="text-xs text-slate-400 ml-2">{totalTiles} người</span>
        </div>
        {elapsedSeconds > 0 && (
          <div className="text-green-400 text-sm font-mono font-semibold">
            {formatTime(elapsedSeconds)}
          </div>
        )}
        {snapshot.error && (
          <div className="text-red-400 text-xs font-medium px-3 py-1 bg-red-500/20 rounded-full">
            {snapshot.error}
          </div>
        )}
      </div>

      {/* ── GRID ── */}
      <div className="flex-1 overflow-y-auto p-3">
        <div className={`grid ${gridCols} gap-3`}>
          {/* LOCAL TILE */}
          <VideoTile
            stream={snapshot.localStream}
            displayName={localUserName}
            avatarUrl={localUserAvatar}
            isSpeaking={false}
            isMicOn={snapshot.isMicOn}
            isCameraOn={snapshot.isCameraOn}
            isLocal
          />
          {/* REMOTE TILES */}
          {snapshot.peers.map((peer: GroupPeerState) => (
            <VideoTile
              key={peer.userId}
              stream={peer.remoteStream}
              displayName={peer.displayName}
              avatarUrl={peer.avatarUrl}
              isSpeaking={peer.isSpeaking}
              isMicOn={peer.isMicOn}
              isCameraOn={peer.isCameraOn}
            />
          ))}
        </div>

        {snapshot.peers.length === 0 && (
          <div className="flex flex-col items-center justify-center py-10 text-slate-500 text-sm gap-2 mt-4">
            <Users size={32} className="opacity-40" />
            <p>Đang chờ người khác tham gia...</p>
          </div>
        )}
      </div>

      {/* ── CONTROLS ── */}
      <div className="flex items-center justify-center gap-5 py-5 bg-black/30 backdrop-blur-sm border-t border-white/10">
        <button
          onClick={onToggleMic}
          title={snapshot.isMicOn ? 'Tắt micro' : 'Bật micro'}
          className={`w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95
            ${snapshot.isMicOn ? 'bg-white/20 text-white hover:bg-white/30' : 'bg-red-500 text-white hover:bg-red-600'}`}
        >
          {snapshot.isMicOn ? <Mic size={22} /> : <MicOff size={22} />}
        </button>

        {!snapshot.audioOnly && (
          <button
            onClick={onToggleCamera}
            title={snapshot.isCameraOn ? 'Tắt camera' : 'Bật camera'}
            className={`w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95
              ${snapshot.isCameraOn ? 'bg-white/20 text-white hover:bg-white/30' : 'bg-slate-600 text-white hover:bg-slate-500'}`}
          >
            {snapshot.isCameraOn ? <Video size={22} /> : <VideoOff size={22} />}
          </button>
        )}

        <button
          onClick={onLeave}
          title="Rời cuộc gọi"
          className="w-16 h-16 rounded-full bg-red-500 text-white flex items-center justify-center hover:bg-red-600 transition-all active:scale-90 shadow-lg shadow-red-500/40"
        >
          <PhoneOff size={26} />
        </button>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────────────────────────
// HOOK — useGroupCall
// ─────────────────────────────────────────────────────────────────

interface UseGroupCallOptions {
  socket: Socket | null
  currentUserId: string
  currentUserName: string
  currentUserAvatar?: string
}

export function useGroupCall({
  socket,
  currentUserId,
  currentUserName,
  currentUserAvatar,
}: UseGroupCallOptions) {
  const [snapshot, setSnapshot] = useState<GroupCallSnapshot | null>(null)
  const [incomingCall, setIncomingCall] = useState<IncomingGroupCallInfo | null>(null)
  const [elapsedSeconds, setElapsedSeconds] = useState(0)
  const serviceRef = useRef<WebRtcGroupCallService | null>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Listen for incoming group-call:started from OTHER users
  useEffect(() => {
    if (!socket) return

    const onGroupCallStarted = (payload: {
      conversationId: string
      conversationName: string
      callId: string
      callerUserId: string
      callerName: string
      callerAvatar?: string
      audioOnly: boolean
    }) => {
      // Bỏ qua nếu chính mình là người gọi
      if (payload.callerUserId === currentUserId) return
      // Bỏ qua nếu đang trong cuộc gọi khác
      if (snapshot !== null) return

      console.log('[useGroupCall] 📞 Incoming group call from:', payload.callerName)
      setIncomingCall({
        callId: payload.callId,
        conversationId: payload.conversationId,
        conversationName: payload.conversationName,
        callerName: payload.callerName,
        callerAvatar: payload.callerAvatar,
        audioOnly: payload.audioOnly,
      })
    }

    socket.off('group-call:started')
    socket.on('group-call:started', onGroupCallStarted)

    return () => {
      socket.off('group-call:started', onGroupCallStarted)
    }
  }, [socket, currentUserId, snapshot])

  // Khi cuộc gọi kết thúc hoàn toàn (người cuối rời) → dismiss banner cho người chưa bắt máy
  useEffect(() => {
    if (!socket) return

    const onGroupCallEnded = (payload: { conversationId: string; callId: string }) => {
      console.log('[useGroupCall] 📴 group-call:ended received, dismissing incoming banner', payload)
      setIncomingCall((prev) => {
        // Chỉ dismiss nếu đúng callId
        if (prev && prev.callId === payload.callId) return null
        return prev
      })
    }

    socket.off('group-call:ended', onGroupCallEnded)
    socket.on('group-call:ended', onGroupCallEnded)

    return () => {
      socket.off('group-call:ended', onGroupCallEnded)
    }
  }, [socket])

  const startTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current)
    setElapsedSeconds(0)
    timerRef.current = setInterval(() => setElapsedSeconds((prev) => prev + 1), 1000)
  }, [])

  const stopTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current)
      timerRef.current = null
    }
  }, [])

  const createService = useCallback(() => {
    serviceRef.current?.leave()
    const service = new WebRtcGroupCallService((snap) => {
      setSnapshot({ ...snap })
      if (snap.isEnded) {
        stopTimer()
        setSnapshot(null)
      }
    })
    serviceRef.current = service
    return service
  }, [stopTimer])

  /** Caller: bắt đầu cuộc gọi nhóm */
  const startGroupCall = useCallback(
    async (params: {
      conversationId: string
      conversationName: string
      callId: string
      audioOnly?: boolean
    }) => {
      if (!socket) return
      const service = createService()
      startTimer()
      await service.startCall({
        socket,
        conversationId: params.conversationId,
        conversationName: params.conversationName,
        callId: params.callId,
        currentUserId,
        currentUserName,
        currentUserAvatar,
        audioOnly: params.audioOnly ?? false,
      })
    },
    [socket, currentUserId, currentUserName, currentUserAvatar, createService, startTimer]
  )

  /** Người nhận: tham gia cuộc gọi sau khi bấm "Tham gia" */
  const joinGroupCall = useCallback(
    async (info: IncomingGroupCallInfo) => {
      if (!socket) return
      setIncomingCall(null)
      const service = createService()
      startTimer()
      await service.joinCall({
        socket,
        conversationId: info.conversationId,
        callId: info.callId,
        currentUserId,
        currentUserName,
        currentUserAvatar,
        audioOnly: info.audioOnly,
      })
    },
    [socket, currentUserId, currentUserName, currentUserAvatar, createService, startTimer]
  )

  const declineGroupCall = useCallback(() => {
    setIncomingCall(null)
  }, [])

  const leaveGroupCall = useCallback(() => {
    serviceRef.current?.leave()
    stopTimer()
    setSnapshot(null)
  }, [stopTimer])

  const toggleMic = useCallback(() => serviceRef.current?.toggleMic(), [])
  const toggleCamera = useCallback(() => serviceRef.current?.toggleCamera(), [])

  return {
    snapshot,
    incomingCall,
    elapsedSeconds,
    startGroupCall,
    joinGroupCall,
    declineGroupCall,
    leaveGroupCall,
    toggleMic,
    toggleCamera,
    isInGroupCall: snapshot !== null && !snapshot.isEnded,
  }
}
