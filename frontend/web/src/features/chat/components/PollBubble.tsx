import React from 'react';
import { ChevronRight } from 'lucide-react';
import type { PollMetadata, MessageReactionMap } from '../chat.types';
import { Modal } from '../../../shared/components/ui/Modal';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useUserStore } from '../context/UserStoreContext';
import { useAuth } from '../../auth/useAuth';
import { useTheme } from '../../../shared/contexts/ThemeContext';

interface PollBubbleProps {
  poll: PollMetadata;
  isMyMessage: boolean;
  currentUserId?: string;
  onVote?: (optionId: string) => void;
  reactions?: MessageReactionMap;
}

export function PollBubble({ poll, isMyMessage, currentUserId, onVote, reactions }: PollBubbleProps) {
  const [selectedOptionIds, setSelectedOptionIds] = React.useState<Set<string>>(new Set());
  const [isVoterModalOpen, setIsVoterModalOpen] = React.useState(false);
  const { accessToken, user: currentUser } = useAuth();
  const { userMap, ensureUser } = useUserStore();
  const { theme } = useTheme();
  const isLightMode = theme === 'light';

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

  const getVotersForOption = React.useCallback((optionId: string) => {
    const voters = new Set<string>();

    if (!reactions) {
      const fromPollData = poll.options.find(o => o.id === optionId)?.votes ?? [];
      fromPollData.forEach(voterId => voters.add(voterId));
      return Array.from(voters);
    }

    const optionMatch = optionId.match(/\d+/);
    const optionNum = optionMatch ? optionMatch[0] : optionId;

    Object.entries(reactions).forEach(([key, reaction]) => {
      const keyMatch = key.match(/\d+/g);
      const matchesSingleVote = key.startsWith('vote:') && keyMatch && keyMatch[0] === optionNum;
      const matchesMultiVote = key.startsWith('v:') && keyMatch && keyMatch.includes(optionNum);

      if (matchesSingleVote || matchesMultiVote) {
        reaction.userIds.forEach(userId => voters.add(userId));
      }
    });

    return Array.from(voters);
  }, [poll.options, reactions]);

  const getAllVoters = React.useCallback(() => {
    const voters = new Set<string>();

    poll.options.forEach((option) => {
      getVotersForOption(option.id).forEach((userId) => voters.add(userId));
    });

    return Array.from(voters);
  }, [getVotersForOption, poll.options]);

  const openVoterModal = () => {
    setIsVoterModalOpen(true);
  };

  React.useEffect(() => {
    if (!isVoterModalOpen || !accessToken) return;

    const voterIds = getAllVoters();
    voterIds.forEach(userId => {
      if (!userMap[userId] || userMap[userId].displayName === 'Người dùng') {
        void ensureUser(accessToken, userId);
      }
    });
  }, [accessToken, ensureUser, getAllVoters, isVoterModalOpen, userMap]);

  const totalVotes = poll.options.reduce((sum, opt) => sum + getVotesCountForOption(opt.id), 0);

  // Check if current user has already voted for ANY option in this poll
  const hasVoted = poll.options.some(opt => isUserVotedOption(opt.id));
  const currentVoteOptionIds = React.useMemo(() => {
    const votedIds = new Set<string>();

    poll.options.forEach((option) => {
      if (isUserVotedOption(option.id)) {
        votedIds.add(option.id);
      }
    });

    return votedIds;
  }, [poll.options, reactions, currentUserId]);

  const selectedOptionKey = React.useMemo(() => Array.from(selectedOptionIds).sort().join('|'), [selectedOptionIds]);
  const currentVoteKey = React.useMemo(() => Array.from(currentVoteOptionIds).sort().join('|'), [currentVoteOptionIds]);

  React.useEffect(() => {
    if (selectedOptionIds.size === 0 && currentVoteOptionIds.size > 0) {
      setSelectedOptionIds(new Set(currentVoteOptionIds));
    }
  }, [currentVoteOptionIds, selectedOptionIds.size]);

  const handleOptionClick = (optionId: string) => {
    setSelectedOptionIds(prev => {
      const next = new Set(prev);
      if (!poll.allowMultiple) {
        next.clear();
        next.add(optionId);
        return next;
      }

      if (next.has(optionId)) {
        next.delete(optionId);
      } else {
        next.add(optionId);
      }
      return next;
    });
  };

  const handleVoteSubmit = async (e: React.MouseEvent) => {
    e.stopPropagation();

    if (selectedOptionIds.size === 0) {
      return;
    }

    if (selectedOptionKey === currentVoteKey) {
      return;
    }

    const ids = Array.from(selectedOptionIds);
    // Extract numeric indices to keep the string short (max 20 chars in backend)
    const numericIds = ids.map(id => id.match(/\d+/)?.[0] || id);

    const bundledEmoji = poll.allowMultiple
      ? `v:${numericIds.join(',')}`
      : `vote:${numericIds[0]}`;

    await Promise.resolve(onVote?.(bundledEmoji));
  };

  const canVote = selectedOptionIds.size > 0 && selectedOptionKey !== currentVoteKey;

  return (
    <div className={`poll-bubble rounded-[14px] border overflow-hidden w-full max-w-[420px] flex flex-col ${isMyMessage ? 'ml-auto' : ''} ${isLightMode ? 'bg-white border-[#dbe4f0] shadow-[0_8px_24px_rgba(15,23,42,0.08)]' : 'bg-[#23262d] border-white/5 shadow-[0_8px_24px_rgba(0,0,0,0.22)]'}`}>
      <div className="p-4 pb-3 space-y-3">
        <div className="space-y-1.5 text-left">
          <h3 className={`text-[17px] font-semibold leading-snug ${isLightMode ? 'text-[#1f2937]' : 'text-[#e5e7eb]'}`}>
            {poll.question}
          </h3>
          <div className={`text-[13px] ${isLightMode ? 'text-[#4b5563]' : 'text-[#e5e7eb]'}`}>
            {poll.allowMultiple ? 'Chọn nhiều phương án' : 'Chọn 1 phương án'}
          </div>
          <button
            type="button"
            onClick={() => {
              openVoterModal()
            }}
            className={`inline-flex items-center gap-1 border-0 bg-transparent px-0 py-0 text-[13px] font-medium shadow-none outline-none transition-colors focus:outline-none focus:ring-0 ${isLightMode ? 'text-[#4f77d6] hover:text-[#315fc0]' : 'text-[#7aa7ff] hover:text-[#9bbcff]'}`}
          >
            <span>{totalVotes} người bình chọn</span>
            <ChevronRight size={13} />
          </button>
        </div>

        <div className="space-y-2.5 mt-1">
          {poll.options.map((opt) => {
            const votesCount = getVotesCountForOption(opt.id);
            const percent = totalVotes > 0 ? (votesCount / totalVotes) * 100 : 0;
            const isLocallySelected = selectedOptionIds.has(opt.id);

            const isActive = isLocallySelected;

            return (
              <div
                key={opt.id}
                onClick={() => handleOptionClick(opt.id)}
                className={`relative h-11 w-full rounded-[6px] overflow-hidden border transition-all cursor-pointer ${isLightMode ? 'bg-[#eef2f7]' : 'bg-[#1f2228]'} ${isActive ? (isLightMode ? 'border-[#a9c4f5]' : 'border-[#33507a]') : (isLightMode ? 'border-[#e3e8f0]' : 'border-transparent')}`}
              >
                <div
                  className={`absolute top-0 left-0 h-full transition-all duration-500 ${isLocallySelected ? (isLightMode ? 'bg-[#dce8ff]' : 'bg-[#36537d]') : (isLightMode ? 'bg-[#e8edf4]' : 'bg-[#1f2228]')}`}
                  style={{ width: isLocallySelected ? `${percent}%` : '0%' }}
                />
                <div className="relative h-full flex items-center justify-between px-3 text-[14px] gap-3">
                  <div className="min-w-0 flex-1">
                    <span className={`block truncate ${isActive ? 'font-medium' : 'font-normal'} ${isLightMode ? 'text-[#1f2937]' : 'text-[#e5e7eb]'}`}>{opt.label}</span>
                  </div>
                  {isActive ? (
                    <div className={`shrink-0 inline-flex h-6 w-6 items-center justify-center rounded-full text-white shadow-sm ${isLightMode ? 'bg-[#3b82f6]' : 'bg-[#3b82f6]'}`}>
                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    </div>
                  ) : null}
                  <button
                    type="button"
                    onClick={(event) => {
                      event.stopPropagation();
                        openVoterModal();
                    }}
                    className={`shrink-0 min-w-[18px] appearance-none border-0 bg-transparent p-0 text-[14px] font-medium shadow-none outline-none focus:outline-none focus:ring-0 ${isLightMode ? 'text-[#1f2937]' : 'text-[#e5e7eb]'}`}
                    aria-label={`Xem danh sách người bình chọn cho ${opt.label}`}
                  >
                    {votesCount}
                  </button>
                </div>
              </div>
            );
          })}
        </div>

      {/* Footer Button */}
      <div className="px-4 pb-4 pt-2">
        <button
          onClick={handleVoteSubmit}
          disabled={!canVote}
          className={`w-full py-2.5 rounded-[6px] text-[14px] font-semibold transition-all tracking-wide flex items-center justify-center gap-2 border ${canVote
              ? isLightMode
                ? 'text-[#2f66d0] border-[#9cb8ee] bg-white hover:bg-[#f7faff] active:scale-[0.99]'
                : 'text-[#a9c7ff] border-[#8fb3ff] bg-transparent hover:bg-white/5 active:scale-[0.99]'
              : hasVoted
                ? isLightMode
                  ? 'text-[#2f66d0] border-[#9cb8ee] bg-white cursor-default'
                  : 'text-[#a9c7ff] border-[#8fb3ff] bg-transparent cursor-default'
                : isLightMode
                  ? 'text-[#8a94a6] border-[#d3dbe7] bg-white cursor-not-allowed opacity-70'
                  : 'text-[#7c8592] border-[#3a3f47] bg-transparent cursor-not-allowed opacity-70'
            }`}
        >
          {hasVoted ? (
            <>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              Đổi bình chọn
            </>
          ) : 'Bình chọn'}
        </button>
      </div>

      </div>

      <Modal
        isOpen={isVoterModalOpen}
        onClose={() => setIsVoterModalOpen(false)}
        title="Chi tiết bình chọn"
        variant="none"
      >
        <div className="bg-[var(--surface)] w-full max-w-none max-h-[70vh] overflow-hidden rounded-b-xl">
          <div className="px-4 pt-4 pb-3 border-b border-[var(--border)]">
            <div className={`text-[15px] font-semibold ${isLightMode ? 'text-[#1f2937]' : 'text-[var(--text)]'}`}>
              {poll.question}
            </div>
            <div className={`mt-1 text-[12px] ${isLightMode ? 'text-[#4b5563]' : 'text-[var(--muted)]'}`}>
              {poll.allowMultiple ? 'Chọn nhiều phương án' : 'Chọn 1 phương án'}
            </div>
          </div>

          <div className="max-h-[calc(70vh-92px)] w-full overflow-y-auto custom-scrollbar px-4 py-4 space-y-6">
            {poll.options.map((option) => {
              const voters = getVotersForOption(option.id)
              const voteCount = voters.length

              return (
                <section key={option.id} className="space-y-3">
                  <div className="flex items-baseline justify-between gap-4">
                    <div className={`text-[15px] font-semibold ${isLightMode ? 'text-[#1f2937]' : 'text-[var(--text)]'}`}>
                      {option.label}
                    </div>
                    <div className={`text-[13px] font-medium ${isLightMode ? 'text-[#4f77d6]' : 'text-[#7aa7ff]'}`}>
                      ({voteCount})
                    </div>
                  </div>

                  {voters.length > 0 ? (
                    <div className="flex flex-wrap gap-x-6 gap-y-4">
                      {voters.map((userId) => {
                        const isMe = userId === currentUser?.id
                        const profile = userMap[userId]
                        const displayName = isMe ? 'Bạn' : (profile?.displayName || 'Người dùng')

                        return (
                          <div key={userId} className="flex min-w-[180px] items-center gap-3">
                            <UserAvatar
                              name={displayName}
                              imageUrl={profile?.avatarUrl ?? null}
                              size="sm"
                            />
                            <div className="min-w-0">
                              <div className={`truncate text-[14px] ${isLightMode ? 'text-[#1f2937]' : 'text-[var(--text)]'}`}>
                                {displayName}
                              </div>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  ) : (
                    <div className={`text-[13px] ${isLightMode ? 'text-[#94a3b8]' : 'text-[var(--muted)]'}`}>
                      Chưa có ai bình chọn phương án này
                    </div>
                  )}
                </section>
              )
            })}
          </div>
        </div>
      </Modal>
    </div>
  );
}
