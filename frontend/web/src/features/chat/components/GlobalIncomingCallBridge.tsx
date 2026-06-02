import React from 'react'

import { useAuth } from '../../auth/useAuth'
import { getOrCreateSocket } from '../chat.socket'
import { useUserStore } from '../context/UserStoreContext'
import { IncomingCallBanner } from './PremiumCallUI'

type IncomingDirectCall = {
  callId: string
  conversationId: string
  peerId: string
  peerName: string
  peerAvatar?: string | null
  audioOnly: boolean
  offerSdp?: RTCSessionDescriptionInit
}

function unwrapSignalPayload(data: unknown): Record<string, any> | null {
  let payload = Array.isArray(data) ? data[0] : data
  if (!payload || typeof payload !== 'object') return null

  const record = payload as Record<string, any>
  if (record.data && typeof record.data === 'object') {
    payload = record.data
  }

  const nested = payload as Record<string, any>
  if (nested.offer && !nested.sdp && typeof nested.offer === 'object') {
    return nested.offer as Record<string, any>
  }

  return nested
}

function storeIncomingOffer(callId: string, offerSdp?: RTCSessionDescriptionInit) {
  if (!offerSdp) return

  try {
    const encodedOffer = btoa(JSON.stringify(offerSdp))
    sessionStorage.setItem(`offer_${callId}`, encodedOffer)
    localStorage.setItem(`pending_offer_${callId}`, JSON.stringify(offerSdp))
  } catch (error) {
    console.warn('[GlobalIncomingCall] Failed to store offer SDP', error)
  }
}

export function GlobalIncomingCallBridge() {
  const { accessToken, user } = useAuth()
  const { ensureUser, userMap } = useUserStore()
  const [incomingCall, setIncomingCall] = React.useState<IncomingDirectCall | null>(null)
  const incomingCallRef = React.useRef<IncomingDirectCall | null>(null)
  const processedOffersRef = React.useRef<Set<string>>(new Set())

  React.useEffect(() => {
    incomingCallRef.current = incomingCall
  }, [incomingCall])

  React.useEffect(() => {
    if (!accessToken || !user?.id) {
      setIncomingCall(null)
      processedOffersRef.current.clear()
      return
    }

    const socket = getOrCreateSocket(accessToken)

    const clearCall = (data: unknown) => {
      const payload = unwrapSignalPayload(data)
      const callId = payload?.callId
      if (!callId || incomingCallRef.current?.callId === callId) {
        setIncomingCall(null)
      }
    }

    const handleOffer = async (data: unknown) => {
      const payload = unwrapSignalPayload(data)
      if (!payload) return

      const callId = payload.callId?.toString()
      const conversationId = (payload.conversationId || payload.roomId)?.toString()
      const peerId = (payload.senderUserId || payload.callerId || payload.fromUserId)?.toString()

      if (!callId || !conversationId || !peerId || peerId === user.id) return
      if (incomingCallRef.current && incomingCallRef.current.callId !== callId) return
      if (processedOffersRef.current.has(callId)) return

      processedOffersRef.current.add(callId)
      const offerSdp = payload.sdp || payload.offer?.sdp || payload.data?.sdp
      storeIncomingOffer(callId, offerSdp)

      const cachedProfile = userMap[peerId]
      const fallbackName = payload.callerName || payload.senderName || payload.peerName || 'Người dùng'
      const profile = accessToken ? await ensureUser(accessToken, peerId) : cachedProfile

      setIncomingCall({
        callId,
        conversationId,
        peerId,
        peerName:
          profile?.displayName && profile.displayName !== 'Người dùng'
            ? profile.displayName
            : fallbackName,
        peerAvatar: profile?.avatarUrl || payload.callerAvatar || payload.senderAvatar || null,
        audioOnly: Boolean(payload.audioOnly),
        offerSdp,
      })
    }

    socket.on('call:offer', handleOffer)
    socket.on('call.offer', handleOffer)
    socket.on('call:answer', clearCall)
    socket.on('call.answer', clearCall)
    socket.on('call:end', clearCall)
    socket.on('call.end', clearCall)

    return () => {
      socket.off('call:offer', handleOffer)
      socket.off('call.offer', handleOffer)
      socket.off('call:answer', clearCall)
      socket.off('call.answer', clearCall)
      socket.off('call:end', clearCall)
      socket.off('call.end', clearCall)
    }
  }, [accessToken, ensureUser, user?.id, userMap])

  const handleAnswer = React.useCallback(() => {
    const call = incomingCallRef.current
    if (!call) return

    storeIncomingOffer(call.callId, call.offerSdp)

    const params = new URLSearchParams({
      type: 'direct',
      conversationId: call.conversationId,
      peerId: call.peerId,
      audioOnly: String(call.audioOnly),
      isCaller: 'false',
      peerName: call.peerName,
      peerAvatar: call.peerAvatar || '',
    })

    const width = window.screen.availWidth
    const height = window.screen.availHeight
    window.open(
      `/call/${call.callId}?${params.toString()}`,
      'VnaloCall',
      `width=${width},height=${height},menubar=no,toolbar=no,location=no,status=no`,
    )
    setIncomingCall(null)
  }, [])

  const handleDecline = React.useCallback(() => {
    const call = incomingCallRef.current
    if (!call || !accessToken || !user?.id) {
      setIncomingCall(null)
      return
    }

    const socket = getOrCreateSocket(accessToken)
    const endPayload = {
      conversationId: call.conversationId,
      roomId: call.conversationId,
      callId: call.callId,
      senderUserId: user.id,
      targetUserId: call.peerId,
      callerId: call.peerId,
      calleeId: user.id,
      reason: 'reject',
      duration: 0,
      outcome: 'missed',
      startedAt: null,
      direction: 'incoming',
      type: call.audioOnly ? 'audio' : 'video',
    }

    socket.emit('call:end', endPayload)
    socket.emit('call.end', endPayload)
    setIncomingCall(null)
  }, [accessToken, user?.id])

  if (!incomingCall) return null

  return (
    <IncomingCallBanner
      peerName={incomingCall.peerName}
      peerAvatar={incomingCall.peerAvatar}
      isGroup={false}
      isAudioOnly={incomingCall.audioOnly}
      onAnswer={handleAnswer}
      onDecline={handleDecline}
    />
  )
}
