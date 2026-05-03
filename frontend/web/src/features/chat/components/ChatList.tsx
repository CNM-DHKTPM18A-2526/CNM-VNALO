import React, { memo } from 'react'

import { SearchInput } from '../../../shared/components/SearchInput'
import { Icon } from '../../../shared/components/Icon'
import { Button } from '../../../shared/components/ui/Button'
import { AddFriendModal } from '../../friends/components/AddFriendModal'
import { Modal } from '../../../shared/components/ui/Modal'
import { useLanguage } from '../../../shared/i18n/LanguageContext'
import type { UserLookupResult } from '../../friends/friends.types'
import type { ConversationSummary } from '../chat.types'
import { ChatItem } from './ChatItem'
import { UserProfileModal } from './UserProfileModal'
import { useAuth } from '../../auth/useAuth'
import { getOrCreateDirectConversation } from '../chat.api'
import { useNavigate } from 'react-router-dom'
import {
  searchConversationsLocal,
  searchMessagesLocal,
  searchUsersByPhoneLocal,
  searchUsersLocal,
} from '../searchIndex'

type SearchUserEntry = {
  user: UserLookupResult
  conversation: ConversationSummary
}

type ChatListProps = {
  conversations: ConversationSummary[]
  friendResults: UserLookupResult[]
  activeConversationId?: string
  onSearchFriends: (keyword: string) => void
  onOpenFriendChat: (friend: UserLookupResult) => void | Promise<void>
  onSelectConversation: (conversationId: string) => void
  onCreateGroupClick?: () => void
}

