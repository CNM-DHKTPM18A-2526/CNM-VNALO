import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Camera, Check, ChevronLeft, ChevronRight, Search, X } from 'lucide-react';

import { UserAvatar } from '../../../shared/components/UserAvatar';
import { Modal } from '../../../shared/components/ui/Modal';
import type { Friend } from '../../friends/friends.types';

type CreateGroupModalProps = {
  isOpen: boolean;
  friends: Friend[];
  mode?: 'create' | 'add-members';
  isSubmitting?: boolean;
  onClose: () => void;
  onCreate: (
    groupName: string,
    avatarUrl: string | null,
    selectedMemberIds: string[]
  ) => Promise<void>;
  initialMemberIds?: string[];
  existingMemberIds?: string[];
};

type FilterType = 'all' | 'customer' | 'family' | 'work' | 'friends' | 'later';

interface GroupedFriends {
  [letter: string]: Friend[];
}

// ==================== HELPERS ====================
function getFirstLetter(friend: Friend): string {
  const name = (friend.displayName || friend.nickname || '').trim();
  if (!name) return '#';
  const first = name[0].toUpperCase();
  return /[A-Z]/.test(first) ? first : '#';
}

function groupFriendsAlphabetically(friends: Friend[]): GroupedFriends {
  const grouped: GroupedFriends = {};
  friends.forEach((friend) => {
    const letter = getFirstLetter(friend);
    if (!grouped[letter]) grouped[letter] = [];
    grouped[letter].push(friend);
  });

  Object.keys(grouped).forEach((letter) => {
    grouped[letter].sort((a, b) => {
      const nameA = (a.displayName || a.nickname || '').trim();
      const nameB = (b.displayName || b.nickname || '').trim();
      return nameA.localeCompare(nameB, 'vi');
    });
  });

  return grouped;
}

function resolveFriendLabel(friend: Friend): string {
  return friend.nickname?.trim() || friend.displayName?.trim() || `Người dùng ${friend.friendId?.slice(0, 8)}`;
}

