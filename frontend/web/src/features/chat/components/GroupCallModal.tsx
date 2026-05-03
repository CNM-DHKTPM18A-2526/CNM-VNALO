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
import type { ConversationSummary } from '../chat.types'
import { WebRtcGroupCallService } from '../webrtcGroupCallService'
import type { Socket } from 'socket.io-client'
import { resolveMediaUrl } from '../../../utils/mediaUtils'

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
  audioOnly?: boolean
}

const VideoTile: React.FC<VideoTileProps> = ({
  stream,
  displayName,
  avatarUrl,
  isSpeaking,
  isMicOn,
  isCameraOn,
  isLocal = false,
  audioOnly = false,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const audioRef = useRef<HTMLAudioElement>(null)

  useEffect(() => {
    if (videoRef.current && stream && isCameraOn && !audioOnly) {
      videoRef.current.srcObject = stream
    }
    if (!isLocal && audioRef.current && stream) {
      audioRef.current.srcObject = stream
      audioRef.current.play().catch(() => {})
    }
  }, [stream, isLocal, isCameraOn, audioOnly])

  const initials = (displayName || 'Người dùng')
    .split(' ')
    .map((w) => w[0] ?? '')
    .join('')
    .slice(0, 2)
    .toUpperCase()

  const resolvedAvatar = resolveMediaUrl(avatarUrl)

  // Logic to determine if we should show active video or avatar
  const videoTrack = stream?.getVideoTracks().find(t => t.enabled && t.readyState === 'live')
  const showVideo = !!(videoTrack && isCameraOn && !audioOnly)

  return (
    <div className={`relative w-full h-full bg-slate-800 rounded-2xl overflow-hidden shadow-inner flex items-center justify-center transition-all duration-300 ${isSpeaking ? 'ring-2 ring-green-500' : ''}`} style={{ minHeight: '120px', aspectRatio: '16/10' }}>
      {!isLocal && <audio ref={audioRef} autoPlay className="hidden" />}

      {/* BACKGROUND AVATAR (BLURRED) - Show when camera is off or it's an audio call */}
      {!showVideo && (
        <div className="absolute inset-0 z-0">
          {avatarUrl ? (
            <img src={resolvedAvatar!} alt="" className="w-full h-full object-cover blur-2xl opacity-40 scale-110" />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-slate-700 to-slate-900" />
          )}
          <div className="absolute inset-0 bg-black/30" />
        </div>
      )}

      {/* VIDEO OR AVATAR CENTER */}
      {showVideo ? (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted={isLocal}
          className={`absolute inset-0 w-full h-full object-cover z-10 ${isLocal ? 'scale-x-[-1]' : ''}`}
        />
      ) : (
        <div className="relative z-20 flex flex-col items-center">
          {avatarUrl ? (
            <div className="relative">
               <img src={resolvedAvatar!} alt={displayName}
                className="w-20 h-20 rounded-full object-cover border-4 border-white/10 shadow-2xl" />
               <div className="absolute inset-0 rounded-full border border-white/20" />
            </div>
          ) : (
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-2xl font-bold border-4 border-white/10 shadow-2xl">
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
  const initials = (info.callerName || 'Người dùng').split(' ').map(w => w[0] ?? '').join('').slice(0, 2).toUpperCase()
  const resolvedCallerAvatar = resolveMediaUrl(info.callerAvatar)
  const resolvedGroupAvatar = resolveMediaUrl(info.groupAvatar)

  // Prioritize showing Group Avatar in the center if it's a group call
  const mainAvatar = resolvedGroupAvatar || resolvedCallerAvatar

  return (
    <div className="fixed inset-0 z-[500] flex flex-col items-center justify-between py-20 bg-slate-950 overflow-hidden">
      <style>{`
        @keyframes pulseRing {
          0% { transform: scale(1); opacity: 0.5; }
          100% { transform: scale(2.5); opacity: 0; }
        }
        @keyframes fadeInDown {
          from { transform: translateY(-20px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
        @keyframes fadeInUp {
          from { transform: translateY(20px); opacity: 0; }
          to { transform: translateY(0); opacity: 1; }
        }
        @keyframes shake {
          0%, 100% { transform: rotate(0); }
          25% { transform: rotate(-10deg); }
          75% { transform: rotate(10deg); }
        }
      `}</style>

      {/* BACKGROUND BACKDROP */}
      <div className="absolute inset-0 z-0">
        {mainAvatar ? (
          <img src={mainAvatar} alt="" className="w-full h-full object-cover blur-3xl opacity-30 scale-110" />
        ) : (
          <div className="w-full h-full bg-gradient-to-b from-blue-900 to-slate-950" />
        )}
        <div className="absolute inset-0 bg-black/40" />
      </div>

      {/* TOP SECTION: GROUP INFO */}
      <div className="relative z-10 flex flex-col items-center gap-2 px-6 text-center" style={{ animation: 'fadeInDown 0.6s ease-out' }}>
        <div className="flex items-center gap-2 bg-white/10 px-4 py-1.5 rounded-full backdrop-blur-md border border-white/10">
          <Users size={16} className="text-blue-400" />
          <span className="text-white/80 text-sm font-medium">{info.conversationName}</span>
        </div>
        <h2 className="text-white text-3xl font-bold mt-4">Cuộc gọi nhóm đến</h2>
        <p className="text-blue-400 text-lg font-medium animate-pulse">
          {info.audioOnly ? '🎙️ Cuộc gọi thoại' : '📹 Cuộc gọi video'}
        </p>
      </div>

      {/* MIDDLE SECTION: CALLER/GROUP AVATAR */}
      <div className="relative z-10 flex flex-col items-center">
        {/* Pulsing Rings */}
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="w-32 h-32 rounded-full border-2 border-green-500/30" style={{ animation: 'pulseRing 2s linear infinite' }} />
          <div className="w-32 h-32 rounded-full border-2 border-green-500/20" style={{ animation: 'pulseRing 2s linear infinite 0.7s' }} />
          <div className="w-32 h-32 rounded-full border-2 border-green-500/10" style={{ animation: 'pulseRing 2s linear infinite 1.4s' }} />
        </div>

        <div className="relative">
          {mainAvatar ? (
            <img 
              src={mainAvatar} 
              alt={info.callerName}
              className="w-40 h-40 rounded-full object-cover border-4 border-white/20 shadow-[0_0_50px_rgba(34,197,94,0.3)]" 
            />
          ) : (
            <div className="w-40 h-40 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-5xl font-bold border-4 border-white/20 shadow-2xl">
              {initials}
            </div>
          )}
          
          {/* Small badge for caller if we are showing group avatar */}
          {resolvedGroupAvatar && resolvedCallerAvatar && (
            <div className="absolute -top-2 -right-2 w-14 h-14 rounded-full border-4 border-slate-950 overflow-hidden shadow-lg">
               <img src={resolvedCallerAvatar} alt={info.callerName} className="w-full h-full object-cover" />
            </div>
          )}

          <div className="absolute -bottom-2 -right-2 w-12 h-12 bg-green-500 rounded-full flex items-center justify-center border-4 border-slate-950 text-white shadow-xl">
             <PhoneIncoming size={24} className="animate-bounce" />
          </div>
        </div>
        
        <p className="text-white text-2xl font-bold mt-8 tracking-wide">{info.callerName}</p>
        <p className="text-white/50 text-sm mt-2">Đang chờ bạn trả lời...</p>
      </div>

      {/* BOTTOM SECTION: ACTIONS */}
      <div className="relative z-10 flex gap-12 sm:gap-24 px-6 pb-10" style={{ animation: 'fadeInUp 0.8s ease-out' }}>
        <div className="flex flex-col items-center gap-3">
          <button
            onClick={onDecline}
            className="w-20 h-20 rounded-full bg-red-500 hover:bg-red-600 flex items-center justify-center transition-all active:scale-90 shadow-[0_10px_30px_rgba(239,68,68,0.4)] group"
          >
            <PhoneOff size={32} className="text-white group-hover:scale-110 transition-transform" />
          </button>
          <span className="text-white/70 text-sm font-semibold uppercase tracking-widest">Từ chối</span>
        </div>

        <div className="flex flex-col items-center gap-3">
          <button
            onClick={onJoin}
            className="w-20 h-20 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center transition-all active:scale-90 shadow-[0_10px_30px_rgba(34,197,94,0.4)] group"
            style={{ animation: 'shake 2s infinite ease-in-out' }}
          >
            <Phone size={32} className="text-white group-hover:scale-110 transition-transform" />
          </button>
          <span className="text-white/70 text-sm font-semibold uppercase tracking-widest">Tham gia</span>
        </div>
      </div>

      {/* AUDIO ELEMENT FOR RINGING (Optional: if we had a ringtone file) */}
      {/* <audio src="/assets/sounds/ringtone.mp3" autoPlay loop /> */}
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
            audioOnly={snapshot.audioOnly}
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
              audioOnly={snapshot.audioOnly}
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
  userMap?: Record<string, any>
  conversations?: ConversationSummary[]
}

export function useGroupCall({
  socket,
  currentUserId,
  currentUserName,
  currentUserAvatar,
  userMap,
  conversations,
}: UseGroupCallOptions) {
  const [snapshot, setSnapshot] = useState<GroupCallSnapshot | null>(null)
  const [incomingCall, setIncomingCall] = useState<IncomingGroupCallInfo | null>(null)
  const [elapsedSeconds, setElapsedSeconds] = useState(0)
  const serviceRef = useRef<WebRtcGroupCallService | null>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const resolveName = useCallback((uid: string) => {
    return userMap?.[uid]?.displayName || userMap?.[uid]?.name
  }, [userMap])

  const resolveAvatar = useCallback((uid: string) => {
    return userMap?.[uid]?.avatarUrl
  }, [userMap])

  // Listen for incoming group-call:started from OTHER users
  useEffect(() => {
    if (!socket) return

    const onGroupCallStarted = (payload: any) => {
      // Normalize payload fields (mobile might use different keys)
      const callerUserId = payload.callerUserId || payload.senderUserId || payload.userId
      
      const isId = (s: any) => typeof s === 'string' && s.length > 20 && /^[0-9a-fA-F-]/.test(s)
      let callerName = payload.callerName || payload.displayName || payload.name || payload.fullName || payload.full_name
      if (!callerName || isId(callerName)) {
        callerName = resolveName(callerUserId) || callerName || 'Người dùng'
      }

      const conversationId = payload.conversationId || payload.groupId
      const conversationName = payload.conversationName || payload.groupName || 'Cuộc gọi nhóm'
      const callId = payload.callId

      // Attempt to resolve group avatar from local conversations list
      const conv = (conversations || []).find(c => c.id === conversationId)
      const groupAvatar = conv?.avatarUrl || payload.groupAvatar || payload.conversationAvatar

      // Bỏ qua nếu chính mình là người gọi
      if (callerUserId === currentUserId) return
      // Bỏ qua nếu đang trong cuộc gọi khác
      if (snapshot !== null) return

      console.log('[useGroupCall] 📞 Incoming group call normalized:', { callerName, conversationName })
      setIncomingCall({
        callId: callId,
        conversationId: conversationId,
        conversationName: conversationName,
        callerName: callerName,
        callerAvatar: payload.callerAvatar || payload.avatarUrl || userMap?.[callerUserId]?.avatarUrl,
        groupAvatar: groupAvatar,
        audioOnly: !!payload.audioOnly,
      })
    }

    socket.off('group-call:started')
    socket.on('group-call:started', onGroupCallStarted)

    return () => {
      socket.off('group-call:started', onGroupCallStarted)
    }
  }, [socket, currentUserId, snapshot, resolveName, userMap, conversations])

  // Khi cuộc gọi kết thúc hoàn toàn (người cuối rời) HOẶC chính mình đã join từ máy khác → dismiss banner
  useEffect(() => {
    if (!socket) return

    const onGroupCallEnded = (payload: { conversationId: string; callId: string }) => {
      console.log('[useGroupCall] 📴 group-call:ended received, dismissing incoming banner', payload)
      setIncomingCall((prev) => {
        if (prev && prev.callId === payload.callId) return null
        return prev
      })
    }

    // Nếu nhận được user-joined mà ID là chính mình => mình đã bắt máy ở máy khác (mobile)
    const onUserJoined = (payload: any) => {
      const joinedUserId = payload.senderUserId || payload.userId || payload.uid
      console.log('[useGroupCall] 👤 User joined event received:', { joinedUserId, currentUserId })
      if (joinedUserId && String(joinedUserId) === String(currentUserId)) {
         console.log('[useGroupCall] 📱 You joined from another device, dismissing web banner')
         setIncomingCall(null)
      }
    }

    // Tương tự cho user-left (nếu mình từ chối ở máy khác)
    const onUserLeft = (payload: any) => {
      const leftUserId = payload.senderUserId || payload.userId || payload.uid
      if (leftUserId && String(leftUserId) === String(currentUserId)) {
        console.log('[useGroupCall] 📱 You left/declined from another device, dismissing web banner')
        setIncomingCall(null)
      }
    }

    socket.on('group-call:ended', onGroupCallEnded)
    socket.on('group-call:user-joined', onUserJoined)
    socket.on('group-call:user-left', onUserLeft)
    // Mobile might emit join directly
    socket.on('group-call:join', onUserJoined)

    return () => {
      socket.off('group-call:ended', onGroupCallEnded)
      socket.off('group-call:user-joined', onUserJoined)
      socket.off('group-call:user-left', onUserLeft)
      socket.off('group-call:join', onUserJoined)
    }
  }, [socket, currentUserId])

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
    }, resolveName, resolveAvatar)
    serviceRef.current = service
    return service
  }, [stopTimer, resolveName, resolveAvatar])

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
