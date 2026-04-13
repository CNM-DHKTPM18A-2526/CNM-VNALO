import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Users, X } from 'lucide-react';

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

  const isValid = groupName.trim().length > 0 && selectedMemberIds.length >= 2;
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
    <Modal isOpen={isOpen} onClose={onClose} title="Tạo nhóm" size="lg">
      <div className="create-group-modal p-5">
        {/* Avatar + Tên nhóm */}
        <div className="flex gap-4 mb-6">
          <div className="relative">
            <div className="w-20 h-20 rounded-full overflow-hidden border-2 border-gray-200">
              {avatarPreviewUrl ? (
                <img src={avatarPreviewUrl} alt="Group" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full bg-gray-100 flex items-center justify-center text-4xl">👥</div>
              )}
            </div>
            <button
              type="button"
              className="absolute bottom-0 right-0 w-7 h-7 bg-[#007AFF] rounded-full flex items-center justify-center border-2 border-white shadow"
              onClick={handleAvatarClick}
            >
              <Users size={16} className="text-white" />
            </button>
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
            className="flex-1 text-lg font-medium border-b border-gray-300 focus:border-[#007AFF] outline-none py-2"
            placeholder="Nhập tên nhóm..."
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
            maxLength={100}
            disabled={isSubmitting}
          />
        </div>

        {/* Selected Members Chips */}
        {selectedMembers.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            {selectedMembers.map((member) => (
              <div key={member.friendId} className="flex items-center bg-blue-50 text-blue-700 rounded-full pl-1 pr-3 py-1 text-sm">
                <UserAvatar name={resolveFriendLabel(member)} imageUrl={member.avatarUrl} size="sm" />
                <span className="ml-2">{resolveFriendLabel(member)}</span>
                <button
                  type="button"
                  className="ml-2 text-blue-400 hover:text-red-500"
                  onClick={() => handleRemoveMember(member.friendId)}
                >
                  <X size={16} />
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Search */}
        <input
          type="text"
          className="w-full px-4 py-3 bg-gray-100 rounded-2xl text-sm mb-4"
          placeholder="Nhập tên, số điện thoại, hoặc danh sách số điện thoại"
          value={searchKeyword}
          onChange={(e) => setSearchKeyword(e.target.value)}
          disabled={isSubmitting}
        />

        {/* Filter Tabs */}
        <div className="flex gap-1 overflow-x-auto pb-3 mb-4 border-b">
          {filterTabs.map((tab) => (
            <button
              key={tab.id}
              className={`px-4 py-1.5 text-sm font-medium rounded-full whitespace-nowrap transition ${
                activeFilter === tab.id
                  ? 'bg-[#007AFF] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
              onClick={() => setActiveFilter(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Recent Chats */}
        <div className="mb-6">
          <h3 className="text-sm font-semibold text-gray-500 mb-3">Trò chuyện gần đây</h3>
          <div className="space-y-1">
            {filteredFriends.slice(0, 6).map((friend) => {
              const isSelected = selectedMemberIds.includes(friend.friendId);
              return (
                <div
                  key={friend.friendId}
                  className="flex items-center gap-3 px-3 py-2 hover:bg-gray-50 rounded-xl cursor-pointer"
                  onClick={() => toggleMemberSelection(friend.friendId)}
                >
                  <input type="checkbox" checked={isSelected} readOnly className="w-5 h-5 accent-[#007AFF]" />
                  <UserAvatar name={resolveFriendLabel(friend)} imageUrl={friend.avatarUrl} size="md" />
                  <div>
                    <div className="font-medium">{resolveFriendLabel(friend)}</div>
                    {friend.statusMessage && <div className="text-xs text-gray-500">{friend.statusMessage}</div>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* A-Z List */}
        <div className="space-y-6">
          {sortedGroupKeys.map((letter) => (
            <div key={letter}>
              <div className="text-xs font-bold text-gray-400 mb-2 px-1">{letter}</div>
              <div className="space-y-1">
                {groupedFriends[letter].map((friend) => {
                  const isSelected = selectedMemberIds.includes(friend.friendId);
                  return (
                    <div
                      key={friend.friendId}
                      className="flex items-center gap-3 px-3 py-2 hover:bg-gray-50 rounded-xl cursor-pointer"
                      onClick={() => toggleMemberSelection(friend.friendId)}
                    >
                      <input type="checkbox" checked={isSelected} readOnly className="w-5 h-5 accent-[#007AFF]" />
                      <UserAvatar name={resolveFriendLabel(friend)} imageUrl={friend.avatarUrl} size="md" />
                      <div className="flex-1">
                        <div className="font-medium">{resolveFriendLabel(friend)}</div>
                        {friend.statusMessage && <div className="text-xs text-gray-500">{friend.statusMessage}</div>}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        {/* Footer */}
        <div className="sticky bottom-0 bg-white border-t pt-4 mt-6 flex gap-3">
          <Button variant="ghost" className="flex-1" onClick={onClose} disabled={isSubmitting}>
            Hủy
          </Button>
          <Button
            variant="primary"
            className="flex-1"
            onClick={handleSubmit}
            disabled={!canSubmit}
          >
            {isSubmitting ? 'Đang tạo...' : `Tạo nhóm (${selectedMemberIds.length})`}
          </Button>
        </div>
      </div>
    </Modal>
  );
}