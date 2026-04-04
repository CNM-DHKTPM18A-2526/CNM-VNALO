import type { ChatMessage } from '../../../shared/mock/data'

type MessageBubbleProps = {
  message: ChatMessage
}

export function MessageBubble({ message }: MessageBubbleProps) {
  return (
    <div className={message.sender === 'me' ? 'message-row message-row-me' : 'message-row'}>
      <article className={message.sender === 'me' ? 'message-bubble message-bubble-me' : 'message-bubble'}>
        <p>{message.text}</p>
        <time>{message.timestamp}</time>
      </article>
    </div>
  )
}
