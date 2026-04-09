import type { ChatMessage } from '../chat.types'

type MessageBubbleProps = {
  message: ChatMessage
  isReadByPeer?: boolean
}

export function MessageBubble({ message, isReadByPeer = false }: MessageBubbleProps) {
  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'}>
      <article className={message.sender === 'me' ? 'message-bubble message-bubble-me' : 'message-bubble'}>
        <p>{message.text}</p>
        <time>
          {message.timestamp}
          {message.sender === 'me' ? ` • ${isReadByPeer ? 'Da xem' : 'Da gui'}` : ''}
        </time>
      </article>
    </div>
  )
}
