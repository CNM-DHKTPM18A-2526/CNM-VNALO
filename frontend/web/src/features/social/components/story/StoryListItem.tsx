import { UserAvatar } from '../../../../shared/components/UserAvatar';
import type { Story } from '../../api/social.api';
import { formatStoryAge } from '../../utils/storyTime';

export type StoryGroupItem = {
  authorId: string;
  stories: Story[];
  latestStoryAt: string;
  unreadCount: number;
};

export function StoryListItem({
  group,
  currentStoryId,
  currentUserId,
  displayName,
  avatarUrl,
  onClick,
}: {
  group: StoryGroupItem;
  currentStoryId: string;
  currentUserId: string | null;
  displayName: string;
  avatarUrl: string | null;
  onClick: () => void;
}) {
  const isMe = currentUserId === group.authorId;
  const hasUnread = group.unreadCount > 0 && !isMe;
  const subtitle = hasUnread
    ? `${group.unreadCount} thẻ mới · ${formatStoryAge(group.latestStoryAt)}`
    : formatStoryAge(group.latestStoryAt);

  return (
    <button type="button" className={`story-list-item ${group.stories.some(item => item.storyId === currentStoryId) ? 'active' : ''}`} onClick={onClick}>
      <div className={`story-list-item-avatar-ring ${hasUnread ? 'unseen' : 'seen'}`}>
        <UserAvatar imageUrl={avatarUrl} name={displayName} size="md" className="story-list-item-avatar" />
      </div>
      <div className="story-list-item-meta">
        <div className="story-list-item-name">{displayName}</div>
        <div className="story-list-item-subtitle">{subtitle}</div>
      </div>
    </button>
  );
}
