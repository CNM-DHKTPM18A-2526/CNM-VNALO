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
  

  // 1. Setup Socket
  useEffect(() => {
    if (!accessToken) return

    const url = SOCKET_URL.endsWith('/') ? `${SOCKET_URL}chat` : `${SOCKET_URL}/chat`;
    console.log('[CallPage] Connecting to socket:', url);
    
    const newSocket = io(url, {
      auth: { token: accessToken },
      transports: ['websocket'],
    })

    newSocket.on('connect', () => {
      console.log('[CallPage] Socket connected to /chat namespace')
      setSocket(newSocket)
    })

    return () => {
      newSocket.disconnect()
    }
  }, [accessToken])

  // 2. Setup Call Services immediately to handle media ASAP
  const callServiceRef = useRef<WebRtcCallService | null>(null)
  const groupServiceRef = useRef<WebRtcGroupCallService | null>(null)

  if (!callServiceRef.current) {
    callServiceRef.current = new WebRtcCallService((state) => {
      setCallState(state)
      // Only close automatically on explicit hangup/completion, not initialization errors
      if (state.isEnded && !state.error) window.close()
    })
  }
  
  if (!groupServiceRef.current) {
    groupServiceRef.current = new WebRtcGroupCallService((s) => {
      setGroupSnapshot(s)
      if (s.isEnded) window.close()
    })
  }

  const service = callServiceRef.current
  const groupService = groupServiceRef.current

  // Pre-request media ASAP (Concurrent with auth/socket load)
  useEffect(() => {
    if (type === 'direct') {
      console.log('[CallPage] Pre-requesting local media (1-1)...');
      void service.openLocalMedia();
    } else if (type === 'group') {
      console.log('[CallPage] Pre-requesting local media (Group)...');
      void groupService.openLocalMedia();
    }
  }, [type, audioOnly, service, groupService]);

  useEffect(() => {
    if (!socket || !user || !callId || !conversationId) return

    if (type === 'direct' && peerId) {

      const initialSdpStr = (() => {
        // FIX BUG #12: Try sessionStorage first
        const callKey = `offer_${callId}`;
        const ssStr = sessionStorage.getItem(callKey);
        if (ssStr) {
          sessionStorage.removeItem(callKey);
          try { return atob(ssStr); } catch { /* ignore */ }
        }
        const lsStr = localStorage.getItem(`pending_offer_${callId}`);
        if (lsStr) { localStorage.removeItem(`pending_offer_${callId}`); }
        return lsStr;
      })();
      let initialSdp: RTCSessionDescriptionInit | undefined = undefined;
      if (initialSdpStr) {
        try {
          initialSdp = JSON.parse(initialSdpStr);
        } catch (e) {
          console.error('[CallPage] Failed to parse initial SDP', e);
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

      // Listener for 1-1 signaling (Handle both colon and dot notation)
      const onAnswer = (data: any) => {
        if (data.callId === callId) {
           console.log('[CallPage] Received answer', data);
           service.handleAnswer(data.sdp);
        }
      };
      const onIce = (data: any) => {
        if (data.callId === callId) {
           service.handleIceCandidate(data.candidate);
        }
      };
      const onEnd = (data: any) => {
        if (data.callId === callId) {
           console.log('[CallPage] Received end call', data);
           service.endCall(data.reason, false);
        }
      };

      socket.on('call:answer', onAnswer)
      socket.on('call.answer', onAnswer)
      
      socket.on('call:ice-candidate', onIce)
      socket.on('call.ice-candidate', onIce)
      
      socket.on('call:end', onEnd)
      socket.on('call.end', onEnd)

    } else if (type === 'group') {
      if (isCaller) {
        groupService.startCall({
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
        groupService.joinCall({
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
  }, [socket, user, type, callId, conversationId, peerId, audioOnly, isCaller, peerName, service, groupService])

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
