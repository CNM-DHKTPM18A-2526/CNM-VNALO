/**
 * webrtcGroupCallService.ts
 *
 * ⚠️  LAYER HOÀN TOÀN ĐỘC LẬP với webrtcCallService.ts (call 1-1).
 *
 * Flow đúng giống Zalo:
 *   1. Caller  →  emit group-call:started  (broadcast tới cả nhóm)
 *   2. Others  →  nhận group-call:incoming →  hiện banner "Tham gia"
 *   3. Others  →  bấm "Tham gia"          →  emit group-call:join
 *   4. Mọi người đang trong phòng nhận group-call:user-joined
 *                                          →  tạo peer + gửi offer
 *   5. Signaling WebRTC bình thường (offer/answer/ice)
 */

import type { Socket } from 'socket.io-client'

// ─────────────────────────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────────────────────────

export interface GroupPeerState {
  userId: string
  displayName: string
  avatarUrl?: string
  pc: RTCPeerConnection
  remoteStream: MediaStream | null
  isSpeaking: boolean
  isMicOn: boolean
  isCameraOn: boolean
  pendingCandidates: RTCIceCandidate[]
  hasRemoteDescription: boolean
}

export interface GroupCallSnapshot {
  callId: string
  conversationId: string
  localStream: MediaStream | null
  peers: GroupPeerState[]
  isEnded: boolean
  isMicOn: boolean
  isCameraOn: boolean
  audioOnly: boolean
  error: string | null
}

/** Thông tin cuộc gọi nhóm đến để hiển thị notification */
export interface IncomingGroupCallInfo {
  callId: string
  conversationId: string
  conversationName: string
  callerName: string
  callerAvatar?: string
  audioOnly: boolean
}

// ─────────────────────────────────────────────────────────────────
// ICE SERVERS
// ─────────────────────────────────────────────────────────────────

function buildIceServers(): RTCIceServer[] {
  const servers: RTCIceServer[] = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun2.l.google.com:19302' },
  ]
  const turnUrl = (import.meta as any).env?.VITE_TURN_URL
  const turnUser = (import.meta as any).env?.VITE_TURN_USERNAME
  const turnPass = (import.meta as any).env?.VITE_TURN_PASSWORD
  if (turnUrl && turnUser && turnPass) {
    servers.push({ urls: turnUrl, username: turnUser, credential: turnPass })
  }
  return servers
}

// ─────────────────────────────────────────────────────────────────
// ACTIVE SPEAKER DETECTION
// ─────────────────────────────────────────────────────────────────

const SPEAKING_THRESHOLD = 15
const SPEAKING_POLL_MS = 200

type SpeakerAnalyser = {
  context: AudioContext
  analyser: AnalyserNode
  source: MediaStreamAudioSourceNode
  interval: ReturnType<typeof setInterval>
}

function createSpeakerAnalyser(
  stream: MediaStream,
  onSpeaking: (speaking: boolean) => void
): SpeakerAnalyser | null {
  try {
    const context = new AudioContext()
    const source = context.createMediaStreamSource(stream)
    const analyser = context.createAnalyser()
    analyser.fftSize = 256
    source.connect(analyser)

    const dataArray = new Uint8Array(analyser.frequencyBinCount)
    let wasSpking = false

    const interval = setInterval(() => {
      analyser.getByteFrequencyData(dataArray)
      const avg = dataArray.reduce((a, b) => a + b, 0) / dataArray.length
      const speaking = avg > SPEAKING_THRESHOLD
      if (speaking !== wasSpking) {
        wasSpking = speaking
        onSpeaking(speaking)
      }
    }, SPEAKING_POLL_MS)

    return { context, analyser, source, interval }
  } catch {
    return null
  }
}

function destroySpeakerAnalyser(analyser: SpeakerAnalyser | null) {
  if (!analyser) return
  clearInterval(analyser.interval)
  analyser.source.disconnect()
  analyser.context.close().catch(() => {})
}

