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
import { Mic, MicOff, Video, VideoOff, Phone, Users } from 'lucide-react'
import type { GroupCallSnapshot, GroupPeerState, IncomingGroupCallInfo } from '../webrtcGroupCallService'
import type { ConversationSummary } from '../chat.types'
import { WebRtcGroupCallService } from '../webrtcGroupCallService'
import type { Socket } from 'socket.io-client'
// import { resolveMediaUrl } from '../../../utils/mediaUtils' // removed as unused in this file now
import { PremiumVideoTile } from './PremiumCallUI'

// ─────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────

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
  
  // Custom grid rendering logic
  const renderTiles = () => {
    const allTiles = [
      {
        id: 'local',
        stream: snapshot.localStream,
        displayName: localUserName,
        avatarUrl: localUserAvatar,
        isSpeaking: false,
        isMicOn: snapshot.isMicOn,
        isCameraOn: snapshot.isCameraOn,
        isLocal: true,
        audioOnly: snapshot.audioOnly
      },
      ...snapshot.peers.map((peer: GroupPeerState) => ({
        id: peer.userId,
        stream: peer.remoteStream,
        displayName: peer.displayName,
        avatarUrl: peer.avatarUrl,
        isSpeaking: peer.isSpeaking,
        isMicOn: peer.isMicOn,
        isCameraOn: peer.isCameraOn,
        isLocal: false,
        audioOnly: snapshot.audioOnly
      }))
    ];

    if (allTiles.length === 1) {
      const tile = allTiles[0];
      return (
        <div className="w-full h-full">
          <PremiumVideoTile
            stream={tile.stream}
            displayName={tile.displayName}
            avatarUrl={tile.avatarUrl}
            isSpeaking={tile.isSpeaking}
            isMicOn={tile.isMicOn}
            isCameraOn={tile.isCameraOn}
            isLocal={tile.isLocal}
            size="full"
          />
        </div>
      );
    }

    if (allTiles.length === 2) {
      return (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 h-full">
          {allTiles.map(tile => (
            <PremiumVideoTile
              key={tile.id}
              stream={tile.stream}
              displayName={tile.displayName}
              avatarUrl={tile.avatarUrl}
              isSpeaking={tile.isSpeaking}
              isMicOn={tile.isMicOn}
              isCameraOn={tile.isCameraOn}
              isLocal={tile.isLocal}
              size="full"
            />
          ))}
        </div>
      );
    }

    if (allTiles.length === 3) {
      return (
        <div className="grid grid-cols-2 gap-3 h-full grid-rows-2">
          {allTiles.map((tile, idx) => (
            <div key={tile.id} className={idx === 2 ? 'col-span-2' : ''}>
              <PremiumVideoTile
                stream={tile.stream}
                displayName={tile.displayName}
                avatarUrl={tile.avatarUrl}
                isSpeaking={tile.isSpeaking}
                isMicOn={tile.isMicOn}
                isCameraOn={tile.isCameraOn}
                isLocal={tile.isLocal}
                size="full"
              />
            </div>
          ))}
        </div>
      );
    }

    // 4+ people
    const cols = allTiles.length <= 4 ? 'grid-cols-2' : 'grid-cols-3';
    return (
      <div className={`grid ${cols} gap-3 h-full`}>
        {allTiles.map(tile => (
          <PremiumVideoTile
            key={tile.id}
            stream={tile.stream}
            displayName={tile.displayName}
            avatarUrl={tile.avatarUrl}
            isSpeaking={tile.isSpeaking}
            isMicOn={tile.isMicOn}
            isCameraOn={tile.isCameraOn}
            isLocal={tile.isLocal}
            size="full"
          />
        ))}
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-[200] flex flex-col bg-[#1C1C2E]">
      {/* ── HEADER ── */}
      <div className="flex items-center justify-between px-6 py-4 bg-[#131313]/90 backdrop-blur-md border-b border-white/5">
        <div className="flex items-center gap-3 text-white">
          <Users size={20} className="text-[#00A2ED]" />
          <span className="font-bold text-[15px]">Cuộc gọi nhóm</span>
          <span className="text-sm font-semibold text-white/50">{totalTiles} người</span>
        </div>
        {elapsedSeconds > 0 && (
          <div className="text-white/80 text-[15px] font-mono font-bold tracking-widest">
            {formatTime(elapsedSeconds)}
          </div>
        )}
        {snapshot.error && (
          <div className="text-[#FF3B30] text-xs font-bold px-3 py-1 bg-[#FF3B30]/20 rounded-full border border-[#FF3B30]/30">
            {snapshot.error}
          </div>
        )}
      </div>

      {/* ── GRID ── */}
      <div className="flex-1 overflow-y-auto p-4 flex flex-col justify-center bg-[#000000]">
        {renderTiles()}

        {snapshot.peers.length === 0 && (
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none z-50">
            <div className="bg-black/50 backdrop-blur-md px-6 py-3 rounded-full flex items-center gap-3">
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-green-500"></span>
              </span>
              <p className="text-white font-medium text-sm">Đang chờ người khác tham gia...</p>
            </div>
          </div>
        )}
      </div>

      {/* ── CONTROLS ── */}
      <div className="grid grid-cols-3 items-center justify-items-center w-[280px] mx-auto gap-4 py-5 bg-black/30 backdrop-blur-sm border-t border-white/10">
        <button
          onClick={onToggleMic}
          title={snapshot.isMicOn ? 'Tắt micro' : 'Bật micro'}
          className={`w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95
            ${snapshot.isMicOn ? 'bg-white/20 text-white hover:bg-white/30' : 'bg-red-500 text-white hover:bg-red-600'}`}
        >
          {snapshot.isMicOn ? <Mic size={22} /> : <MicOff size={22} />}
        </button>

        <button
          onClick={onLeave}
          title="Rời cuộc gọi"
          className="w-16 h-16 rounded-full bg-[#FF3B30] text-white flex items-center justify-center hover:bg-[#E03328] transition-all active:scale-90 shadow-lg shadow-[#FF3B30]/40 border border-white/10"
        >
          <Phone size={28} className="fill-white rotate-[135deg] transform-gpu" />
        </button>

        {!snapshot.audioOnly ? (
          <button
            onClick={onToggleCamera}
            title={snapshot.isCameraOn ? 'Tắt camera' : 'Bật camera'}
            className={`w-14 h-14 rounded-full flex items-center justify-center transition-all active:scale-95
              ${snapshot.isCameraOn ? 'bg-white/20 text-white hover:bg-white/30' : 'bg-slate-600 text-white hover:bg-slate-500'}`}
          >
            {snapshot.isCameraOn ? <Video size={22} /> : <VideoOff size={22} />}
          </button>
        ) : (
          <div className="w-14 h-14" />
        )}
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
  userMap?: Record<string, { displayName: string; avatarUrl: string | null; bio?: string | null }>
  conversations?: ConversationSummary[]
}

// eslint-disable-next-line react-refresh/only-export-components
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
  const userMapRef = useRef(userMap)

  // Always keep userMapRef in sync with the latest userMap (avoids stale closure in service)
  useEffect(() => {
    userMapRef.current = userMap
  }, [userMap])

  // FIX: Use userMapRef directly instead of userMap in closures.
  // This prevents stale closures where resolveName/resolveAvatar capture
  // an old userMap that doesn't have group members' profiles yet.
  const resolveName = useCallback((uid: string) => {
    return userMapRef.current?.[uid]?.displayName || undefined
  }, [])

  const resolveAvatar = useCallback((uid: string) => {
    return userMapRef.current?.[uid]?.avatarUrl || undefined
  }, [])

  // Listen for incoming group-call:started from OTHER users
  useEffect(() => {
    if (!socket) return

    const onGroupCallStarted = (payload: {
      callerUserId?: string;
      senderUserId?: string;
      userId?: string;
      callerName?: string;
      displayName?: string;
      name?: string;
      fullName?: string;
      full_name?: string;
      conversationId?: string;
      groupId?: string;
      conversationName?: string;
      groupName?: string;
      callId: string;
      groupAvatar?: string;
      conversationAvatar?: string;
      callerAvatar?: string;
      avatarUrl?: string;
      audioOnly?: boolean;
    }) => {
      // Normalize payload fields (mobile might use different keys)
      const callerUserId = payload.callerUserId || payload.senderUserId || payload.userId || ''
      
      const isId = (s: string | undefined | null) => typeof s === 'string' && s.length > 20 && /^[0-9a-fA-F-]/.test(s)
      let callerName = payload.callerName || payload.displayName || payload.name || payload.fullName || payload.full_name
      if (!callerName || isId(callerName)) {
        const resolved = resolveName(callerUserId)
        callerName = resolved || (isId(callerName) ? 'Người dùng' : (callerName || 'Người dùng'))
      }

      const conversationId = (payload.conversationId || payload.groupId) as string
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
        callerAvatar: payload.callerAvatar || payload.avatarUrl || (userMapRef.current?.[callerUserId]?.avatarUrl ?? undefined),
        groupAvatar: groupAvatar || undefined,
        audioOnly: !!payload.audioOnly,
      })
    }

    socket.off('group-call:started')
    socket.on('group-call:started', onGroupCallStarted)

    return () => {
      socket.off('group-call:started', onGroupCallStarted)
    }
  }, [socket, currentUserId, snapshot, conversations])

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
    const onUserJoined = (payload: { senderUserId?: string; userId?: string; uid?: string }) => {
      const joinedUserId = payload.senderUserId || payload.userId || payload.uid
      console.log('[useGroupCall] 👤 User joined event received:', { joinedUserId, currentUserId })
      if (joinedUserId && String(joinedUserId) === String(currentUserId)) {
         console.log('[useGroupCall] 📱 You joined from another device, dismissing web banner')
         setIncomingCall(null)
      }
    }

    // Tương tự cho user-left (nếu mình từ chối ở máy khác)
    const onUserLeft = (payload: { senderUserId?: string; userId?: string; uid?: string }) => {
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
