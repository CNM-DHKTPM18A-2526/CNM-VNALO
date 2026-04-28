import React, { useState } from 'react';
import { ChevronRight } from 'lucide-react';
import type { PollMetadata, MessageReactionMap } from '../chat.types';

interface PollBubbleProps {
  poll: PollMetadata;
  isMyMessage: boolean;
  currentUserId?: string;
  onVote?: (optionId: string) => void;
  reactions?: MessageReactionMap;
}

export function PollBubble({ poll, isMyMessage, currentUserId, onVote, reactions }: PollBubbleProps) {
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);

  // Derive votes from reactions if available, otherwise fallback to pollData
  const getVotesForOption = (optionId: string) => {
    if (!reactions) return poll.options.find(o => o.id === optionId)?.votes || [];
    
    const reactionKey = `vote:${optionId}`;
    return reactions[reactionKey] || [];
  };

  const allVoters = new Set<string>();
  poll.options.forEach(opt => {
    getVotesForOption(opt.id).forEach(uid => allVoters.add(uid));
  });
  
  const totalVotes = allVoters.size;

  // Check if current user has already voted for ANY option in this poll
  const userVoteOptionId = currentUserId ? poll.options.find(opt => getVotesForOption(opt.id).includes(currentUserId))?.id : null;
  const hasVoted = !!userVoteOptionId;

  const handleOptionClick = (optionId: string) => {
    if (hasVoted && !poll.allowMulti) return; // Can't change vote if not multi-vote (simplified)
    setSelectedOptionId(optionId);
  };

  const handleVoteSubmit = () => {
    if (selectedOptionId) {
      onVote?.(selectedOptionId);
      setSelectedOptionId(null); // Clear local selection after voting
    } else if (!hasVoted) {
      // Alert or highlight that an option must be selected
    }
  };

  return (
    <div className={`poll-bubble bg-[var(--surface)] rounded-xl border border-[var(--border)] shadow-sm overflow-hidden w-full max-w-[300px] flex flex-col ${isMyMessage ? 'ml-auto' : ''}`}>
      <div className="p-4 space-y-3">
        {/* Title */}
        <div className="text-center space-y-1">
          <h3 className="text-[16px] font-bold text-[var(--text)] leading-tight">
            {poll.question}
          </h3>
          <p className="text-[13px] text-[#0068ff] font-medium">
            Đã có {totalVotes} lượt bình chọn <ChevronRight size={14} className="inline-block" />
          </p>
        </div>

        <div className="space-y-2 mt-2">
          {poll.options.map((opt) => {
            const votes = getVotesForOption(opt.id);
            const votesCount = votes.length;
            const percent = totalVotes > 0 ? (votesCount / totalVotes) * 100 : 0;
            const isUserVotedThis = currentUserId ? votes.includes(currentUserId) : false;
            const isLocallySelected = selectedOptionId === opt.id;
            
            const isActive = isUserVotedThis || isLocallySelected;

            return (
              <div 
                key={opt.id} 
                onClick={() => handleOptionClick(opt.id)}
                className={`relative h-9 w-full bg-[var(--bg)] rounded-lg overflow-hidden border transition-all cursor-pointer ${isActive ? 'border-blue-500 ring-1 ring-blue-500/20' : 'border-[var(--border)] hover:border-slate-200'}`}
              >
                <div 
                  className={`absolute top-0 left-0 h-full transition-all duration-500 ${isActive ? 'bg-[#0068ff]/20' : 'bg-[#0068ff]/10'}`} 
                  style={{ width: `${percent}%` }}
                />
                <div className="relative h-full flex items-center justify-between px-3 text-[14px]">
                  <div className="flex items-center truncate mr-2">
                    {isActive && (
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center mr-2 shrink-0 ${isUserVotedThis ? 'bg-blue-600' : 'bg-blue-400'}`}>
                        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                      </div>
                    )}
                    <span className={`font-medium truncate ${isActive ? 'text-[#0068ff]' : 'text-[var(--text)]'}`}>{opt.label}</span>
                  </div>
                  <span className={`shrink-0 ${isActive ? 'text-[#0068ff] font-bold' : 'text-[var(--muted)]'}`}>{votesCount}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Footer Button */}
      <button 
        onClick={handleVoteSubmit}
        disabled={!selectedOptionId && !hasVoted}
        className={`w-full py-3 border-t border-[var(--border)] text-[14px] font-bold transition-colors uppercase tracking-wide cursor-pointer outline-none ${
          (selectedOptionId || !hasVoted) 
            ? 'text-[#0068ff] bg-[var(--surface)] hover:bg-[var(--surface-hover)]' 
            : 'text-[var(--muted)] bg-[var(--bg)] cursor-default'
        }`}
      >
        {hasVoted ? 'Đã bình chọn' : 'Bình chọn'}
      </button>
    </div>
  );
}