// ─────────────────────────────────────────────────────────────────
// SERVICE CLASS
// ─────────────────────────────────────────────────────────────────

interface GroupCallState {
  callId: string
  conversationId: string
  localStream: MediaStream | null
  peers: Map<string, GroupPeerState>
  isEnded: boolean
  isMicOn: boolean
  isCameraOn: boolean
  audioOnly: boolean
  error: string | null
}

export class WebRtcGroupCallService {
  private state: GroupCallState = {
    callId: '',
    conversationId: '',
    localStream: null,
    peers: new Map(),
    isEnded: false,
    isMicOn: true,
    isCameraOn: true,
    audioOnly: false,
    error: null,
  }

  private socket: Socket | null = null
  private currentUserId: string = ''
  private currentUserName: string = ''
  private currentUserAvatar: string = ''
  private onStateChange: (snapshot: GroupCallSnapshot) => void

  private localAnalyser: SpeakerAnalyser | null = null
  private remoteAnalysers: Map<string, SpeakerAnalyser> = new Map()

  constructor(onStateChange: (snapshot: GroupCallSnapshot) => void) {
    this.onStateChange = onStateChange
  }

  // ─── INIT (Caller starts) ────────────────────────────────────────
  /**
   * Được gọi bởi người BẮT ĐẦU cuộc gọi.
   * Chỉ broadcast group-call:started tới cả nhóm.
   * KHÔNG tạo peer connections trước — chỉ tạo khi có người join.
   */
  async startCall(params: {
    socket: Socket
    conversationId: string
    conversationName: string
    callId: string
    currentUserId: string
    currentUserName: string
    currentUserAvatar?: string
    audioOnly?: boolean
  }) {
    console.log('[GroupCall] 📣 Starting call (broadcast)', params)
    this.socket = params.socket
    this.currentUserId = params.currentUserId
    this.currentUserName = params.currentUserName
    this.currentUserAvatar = params.currentUserAvatar ?? ''
    this.state.conversationId = params.conversationId
    this.state.callId = params.callId
    this.state.audioOnly = params.audioOnly ?? false
    this.state.isEnded = false
    this.state.error = null

    try {
      // 1. Mở camera/mic cho bản thân
      await this.openLocalMedia()

      // 2. Đăng ký lắng nghe socket (các user khác join)
      this.registerSocketListeners()

      // 3. Broadcast thông báo tới cả nhóm (BẮT BUỘC backend relay tới conversation room)
      this.socket?.emit('group-call:started', {
        conversationId: this.state.conversationId,
        conversationName: params.conversationName,
        callId: this.state.callId,
        callerUserId: this.currentUserId,
        callerName: this.currentUserName,
        callerAvatar: this.currentUserAvatar,
        audioOnly: this.state.audioOnly,
      })

      console.log('[GroupCall] ✅ Started, waiting for peers to join...')
      this.notify()
    } catch (err) {
      console.error('[GroupCall] Start failed', err)
      this.updateState({ error: 'Không thể khởi động group call' })
    }
  }

  // ─── JOIN (Other users join) ─────────────────────────────────────
  /**
   * Được gọi bởi người THAM GIA sau khi nhận notification.
   * Mở media → emit group-call:join → những người đã trong room nhận được
   * group-call:user-joined và tạo offer tới mình.
   */
  async joinCall(params: {
    socket: Socket
    conversationId: string
    callId: string
    currentUserId: string
    currentUserName: string
    currentUserAvatar?: string
    audioOnly?: boolean
  }) {
    console.log('[GroupCall] 🚪 Joining call', params)
    this.socket = params.socket
    this.currentUserId = params.currentUserId
    this.currentUserName = params.currentUserName
    this.currentUserAvatar = params.currentUserAvatar ?? ''
    this.state.conversationId = params.conversationId
    this.state.callId = params.callId
    this.state.audioOnly = params.audioOnly ?? false
    this.state.isEnded = false
    this.state.error = null

    try {
      await this.openLocalMedia()
      this.registerSocketListeners()

      // Thông báo cho cả room biết mình vừa join
      this.socket?.emit('group-call:join', {
        conversationId: this.state.conversationId,
        callId: this.state.callId,
        senderUserId: this.currentUserId,
        displayName: this.currentUserName,
        avatarUrl: this.currentUserAvatar,
        audioOnly: this.state.audioOnly,
      })

      console.log('[GroupCall] ✅ Join emitted, waiting for offers...')
      this.notify()
    } catch (err) {
      console.error('[GroupCall] Join failed', err)
      this.updateState({ error: 'Không thể tham gia cuộc gọi' })
    }
  }

