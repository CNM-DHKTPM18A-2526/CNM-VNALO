import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Camera, Check, Search, Users, X } from 'lucide-react';


import { UserAvatar } from '../../../shared/components/UserAvatar';
import { Button } from '../../../shared/components/ui/Button';
import { Modal } from '../../../shared/components/ui/Modal';
import type { Friend } from '../../friends/friends.types';

type CreateGroupModalProps = {
  isOpen: boolean;
  friends: Friend[];
  isSubmitting?: boolean;
  onClose: () => void;
  onCreate: (
    groupName: string,
    avatarUrl: string | null,
    selectedMemberIds: string[]
  ) => Promise<void>;
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
  isSubmitting = false,
  onClose,
  onCreate,
}: CreateGroupModalProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [groupName, setGroupName] = useState('');
  const [searchKeyword, setSearchKeyword] = useState('');
  const [selectedMemberIds, setSelectedMemberIds] = useState<string[]>([]);
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');
  const [avatarPreviewUrl, setAvatarPreviewUrl] = useState<string | null>(null);

  // Reset khi mở modal
  useEffect(() => {
    if (!isOpen) return;
    setGroupName('');
    setSearchKeyword('');
    setSelectedMemberIds([]);
    setActiveFilter('all');
    setAvatarPreviewUrl(null);
  }, [isOpen]);

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

  const isValid = groupName.trim().length > 0 && selectedMemberIds.length >= 1;
  const canSubmit = isValid && !isSubmitting;

  const toggleMemberSelection = useCallback((friendId: string) => {
    setSelectedMemberIds((prev) =>
      prev.includes(friendId) ? prev.filter((id) => id !== friendId) : [...prev, friendId]
    );
  }, []);

  const handleRemoveMember = (id: string) => {
    setSelectedMemberIds((prev) => prev.filter((mid) => mid !== id));
  };

  const handleAvatarClick = () => fileInputRef.current?.click();

  const handleAvatarFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    setAvatarPreviewUrl(URL.createObjectURL(file));
  };

  const handleSubmit = async () => {
    if (!canSubmit) return;
    await onCreate(groupName.trim(), avatarPreviewUrl, selectedMemberIds);
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Tạo nhóm">
      <div className="flex flex-col h-[600px] max-h-[85vh] -m-5 bg-white overflow-hidden">

        {/* Top section: Avatar + Tên nhóm */}
        <div className="flex items-center gap-4 px-5 pt-4 pb-3 border-b border-gray-200 shrink-0">
          <div className="relative cursor-pointer group shrink-0" onClick={handleAvatarClick}>
            <div className="w-[50px] h-[50px] rounded-full overflow-hidden border border-gray-200 bg-white flex items-center justify-center transition-colors group-hover:bg-gray-50">
              {avatarPreviewUrl ? (
                <img src={avatarPreviewUrl} alt="Group" className="w-full h-full object-cover" />
              ) : (
                <Camera size={20} strokeWidth={2} className="text-[#596677]" />
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

          <input
            type="text"
            className="flex-1 text-[15px] font-medium border-b border-[#0068ff] outline-none py-1.5 transition-colors placeholder-[#8b9bb4] bg-transparent text-gray-900"
            placeholder="Nhập tên nhóm..."
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
            maxLength={100}
            disabled={isSubmitting}
          />
        </div>

        {/* Search bar */}
        <div className="px-5 pt-4 pb-3 shrink-0">
          <div className="flex items-center bg-white rounded-full px-3 py-1.5 border border-gray-300 focus-within:border-[#0068ff] transition-all cursor-text text-gray-700">
            <Search size={16} strokeWidth={2.5} className="text-gray-400 shrink-0 ml-1" />
            <input
              type="text"
              className="w-full bg-transparent border-none text-[15px] outline-none px-3 placeholder-[#627083]"
              placeholder="Nhập tên, số điện thoại, hoặc danh sách số điện thoại"
              value={searchKeyword}
              onChange={(e) => setSearchKeyword(e.target.value)}
              disabled={isSubmitting}
            />
          </div>
        </div>

        {/* Tabs/filters */}
        <div className="flex gap-2.5 overflow-x-auto px-5 pb-3 items-center shrink-0 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
          {filterTabs.map((tab) => (
            <button
              key={tab.id}
              className={`px-3 py-1 text-[13.5px] rounded-full whitespace-nowrap transition-colors outline-none cursor-pointer border-transparent ${activeFilter === tab.id
                ? 'bg-[#0068ff] text-white font-medium'
                : 'bg-[#e5e7eb] text-[#081c36] hover:bg-gray-300 font-normal'
                }`}
              onClick={() => setActiveFilter(tab.id)}
            >
              {tab.label}
            </button>
          ))}
          <div className="sticky right-0 flex items-center justify-center pl-2 bg-white/90 backdrop-blur-sm -ml-2">
            <div className="w-7 h-7 flex items-center justify-center rounded-full border border-gray-200 text-gray-500 bg-white shadow-sm cursor-pointer hover:bg-gray-50">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="m9 18 6-6-6-6" /></svg>
            </div>
          </div>
        </div>

        {/* Selected members */}
        {selectedMembers.length > 0 && (
          <div className="flex gap-3 overflow-x-auto px-5 pb-2 border-b border-gray-100 min-h-[56px] items-center shrink-0 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
            {selectedMembers.map((member) => (
              <div key={member.friendId} className="relative shrink-0 w-[42px] h-[42px] group">
                <UserAvatar name={resolveFriendLabel(member)} imageUrl={member.avatarUrl} size="md" />
                <button
                  type="button"
                  className="absolute -top-1 -right-1 bg-white rounded-full p-[2px] shadow-sm text-gray-400 group-hover:text-red-500 z-10 border border-gray-200 transition-colors cursor-pointer"
                  onClick={() => handleRemoveMember(member.friendId)}
                >
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Contact list */}
        <div className="flex-1 overflow-y-auto scroll-smooth border-t border-gray-200 relative pt-1">
          {searchKeyword === '' && filteredFriends.length > 0 && (
            <div className="mb-2 pt-2">
              <div className="sticky top-0 bg-white/95 backdrop-blur z-10 px-5 py-2 text-[15px] font-bold text-[#081c36]">Trò chuyện gần đây</div>
              <div className="space-y-0.5 mt-1">
                {filteredFriends.slice(0, 4).map((friend) => {
                  const isSelected = selectedMemberIds.includes(friend.friendId);
                  return (
                    <div
                      key={`recent-${friend.friendId}`}
                      className={`flex items-center gap-4 px-5 py-2.5 cursor-pointer transition-colors ${isSelected ? 'bg-blue-50/50' : 'hover:bg-gray-50'}`}
                      onClick={() => toggleMemberSelection(friend.friendId)}
                    >
                      <div className={`w-[22px] h-[22px] flex-shrink-0 rounded-full border-[1.5px] flex items-center justify-center transition-colors ${isSelected ? 'bg-[#0068ff] border-[#0068ff]' : 'border-[#d6dbe1] bg-white'}`}>
                        {isSelected && <Check size={14} strokeWidth={3} className="text-white" />}
                      </div>
                      <UserAvatar name={resolveFriendLabel(friend)} imageUrl={friend.avatarUrl} size="md" />
                      <div className="flex-1 min-w-0">
                        <div className="text-[15px] font-normal text-black truncate">{resolveFriendLabel(friend)}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Alphabet List */}
          <div className="pb-4">
            {sortedGroupKeys.map((letter) => (
              <div key={letter} className="relative">
                <div className="sticky top-0 bg-white/95 backdrop-blur z-10 px-5 py-2 text-[15px] font-bold text-[#081c36]">{letter}</div>
                <div className="space-y-0.5 pt-1">
                  {groupedFriends[letter].map((friend) => {
                    const isSelected = selectedMemberIds.includes(friend.friendId);
                    return (
                      <div
                        key={friend.friendId}
                        className={`flex items-center gap-4 px-5 py-2.5 cursor-pointer transition-colors ${isSelected ? 'bg-blue-50/50' : 'hover:bg-gray-50'}`}
                        onClick={() => toggleMemberSelection(friend.friendId)}
                      >
                        <div className={`w-[22px] h-[22px] flex-shrink-0 rounded-full border-[1.5px] flex items-center justify-center transition-colors ${isSelected ? 'bg-[#0068ff] border-[#0068ff]' : 'border-[#d6dbe1] bg-white'}`}>
                          {isSelected && <Check size={14} strokeWidth={3} className="text-white" />}
                        </div>
                        <UserAvatar name={resolveFriendLabel(friend)} imageUrl={friend.avatarUrl} size="md" />
                        <div className="flex-1 min-w-0">
                          <div className="text-[15px] font-normal text-black truncate">{resolveFriendLabel(friend)}</div>
                          {friend.statusMessage && <div className="text-[13px] text-[#596677] truncate">{friend.statusMessage}</div>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-3 px-5 py-4 border-t border-gray-200 bg-white shrink-0">
          <button
            className="px-6 py-2.5 rounded font-semibold text-[15px] text-[#081c36] bg-[#e9ebed] hover:bg-gray-300 transition-colors duration-200 cursor-pointer"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Hủy
          </button>
          <button
            className={`px-6 py-2.5 rounded font-semibold text-[15px] transition-all duration-200 ${canSubmit
              ? 'bg-[#0068ff] text-white hover:bg-blue-600 shadow-sm cursor-pointer'
              : 'bg-[#abc9ff] text-white cursor-not-allowed'
              }`}
            onClick={handleSubmit}
            disabled={!canSubmit}
          >
            {isSubmitting ? 'Đang tạo...' : 'Tạo nhóm'}
          </button>
        </div>

      </div>
    </Modal>
  );

}