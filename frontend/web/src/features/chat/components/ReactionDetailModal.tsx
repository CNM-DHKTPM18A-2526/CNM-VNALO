import React from 'react'
import { Modal } from '../../../shared/components/ui/Modal'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { REACTION_OPTIONS } from '../chat.constants'
import type { MessageReactionMap, ReactionKey } from '../chat.types'
import { useUserStore } from '../context/UserStoreContext'
import { useAuth } from '../../auth/useAuth'

type ReactionDetailModalProps = {
  isOpen: boolean
  onClose: () => void
  reactions: MessageReactionMap
}

export function ReactionDetailModal({ isOpen, onClose, reactions }: ReactionDetailModalProps) {
  const { accessToken, user: currentUser } = useAuth()
  const { userMap, ensureUser } = useUserStore()
  const [activeTab, setActiveTab] = React.useState<'all' | ReactionKey>('all')

  // Fetch missing users on mount/open
  React.useEffect(() => {
    if (!isOpen || !accessToken) return

    const allUserIds = Object.values(reactions).flatMap(r => r.userIds)
    const uniqueIds = Array.from(new Set(allUserIds))
    
    uniqueIds.forEach(uid => {
      if (!userMap[uid] || userMap[uid].displayName === 'Người dùng') {
        void ensureUser(accessToken, uid)
      }
    })
  }, [isOpen, reactions, accessToken, userMap, ensureUser])

  const activeReactions = React.useMemo(() => {
    return REACTION_OPTIONS.filter((opt) => (reactions[opt.key]?.count ?? 0) > 0)
  }, [reactions])

  const totalCount = React.useMemo(() => {
    return Object.values(reactions).reduce((sum, r) => sum + (r.count || 0), 0)
  }, [reactions])

  const displayedUserIds = React.useMemo(() => {
    if (activeTab === 'all') {
      const all: string[] = []
      // Combine all userIds, but keep track of which emoji they used
      Object.entries(reactions).forEach(([key, val]) => {
        val.userIds.forEach(uid => {
          all.push(`${uid}:${key}`)
        })
      })
      return all
    }
    
    return (reactions[activeTab]?.userIds || []).map(uid => `${uid}:${activeTab}`)
  }, [activeTab, reactions])

  return (
    <Modal isOpen={isOpen} title="Biểu cảm" onClose={onClose} variant="none">
      <div className="flex h-[400px] overflow-hidden bg-[var(--surface)]">
        {/* Sidebar Tabs */}
        <div className="w-[120px] bg-[var(--surface)] border-r border-[var(--border)] overflow-y-auto">
          <button
            onClick={() => setActiveTab('all')}
            className={`w-full px-4 py-3 text-left text-sm flex items-center justify-between transition border-none ${
              activeTab === 'all' 
                ? 'bg-[var(--surface-hover)] font-bold text-sky-500 border-r-2 border-sky-500' 
                : 'bg-transparent text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]'
            }`}
          >
            <span>Tất cả</span>
            <span className="text-xs opacity-70">{totalCount}</span>
          </button>
          
          {activeReactions.map((reaction) => (
            <button
              key={reaction.key}
              onClick={() => setActiveTab(reaction.key)}
              className={`w-full px-4 py-3 text-left text-sm flex items-center justify-between transition border-none ${
                activeTab === reaction.key 
                  ? 'bg-[var(--surface-hover)] font-bold text-sky-500 border-r-2 border-sky-500' 
                  : 'bg-transparent text-[var(--text-secondary)] hover:bg-[var(--surface-hover)]'
              }`}
            >
              <span className="text-base">{reaction.emoji}</span>
              <span className="text-xs opacity-70">{reactions[reaction.key].count}</span>
            </button>
          ))}
        </div>

        {/* User List */}
        <div className="flex-1 overflow-y-auto p-4 custom-scrollbar bg-[var(--surface)]">
          {displayedUserIds.length === 0 ? (
            <div className="h-full flex items-center justify-center text-[var(--text-secondary)] text-sm italic">
              Chưa có biểu cảm nào
            </div>
          ) : (
            <div className="space-y-4">
              {displayedUserIds.map((compositeId) => {
                const [userId, reactionKey] = compositeId.split(':')
                const profile = userMap[userId]
                const emoji = REACTION_OPTIONS.find(opt => opt.key === reactionKey)?.emoji
                
                const isMe = userId === currentUser?.id
                const displayName = isMe ? 'Bạn' : (profile?.displayName || 'Người dùng')
                
                return (
                  <div key={compositeId} className="flex items-center justify-between group">
                    <div className="flex items-center gap-3">
                      <UserAvatar 
                        name={displayName} 
                        imageUrl={userMap[userId]?.avatarUrl} 
                        size="sm" 
                      />
                      <span className="text-sm font-medium text-[var(--text)]">
                        {displayName}
                      </span>
                    </div>
                    <div className="flex items-center gap-1.5 bg-[var(--surface-muted)] px-2 py-1 rounded-full border border-[var(--border)]">
                      <span className="text-sm">{emoji}</span>
                      <span className="text-[10px] font-bold text-[var(--text-secondary)]">1</span>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </Modal>
  )
}
