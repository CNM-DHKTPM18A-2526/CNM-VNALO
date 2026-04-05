import { useMemo, useState } from 'react'

import { SearchInput } from '../../../shared/components/SearchInput'
import { Icon } from '../../../shared/components/Icon'
import { Button } from '../../../shared/components/ui/Button'
import { Modal } from '../../../shared/components/ui/Modal'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
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
  const { t } = useLanguage()
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
        <h2>{t('chat.conversationTitle')}</h2>
        <div className='chat-toolbar-row'>
          <SearchInput placeholder={t('chat.searchPlaceholder')} value={keyword} onChange={setKeyword} />
          <div className='chat-toolbar-actions' aria-label={t('chat.quickActions')}>
            <button
              className='chat-toolbar-btn'
              onClick={() => setIsAddFriendOpen(true)}
              title={t('chat.addFriend')}
              type='button'
            >
              <Icon name='userPlus' />
              <span className='chat-toolbar-tooltip'>{t('chat.addFriend')}</span>
            </button>
            <button
              className='chat-toolbar-btn'
              onClick={() => setIsCreateGroupOpen(true)}
              title={t('chat.createGroup')}
              type='button'
            >
              <Icon name='group' />
              <span className='chat-toolbar-tooltip'>{t('chat.createGroup')}</span>
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
        description={t('chat.modalAddFriendDesc')}
        footer={
          <>
            <Button variant='ghost' onClick={() => setIsAddFriendOpen(false)}>
              {t('chat.modalCancel')}
            </Button>
            <Button
              onClick={() => {
                setIsAddFriendOpen(false)
                setFriendIdentifier('')
              }}
              variant='primary'
            >
              {t('chat.modalConfirm')}
            </Button>
          </>
        }
        isOpen={isAddFriendOpen}
        onClose={() => setIsAddFriendOpen(false)}
        title={t('chat.modalAddFriendTitle')}
      >
        <label className='modal-field'>
          <span>{t('chat.modalPhoneOrEmail')}</span>
          <input
            placeholder={t('chat.modalPhoneOrEmailPlaceholder')}
            value={friendIdentifier}
            onChange={(event) => setFriendIdentifier(event.target.value)}
          />
        </label>
      </Modal>

      <Modal
        description={t('chat.modalCreateGroupDesc')}
        footer={
          <>
            <Button variant='ghost' onClick={() => setIsCreateGroupOpen(false)}>
              {t('chat.modalCancel')}
            </Button>
            <Button
              onClick={() => {
                setIsCreateGroupOpen(false)
                setGroupName('')
                setGroupMembers('')
              }}
              variant='primary'
            >
              {t('chat.createGroup')}
            </Button>
          </>
        }
        isOpen={isCreateGroupOpen}
        onClose={() => setIsCreateGroupOpen(false)}
        title={t('chat.modalCreateGroupTitle')}
      >
        <label className='modal-field'>
          <span>{t('chat.modalGroupName')}</span>
          <input
            placeholder={t('chat.modalGroupNamePlaceholder')}
            value={groupName}
            onChange={(event) => setGroupName(event.target.value)}
          />
        </label>
        <label className='modal-field'>
          <span>{t('chat.modalMembers')}</span>
          <textarea
            placeholder={t('chat.modalMembersPlaceholder')}
            value={groupMembers}
            onChange={(event) => setGroupMembers(event.target.value)}
            rows={4}
          />
          <small className='modal-helper-text'>{t('chat.modalMembersHelper')}</small>
        </label>
      </Modal>
    </section>
  )
}