export const ChatList = memo(function ChatList({
  conversations,
  friendResults,
  activeConversationId,
  onSearchFriends,
  onOpenFriendChat,
  onSelectConversation,
  onCreateGroupClick,
}: ChatListProps) {
  const { accessToken } = useAuth()
  const navigate = useNavigate()
  const { t } = useLanguage()
  const [keyword, setKeyword] = React.useState('')
  const [debouncedKeyword, setDebouncedKeyword] = React.useState('')
  const [isAddFriendOpen, setIsAddFriendOpen] = React.useState(false)
  const [selectedProfileUserId, setSelectedProfileUserId] = React.useState<string | null>(null)
  const [isCreateGroupOpen, setIsCreateGroupOpen] = React.useState(false)
  const [groupName, setGroupName] = React.useState('')
  const [groupMembers, setGroupMembers] = React.useState('')

  React.useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedKeyword(keyword.trim())
    }, 300)

    return () => {
      window.clearTimeout(timer)
    }
  }, [keyword])

  React.useEffect(() => {
    onSearchFriends(debouncedKeyword)
  }, [debouncedKeyword, onSearchFriends])

  const normalizedKeyword = debouncedKeyword.trim()
  const normalizedPhone = normalizedKeyword.replace(/\D/g, '')
  const isPhoneQuery = normalizedPhone.length >= 2 && normalizedPhone.length >= Math.max(2, normalizedKeyword.length - 2)

  const localConversationMatches = React.useMemo(() => {
    if (!normalizedKeyword) {
      return conversations
    }

    const conversationNameMatches = searchConversationsLocal(normalizedKeyword)
    const messageMatches = searchMessagesLocal(normalizedKeyword)
    const messageConversationIds = new Set(messageMatches.map((message) => message.conversationId))
    const matchedConversationIds = new Set<string>()
    const results: ConversationSummary[] = []

    const addConversation = (conversation: ConversationSummary, preview?: string) => {
      if (matchedConversationIds.has(conversation.id)) {
        return
      }

      matchedConversationIds.add(conversation.id)
      results.push(
        preview
          ? {
            ...conversation,
            lastMessage: preview,
          }
          : conversation,
      )
    }

    for (const conversation of conversationNameMatches) {
      addConversation(conversation)
    }

    for (const conversation of conversations) {
      if (messageConversationIds.has(conversation.id)) {
        const matchedMessage = messageMatches.find((message) => message.conversationId === conversation.id)
        addConversation(
          conversation,
          matchedMessage?.content?.trim() || matchedMessage?.messageType || t('chat.searchMessagesSection'),
        )
      }
    }

    return results
  }, [conversations, normalizedKeyword, t])

  const localUserLookupItems = React.useMemo<SearchUserEntry[]>(() => {
    if (!normalizedKeyword) {
      return []
    }

    const candidates = isPhoneQuery ? searchUsersByPhoneLocal(normalizedPhone) : searchUsersLocal(normalizedKeyword)

    return candidates.map((user) => {
      const displayName = user.displayName?.trim() || user.phone || user.email || t('contacts.common.unknownUser')
      return {
        user: {
          id: user.id,
          phone: user.phone ?? null,
          email: user.email ?? null,
          displayName: user.displayName ?? null,
          avatarUrl: user.avatarUrl ?? null,
          coverUrl: null,
          bio: user.bio ?? null,
          statusMessage: user.bio ?? null,
        },
        conversation: {
          id: user.id,
          name: displayName,
          lastMessage: user.bio?.trim() || user.phone || user.email || '',
          unreadCount: 0,
          online: false,
          lastMessageSeq: 0,
          avatarUrl: user.avatarUrl ?? null,
        },
      }
    })
  }, [isPhoneQuery, normalizedKeyword, normalizedPhone, t])

  const backendUserLookupItems = React.useMemo<SearchUserEntry[]>(() => {
    const seenIds = new Set<string>()
    const results: SearchUserEntry[] = []

    for (const friend of friendResults) {
      if (seenIds.has(friend.id)) {
        continue
      }

      seenIds.add(friend.id)
      const displayName = friend.displayName?.trim() || friend.phone || friend.email || t('contacts.common.unknownUser')
      results.push({
        user: friend,
        conversation: {
          id: friend.id,
          name: displayName,
          lastMessage: friend.statusMessage?.trim() || friend.phone || friend.email || '',
          unreadCount: 0,
          online: false,
          lastMessageSeq: 0,
          avatarUrl: friend.avatarUrl ?? null,
        },
      })
    }

    return results
  }, [friendResults, t])

  const friendLookupItems = React.useMemo(() => {
    const seenIds = new Set<string>()
    const merged: SearchUserEntry[] = []

    for (const item of localUserLookupItems) {
      if (!seenIds.has(item.user.id)) {
        seenIds.add(item.user.id)
        merged.push(item)
      }
    }

    for (const item of backendUserLookupItems) {
      if (!seenIds.has(item.user.id)) {
        seenIds.add(item.user.id)
        merged.push(item)
      }
    }

    return merged
  }, [backendUserLookupItems, localUserLookupItems])

  const hasKeyword = debouncedKeyword.length > 0
  const hasResults = localConversationMatches.length > 0 || friendLookupItems.length > 0

  const openFriendSearch = () => {
    setIsAddFriendOpen(true)
  }

  const addFriendInitialTarget = React.useMemo(
    () => {
      const seedQuery = keyword.trim()
      return seedQuery ? { seedQuery } : null
    },
    [keyword],
  )

  return (
    <section className='chat-list-panel'>
      <div className='panel-header'>
        <h2>{t('chat.conversationTitle')}</h2>
        <div className='chat-toolbar-row'>
          <SearchInput placeholder={t('chat.searchPlaceholder')} value={keyword} onChange={setKeyword} />
          <div className='chat-toolbar-actions' aria-label={t('chat.quickActions')}>
            <button
              className='chat-toolbar-btn'
              onClick={openFriendSearch}
              title={t('chat.addFriend')}
              type='button'
            >
              <Icon name='userPlusZalo' size={20} />
              <span className='chat-toolbar-tooltip'>{t('chat.addFriend')}</span>
            </button>
            <button
              className='chat-toolbar-btn'
              onClick={() => onCreateGroupClick ? onCreateGroupClick() : setIsCreateGroupOpen(true)}
              title={t('chat.createGroup')}
              type='button'
            >
              <Icon name='groupPlusZalo' size={22} />
              <span className='chat-toolbar-tooltip'>{t('chat.createGroup')}</span>
            </button>
          </div>
        </div>
      </div>
      <div className='chat-list'>
        {hasKeyword ? <p>{t('chat.searchConversationsSection')}</p> : null}
        {localConversationMatches.map((conversation, index) => (
          <ChatItem
            key={conversation.id}
            conversation={conversation}
            active={conversation.id === activeConversationId}
            index={index}
            onSelect={onSelectConversation}
          />
        ))}

        {friendLookupItems.length > 0 ? <p>{t('chat.searchFriendsSection')}</p> : null}
        {friendLookupItems.map((entry, index) => (
          <ChatItem
            key={`friend-${entry.user.id}`}
            conversation={entry.conversation}
            active={entry.conversation.id === activeConversationId}
            index={localConversationMatches.length + index}
            onSelect={() => {
              void onOpenFriendChat(entry.user)
            }}
          />
        ))}

        {hasKeyword && !hasResults ? <p>{t('chat.searchEmpty')}</p> : null}
      </div>

      <AddFriendModal
        initialTarget={addFriendInitialTarget}
        isOpen={isAddFriendOpen}
        onClose={() => setIsAddFriendOpen(false)}
        onUserFound={(user) => {
          setSelectedProfileUserId(user.id)
        }}
      />

      <UserProfileModal
        accessToken={accessToken}
        isOpen={Boolean(selectedProfileUserId)}
        onClose={() => setSelectedProfileUserId(null)}
        userId={selectedProfileUserId}
        onMessage={async (targetUser) => {
          if (!accessToken) return
          const conversationId = await getOrCreateDirectConversation(accessToken, targetUser.id)
          navigate(`/chat/${conversationId}`)
        }}
      />

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
})
