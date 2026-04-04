import { useMemo, useState } from 'react'

import { SearchInput } from '../../../shared/components/SearchInput'
import { Icon } from '../../../shared/components/Icon'
import { Button } from '../../../shared/components/ui/Button'
import { Modal } from '../../../shared/components/ui/Modal'
import type { ChatConversation } from '../../../shared/mock/data'
import { ChatItem } from './ChatItem'

type ChatListProps = {
  conversations: ChatConversation[]
  selectedConversationId: string
  onSelectConversation: (conversationId: string) => void
}

export function ChatList({
  conversations,
  selectedConversationId,
  onSelectConversation,
}: ChatListProps) {
  const [keyword, setKeyword] = useState('')
  const [isAddFriendOpen, setIsAddFriendOpen] = useState(false)
  const [isCreateGroupOpen, setIsCreateGroupOpen] = useState(false)
  const [friendIdentifier, setFriendIdentifier] = useState('')
  const [groupName, setGroupName] = useState('')
  const [groupMembers, setGroupMembers] = useState('')

  const filteredConversations = useMemo(() => {
    const normalizedKeyword = keyword.trim().toLowerCase()

    if (!normalizedKeyword) {
      return conversations
    }

    return conversations.filter((conversation) =>
      conversation.name.toLowerCase().includes(normalizedKeyword),
    )
  }, [conversations, keyword])

  return (
    <section className='chat-list-panel'>
      <div className='panel-header'>
        <h2>Hội thoại</h2>
        <div className='chat-toolbar-row'>
          <SearchInput placeholder='Tìm hội thoại' value={keyword} onChange={setKeyword} />
          <div className='chat-toolbar-actions' aria-label='Tác vụ nhanh'>
            <button
              className='chat-toolbar-btn'
              onClick={() => setIsAddFriendOpen(true)}
              title='Thêm bạn'
              type='button'
            >
              <Icon name='userPlus' />
              <span className='chat-toolbar-tooltip'>Thêm bạn</span>
            </button>
            <button
              className='chat-toolbar-btn'
              onClick={() => setIsCreateGroupOpen(true)}
              title='Tạo nhóm'
              type='button'
            >
              <Icon name='group' />
              <span className='chat-toolbar-tooltip'>Tạo nhóm</span>
            </button>
          </div>
        </div>
      </div>
      <div className='chat-list'>
        {filteredConversations.map((conversation, index) => (
          <ChatItem
            key={conversation.id}
            conversation={conversation}
            active={conversation.id === selectedConversationId}
            index={index}
            onSelect={onSelectConversation}
          />
        ))}
      </div>

      <Modal
        description='Mời một người dùng bằng số điện thoại hoặc email.'
        footer={
          <>
            <Button variant='ghost' onClick={() => setIsAddFriendOpen(false)}>
              Hủy
            </Button>
            <Button
              onClick={() => {
                setIsAddFriendOpen(false)
                setFriendIdentifier('')
              }}
              variant='primary'
            >
              Xác nhận
            </Button>
          </>
        }
        isOpen={isAddFriendOpen}
        onClose={() => setIsAddFriendOpen(false)}
        title='Thêm bạn'
      >
        <label className='modal-field'>
          <span>Số điện thoại hoặc email</span>
          <input
            placeholder='0917949410 hoặc ban@vnalo.app'
            value={friendIdentifier}
            onChange={(event) => setFriendIdentifier(event.target.value)}
          />
        </label>
      </Modal>

      <Modal
        description='Tạo nhóm chat mới và chọn các thành viên sẽ tham gia.'
        footer={
          <>
            <Button variant='ghost' onClick={() => setIsCreateGroupOpen(false)}>
              Hủy
            </Button>
            <Button
              onClick={() => {
                setIsCreateGroupOpen(false)
                setGroupName('')
                setGroupMembers('')
              }}
              variant='primary'
            >
              Tạo nhóm
            </Button>
          </>
        }
        isOpen={isCreateGroupOpen}
        onClose={() => setIsCreateGroupOpen(false)}
        title='Tạo nhóm'
      >
        <label className='modal-field'>
          <span>Tên nhóm</span>
          <input
            placeholder='Nhập tên nhóm...'
            value={groupName}
            onChange={(event) => setGroupName(event.target.value)}
          />
        </label>
        <label className='modal-field'>
          <span>Thành viên</span>
          <textarea
            placeholder='Chọn thành viên theo tên, email hoặc số điện thoại...'
            value={groupMembers}
            onChange={(event) => setGroupMembers(event.target.value)}
            rows={4}
          />
          <small className='modal-helper-text'>Tạm thời là giao diện mô phỏng, sẽ nối dữ liệu thật sau.</small>
        </label>
      </Modal>
    </section>
  )
}
