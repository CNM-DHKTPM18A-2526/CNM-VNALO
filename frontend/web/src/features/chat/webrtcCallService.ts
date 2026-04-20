import { Socket } from 'socket.io-client'

export type CallOutcome = 'completed' | 'canceled' | 'missed'

export interface WebRTCCallState {
  pc: RTCPeerConnection | null
  localStream: MediaStream | null
  remoteStream: MediaStream | null
  isConnected: boolean
  isEnded: boolean
  isMicOn: boolean
  isCameraOn: boolean
  startedAt?: number
  hasRemoteDescription: boolean
  pendingCandidates: RTCIceCandidate[]
  error: string | null
}

export class WebRtcCallService {
  private state: WebRTCCallState = {
    pc: null,
    localStream: null,
    remoteStream: null,
    isConnected: false,
    isEnded: false,
    isMicOn: true,
    isCameraOn: true,
    pendingCandidates: [],
    hasRemoteDescription: false,
    error: null,
  }

  private resetInternalState() {
    this.state.hasRemoteDescription = false
    this.state.pendingCandidates = []
    this.state.isConnected = false
    this.state.isEnded = false
    this.state.error = null
  }

  private socket: Socket | null = null
  private conversationId: string = ''
  private callId: string = ''
  private currentUserId: string = ''
  private peerUserId: string = ''
  private audioOnly: boolean = false
  private isCaller: boolean = false
  private onStateChange: (state: WebRTCCallState) => void

  private ringTimeoutTimer: any = null
  private readonly RING_TIMEOUT_MS = 38000

  constructor(onStateChange: (state: WebRTCCallState) => void) {
    this.onStateChange = onStateChange
  }

  private updateState(patch: Partial<WebRTCCallState>) {
    this.state = { ...this.state, ...patch }
    this.onStateChange(this.state)
  }

  async initialize(params: {
    socket: Socket
    conversationId: string
    callId: string
    currentUserId: string
    peerUserId: string
    audioOnly: boolean
    isCaller: boolean
    initialSdp?: any
  }) {
    console.log('[WebRTC] Initializing service', params)
    this.socket = params.socket
    this.conversationId = params.conversationId
    this.callId = params.callId
    this.currentUserId = params.currentUserId
    this.peerUserId = params.peerUserId
    this.audioOnly = params.audioOnly
    this.isCaller = params.isCaller

    try {
      // 1. Setup PeerConnection
      const configuration: RTCConfiguration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun1.l.google.com:19302' },
          { urls: 'stun:stun2.l.google.com:19302' },
          { urls: 'stun:stun3.l.google.com:19302' },
          { urls: 'stun:stun4.l.google.com:19302' },
          // Note: For full reliability on all cellular networks (Symmetric NAT), 
          // a TURN relay server is highly recommended.
        ],
        iceCandidatePoolSize: 10,
      }
      this.resetInternalState()
      this.state.pc = new RTCPeerConnection(configuration)

      this.registerPeerEvents()

      // 2. Setup Local Media
      await this.openLocalMedia()

