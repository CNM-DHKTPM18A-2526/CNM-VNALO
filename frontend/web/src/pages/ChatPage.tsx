import { useMemo, useState } from 'react'

import { ChatList } from '../features/chat/components/ChatList'
import { ChatWindow } from '../features/chat/components/ChatWindow'
import { useAuth } from '../features/auth/useAuth'
import { Skeleton } from '../shared/components/ui/Skeleton'
import { Card } from '../shared/components/ui/Card'
import { conversations, messages } from '../shared/mock/data'

export function ChatPage() {
  const { isBootstrapping } = useAuth()
  const [selectedConversationId, setSelectedConversationId] = useState(conversations[0]?.id ?? '')

  const selectedConversation = useMemo(
    () => conversations.find((conversation) => conversation.id === selectedConversationId),
    [selectedConversationId],
  )

  if (isBootstrapping) {
    return (
      <div className='chat-layout'>
        <section className='chat-list-panel chat-list-panel-skeleton'>
          <div className='panel-header'>
            <Skeleton className='skeleton-line skeleton-line-title' />
            <Skeleton className='skeleton-line' />
          </div>
          <div className='chat-list chat-list-skeleton'>
            {Array.from({ length: 6 }).map((_, index) => (
              <div className='chat-item-skeleton' key={`chat-skeleton-${index}`}>
                <Skeleton className='chat-item-avatar-skeleton' />
                <div className='chat-item-skeleton-copy'>
                  <Skeleton className='skeleton-line skeleton-line-title' />
                  <Skeleton className='skeleton-line' />
                </div>
              </div>
            ))}
          </div>
        </section>
        <section className='chat-window'>
          <div className='chat-window-header'>
            <Skeleton className='skeleton-line skeleton-line-title' />
          </div>
          <div className='chat-window-messages'>
            <Skeleton className='chat-message-skeleton me' />
            <Skeleton className='chat-message-skeleton' />
            <Skeleton className='chat-message-skeleton me' />
          </div>
        </section>
        <aside className='chat-side-panel'>
          <Skeleton className='skeleton-line skeleton-line-title' />
          <Skeleton className='skeleton-line' />
          <Card className='chat-side-card'>
            <Skeleton className='skeleton-line' />
            <Skeleton className='skeleton-line skeleton-line-short' />
          </Card>
        </aside>
      </div>
    )
  }

  return (
    <div className='chat-layout'>
      <ChatList
        conversations={conversations}
        selectedConversationId={selectedConversationId}
        onSelectConversation={setSelectedConversationId}
      />
      <ChatWindow conversation={selectedConversation} seedMessages={messages} />
      <aside className='chat-side-panel'>
        <h3>Thông tin hội thoại</h3>
        <p>
          {selectedConversation
            ? `Đang trò chuyện với ${selectedConversation.name}.`
            : 'Hãy chọn một hội thoại để xem tin nhắn.'}
        </p>
        <Card className='chat-side-card'>
          <p>File đã chia sẻ</p>
          <strong>4 tệp</strong>
        </Card>
        <Card className='chat-side-card'>
          <p>Media</p>
          <strong>12 mục</strong>
        </Card>
      </aside>
    </div>
  )
}
