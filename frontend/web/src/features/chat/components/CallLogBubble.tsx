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
export function CallLogBubble({ message, currentUserId, onInitiateCall }: CallLogBubbleProps) {
  const logData = parseCallLog(message.text)
  const isMyMessage = message.sender === 'me'
  
  console.log('[CallLogBubble] Render', { 
    id: message.id, 
    isMyMessage, 
    hasHandler: !!onInitiateCall 
  })
  
  if (!logData) {
    // Fallback if data is corrupted
    return (
      <div className="p-3 bg-[#f0f2f5] rounded-xl text-sm italic text-slate-500">
        Cuộc gọi không xác định
      </div>
    )
  }

  const isVideo = logData.mediaType === 'video'
  const isGroup = logData.isGroup === true || logData.calleeId === 'group'
  const isOutgoing = logData.callerId === currentUserId || isMyMessage
  const durationText = formatDurationZalo(logData.durationSeconds)
  
  // Labels
  let label: string
  if (isGroup) {
    label = isVideo ? 'Cuộc gọi video nhóm' : 'Cuộc gọi thoại nhóm'
  } else if (isVideo) {
    label = isOutgoing ? 'Cuộc gọi video đi' : 'Cuộc gọi video đến'
  } else {
    label = isOutgoing ? 'Cuộc gọi thoại đi' : 'Cuộc gọi thoại đến'
  }

  const handleCallBack = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    console.log('[CallLogBubble] Callback initiative triggered', { 
      type: isVideo ? 'video' : 'audio', 
      peer: message.conversationId,
      hasHandler: !!onInitiateCall 
    })
    
    if (onInitiateCall) {
      onInitiateCall(isVideo ? 'video' : 'audio')
    } else {
      console.error('[CallLogBubble] CRITICAL: onInitiateCall handler missing in prop tree')
    }
  }

  return (
    <div 
      className={`call-log-bubble-container relative flex flex-col min-w-[180px] max-w-[240px] border border-black/[0.08] rounded-2xl overflow-hidden shadow-sm transition-all hover:shadow-md ${isOutgoing ? 'bg-[#E5EFFF]' : 'bg-white'}`}
    >
      {/* Content Section */}
      <div className="flex flex-col items-center p-3 pb-2">
        {/* Title */}
        <h3 className="text-[15px] font-medium text-slate-800 mb-1.5 px-2 text-center">
          {label}
        </h3>

        {/* Icon & Duration Row */}
        <div className="flex items-center gap-2 mb-3">
          <div className="relative">
            {isGroup ? (
              <Users size={18} className="text-slate-500 fill-slate-500/10" />
            ) : isVideo ? (
              <Video size={18} className="text-slate-500 fill-slate-500/10" />
            ) : (
              <Phone size={18} className="text-slate-500 fill-slate-500/10" />
            )}
            
            {isOutgoing && !isGroup && (
              <div className="absolute -top-1 -right-2 bg-transparent">
                <ArrowUpRight size={12} className="text-green-500 stroke-[3px]" />
              </div>
            )}
            {!isOutgoing && logData.outcome === 'missed' && (
               <div className="absolute -top-1 -right-2 bg-transparent">
                 <div className="text-red-500 font-bold text-[12px]">!</div>
               </div>
            )}
          </div>
          
          <span className="text-[14px] text-slate-500 font-normal">
            {durationText || (logData.outcome === 'missed' ? 'Cuộc gọi nhỡ' : 'Đã hủy')}
          </span>
        </div>

        {/* Separator Line */}
        <div className="w-full h-[1px] bg-black/[0.06] mb-0.5" />

        {/* Action Button - hide for group calls */}
        {!isGroup && (
        <button
          type="button"
          onMouseDown={(e) => {
            e.stopPropagation();
          }}
          onClick={handleCallBack}
          className={`w-full py-2 text-[#0068ff] font-bold text-[14px] transition-all hover:brightness-95 active:bg-black/5 flex items-center justify-center cursor-pointer relative z-[50] pointer-events-auto rounded-b-xl border-none ${isOutgoing ? 'bg-[#E5EFFF]' : 'bg-white'}`}
        >
          Gọi lại
        </button>
        )}
        {isGroup && (
          <div className="w-full py-2 text-slate-400 text-[13px] text-center">
            {(logData.participantCount ?? 0) > 1 ? `${logData.participantCount} người tham gia` : 'Cuộc gọi nhóm'}
          </div>
        )}
      </div>

    </div>
  )
}
