import { useMemo, useState } from 'react'

import { EmptyState } from '../../../shared/components/EmptyState'
import { LoadingState } from '../../../shared/components/LoadingState'
import type { ChatConversation, ChatMessage } from '../../../shared/mock/data'
import { MessageBubble } from './MessageBubble'
import { MessageInput } from './MessageInput'

type ChatWindowProps = {
  conversation: ChatConversation | undefined
  seedMessages: ChatMessage[]
}

export function ChatWindow({ conversation, seedMessages }: ChatWindowProps) {
  const [messages, setMessages] = useState<ChatMessage[]>(seedMessages)

  const conversationMessages = useMemo(() => {
    if (!conversation) {
      return []
    }

    return messages.filter((message) => message.conversationId === conversation.id)
  }, [conversation, messages])

  const handleSend = (text: string) => {
    if (!conversation) {
      return
    }

    const now = new Date()
    const minutes = `${now.getMinutes()}`.padStart(2, '0')
    const hours = `${now.getHours()}`.padStart(2, '0')

    const newMessage: ChatMessage = {
      id: `m-${messages.length + 1}`,
      conversationId: conversation.id,
      sender: 'me',
      text,
      timestamp: `${hours}:${minutes}`,
    }

    setMessages((prev) => [...prev, newMessage])
  }

  if (!conversation) {
    return (
      <section className='chat-window'>
        <EmptyState
          title='Chưa chọn hội thoại'
          description='Hãy chọn một hội thoại.'
        />
      </section>
    )
  }

  return (
    <section className='chat-window'>
      <header className='chat-window-header'>
        <h2>{conversation.name}</h2>
        <p>{conversation.online ? 'Đang hoạt động' : 'Ngoại tuyến'}</p>
      </header>
      <div className='chat-window-messages'>
        {conversationMessages.length === 0 ? (
          <LoadingState label='Đang tải hội thoại...' />
        ) : (
          conversationMessages.map((message) => <MessageBubble key={message.id} message={message} />)
        )}
      </div>
      <MessageInput onSend={handleSend} />
    </section>
  )
}
