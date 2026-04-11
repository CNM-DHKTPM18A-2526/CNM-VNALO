import type { ChatMessage } from '../chat.types'

type MessageBubbleProps = {
  message: ChatMessage
  isReadByPeer?: boolean
}

export function MessageBubble({ message, isReadByPeer = false }: MessageBubbleProps) {
  const statusLabel = (() => {
    if (message.sender !== 'me') {
      return ''
    }

    if (message.deliveryState === 'failed') {
      return ' • Loi gui'
    }

    if (message.deliveryState === 'sending' || message.serverSeq === undefined) {
      return ' • Dang gui'
    }

    if (message.deliveryState === 'read' || isReadByPeer) {
      return ' • Da xem'
    }

    return ' • Da gui'
  })()

  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'}>
      <article className={message.sender === 'me' ? 'message-bubble message-bubble-me' : 'message-bubble'}>
        <p>{message.text}</p>
        <time>
          {message.timestamp}
          {statusLabel}
        </time>
      </article>
    </div>
  )
}
