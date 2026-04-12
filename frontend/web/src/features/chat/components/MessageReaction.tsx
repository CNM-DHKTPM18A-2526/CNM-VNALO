export type ReactionKey = 'like' | 'love' | 'haha' | 'wow' | 'sad' | 'angry'

export type ReactionOption = {
  key: ReactionKey
  emoji: string
  label: string
}

export type ReactionState = {
  count: number
  myCount: number
}

export type MessageReactionMap = Partial<Record<ReactionKey, ReactionState>>

export type MessageReactionState = {
  reactions: MessageReactionMap
  lastUsedReaction?: ReactionKey
}

export const REACTION_OPTIONS: ReactionOption[] = [
  { key: 'like', emoji: '👍', label: 'Thích' },
  { key: 'love', emoji: '❤️', label: 'Tim' },
  { key: 'haha', emoji: '😂', label: 'Cười' },
  { key: 'wow', emoji: '😮', label: 'Ngạc nhiên' },
  { key: 'sad', emoji: '😢', label: 'Buồn' },
  { key: 'angry', emoji: '😡', label: 'Giận' },
]

type MessageReactionBarProps = {
  reactions: MessageReactionMap
  onAddReaction: (reactionKey: ReactionKey) => void
  onOpenFullEmoji?: () => void
}

export function MessageReactionBar({ reactions, onAddReaction, onOpenFullEmoji }: MessageReactionBarProps) {
  return (
    <div className='flex items-center gap-1 rounded-2xl border border-slate-200 bg-white px-2 py-1.5 shadow-[0_10px_28px_rgba(15,23,42,0.18)]'>
      {REACTION_OPTIONS.map((reaction) => {
        const reactedByMe = (reactions[reaction.key]?.myCount ?? 0) > 0

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

      <button
        type='button'
        title='Mở bảng emoji'
        onClick={onOpenFullEmoji}
        className='inline-flex h-9 w-9 items-center justify-center rounded-full border border-slate-200 bg-slate-50 text-lg font-semibold text-slate-500 transition hover:scale-110 hover:bg-slate-100'
      >
        +
      </button>
    </div>
  )
}

type MessageReactionSummaryProps = {
  reactions: MessageReactionMap
  onRemoveReaction: (reactionKey: ReactionKey) => void
}

export function MessageReactionSummary({ reactions, onRemoveReaction }: MessageReactionSummaryProps) {
  const activeReactions = REACTION_OPTIONS.filter((item) => (reactions[item.key]?.count ?? 0) > 0)

  if (activeReactions.length === 0) {
    return null
  }

  return (
    <div className='mt-1.5 flex flex-wrap gap-1.5'>
      {activeReactions.map((reaction) => {
        const state = reactions[reaction.key]
        const count = state?.count ?? 0
        const reactedByMe = (state?.myCount ?? 0) > 0

        return (
          <button
            key={reaction.key}
            type='button'
            disabled={!reactedByMe}
            onClick={() => onRemoveReaction(reaction.key)}
            className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs shadow-sm transition ${
              reactedByMe
                ? 'border-sky-200 bg-sky-50 text-sky-700'
                : 'cursor-default border-slate-200 bg-white text-slate-600'
            }`}
          >
            <span className='text-sm'>{reaction.emoji}</span>
            <span className='font-semibold'>{count}</span>
          </button>
        )
      })}
    </div>
  )
}