  // ─── LOCAL MEDIA ─────────────────────────────────────────────────

  private async openLocalMedia() {
    const constraints = {
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      video: this.state.audioOnly ? false : { facingMode: 'user', width: 1280, height: 720 },
    }
    const stream = await navigator.mediaDevices.getUserMedia(constraints)
    this.updateState({ localStream: stream })

    this.localAnalyser = createSpeakerAnalyser(stream, (_speaking) => {
      // local speaking indicator placeholder
    })
  }

  // ─── SOCKET LISTENERS ────────────────────────────────────────────

  private registerSocketListeners() {
    if (!this.socket) return

    this.socket.off('group-call:user-joined')
    this.socket.off('group-call:offer')
    this.socket.off('group-call:answer')
    this.socket.off('group-call:ice-candidate')
    this.socket.off('group-call:user-left')

    this.socket.on('group-call:user-joined', this.onUserJoined)
    this.socket.on('group-call:offer', this.onRemoteOffer)
    this.socket.on('group-call:answer', this.onRemoteAnswer)
    this.socket.on('group-call:ice-candidate', this.onRemoteIceCandidate)
    this.socket.on('group-call:user-left', this.onUserLeft)
  }

  private removeSocketListeners() {
    if (!this.socket) return
    this.socket.off('group-call:user-joined', this.onUserJoined)
    this.socket.off('group-call:offer', this.onRemoteOffer)
    this.socket.off('group-call:answer', this.onRemoteAnswer)
    this.socket.off('group-call:ice-candidate', this.onRemoteIceCandidate)
    this.socket.off('group-call:user-left', this.onUserLeft)
  }

  /**
   * Khi nhận được sự kiện group-call:user-joined từ server
   * (backend relay tới mọi người trong room),
   * người trong room tạo offer gửi tới người vừa join.
   */
  private onUserJoined = async (payload: {
    senderUserId: string
    displayName: string
    avatarUrl?: string
    callId: string
    conversationId: string
  }) => {
    if (payload.callId !== this.state.callId) return
    if (payload.senderUserId === this.currentUserId) return
    if (this.state.peers.has(payload.senderUserId)) return

    console.log('[GroupCall] 👤 New peer joined:', payload.senderUserId)
    await this.createPeerAndOffer({
      userId: payload.senderUserId,
      displayName: payload.displayName,
      avatarUrl: payload.avatarUrl,
    })
  }

  private onRemoteOffer = async (payload: {
    senderUserId: string
    targetUserId: string
    callId: string
    conversationId: string
    displayName?: string
    avatarUrl?: string
    sdp: RTCSessionDescriptionInit
  }) => {
    if (payload.callId !== this.state.callId) return
    if (payload.targetUserId !== this.currentUserId) return

    console.log('[GroupCall] 📥 Offer from:', payload.senderUserId)

    if (!this.state.peers.has(payload.senderUserId)) {
      this.createPeerState({
        userId: payload.senderUserId,
        displayName: payload.displayName ?? payload.senderUserId,
        avatarUrl: payload.avatarUrl,
      })
    }

    const peer = this.state.peers.get(payload.senderUserId)!
    try {
      await peer.pc.setRemoteDescription(new RTCSessionDescription(payload.sdp))
      peer.hasRemoteDescription = true
      await this.flushPendingCandidates(peer)

      const answer = await peer.pc.createAnswer()
      await peer.pc.setLocalDescription(answer)

      this.socket?.emit('group-call:answer', {
        conversationId: this.state.conversationId,
        callId: this.state.callId,
        senderUserId: this.currentUserId,
        targetUserId: payload.senderUserId,
        sdp: { type: answer.type, sdp: answer.sdp },
      })
    } catch (err) {
      console.error('[GroupCall] Failed to handle offer', err)
    }

    this.notify()
  }

