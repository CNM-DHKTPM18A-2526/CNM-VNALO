import { io, type Socket } from 'socket.io-client'
import type { RawMessage } from './chat.api'

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL ?? 'http://localhost:3000'

export type SocketMessagePayload = {
  conversationId: string
  content: string
  messageType?: string
  clientMessageId?: string
}

export type SendMessageAck = {
  event?: 'message.sent' | string
  data?: RawMessage
  message?: string
}

export function createChatSocket(token: string): Socket {
  return io(`${SOCKET_URL}/chat`, {
    transports: ['websocket', 'polling'],
    auth: { token },
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1000,
  })
}

export function emitSendMessage(socket: Socket, payload: SocketMessagePayload): Promise<SendMessageAck | null> {
  return new Promise((resolve) => {
    socket.emit('message.send', payload, (ack: unknown) => {
      resolve((ack as SendMessageAck | null) ?? null)
    })
  })
}
