import { useMemo } from 'react';
import { type Story } from '../api/social.api';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useNavigate } from 'react-router-dom';

type StoryAuthorProfile = {
  displayName: string
  avatarUrl: string | null
}

export function StoryBar({ stories, authorProfiles = {}, currentUserId = null }: { stories: Story[], authorProfiles?: Record<string, StoryAuthorProfile>, currentUserId?: string | null }) {
  const navigate = useNavigate();

  const groupedStories = useMemo(() => {
    const byAuthor = new Map<string, Story[]>();

    stories.forEach(story => {
      const items = byAuthor.get(story.authorId) ?? [];
      items.push(story);
      byAuthor.set(story.authorId, items);
    });

    return [...byAuthor.entries()]
      .map(([authorId, authorStories]) => ({
        authorId,
        stories: authorStories.sort((left, right) => left.createdAt.localeCompare(right.createdAt)),
        latestStoryAt: authorStories.reduce((latest, story) => (story.createdAt > latest ? story.createdAt : latest), authorStories[0]?.createdAt ?? ''),
      }))
      .sort((left, right) => right.latestStoryAt.localeCompare(left.latestStoryAt));
  }, [stories]);

  const openStoryGroup = (authorStories: Story[]) => {
    if (authorStories.length === 0) return;
    navigate(`/stories/${authorStories[authorStories.length - 1].storyId}`);
  };

  return (
    <div className="story-bar-container">
      <button type="button" className="story-item story-item-button story-card story-create" onClick={() => navigate('/stories/create')}>
        <div className="story-create-inner">
          <div className="story-create-plus">+</div>
        </div>
        <div className="story-card-footer">
          <span className="story-author-name">Tạo tin</span>
        </div>
      </button>

      {groupedStories.map(({ authorId, stories: authorStories }) => {
        const isMe = currentUserId && authorId === currentUserId;
        const displayName = isMe ? 'Bạn' : (authorProfiles[authorId]?.displayName || `User ${authorId.substring(0, 4)}`);
        const coverUrl = authorStories && authorStories.length > 0 ? authorStories[0].mediaUrl ?? authorProfiles[authorId]?.avatarUrl ?? null : authorProfiles[authorId]?.avatarUrl ?? null;

        return (
          <button
            key={authorId}
            type="button"
            className="story-item story-item-button story-card"
            onClick={() => openStoryGroup(authorStories)}
            style={coverUrl ? { backgroundImage: `url(${coverUrl})` } : undefined}
          >
            <div className={`story-avatar-ring ${isMe ? 'me' : ''}`}>
              <UserAvatar imageUrl={authorProfiles[authorId]?.avatarUrl ?? null} name={authorProfiles[authorId]?.displayName || authorId} size="sm" className="story-avatar-img" />
            </div>

            {authorStories.length > 1 ? <span className="story-count-badge">{authorStories.length}</span> : null}

            <div className="story-card-footer">
              <span className="story-author-name">{displayName}</span>
            </div>
          </button>
        );
      })}
    </div>
  );
}