  private onRemoteAnswer = async (payload: {
    senderUserId: string
    targetUserId: string
    callId: string
    sdp: RTCSessionDescriptionInit
  }) => {
    if (payload.callId !== this.state.callId) return
    if (payload.targetUserId !== this.currentUserId) return

    const peer = this.state.peers.get(payload.senderUserId)
    if (!peer) return

    if (peer.pc.signalingState === 'stable') {
      console.warn('[GroupCall] Ignoring answer: already stable')
      return
    }

    try {
      await peer.pc.setRemoteDescription(new RTCSessionDescription(payload.sdp))
      peer.hasRemoteDescription = true
      await this.flushPendingCandidates(peer)
    } catch (err) {
      console.error('[GroupCall] Failed to handle answer', err)
    }

    this.notify()
  }

  private onRemoteIceCandidate = async (payload: {
    senderUserId: string
    targetUserId: string
    callId: string
    candidate: RTCIceCandidateInit
  }) => {
    if (payload.callId !== this.state.callId) return
    if (payload.targetUserId !== this.currentUserId) return

    const peer = this.state.peers.get(payload.senderUserId)
    if (!peer || !payload.candidate) return

    try {
      const candidate = new RTCIceCandidate(payload.candidate)
      if (!peer.hasRemoteDescription) {
        peer.pendingCandidates.push(candidate)
      } else {
        await peer.pc.addIceCandidate(candidate)
      }
    } catch (err) {
      console.warn('[GroupCall] Failed to add ICE candidate', err)
    }
  }

  private onUserLeft = (payload: {
    senderUserId: string
    callId: string
    conversationId: string
  }) => {
    if (payload.callId !== this.state.callId) return
    console.log('[GroupCall] 👋 User left:', payload.senderUserId)
    this.removePeer(payload.senderUserId)
    this.notify()
  }

  // ─── PEER MANAGEMENT ────────────────────────────────────────────

