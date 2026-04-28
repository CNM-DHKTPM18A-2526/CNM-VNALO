import React, { memo } from 'react'
import { Phone, Video, ArrowUpRight, Users } from 'lucide-react'
import type { ChatMessage } from '../chat.types'
import { parseCallLog, formatDurationZalo } from '../utils/messageUtils'

type CallLogBubbleProps = {
  message: ChatMessage
  currentUserId?: string
  onInitiateCall?: (type: 'audio' | 'video') => void
}

/**
 * Zalo-style Call Log Bubble component.
 * Displays call direction, type icon, duration, and a "Gọi lại" (Call back) button.
 */
export const CallLogBubble = memo(function CallLogBubble({ message, currentUserId, onInitiateCall }: CallLogBubbleProps) {
  const logData = parseCallLog(message.text)
  const isMyMessage = message.sender === 'me'
  
  if (!logData) {
    return <div className="p-3 bg-[#f0f2f5] rounded-xl text-sm italic text-slate-500">Cuộc gọi không xác định</div>
  }

  const isVideo = logData.mediaType === 'video'
  const isGroup = logData.isGroup === true || logData.calleeId === 'group'
  const isOutgoing = logData.callerId === currentUserId || isMyMessage
  const durationText = formatDurationZalo(logData.durationSeconds)
  
  let label: string
  if (isGroup) {
    label = isVideo ? 'Cuộc gọi video nhóm' : 'Cuộc gọi thoại nhóm'
  } else if (isVideo) {
    label = isOutgoing ? 'Cuộc gọi video đi' : 'Cuộc gọi video đến'
  } else {
    label = isOutgoing ? 'Cuộc gọi thoại đi' : 'Cuộc gọi thoại đến'
  }

  const handleCallBack = (e: React.MouseEvent) => {
    e.preventDefault(); e.stopPropagation()
    if (onInitiateCall) onInitiateCall(isVideo ? 'video' : 'audio')
  }

  return (
    <div className={`call-log-bubble-container relative flex flex-col min-w-[180px] max-w-[240px] border border-[var(--border)] rounded-2xl overflow-hidden shadow-sm transition-all hover:shadow-md ${isOutgoing ? 'bg-[var(--primary-soft)]' : 'bg-[var(--surface)]'}`}>
      <div className="flex flex-col items-center p-3 pb-2">
        <h3 className="text-[15px] font-medium text-[var(--text)] mb-1.5 px-2 text-center">{label}</h3>
        <div className="flex items-center gap-2 mb-3">
          <div className="relative">
            {isGroup ? <Users size={18} className="text-slate-500 dark:text-slate-400" /> : isVideo ? <Video size={18} className="text-slate-500 dark:text-slate-400" /> : <Phone size={18} className="text-slate-500 dark:text-slate-400" />}
            {isOutgoing && !isGroup && <div className="absolute -top-1 -right-2"><ArrowUpRight size={12} className="text-green-500 stroke-[3px]" /></div>}
            {!isOutgoing && logData.outcome === 'missed' && <div className="absolute -top-1 -right-2 text-red-500 font-bold text-[12px]">!</div>}
          </div>
          <span className="text-[14px] text-slate-500 dark:text-slate-400">{durationText || (logData.outcome === 'missed' ? 'Cuộc gọi nhỡ' : 'Đã hủy')}</span>
        </div>
        <div className="w-full h-[1px] bg-black/[0.06] dark:bg-white/10 mb-0.5" />
        {!isGroup && (
          <button type="button" onMouseDown={(e) => e.stopPropagation()} onClick={handleCallBack} className={`w-full py-2 text-[#0068ff] dark:text-sky-400 font-bold text-[14px] transition-all hover:brightness-95 active:bg-black/5 dark:active:bg-white/5 flex items-center justify-center cursor-pointer relative z-[50] pointer-events-auto rounded-b-xl border-none bg-transparent`}>
            Gọi lại
          </button>
        )}
        {isGroup && <div className="w-full py-2 text-slate-400 dark:text-slate-500 text-[13px] text-center">{(logData.participantCount ?? 0) > 1 ? `${logData.participantCount} người tham gia` : 'Cuộc gọi nhóm'}</div>}
      </div>
    </div>
  )
}, (prev, next) => prev.message.id === next.message.id && prev.message.text === next.message.text)