export function CreateGroupModal({
  isOpen,
  friends,
  mode = 'create',
  isSubmitting = false,
  onClose,
  onCreate,
  initialMemberIds = [],
  existingMemberIds = [],
}: CreateGroupModalProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [groupName, setGroupName] = useState('');
  const [searchKeyword, setSearchKeyword] = useState('');
  const [selectedMemberIds, setSelectedMemberIds] = useState<string[]>([]);
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');
  const [avatarPreviewUrl, setAvatarPreviewUrl] = useState<string | null>(null);
  
  const filterScrollRef = useRef<HTMLDivElement>(null);
  const [showLeftArrow, setShowLeftArrow] = useState(false);
  const [showRightArrow, setShowRightArrow] = useState(true);

  // Reset khi mở modal
  useEffect(() => {
    if (!isOpen) return;

    // Use requestAnimationFrame to avoid synchronous setState in effect warning
    requestAnimationFrame(() => {
      setGroupName('');
      setSearchKeyword('');
      setSelectedMemberIds(initialMemberIds);
      setActiveFilter('all');
      setAvatarPreviewUrl(null);
    });
  }, [isOpen, initialMemberIds]);

  const filterTabs: Array<{ id: FilterType; label: string }> = [
    { id: 'all', label: 'Tất cả' },
    { id: 'customer', label: 'Khách hàng' },
    { id: 'family', label: 'Gia đình' },
    { id: 'work', label: 'Công việc' },
    { id: 'friends', label: 'Bạn bè' },
    { id: 'later', label: 'Trả lời sau' },
  ];

  const filteredFriends = useMemo(() => {
    const keyword = searchKeyword.trim().toLowerCase();
    if (!keyword) return friends;
    return friends.filter((friend) => {
      const label = resolveFriendLabel(friend).toLowerCase();
      const searchable = `${label} ${friend.friendId || ''} ${friend.statusMessage || ''}`.toLowerCase();
      return searchable.includes(keyword);
    });
  }, [friends, searchKeyword]);

  const groupedFriends = useMemo(() => groupFriendsAlphabetically(filteredFriends), [filteredFriends]);
  const sortedGroupKeys = useMemo(() => Object.keys(groupedFriends).sort((a, b) => (a === '#' ? 1 : a.localeCompare(b))), [groupedFriends]);

  const selectedMembers = useMemo(() => friends.filter((f) => selectedMemberIds.includes(f.friendId)), [friends, selectedMemberIds]);

  const newSelectedMemberIds = useMemo(() => 
    selectedMemberIds.filter(id => !existingMemberIds.includes(id)), 
  [selectedMemberIds, existingMemberIds]);

  const isValid = mode === 'create' 
    ? (selectedMemberIds.length >= 2) 
    : newSelectedMemberIds.length >= 1;

  const canSubmit = isValid && !isSubmitting;

  const toggleMemberSelection = useCallback((friendId: string) => {
    if (existingMemberIds.includes(friendId)) return;
    setSelectedMemberIds((prev) =>
      prev.includes(friendId) ? prev.filter((id) => id !== friendId) : [...prev, friendId]
    );
  }, [existingMemberIds]);

  const handleRemoveMember = (id: string) => {
    if (existingMemberIds.includes(id)) return;
    setSelectedMemberIds((prev) => prev.filter((mid) => mid !== id));
  };

  const handleAvatarClick = () => fileInputRef.current?.click();

  const handleAvatarFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    setAvatarPreviewUrl(URL.createObjectURL(file));
  };

  const handleScroll = () => {
    if (filterScrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = filterScrollRef.current;
      setShowLeftArrow(scrollLeft > 0);
      setShowRightArrow(scrollLeft < scrollWidth - clientWidth - 5);
    }
  };

  const scrollFilters = (direction: 'left' | 'right') => {
    if (filterScrollRef.current) {
      const scrollAmount = 200;
      filterScrollRef.current.scrollBy({
        left: direction === 'left' ? -scrollAmount : scrollAmount,
        behavior: 'smooth'
      });
    }
  };

  const handleSubmit = async () => {
    if (!canSubmit) return;
    // For 'add-members', only send the NEWLY selected people to the API
    const idsToSubmit = mode === 'create' ? selectedMemberIds : newSelectedMemberIds;
    
    let finalName = groupName.trim();
    if (mode === 'create' && !finalName) {
      // Generate automatic name from selected members' names
      const names = selectedMembers.map(m => resolveFriendLabel(m));
      finalName = names.join(', ');
      // Truncate if too long for Zalo-like aesthetic
      if (finalName.length > 50) {
        finalName = finalName.substring(0, 47) + '...';
      }
    }

    await onCreate(finalName, avatarPreviewUrl, idsToSubmit);
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={mode === 'create' ? "Tạo nhóm" : "Thêm thành viên"}>
      <div className="flex flex-col h-[600px] max-h-[90vh] -m-5 bg-[var(--surface)] overflow-hidden shadow-xl rounded-xl">

        {/* Top section: Avatar + Tên nhóm */}
        {mode === 'create' && (
          <div className="flex items-center gap-4 px-6 pt-5 pb-4 shrink-0 bg-[var(--surface)]">
            <div className="relative group shrink-0" onClick={handleAvatarClick}>
              <div className="w-12 h-12 rounded-full border border-[var(--border)] bg-[var(--bg)] flex items-center justify-center cursor-pointer transition-all hover:bg-[var(--surface-hover)] overflow-hidden">
                {avatarPreviewUrl ? (
                  <img src={avatarPreviewUrl} alt="Group" className="w-full h-full object-cover" />
                ) : (
                  <div className="text-gray-500">
                    <Camera size={22} strokeWidth={1.5} />
                  </div>
                )}
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleAvatarFileChange}
                className="hidden"
              />
            </div>

            <div className="flex-1 border-b border-blue-500 pb-1.5 focus-within:border-blue-600 transition-colors">
              <input
                type="text"
                className="w-full text-base font-normal outline-none bg-transparent text-[var(--text)] placeholder-[var(--muted)] placeholder:opacity-50"
                placeholder="Nhập tên nhóm..."
                value={groupName}
                onChange={(e) => setGroupName(e.target.value)}
                maxLength={100}
                disabled={isSubmitting}
              />
            </div>
          </div>
        )}

        {/* Search bar */}
        <div className="px-6 py-3 shrink-0">
          <div className="flex items-center bg-[var(--bg)] rounded-full px-4 py-2 border border-transparent focus-within:border-blue-400 focus-within:bg-[var(--surface)] transition-all text-[var(--text)]">
            <Search size={18} className="text-[var(--muted)] shrink-0" />
            <input
              type="text"
              className="w-full bg-transparent border-none text-[15px] outline-none px-3 text-[var(--text)] placeholder-[var(--muted)] placeholder:opacity-50"
              placeholder="Nhập tên, số điện thoại..."
              value={searchKeyword}
              onChange={(e) => setSearchKeyword(e.target.value)}
              disabled={isSubmitting}
            />
          </div>
        </div>

        {/* Filters */}
        <div className="relative group/filters px-2 shrink-0 border-b border-[var(--border)] pb-1">
          {showLeftArrow && (
            <button 
              onClick={() => scrollFilters('left')}
              className="absolute left-1 top-1/2 -translate-y-1/2 z-10 w-7 h-7 flex items-center justify-center rounded-full bg-[var(--surface)] shadow-md border border-[var(--border)] text-[var(--muted)] hover:text-blue-600 transition-all cursor-pointer"
            >
              <ChevronLeft size={18} strokeWidth={2.5} />
            </button>
          )}

          <div 
            ref={filterScrollRef}
            onScroll={handleScroll}
            className="flex gap-2 px-4 py-3 overflow-x-auto scrollbar-hide scroll-smooth"
          >
            {filterTabs.map((tab) => (
              <button
                key={tab.id}
                className={`px-4 py-1.5 text-[13px] rounded-full whitespace-nowrap transition-all border-none cursor-pointer font-medium shrink-0 ${activeFilter === tab.id
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'bg-[var(--bg)] text-[var(--muted)] hover:bg-[var(--surface-hover)]'
                  }`}
                onClick={() => setActiveFilter(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {showRightArrow && (
            <button 
              onClick={() => scrollFilters('right')}
              className="absolute right-1 top-1/2 -translate-y-1/2 z-10 w-7 h-7 flex items-center justify-center rounded-full bg-[var(--surface)] shadow-md border border-[var(--border)] text-[var(--muted)] hover:text-blue-600 transition-all cursor-pointer"
            >
              <ChevronRight size={18} strokeWidth={2.5} />
            </button>
          )}
        </div>

        {/* Selected members list (horizontal chips) */}
        {selectedMembers.length > 0 && (
          <div className="flex gap-4 overflow-x-auto px-6 pb-3 min-h-[60px] items-center shrink-0 border-b border-[var(--border)] scrollbar-hide">
            {selectedMembers.map((member) => {
              const isLocked = existingMemberIds.includes(member.friendId);
              return (
                <div key={member.friendId} className="relative shrink-0 group">
                  <UserAvatar name={resolveFriendLabel(member)} imageUrl={member.avatarUrl} size="md" />
                  {!isLocked && (
                    <button
                      type="button"
                      className="absolute -top-1 -right-1 bg-[var(--surface)] rounded-full p-0.5 shadow-md text-[var(--muted)] hover:text-red-500 border border-[var(--border)] z-10 transition-transform hover:scale-110"
                      onClick={() => handleRemoveMember(member.friendId)}
                    >
                      <X size={12} />
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {/* Contact list with alphabetic sections */}
        <div className="flex-1 overflow-y-auto pt-1 bg-[var(--surface)] scrollbar-thin scrollbar-thumb-[var(--border)]">
          {/* Recent chats */}
          {searchKeyword === '' && filteredFriends.length > 0 && (
            <div className="mb-4">
              <div className="sticky top-0 bg-[var(--surface)]/95 backdrop-blur z-10 px-6 py-2 text-[14px] font-bold text-[var(--text)]">Trò chuyện gần đây</div>
              <div className="mt-1">
                {filteredFriends.slice(0, 5).map((friend) => (
                  <ContactRow 
                    key={`recent-${friend.friendId}`}
                    friend={friend}
                    isSelected={selectedMemberIds.includes(friend.friendId)}
                    isLocked={existingMemberIds.includes(friend.friendId)}
                    onToggle={() => toggleMemberSelection(friend.friendId)}
                  />
                ))}
              </div>
            </div>
          )}

          {/* Alphabet sections */}
          {sortedGroupKeys.map((letter) => (
            <div key={letter} className="mb-4">
              <div className="sticky top-0 bg-[var(--surface)]/95 backdrop-blur z-10 px-6 py-2 text-[14px] font-bold text-[var(--text)]">{letter}</div>
              <div className="mt-1">
                {groupedFriends[letter].map((friend) => (
                  <ContactRow 
                    key={friend.friendId}
                    friend={friend}
                    isSelected={selectedMemberIds.includes(friend.friendId)}
                    isLocked={existingMemberIds.includes(friend.friendId)}
                    onToggle={() => toggleMemberSelection(friend.friendId)}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-3 px-6 py-4 border-t border-[var(--border)] bg-[var(--surface)] shrink-0">
          <button
            className="px-8 py-2 rounded-lg font-medium text-[15px] text-[var(--text)] bg-[var(--bg)] hover:bg-[var(--surface-hover)] transition-colors border-none cursor-pointer"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Hủy
          </button>
          <button
            className={`px-8 py-2 rounded-lg font-medium text-[15px] transition-all border-none ${canSubmit
              ? 'bg-blue-600 text-white hover:bg-blue-700 shadow-md cursor-pointer'
              : 'bg-blue-200 text-white cursor-not-allowed'
              }`}
            onClick={handleSubmit}
            disabled={!canSubmit}
          >
            {isSubmitting ? (mode === 'create' ? 'Đang tạo...' : 'Đang thêm...') : (mode === 'create' ? 'Tạo nhóm' : 'Xác nhận')}
          </button>
        </div>

      </div>
    </Modal>
  );
}

// Sub-component for individual contact rows to keep main component clean
function ContactRow({ friend, isSelected, isLocked, onToggle }: { 
  friend: Friend, 
  isSelected: boolean, 
  isLocked: boolean, 
  onToggle: () => void 
}) {
  const name = resolveFriendLabel(friend);
  
  return (
    <div
      className={`flex items-center gap-4 px-6 py-2.5 transition-colors ${isLocked ? 'cursor-not-allowed opacity-60' : 'cursor-pointer hover:bg-[var(--surface-hover)]'} ${isSelected ? 'bg-blue-500/10' : ''}`}
      onClick={() => !isLocked && onToggle()}
    >
      <div className={`w-6 h-6 flex-shrink-0 rounded-full border-2 flex items-center justify-center transition-all ${
        isSelected 
          ? (isLocked ? 'bg-[var(--muted)] border-[var(--muted)]' : 'bg-blue-600 border-blue-600') 
          : 'border-[var(--border)] bg-[var(--surface)]'
      }`}>
        {isSelected && <Check size={14} strokeWidth={3.5} className="text-white" />}
      </div>
      <UserAvatar name={name} imageUrl={friend.avatarUrl} size="md" />
      <div className="flex-1 min-w-0">
        <div className="text-[15px] font-medium text-[var(--text)] truncate">{name}</div>
        {friend.statusMessage && (
          <div className="text-[13px] text-[var(--muted)] truncate mt-0.5">{friend.statusMessage}</div>
        )}
      </div>
      {isLocked && <span className="text-[12px] text-[var(--muted)] font-medium">Đã vào nhóm</span>}
    </div>
  );
}