import React from 'react'
import { X } from 'lucide-react'
import { REACTION_OPTIONS } from '../chat.constants'
import type {
  MessageReactionMap,
  ReactionKey,
} from '../chat.types'
import { useUserStore } from '../context/UserStoreContext'
import { ReactionDetailModal } from './ReactionDetailModal'
import { useAuth } from '../../auth/useAuth'

type MessageReactionBarProps = {
  reactions: MessageReactionMap
  onAddReaction: (reactionKey: ReactionKey) => void
  onRemoveReaction: (reactionKey: ReactionKey) => void
  onOpenFullEmoji?: () => void
}

export function MessageReactionBar({ reactions, onAddReaction, onRemoveReaction, onOpenFullEmoji }: MessageReactionBarProps) {
  // Find which reaction the user has already made (if any)
  const myReactionKey = (Object.keys(reactions) as ReactionKey[]).find(
    (key) => (reactions[key]?.myCount ?? 0) > 0
  )

  return (
    <div className='flex items-center gap-1 rounded-2xl border border-slate-200 bg-white px-2 py-1.5 shadow-[0_10px_28px_rgba(15,23,42,0.18)] animate-in fade-in zoom-in duration-200'>
      {REACTION_OPTIONS.map((reaction) => {
        const reactedByMe = reaction.key === myReactionKey

        return (
          <button
            key={reaction.key}
            type='button'
            title={reaction.label}
            onClick={() => onAddReaction(reaction.key)}
            className={`inline-flex h-10 w-10 items-center justify-center rounded-full border-0 bg-transparent text-[29px] leading-none transition duration-150 hover:scale-125 active:scale-110 ${
              reactedByMe ? 'bg-sky-50 ring-1 ring-sky-200' : 'hover:bg-slate-50'
            }`}
          >
            {reaction.emoji}
          </button>
        )
      })}

      {myReactionKey && (
        <button
          type='button'
          title='Gỡ biểu cảm'
          onClick={() => onRemoveReaction(myReactionKey)}
          className='inline-flex h-9 w-9 items-center justify-center rounded-full border border-red-100 bg-red-50 text-red-500 transition hover:scale-110 hover:bg-red-100'
        >
          <X size={18} />
        </button>
      )}
    </div>
  )
}

type MessageReactionSummaryProps = {
  reactions: MessageReactionMap
  onRemoveReaction: (reactionKey: ReactionKey) => void
  isIncoming?: boolean
}

export function MessageReactionSummary({ reactions, onRemoveReaction, isIncoming = true }: MessageReactionSummaryProps) {
  const { user } = useAuth()
  const { userMap } = useUserStore()
  const [isDetailModalOpen, setIsDetailModalOpen] = React.useState(false)
  const [hoveredReactionKey, setHoveredReactionKey] = React.useState<ReactionKey | null>(null)
  const [tooltipPlacement, setTooltipPlacement] = React.useState<'top' | 'bottom'>('bottom')
  const activeReactions = REACTION_OPTIONS.filter((item) => (reactions[item.key]?.count ?? 0) > 0)

  const getReactionNames = (userIds: string[] | undefined) => {
    const names = (userIds ?? [])
      .map((uid) => (uid === user?.id ? 'Bạn' : (userMap[uid]?.displayName || 'Người dùng')))
      .filter(Boolean)

    if (names.length === 0) {
      return ['Chưa có ai thả biểu cảm']
    }

    const uniqueNames = Array.from(new Set(names))
    if (uniqueNames.includes('Bạn')) {
      return ['Bạn', ...uniqueNames.filter((name) => name !== 'Bạn')]
    }

    return uniqueNames
  }

  if (activeReactions.length === 0) {
    return null
  }

  return (
    <>
      <div 
        className='mt-1.5 flex flex-wrap gap-1.5 cursor-pointer overflow-visible'
        onClick={(e) => {
          e.stopPropagation()
          setIsDetailModalOpen(true)
        }}
      >
        {activeReactions.map((reaction) => {
          const state = reactions[reaction.key]
          const count = state?.count ?? 0
          const reactedByMe = (state?.myCount ?? 0) > 0
          const userNames = getReactionNames(state?.userIds)

          // Tooltip position handling
          const handleMouseEnter = (e: React.MouseEvent) => {
            const rect = e.currentTarget.getBoundingClientRect()
            
            // Check space relative to the chat scroll container if possible
            const scrollContainer = e.currentTarget.closest('.chat-window-messages')
            const containerBottom = scrollContainer ? scrollContainer.getBoundingClientRect().bottom : window.innerHeight
            
            const spaceBelow = containerBottom - rect.bottom
            const spaceAbove = rect.top
            
            // If space below is less than 160px (to account for input bar + tooltip), flip to top
            if (spaceBelow < 160 && spaceAbove > spaceBelow) {
              setTooltipPlacement('top')
            } else {
              setTooltipPlacement('bottom')
            }
            setHoveredReactionKey(reaction.key)
          }

          return (
            <div
              key={reaction.key}
              className={`group relative inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs shadow-sm transition ${
                reactedByMe
                  ? 'border-sky-200 bg-sky-50 text-sky-700'
                  : 'border-slate-200 bg-white text-slate-600'
              }`}
              onMouseEnter={handleMouseEnter}
              onMouseLeave={() => setHoveredReactionKey(null)}
            >
              <span className='text-sm'>{reaction.emoji}</span>
              <span className='font-semibold'>{count}</span>

              {hoveredReactionKey === reaction.key && (
                <div 
                  className={`pointer-events-none absolute z-[100] rounded-xl bg-[#1f4fbf] px-3 py-2 text-left text-xs font-medium text-white shadow-[0_12px_28px_rgba(15,23,42,0.28)] whitespace-nowrap min-w-[max-content] animate-in fade-in zoom-in duration-150 ${
                    tooltipPlacement === 'top' 
                      ? 'bottom-full mb-2' 
                      : 'top-full mt-2'
                  } ${
                    isIncoming ? 'left-1/2 -translate-x-1/2' : 'right-0'
                  }`}
                >
                  <div className='flex flex-col gap-1'>
                    {userNames.map((name) => (
                      <span key={name} className='leading-tight'>
                        {name}
                      </span>
                    ))}
                  </div>
                  {/* Tooltip Arrow */}
                  <div 
                    className={`absolute border-4 border-transparent ${
                      isIncoming ? 'left-1/2 -translate-x-1/2' : 'right-3'
                    } ${
                      tooltipPlacement === 'top'
                        ? 'top-full border-t-[#1f4fbf]'
                        : 'bottom-full border-b-[#1f4fbf]'
                    }`} 
                  />
                </div>
              )}
            </div>
          )
        })}
      </div>

      <ReactionDetailModal 
        isOpen={isDetailModalOpen} 
        onClose={() => setIsDetailModalOpen(false)} 
        reactions={reactions} 
      />
    </>
  )
}