      // 3. Handshake logic
      if (this.isCaller) {
        await this.createOffer()
        this.startRingTimeout()
      } else if (params.initialSdp) {
        await this.handleOffer(params.initialSdp)
      }
    } catch (error) {
      console.error('[WebRTC] Initialization failed', error)
      this.endCall('failed')
    }
  }

  private registerPeerEvents() {
    const pc = this.state.pc
    if (!pc) return

    pc.onicecandidate = (event) => {
      if (event.candidate && this.socket) {
        console.log('[CALL][ICE CANDIDATE GENERATED]')

        const candidatePayload = {
          candidate: event.candidate.candidate,
          sdpMid: event.candidate.sdpMid,
          sdpMLineIndex: event.candidate.sdpMLineIndex,
        }

        const payload = {
          conversationId: this.conversationId,
          callId: this.callId,
          targetUserId: this.peerUserId,
          senderUserId: this.currentUserId,
          callerId: this.isCaller ? this.currentUserId : this.peerUserId,
          calleeId: this.isCaller ? this.peerUserId : this.currentUserId,
          roomId: this.conversationId,
          candidate: candidatePayload,
          type: 'ice-candidate',
        }

        if (this.socket) {
          // Quad-broadcast immediately for maximum cross-platform reliability
          this.socket.emit('call:ice-candidate', payload)
          this.socket.emit('call.ice-candidate', payload)
          this.socket.emit('call.signal', { ...payload, type: 'ice-candidate' })
          this.socket.emit('call:signal', { ...payload, type: 'ice-candidate' })
        }
      }
    }

    pc.ontrack = (event) => {
      console.log('[WebRTC] Remote track received')
      if (event.streams && event.streams[0]) {
        this.updateState({ remoteStream: event.streams[0] })
      }
    }

    pc.onconnectionstatechange = () => {
      console.log('[WebRTC] Connection state changed:', pc.connectionState)
      this.updateState({ isConnected: pc.connectionState === 'connected' })
      
      if (pc.connectionState === 'connected') {
        this.stopRingTimeout()
        this.updateState({ startedAt: Date.now(), error: null })
      } else if (pc.connectionState === 'failed') {
        console.error('[WebRTC] Connection failed. Signaling state:', pc.signalingState, 'ICE Gathering:', pc.iceGatheringState)
        this.updateState({ error: 'Kết nối mạng thất bại' })
      } else if (pc.connectionState === 'disconnected') {
        console.warn('[WebRTC] Connection disconnected')
      }
    }

    pc.onsignalingstatechange = () => {
      console.log('[WebRTC] Signaling state changed:', pc.signalingState)
    }

    pc.onicegatheringstatechange = () => {
      console.log('[WebRTC] ICE gathering state changed:', pc.iceGatheringState)
    }
  }

  private async openLocalMedia() {
    try {
      const constraints = {
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
        video: this.audioOnly ? false : { facingMode: 'user', width: 1280, height: 720 },
      }
      
      console.log('[WebRTC] Requesting media (10s timeout):', constraints)
      
      // Use a timeout to prevent the UI from hanging if the user doesn't respond to the browser prompt
      const mediaPromise = navigator.mediaDevices.getUserMedia(constraints)
      const timeoutPromise = new Promise<never>((_, reject) => 
        setTimeout(() => reject(new Error('Media request timed out (10s)')), 10000)
      )

      const stream = await Promise.race([mediaPromise, timeoutPromise])
      
      console.log('[WebRTC] Local media stream obtained', {
        id: stream.id,
        audio: stream.getAudioTracks().length,
        video: stream.getVideoTracks().length
      })
      this.updateState({ localStream: stream })

      stream.getTracks().forEach((track) => {
        if (this.state.pc) {
          this.state.pc.addTrack(track, stream)
        }
      })
    } catch (error) {
      console.error('[WebRTC] Failed to open local media', error)
      throw error
    }
  }

  private async createOffer() {
    const pc = this.state.pc
    if (!pc) return

    const offer = await pc.createOffer({
      offerToReceiveAudio: true,
      offerToReceiveVideo: !this.audioOnly
    })
    await pc.setLocalDescription(offer)

    const offerPayload = {
      conversationId: this.conversationId,
      callId: this.callId,
      senderUserId: this.currentUserId,
      targetUserId: this.peerUserId,
      callerId: this.currentUserId,
      calleeId: this.peerUserId,
      roomId: this.conversationId,
      mediaType: this.audioOnly ? 'voice' : 'video',
      audioOnly: this.audioOnly,
      sdp: { type: offer.type, sdp: offer.sdp },
    }

    console.log('[CALL][SEND OFFER]', offerPayload)

    if (this.socket) {
      // Quad-broadcast Offer for extreme cross-platform reliability
      this.socket.emit('call:offer', offerPayload)
      this.socket.emit('call.offer', offerPayload)

      const signalPayload = {
        ...offerPayload,
        type: 'offer',
        data: offerPayload,
        offer: offerPayload,
        sdp: offerPayload.sdp
      }

      this.socket.emit('call.signal', signalPayload)
      this.socket.emit('call:signal', signalPayload)
    }
  }

  async acceptCall() {
    if (this.state.isEnded || !this.state.hasRemoteDescription) {
      console.warn('[WebRTC] Cannot accept call: Ended or missing remote description')
      return
    }

    const pc = this.state.pc
    if (!pc) return

    // Critical State Guard: createAnswer only works in have-remote-offer
    if (pc.signalingState !== 'have-remote-offer') {
      console.warn('[WebRTC] Cannot accept call: PC signalingState is', pc.signalingState)
      return
    }

    try {
      const answer = await pc.createAnswer({
        offerToReceiveAudio: true,
        offerToReceiveVideo: !this.audioOnly
      })
      await pc.setLocalDescription(answer)

      const answerPayload = {
        conversationId: this.conversationId,
        callId: this.callId,
        senderUserId: this.currentUserId,
        targetUserId: this.peerUserId,
        callerId: this.peerUserId,
        calleeId: this.currentUserId,
        roomId: this.conversationId,
        mediaType: this.audioOnly ? 'voice' : 'video',
        sdp: { type: answer.type, sdp: answer.sdp },
      }

      console.log('[CALL][SEND ANSWER]', answerPayload)
      if (this.socket) {
        // Quad-broadcast Answer
        this.socket.emit('call:answer', answerPayload)
        this.socket.emit('call.answer', answerPayload)

        const signalPayload = {
          ...answerPayload,
          type: 'answer',
          data: answerPayload,
          answer: answerPayload,
          sdp: answerPayload.sdp
        }

        this.socket.emit('call.signal', signalPayload)
        this.socket.emit('call:signal', signalPayload)
      }
    } catch (error) {
      console.error('[WebRTC] Failed to accept call', error)
    }
  }

  async handleOffer(offerSdp: any) {
    if (this.state.hasRemoteDescription && !this.isCaller) return

    const pc = this.state.pc
    if (!pc) return

    try {
      await pc.setRemoteDescription(new RTCSessionDescription(offerSdp))
      this.updateState({ hasRemoteDescription: true })
      await this.flushPendingCandidates()
    } catch (error) {
      console.error('[WebRTC] Failed to handle offer', error)
    }
  }

  async handleAnswer(answerSdp: any) {
    const pc = this.state.pc
    if (!pc) return

    if (pc.signalingState === 'stable') {
      console.warn('[WebRTC] Ignoring handleAnswer: peer connection is already stable')
      return
    }

    try {
      console.log('[WebRTC] Setting remote answer description...')
      await pc.setRemoteDescription(new RTCSessionDescription(answerSdp))
      this.updateState({ hasRemoteDescription: true })
      console.log('[WebRTC] Remote answer set. Flushing', this.state.pendingCandidates.length, 'candidates')
      await this.flushPendingCandidates()
    } catch (error) {
      console.error('[WebRTC] Failed to handle answer', error)
      this.updateState({ error: 'Không thể xử lý phản hồi cuộc gọi' })
    }
  }

  async handleIceCandidate(candidateData: any) {
    if (!this.state.pc || !candidateData) return

    try {
      // Support both structured candidate objects and raw candidate strings
      const candidate = new RTCIceCandidate(
        typeof candidateData === 'string' ? { candidate: candidateData } : candidateData
      )

      if (!this.state.hasRemoteDescription) {
        console.log('[WebRTC] Queueing ICE candidate (remote description not ready)')
        this.updateState({ pendingCandidates: [...this.state.pendingCandidates, candidate] })
      } else {
        await this.state.pc.addIceCandidate(candidate)
        console.log('[WebRTC] ICE candidate added successfully')
      }
    } catch (error) {
      console.warn('[WebRTC] Failed to add ICE candidate', error)
    }
  }

  private async flushPendingCandidates() {
    if (!this.state.pc || this.state.pendingCandidates.length === 0) return

    for (const candidate of this.state.pendingCandidates) {
      try {
        await this.state.pc.addIceCandidate(candidate)
      } catch (error) {
        console.error('[WebRTC] Failed to flush ICE candidate', error)
      }
    }
    this.updateState({ pendingCandidates: [] })
  }

  toggleMic() {
    const stream = this.state.localStream
    if (!stream) return
    const audioTrack = stream.getAudioTracks()[0]
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled
      this.updateState({ isMicOn: audioTrack.enabled })
    }
  }

  toggleCamera() {
    const stream = this.state.localStream
    if (!stream) return
    const videoTrack = stream.getVideoTracks()[0]
    if (videoTrack) {
      videoTrack.enabled = !videoTrack.enabled
      this.updateState({ isCameraOn: videoTrack.enabled })
    }
  }

  private startRingTimeout() {
    this.stopRingTimeout()
    this.ringTimeoutTimer = setTimeout(() => {
      if (!this.state.isConnected && !this.state.isEnded) {
        this.endCall('no-answer-timeout')
      }
    }, this.RING_TIMEOUT_MS)
  }

  private stopRingTimeout() {
    if (this.ringTimeoutTimer) {
      clearTimeout(this.ringTimeoutTimer)
      this.ringTimeoutTimer = null
    }
  }

  endCall(reason: string = 'hangup', notifyPeer: boolean = true) {
    if (this.state.isEnded) return

    const safeReason = typeof reason === 'string' ? reason : 'hangup';
    console.log('[WebRTC] Ending call, reason:', safeReason)

    this.stopRingTimeout()

    this.updateState({ isEnded: true, isConnected: false })

    if (notifyPeer && this.socket) {
      const endPayload = {
        conversationId: this.conversationId,
        callId: this.callId,
        senderUserId: this.currentUserId,
        targetUserId: this.peerUserId,
        callerId: this.isCaller ? this.currentUserId : this.peerUserId,
        calleeId: this.isCaller ? this.peerUserId : this.currentUserId,
        roomId: this.conversationId,
        reason: safeReason,
      }
      this.socket.emit('call.end', endPayload)
      this.socket.emit('call:end', endPayload)
    }

    // Cleanup tracks
    this.state.localStream?.getTracks().forEach((track) => track.stop())
    this.state.remoteStream?.getTracks().forEach((track) => track.stop())

    // Close PC
    if (this.state.pc) {
      this.state.pc.close()
    }

    this.updateState({
      pc: null,
      localStream: null,
      remoteStream: null,
      pendingCandidates: [],
      hasRemoteDescription: false,
    })
  }
}
