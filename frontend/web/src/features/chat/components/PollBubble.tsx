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
  const [selectedOptionIds, setSelectedOptionIds] = useState<Set<string>>(new Set());

  // Derive votes from reactions if available, otherwise fallback to pollData
  const getVotesCountForOption = (optionId: string) => {
    if (!reactions) return (poll.options.find(o => o.id === optionId)?.votes || []).length;
    
    let count = 0;
    const optionMatch = optionId.match(/\d+/);
    const optionNum = optionMatch ? optionMatch[0] : optionId;
    
    Object.entries(reactions).forEach(([key, reaction]) => {
      // Extract numeric part from reaction key (e.g., "vote:o0" -> "0", "vote:0" -> "0", "v:0,1" -> ["0", "1"])
      const keyMatch = key.match(/\d+/g);
      if (key.startsWith('vote:') && keyMatch && keyMatch[0] === optionNum) {
        count += reaction.count;
      } else if (key.startsWith('v:') && keyMatch) {
        if (keyMatch.includes(optionNum)) {
          count += reaction.count;
        }
      }
    });
    return count;
  };

  const isUserVotedOption = (optionId: string) => {
    if (!reactions) return currentUserId ? (poll.options.find(o => o.id === optionId)?.votes || []).includes(currentUserId) : false;
    
    const optionMatch = optionId.match(/\d+/);
    const optionNum = optionMatch ? optionMatch[0] : optionId;
    let isVoted = false;
    
    Object.entries(reactions).forEach(([key, reaction]) => {
      if (reaction.myCount > 0) {
        const keyMatch = key.match(/\d+/g);
        if (key.startsWith('vote:') && keyMatch && keyMatch[0] === optionNum) {
          isVoted = true;
        } else if (key.startsWith('v:') && keyMatch) {
          if (keyMatch.includes(optionNum)) {
            isVoted = true;
          }
        }
      }
    });
    
    return isVoted;
  };

  const totalVotes = poll.options.reduce((sum, opt) => sum + getVotesCountForOption(opt.id), 0);

  // Check if current user has already voted for ANY option in this poll
  const hasVoted = poll.options.some(opt => isUserVotedOption(opt.id));

  const handleOptionClick = (optionId: string) => {
    if (hasVoted) return;
    
    setSelectedOptionIds(prev => {
      const next = new Set(prev);
      if (next.has(optionId)) {
        next.delete(optionId);
      } else {
        if (!poll.allowMultiple) {
          next.clear();
        }
        next.add(optionId);
      }
      return next;
    });
  };

  const handleVoteSubmit = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (selectedOptionIds.size > 0) {
      const ids = Array.from(selectedOptionIds);
      // Extract numeric indices to keep the string short (max 20 chars in backend)
      const numericIds = ids.map(id => id.match(/\d+/)?.[0] || id);
      
      const bundledEmoji = poll.allowMultiple 
        ? `v:${numericIds.join(',')}`
        : `vote:${numericIds[0]}`;
      
      setSelectedOptionIds(new Set());
      await Promise.resolve(onVote?.(bundledEmoji));
    }
  };

  const canVote = selectedOptionIds.size > 0 && !hasVoted;

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
            const votesCount = getVotesCountForOption(opt.id);
            const percent = totalVotes > 0 ? (votesCount / totalVotes) * 100 : 0;
            const isUserVotedThis = isUserVotedOption(opt.id);
            const isLocallySelected = selectedOptionIds.has(opt.id);

            const isActive = isUserVotedThis || isLocallySelected;

            return (
              <div
                key={opt.id}
                onClick={() => handleOptionClick(opt.id)}
                className={`relative h-10 w-full bg-[var(--bg)] rounded-lg overflow-hidden border transition-all cursor-pointer ${isActive ? 'border-[#0068ff] ring-1 ring-[#0068ff]/20' : 'border-[var(--border)] hover:border-slate-300'}`}
              >
                <div
                  className={`absolute top-0 left-0 h-full transition-all duration-500 ${isUserVotedThis ? 'bg-[#0068ff]/20' : isLocallySelected ? 'bg-[#0068ff]/10' : 'bg-slate-100 dark:bg-slate-800'}`}
                  style={{ width: isUserVotedThis ? `${percent}%` : '0%' }}
                />
                <div className="relative h-full flex items-center justify-between px-3 text-[14px]">
                  <div className="flex items-center truncate mr-2">
                    <div className={`w-4 h-4 rounded-full border flex items-center justify-center mr-2 shrink-0 transition-colors ${isActive ? 'bg-[#0068ff] border-[#0068ff]' : 'border-slate-300 bg-white'}`}>
                      {isActive && (
                        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                      )}
                    </div>
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
      <div className="px-4 pb-4">
        <button
          onClick={handleVoteSubmit}
          disabled={!canVote}
          className={`w-full py-2.5 rounded-lg text-[14px] font-bold transition-all uppercase tracking-wide flex items-center justify-center gap-2 ${canVote
              ? 'text-white bg-[#0068ff] hover:bg-[#005ae0] shadow-md hover:shadow-lg active:scale-[0.98]'
              : hasVoted
                ? 'text-[#0068ff] bg-[#0068ff]/10 cursor-default'
                : 'text-slate-400 bg-slate-100 dark:bg-slate-800 cursor-not-allowed opacity-60'
            }`}
        >
          {hasVoted ? (
            <>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              Đã bình chọn
            </>
          ) : 'Bình chọn'}
        </button>
      </div>
    </div>
  );
}
