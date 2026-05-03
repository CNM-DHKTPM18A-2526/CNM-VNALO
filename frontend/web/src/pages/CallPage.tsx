import React, { useEffect, useRef, useState } from 'react'
import { useSearchParams, useParams } from 'react-router-dom'
import { io, Socket } from 'socket.io-client'
import { CallModal } from '../features/chat/components/CallModal'
import { GroupCallModal } from '../features/chat/components/GroupCallModal'
import { WebRtcCallService } from '../features/chat/webrtcCallService'
import type { WebRTCCallState } from '../features/chat/webrtcCallService'
import { WebRtcGroupCallService } from '../features/chat/webrtcGroupCallService'
import type { GroupCallSnapshot } from '../features/chat/webrtcGroupCallService'
import { useAuth } from '../features/auth/useAuth'
import { WS_BASE_URL as SOCKET_URL } from '../api.client'

const CallPage: React.FC = () => {
  const [searchParams] = useSearchParams()
  const { user, accessToken } = useAuth()
  
  const type = searchParams.get('type') as 'direct' | 'group'
  const { callId: pathCallId } = useParams<{ callId: string }>()
  const callId = pathCallId || searchParams.get('callId')
  const conversationId = searchParams.get('conversationId')
  const peerId = searchParams.get('peerId')
  const audioOnly = searchParams.get('audioOnly') === 'true'
  const isCaller = searchParams.get('isCaller') === 'true'
  const peerName = searchParams.get('peerName') || 'Người dùng'
  const peerAvatar = searchParams.get('peerAvatar')

  const [socket, setSocket] = useState<Socket | null>(null)
  const [callState, setCallState] = useState<WebRTCCallState>({
    pc: null,
    localStream: null,
    remoteStream: null,
    isConnected: false,
    isEnded: false,
    isMicOn: true,
    isCameraOn: !audioOnly,
    isRemoteMicOn: true,
    isRemoteCameraOn: !audioOnly,
    hasRemoteDescription: false,
    pendingCandidates: [],
    error: null,
  })
  const [groupSnapshot, setGroupSnapshot] = useState<GroupCallSnapshot | null>(null)
  
  const callServiceRef = useRef<WebRtcCallService | null>(null)
  const groupServiceRef = useRef<WebRtcGroupCallService | null>(null)

  // 1. Setup Socket
  useEffect(() => {
    if (!accessToken) return

    const newSocket = io(SOCKET_URL, {
      auth: { token: accessToken },
      transports: ['websocket'],
    })

    newSocket.on('connect', () => {
      console.log('[CallPage] Socket connected')
      setSocket(newSocket)
    })

    return () => {
      newSocket.disconnect()
    }
  }, [accessToken])

  // 2. Setup Call Service
  useEffect(() => {
    if (!socket || !user || !callId || !conversationId) return

    if (type === 'direct' && peerId) {
      const service = new WebRtcCallService((state) => {
        setCallState(state)
        if (state.isEnded) window.close()
      })
      callServiceRef.current = service

      const initialSdpStr = localStorage.getItem(`pending_offer_${callId}`)
      let initialSdp = null
      if (initialSdpStr) {
        try {
          initialSdp = JSON.parse(initialSdpStr)
          localStorage.removeItem(`pending_offer_${callId}`)
        } catch (e) {
          console.error('[CallPage] Failed to parse initial SDP', e)
        }
      }

      service.initialize({
        socket,
        conversationId,
        callId,
        currentUserId: user.id,
        peerUserId: peerId,
        audioOnly,
        isCaller,
        initialSdp,
      })

      // Listener for 1-1 signaling
      // NOTE: We MUST listen on DOT notation ('call.answer', etc.) to match what
      // webrtcCallService emits and what the backend gateway emits via emitToUser().
      // The backend @SubscribeMessage handlers also use DOT notation.
      socket.on('call.answer', (data) => {
        if (data.callId === callId) service.handleAnswer(data.sdp)
      })
      socket.on('call.ice-candidate', (data) => {
        if (data.callId === callId) service.handleIceCandidate(data.candidate)
      })
      socket.on('call.end', (data) => {
        if (data.callId === callId) service.endCall(data.reason, false)
      })

    } else if (type === 'group') {
      const service = new WebRtcGroupCallService((snapshot) => {
        setGroupSnapshot(snapshot)
        if (snapshot.isEnded) window.close()
      })
      groupServiceRef.current = service

      if (isCaller) {
        service.startCall({
          socket,
          conversationId,
          conversationName: peerName, // For group, peerName param is reused as convName
          callId,
          currentUserId: user.id,
          currentUserName: user.name || 'Bạn',
          currentUserAvatar: user.avatarUrl || undefined,
          audioOnly,
        })
      } else {
        service.joinCall({
          socket,
          conversationId,
          callId,
          currentUserId: user.id,
          currentUserName: user.name || 'Bạn',
          currentUserAvatar: user.avatarUrl || undefined,
          audioOnly,
        })
      }
    }

    return () => {
      callServiceRef.current?.endCall('hangup')
      groupServiceRef.current?.leave()
    }
  }, [socket, user, type, callId, conversationId, peerId, audioOnly, isCaller, peerName])

  // 3. Handle window close
  useEffect(() => {
    const handleUnload = () => {
      callServiceRef.current?.endCall('hangup')
      groupServiceRef.current?.leave()
    }
    window.addEventListener('beforeunload', handleUnload)
    return () => window.removeEventListener('beforeunload', handleUnload)
  }, [])

  if (!callId) return <div className="h-screen bg-black flex items-center justify-center text-white">Invalid Call ID</div>

  if (!accessToken) return <div className="h-screen bg-black flex flex-col items-center justify-center text-white gap-4">
    <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
    <p>Đang xác thực phiên làm việc...</p>
  </div>

  if (!user) return <div className="h-screen bg-black flex flex-col items-center justify-center text-white gap-4">
    <div className="w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
    <p>Đang tải thông tin người dùng...</p>
  </div>

  return (
    <div className="h-screen w-screen bg-black overflow-hidden">
      {type === 'direct' && (
        <CallModal
          isOpen={true}
          type={audioOnly ? 'audio' : 'video'}
          status={callState.isConnected ? 'connected' : callState.error ? 'failed' : 'connecting'}
          peerName={peerName}
          peerAvatar={peerAvatar}
          localAvatar={user?.avatarUrl}
          localStream={callState.localStream}
          remoteStream={callState.remoteStream}
          isMicOn={callState.isMicOn}
          isCameraOn={callState.isCameraOn}
          isRemoteCameraOn={callState.isRemoteCameraOn}
          hasRemoteDescription={callState.hasRemoteDescription}
          onEnd={() => {
            callServiceRef.current?.endCall('hangup')
            window.close()
          }}
          onToggleMic={() => callServiceRef.current?.toggleMic()}
          onToggleCamera={() => callServiceRef.current?.toggleCamera()}
          error={callState.error}
        />
      )}

      {type === 'group' && groupSnapshot && (
        <GroupCallModal
          isOpen={true}
          snapshot={groupSnapshot}
          localUserName={user?.name ?? 'Bạn'}
          localUserAvatar={user?.avatarUrl ?? undefined}
          onLeave={() => {
            groupServiceRef.current?.leave()
            window.close()
          }}
          onToggleMic={() => groupServiceRef.current?.toggleMic()}
          onToggleCamera={() => groupServiceRef.current?.toggleCamera()}
          elapsedSeconds={0} // We'll need to sync timer or just let it start from 0
        />
      )}
    </div>
  )
}

export default CallPage
