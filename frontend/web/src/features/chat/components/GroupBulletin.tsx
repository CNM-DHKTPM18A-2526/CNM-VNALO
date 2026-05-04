import React from 'react';
import { ArrowLeft, Plus, MessageCircle, Link, AlarmClock, FileText, ChevronRight } from 'lucide-react';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useUserStore } from '../context/UserStoreContext';
import { fetchPinnedMessages, type RawPinnedMessage, type ChatMessage } from '../chat.api';
import { CreatePollModal } from './CreatePollModal';
import type { PollMetadata } from '../chat.types';

type TabType = 'all' | 'pin' | 'note' | 'poll';

interface GroupBulletinProps {
  conversationId: string;
  token: string;
  messages: ChatMessage[]; // Pass current messages to resolve content for pins
  onClose: () => void;
  onJumpToMessage: (messageId: string) => void;
  onSendPoll?: (poll: PollMetadata) => void;
  currentUserId?: string;
  reactionStates?: Record<string, any>;
}

export function GroupBulletin({ conversationId, token, messages, onClose, onJumpToMessage, onSendPoll, currentUserId, reactionStates }: GroupBulletinProps) {
  const { userMap } = useUserStore();
  const [activeTab, setActiveTab] = React.useState<TabType>('all');
  const [pinnedItems, setPinnedItems] = React.useState<RawPinnedMessage[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [showCreatePoll, setShowCreatePoll] = React.useState(false);

  React.useEffect(() => {
    const loadPinned = async () => {
      try {
        const data = await fetchPinnedMessages(token, conversationId);
        setPinnedItems(Array.isArray(data) ? data : []);
      } catch (error) {
        console.error('Failed to fetch pinned messages:', error);
      } finally {
        setIsLoading(false);
      }
    };
    loadPinned();
  }, [conversationId, token, messages.length]); // Refetch when messages change (realtime)

  const formatRelativeDate = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    
    const yesterday = new Date();
    yesterday.setDate(now.getDate() - 1);
    const isYesterday = date.toDateString() === yesterday.toDateString();

    const timeStr = date.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
    
    if (isToday) return `Hôm nay lúc ${timeStr}`;
    if (isYesterday) return `Hôm qua lúc ${timeStr}`;
    
    return date.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' }) + ` lúc ${timeStr}`;
  };

  const tabs: { id: TabType; label: string }[] = [
    { id: 'all', label: 'Tất cả' },
    { id: 'pin', label: 'Tin ghim' },
    { id: 'note', label: 'Ghi chú' },
    { id: 'poll', label: 'Bình chọn' },
  ];

  // Helper to find message content from the main message list
  const getPinnedMessageContent = (msgId: string) => {
    return messages.find(m => m.id === msgId);
  };

  const renderContent = () => {
    if (isLoading && pinnedItems.length === 0) return <div className="p-10 text-center text-slate-400 font-medium">Đang tải bảng tin...</div>;

    let itemsToRender: any[] = [];

    if (activeTab === 'all' || activeTab === 'pin') {
      const pins = pinnedItems.map(pin => {
        const msg = getPinnedMessageContent(pin.messageId);
        return {
          type: 'pin',
          id: pin.id,
          messageId: pin.messageId,
          senderId: msg?.senderId || pin.pinnedBy || '',
          content: msg?.text || (msg?.type === 'file' ? 'Tệp tin' : msg?.type === 'image' ? 'Hình ảnh' : 'Hội thoại'),
          createdAt: pin.pinnedAt || msg?.createdAt,
        };
      });
      itemsToRender = [...itemsToRender, ...pins];
    }

    if (activeTab === 'all' || activeTab === 'poll') {
      const realPolls = messages
        .filter(m => m.type === 'poll' && m.pollData)
        .map(m => {
          const pData = m.pollData!;
          const messageReactions = reactionStates?.[m.id]?.reactions;

          const getVotesCountForOption = (optionId: string, optVotes: string[]) => {
            if (!messageReactions) return optVotes.length;
            
            let count = 0;
            const optionMatch = optionId.match(/\d+/);
            const optionNum = optionMatch ? optionMatch[0] : optionId;
            
            Object.entries(messageReactions).forEach(([key, reaction]: [string, any]) => {
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

          const isUserVotedOption = (optionId: string, optVotes: string[]) => {
            if (!messageReactions) return currentUserId ? optVotes.includes(currentUserId) : false;
            
            const optionMatch = optionId.match(/\d+/);
            const optionNum = optionMatch ? optionMatch[0] : optionId;
            let isVoted = false;
            
            Object.entries(messageReactions).forEach(([key, reaction]: [string, any]) => {
              if (reaction.userIds?.includes(currentUserId) || reaction.myCount > 0) {
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

          let computedOptions = pData.options.map((opt: any) => {
             const votesCount = getVotesCountForOption(opt.id, opt.votes || []);
             const selected = isUserVotedOption(opt.id, opt.votes || []);
             return {
               id: opt.id,
               label: opt.label || opt.text || 'Lựa chọn',
               votes: votesCount,
               selected
             }
          });

          const totalVotes = computedOptions.reduce((acc: number, cur: any) => acc + cur.votes, 0);

          return {
            type: 'poll',
            id: m.id,
            title: pData.question || 'Bình chọn',
            description: pData.allowMultiple ? 'Chọn nhiều phương án' : 'Chọn một phương án',
            voterCount: totalVotes,
            options: computedOptions.map((opt: any) => ({
               ...opt,
               percent: totalVotes > 0 ? Math.round((opt.votes / totalVotes) * 100) : 0
            })),
            createdAt: m.createdAt,
            senderId: m.senderId
          };
        });
      itemsToRender = [...itemsToRender, ...realPolls];
    }

    if (activeTab === 'all' || activeTab === 'note') {
      // Notes are considered any text message that is pinned, or any mock notes if we want to fallback
      // Since backend doesn't have a "note" type, we can filter pinned messages that are just text.
      // But actually, we don't need mock notes anymore. If empty, it'll just show "Chưa có bảng tin".
      // Let's just leave it empty for now, or you can implement if a custom type exists.
    }

    // Sort items by date descending
    itemsToRender.sort((a, b) => {
      const dateA = new Date(a.createdAt || 0).getTime();
      const dateB = new Date(b.createdAt || 0).getTime();
      return dateB - dateA;
    });

    if (itemsToRender.length === 0) {
      return (
        <div className="flex flex-col items-center justify-center p-20 text-slate-400 opacity-60">
          <FileText size={48} strokeWidth={1} />
          <p className="mt-4 text-sm">Chưa có bảng tin nào</p>
        </div>
      );
    }

    return (
      <div className="p-4 space-y-4">
        {itemsToRender.map((item) => (
          <div key={item.id} className="bg-[var(--surface)] rounded-xl border border-[var(--border)] shadow-sm overflow-hidden p-3 transition-transform active:scale-[0.98]">
            {(item.type === 'pin' || item.type === 'note') ? (
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <UserAvatar 
                    name={userMap[item.senderId]?.displayName || 'Người dùng'} 
                    imageUrl={userMap[item.senderId]?.avatarUrl} 
                    size="sm" 
                  />
                  <div className="flex flex-col">
                    <span className="text-[14px] font-bold text-[var(--text)]">{userMap[item.senderId]?.displayName || 'Người dùng'}</span>
                    <div className="flex items-center gap-1 text-[12px] text-[var(--muted)]">
                      {item.type === 'pin' ? (
                        <>
                          <MessageCircle size={12} className="text-blue-500" />
                          <span>Tin ghim</span>
                        </>
                      ) : (
                        <>
                          <FileText size={12} className="text-orange-500" />
                          <span>Ghi chú</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                <div className="text-[14px] text-[var(--text)] opacity-90">
                  <p className="mt-1 line-clamp-3">
                    {item.content.startsWith('http') ? (
                      <span className="flex items-center gap-1 text-blue-500 break-all cursor-pointer hover:underline">
                        <Link size={14} />
                        {item.content}
                      </span>
                    ) : item.content}
                  </p>
                </div>

                <div className="flex items-center gap-2 mt-2 text-[12px]">
                  <span className="text-[var(--muted)] opacity-70">
                    {formatRelativeDate(item.createdAt)}
                  </span>
                  {item.type === 'pin' && (
                    <>
                      <span className="text-[var(--border)]">|</span>
                      <button 
                        onClick={() => onJumpToMessage(item.messageId)}
                        className="font-bold text-blue-600 hover:underline bg-transparent border-none cursor-pointer p-0"
                      >
                        Xem tin nhắn gốc
                      </button>
                    </>
                  )}
                </div>
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex flex-col">
                  <h3 className="text-[15px] font-bold text-[var(--text)]">{item.title}</h3>
                  <p className="text-[13px] text-[var(--muted)]">{item.description}</p>
                </div>
                
                <div 
                  className="flex items-center gap-1 text-[13px] text-blue-600 font-medium cursor-pointer"
                  onClick={() => {}}
                >
                  {item.voterCount} người bình chọn <ChevronRight size={14} />
                </div>

                <div className="space-y-2 mt-2">
                  {item.options.map((opt: any, idx: number) => (
                    <div key={idx} className="relative h-9 w-full bg-[var(--bg)] rounded-lg overflow-hidden border border-[var(--border)]">
                      <div 
                        className="absolute top-0 left-0 h-full bg-blue-100 dark:bg-blue-900/30 transition-all duration-500" 
                        style={{ width: `${opt.percent}%` }}
                      />
                      <div className="relative h-full flex items-center justify-between px-3 text-[14px]">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-[var(--text)]">{opt.label}</span>
                          {opt.selected && <div className="h-4 w-4 bg-blue-500 rounded-full flex items-center justify-center"><span className="text-[10px] text-white">✓</span></div>}
                        </div>
                        <span className="text-[var(--muted)]">{opt.votes}</span>
                      </div>
                    </div>
                  ))}
                </div>

                <button 
                  className="w-full py-2 text-[14px] font-semibold text-[#005ae0] bg-[#e5efff] dark:bg-blue-900/20 rounded-md hover:bg-[#d0e3ff] dark:hover:bg-blue-900/30 transition-colors"
                  onClick={() => onJumpToMessage(item.id)}
                >
                  Xem chi tiết bình chọn
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="flex flex-col h-full bg-[var(--bg)]">
      {/* Tabs */}
      <nav className="flex bg-[var(--surface)] shrink-0 sticky top-0 z-20">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex-1 py-3 text-[14px] font-medium transition-all relative border-none bg-transparent cursor-pointer ${
              activeTab === tab.id ? 'text-blue-600' : 'text-[var(--muted)] hover:text-[var(--text)]'
            }`}
          >
            {tab.label}
            {activeTab === tab.id && (
              <div className="absolute bottom-0 left-0 w-full h-[2px] bg-blue-600" />
            )}
          </button>
        ))}
      </nav>
      <div className="h-[1px] bg-[var(--border)]" /> {/* Subtle divider under tabs */}

      {/* Content Area */}
      <main className="flex-1 overflow-y-auto custom-scrollbar">
        {renderContent()}
        <div className="p-4 pt-2 space-y-2 mb-6 text-[var(--text)]">
          <button className="w-full h-11 bg-[#e5efff] dark:bg-blue-900/20 text-[#005ae0] dark:text-sky-400 font-semibold rounded-md hover:bg-[#d0e3ff] dark:hover:bg-blue-900/30 transition-colors text-[14px] border-none cursor-pointer">
            Tạo ghi chú
          </button>
          <button 
            onClick={() => setShowCreatePoll(true)}
            className="w-full h-11 bg-[#e5efff] dark:bg-blue-900/20 text-[#005ae0] dark:text-sky-400 font-semibold rounded-md hover:bg-[#d0e3ff] dark:hover:bg-blue-900/30 transition-colors text-[14px] border-none cursor-pointer"
          >
            Tạo bình chọn
          </button>
        </div>
      </main>

      {showCreatePoll && (
        <CreatePollModal 
          onClose={() => setShowCreatePoll(false)}
          onCreate={(poll) => {
            onSendPoll?.(poll);
            setShowCreatePoll(false);
          }}
        />
      )}
    </div>
  );
}
