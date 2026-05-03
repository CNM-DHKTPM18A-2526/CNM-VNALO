import React from 'react'

import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'
import { Modal } from '../../../shared/components/ui/Modal'
import type { Friend } from '../../friends/friends.types'
import type { ChatMessage } from '../chat.types'

type MessageShareModalProps = {
  isOpen: boolean
  message: ChatMessage | null
  friends: Friend[]
  isSubmitting?: boolean
  onClose: () => void
  onShare: (targetUserIds: string[], note: string) => Promise<void> | void
}

function resolveFriendLabel(friend: Friend): string {
  return friend.nickname?.trim() || friend.displayName?.trim() || `Người dùng ${friend.friendId.slice(0, 8)}`
}

export function MessageShareModal({
  isOpen,
  message,
  friends,
  isSubmitting = false,
  onClose,
  onShare,
}: MessageShareModalProps) {
  const [searchKeyword, setSearchKeyword] = React.useState('')
  const [note, setNote] = React.useState('')
  const [selectedUserIds, setSelectedUserIds] = React.useState<string[]>([])

  React.useEffect(() => {
    if (!isOpen) {
      return
    }

    // Use requestAnimationFrame to avoid synchronous setState in effect warning
    requestAnimationFrame(() => {
      setSearchKeyword('')
      setNote('')
      setSelectedUserIds([])
    })
  }, [isOpen, message?.id])

  const filteredFriends = React.useMemo(() => {
    const normalized = searchKeyword.trim().toLowerCase()

    if (!normalized) {
      return friends
    }

    return friends.filter((friend) => {
      const label = resolveFriendLabel(friend).toLowerCase()
      const searchable = `${label} ${friend.friendId} ${friend.statusMessage ?? ''}`.toLowerCase()
      return searchable.includes(normalized)
    })
  }, [friends, searchKeyword])

  const toggleSelection = (userId: string) => {
    setSelectedUserIds((prev) => {
      if (prev.includes(userId)) {
        return prev.filter((item) => item !== userId)
      }

      return [...prev, userId]
    })
  }

  const canShare = Boolean(message) && selectedUserIds.length > 0 && !isSubmitting

  return (
    <Modal
      isOpen={isOpen}
      title='Chia sẻ tin nhắn'
      description='Chọn một hoặc nhiều bạn bè để chia sẻ tin nhắn này.'
      onClose={onClose}
      footer={
        <>
          <Button variant='ghost' onClick={onClose} disabled={isSubmitting}>
            Hủy
          </Button>
          <Button
            variant='primary'
            disabled={!canShare}
            onClick={() => {
              void onShare(selectedUserIds, note)
            }}
          >
            {isSubmitting ? 'Đang chia sẻ...' : 'Chia sẻ'}
          </Button>
        </>
      }
    >
      <div className='message-share-modal'>
        <div className='message-share-search'>
          <input
            type='text'
            placeholder='Tìm bạn bè...'
            value={searchKeyword}
            onChange={(event) => setSearchKeyword(event.target.value)}
          />
        </div>

        <div className='message-share-friend-list'>
          {filteredFriends.length === 0 ? (
            <p className='message-share-empty'>Không tìm thấy bạn bè phù hợp.</p>
          ) : (
            filteredFriends.map((friend) => {
              const checked = selectedUserIds.includes(friend.friendId)
              const label = resolveFriendLabel(friend)
              const subtitle = friend.statusMessage?.trim() || friend.friendId

              return (
                <label key={friend.friendshipId} className='message-share-friend-item'>
                  <input
                    type='checkbox'
                    checked={checked}
                    onChange={() => toggleSelection(friend.friendId)}
                  />
                  <UserAvatar name={label} imageUrl={friend.avatarUrl} size='sm' />
                  <span className='message-share-friend-copy'>
                    <strong>{label}</strong>
                    <small>{subtitle}</small>
                  </span>
                </label>
              )
            })
          )}
        </div>

        <div className='message-share-note'>
          <textarea
            rows={3}
            placeholder='Thêm lời nhắn (không bắt buộc)...'
            value={note}
            onChange={(event) => setNote(event.target.value)}
          />
        </div>
      </div>
    </Modal>
  )
}
