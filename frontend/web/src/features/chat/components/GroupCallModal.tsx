import React, { useEffect, useState } from 'react'
import type { GroupCallSnapshot, GroupPeerState, IncomingGroupCallInfo } from '../webrtcGroupCallService'
import { WebRtcGroupCallService } from '../webrtcGroupCallService'
import type { Socket } from 'socket.io-client'
import { PremiumVideoTile, PremiumCallControls } from './PremiumCallUI'

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
  onMinimize?: () => void
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
  onMinimize,
}) => {
  if (!isOpen) return null

  const totalTiles = 1 + snapshot.peers.length
  const gridCols = getGridCols(totalTiles)

  return (
    <div className="fixed inset-0 z-[500] bg-[#000000] flex flex-col overflow-hidden">
      {/* ── BACKGROUND ── */}
      <div className="absolute inset-0 z-0">
        <div className="w-full h-full bg-gradient-to-br from-[#001A33] via-[#000000] to-black" />
        <div className="absolute inset-0 bg-[#007BFF]/5" />
      </div>

      {/* ── HEADER ── */}
      <div className="relative z-10 flex items-center justify-between px-6 py-4 backdrop-blur-md bg-white/5 border-b border-white/10">
        <div className="flex items-center gap-3 text-white">
          <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          <span className="font-bold text-sm uppercase tracking-wider opacity-80">Cuộc gọi nhóm</span>
          <span className="text-xs bg-white/10 px-2 py-0.5 rounded-full border border-white/10 ml-2">
            {totalTiles} người tham gia
          </span>
        </div>
        {elapsedSeconds > 0 && (
          <div className="text-white/90 text-sm font-mono font-bold bg-white/5 px-4 py-1 rounded-full border border-white/10">
            {formatTime(elapsedSeconds)}
          </div>
        )}
      </div>

      {/* ── GRID ── */}
      <div className="relative z-10 flex-1 overflow-y-auto p-4 sm:p-8">
        <div className={`grid ${gridCols} gap-4 sm:gap-6 h-full auto-rows-fr`}>
          {/* LOCAL TILE */}
          <PremiumVideoTile
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
            <PremiumVideoTile
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
          <div className="absolute inset-0 flex flex-col items-center justify-center text-white/30 pointer-events-none">
            <p className="text-lg font-medium">Đang chờ người khác tham gia...</p>
          </div>
        )}
      </div>

      {/* ── CONTROLS ── */}
      <div className="relative z-10 py-8">
        <PremiumCallControls
          isMicOn={snapshot.isMicOn}
          isCameraOn={snapshot.isCameraOn}
          isAudioOnly={snapshot.audioOnly}
          onToggleMic={onToggleMic}
          onToggleCamera={onToggleCamera}
          onEnd={onLeave}
          onMinimize={onMinimize}
        />
      </div>

      {snapshot.error && (
        <div className="absolute top-20 left-1/2 -translate-x-1/2 z-50 bg-red-500 text-white text-xs font-bold px-4 py-2 rounded-full shadow-lg border border-red-400">
          {snapshot.error}
        </div>
      )}
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
  conversations?: any[]
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
  const serviceRef = React.useRef<WebRtcGroupCallService | null>(null)
  const timerRef = React.useRef<ReturnType<typeof setInterval> | null>(null)

  const resolveName = React.useCallback((uid: string) => {
    return userMap?.[uid]?.displayName || userMap?.[uid]?.name
  }, [userMap])

  const resolveAvatar = React.useCallback((uid: string) => {
    return userMap?.[uid]?.avatarUrl
  }, [userMap])

  // Listen for incoming group-call:started from OTHER users
  useEffect(() => {
    if (!socket) return

    const onGroupCallStarted = (payload: any) => {
      const callerUserId = payload.callerUserId || payload.senderUserId || payload.userId
      if (callerUserId === currentUserId) return
      if (snapshot !== null) return

      const isId = (s: any) => typeof s === 'string' && s.length > 20 && /^[0-9a-fA-F-]/.test(s)
      let callerName = payload.callerName || payload.displayName || payload.name || payload.fullName || payload.full_name
      if (!callerName || isId(callerName)) {
        callerName = resolveName(callerUserId) || callerName || 'Người dùng'
      }

      const conversationId = payload.conversationId || payload.groupId
      const conversationName = payload.conversationName || payload.groupName || 'Cuộc gọi nhóm'
      const callId = payload.callId

      const conv = (conversations || []).find(c => c.id === conversationId)
      const groupAvatar = conv?.avatarUrl || payload.groupAvatar || payload.conversationAvatar

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

    socket.on('group-call:started', onGroupCallStarted)
    return () => { socket.off('group-call:started', onGroupCallStarted) }
  }, [socket, currentUserId, snapshot, resolveName, userMap, conversations])

  // Clear incoming when ended or joined elsewhere
  useEffect(() => {
    if (!socket) return
    const onGroupCallEnded = (payload: any) => {
      setIncomingCall((prev) => (prev && prev.callId === payload.callId ? null : prev))
    }
    const onUserJoined = (payload: any) => {
      const joinedUserId = payload.senderUserId || payload.userId || payload.uid
      if (joinedUserId && String(joinedUserId) === String(currentUserId)) setIncomingCall(null)
    }
    socket.on('group-call:ended', onGroupCallEnded)
    socket.on('group-call:user-joined', onUserJoined)
    socket.on('group-call:join', onUserJoined)
    return () => {
      socket.off('group-call:ended', onGroupCallEnded)
      socket.off('group-call:user-joined', onUserJoined)
      socket.off('group-call:join', onUserJoined)
    }
  }, [socket, currentUserId])

  const startTimer = React.useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current)
    setElapsedSeconds(0)
    timerRef.current = setInterval(() => setElapsedSeconds((prev) => prev + 1), 1000)
  }, [])

  const stopTimer = React.useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current)
      timerRef.current = null
    }
  }, [])

  const createService = React.useCallback(() => {
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

  const startGroupCall = React.useCallback(
    async (params: any) => {
      if (!socket) return
      const service = createService()
      startTimer()
      await service.startCall({
        socket,
        ...params,
        currentUserId,
        currentUserName,
        currentUserAvatar,
        audioOnly: params.audioOnly ?? false,
      })
    },
    [socket, currentUserId, currentUserName, currentUserAvatar, createService, startTimer]
  )

  const joinGroupCall = React.useCallback(
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

  const declineGroupCall = React.useCallback(() => setIncomingCall(null), [])
  const leaveGroupCall = React.useCallback(() => {
    serviceRef.current?.leave()
    stopTimer()
    setSnapshot(null)
  }, [stopTimer])

  const toggleMic = React.useCallback(() => serviceRef.current?.toggleMic(), [])
  const toggleCamera = React.useCallback(() => serviceRef.current?.toggleCamera(), [])

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