  private createPeerState(user: { userId: string; displayName: string; avatarUrl?: string }): GroupPeerState {
    const pc = new RTCPeerConnection({ iceServers: buildIceServers(), iceCandidatePoolSize: 8 })

    const peerState: GroupPeerState = {
      userId: user.userId,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      pc,
      remoteStream: null,
      isSpeaking: false,
      isMicOn: true,
      isCameraOn: true,
      pendingCandidates: [],
      hasRemoteDescription: false,
    }

    this.state.localStream?.getTracks().forEach((track) => {
      pc.addTrack(track, this.state.localStream!)
    })

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.socket?.emit('group-call:ice-candidate', {
          conversationId: this.state.conversationId,
          callId: this.state.callId,
          senderUserId: this.currentUserId,
          targetUserId: user.userId,
          candidate: {
            candidate: event.candidate.candidate,
            sdpMid: event.candidate.sdpMid,
            sdpMLineIndex: event.candidate.sdpMLineIndex,
          },
        })
      }
    }

    pc.ontrack = (event) => {
      console.log('[GroupCall] 🎥 Remote track from:', user.userId)
      const stream = event.streams?.[0] ?? new MediaStream([event.track])
      peerState.remoteStream = stream

      const existing = this.remoteAnalysers.get(user.userId)
      if (existing) destroySpeakerAnalyser(existing)

      const analyser = createSpeakerAnalyser(stream, (speaking) => {
        peerState.isSpeaking = speaking
        this.notify()
      })
      if (analyser) this.remoteAnalysers.set(user.userId, analyser)

      this.notify()
    }

    pc.onconnectionstatechange = () => {
      console.log(`[GroupCall] PC[${user.userId}] state: ${pc.connectionState}`)
      if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
        this.removePeer(user.userId)
        this.notify()
      }
    }

    this.state.peers.set(user.userId, peerState)
    return peerState
  }

  private async createPeerAndOffer(user: { userId: string; displayName: string; avatarUrl?: string }) {
    const peer = this.createPeerState(user)

    try {
      const offer = await peer.pc.createOffer({
        offerToReceiveAudio: true,
        offerToReceiveVideo: !this.state.audioOnly,
      })
      await peer.pc.setLocalDescription(offer)

      this.socket?.emit('group-call:offer', {
        conversationId: this.state.conversationId,
        callId: this.state.callId,
        senderUserId: this.currentUserId,
        targetUserId: user.userId,
        displayName: this.currentUserName,
        avatarUrl: this.currentUserAvatar,
        sdp: { type: offer.type, sdp: offer.sdp },
      })

      console.log('[GroupCall] 📤 Sent offer to:', user.userId)
    } catch (err) {
      console.error('[GroupCall] Failed to create offer', err)
    }

    this.notify()
  }

  private async flushPendingCandidates(peer: GroupPeerState) {
    for (const candidate of peer.pendingCandidates) {
      try {
        await peer.pc.addIceCandidate(candidate)
      } catch (err) {
        console.warn('[GroupCall] Error flushing ICE candidate', err)
      }
    }
    peer.pendingCandidates = []
  }

  private removePeer(userId: string) {
    const peer = this.state.peers.get(userId)
    if (!peer) return
    peer.remoteStream?.getTracks().forEach((t) => t.stop())
    peer.pc.close()
    this.state.peers.delete(userId)
    destroySpeakerAnalyser(this.remoteAnalysers.get(userId) ?? null)
    this.remoteAnalysers.delete(userId)
  }

  // ─── CONTROLS ────────────────────────────────────────────────────

  toggleMic() {
    const stream = this.state.localStream
    if (!stream) return
    const track = stream.getAudioTracks()[0]
    if (track) {
      track.enabled = !track.enabled
      this.updateState({ isMicOn: track.enabled })
    }
  }

  toggleCamera() {
    const stream = this.state.localStream
    if (!stream) return
    const track = stream.getVideoTracks()[0]
    if (track) {
      track.enabled = !track.enabled
      this.updateState({ isCameraOn: track.enabled })
    }
  }

  // ─── LEAVE / CLEANUP ────────────────────────────────────────────

  leave() {
    if (this.state.isEnded) return
    this.updateState({ isEnded: true })

    this.socket?.emit('group-call:leave', {
      conversationId: this.state.conversationId,
      callId: this.state.callId,
      senderUserId: this.currentUserId,
    })

    this.cleanup()
  }

  private cleanup() {
    this.removeSocketListeners()
    this.state.peers.forEach((peer) => {
      peer.remoteStream?.getTracks().forEach((t) => t.stop())
      peer.pc.close()
    })
    this.state.peers.clear()
    this.state.localStream?.getTracks().forEach((t) => t.stop())
    destroySpeakerAnalyser(this.localAnalyser)
    this.localAnalyser = null
    this.remoteAnalysers.forEach((a) => destroySpeakerAnalyser(a))
    this.remoteAnalysers.clear()
    this.updateState({ localStream: null })
  }

  // ─── STATE HELPERS ───────────────────────────────────────────────

  private updateState(patch: Partial<Omit<GroupCallState, 'peers'>>) {
    this.state = { ...this.state, ...patch }
    this.notify()
  }

  private notify() {
    this.onStateChange({
      callId: this.state.callId,
      conversationId: this.state.conversationId,
      localStream: this.state.localStream,
      peers: Array.from(this.state.peers.values()),
      isEnded: this.state.isEnded,
      isMicOn: this.state.isMicOn,
      isCameraOn: this.state.isCameraOn,
      audioOnly: this.state.audioOnly,
      error: this.state.error,
    })
  }
}
