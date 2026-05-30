import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { type Story } from '../api/social.api';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useNavigate } from 'react-router-dom';
import { useStoryStore } from '../store/story.store';

type StoryAuthorProfile = {
  displayName: string
  avatarUrl: string | null
}

export function StoryBar({ stories, authorProfiles = {}, currentUserId = null }: { stories: Story[], authorProfiles?: Record<string, StoryAuthorProfile>, currentUserId?: string | null }) {
  const navigate = useNavigate();
  const viewersByStoryId = useStoryStore(state => state.viewersByStoryId);
  const scrollRef = useRef<HTMLDivElement | null>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);

  const updateScrollState = useCallback(() => {
    const element = scrollRef.current;
    if (!element) return;

    const maxScrollLeft = Math.max(0, element.scrollWidth - element.clientWidth);
    setCanScrollLeft(element.scrollLeft > 2);
    setCanScrollRight(element.scrollLeft < maxScrollLeft - 2);
  }, []);

  useEffect(() => {
    updateScrollState();
    const handleResize = () => updateScrollState();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [updateScrollState, stories.length]);

  const isViewedByCurrentUser = (storyId: string) => {
    if (!currentUserId) return false;

    const viewedByStore = (viewersByStoryId[storyId] ?? []).some(viewer => viewer.viewerId === currentUserId);
    if (viewedByStore) return true;

    try {
      return localStorage.getItem(`story:viewed:${currentUserId}:${storyId}`) === '1';
    } catch {
      return false;
    }
  };

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
      .sort((left, right) => {
        if (left.authorId === currentUserId && right.authorId !== currentUserId) return -1;
        if (right.authorId === currentUserId && left.authorId !== currentUserId) return 1;
        return right.latestStoryAt.localeCompare(left.latestStoryAt);
      });
  }, [stories, currentUserId]);

  const openStoryGroup = (authorStories: Story[]) => {
    if (authorStories.length === 0) return;
    navigate(`/stories/${authorStories[authorStories.length - 1].storyId}`);
  };

  const scrollStories = (direction: 'left' | 'right') => {
    const element = scrollRef.current;
    if (!element) return;

    const amount = Math.max(220, Math.floor(element.clientWidth * 0.7));
    element.scrollBy({ left: direction === 'left' ? -amount : amount, behavior: 'smooth' });
  };

  return (
    <div className="story-bar-shell">
      {canScrollLeft && (
        <button type="button" className="story-bar-nav story-bar-nav-left" aria-label="Cuộn trái" onClick={() => scrollStories('left')}>
          <span className="story-bar-nav-glyph">‹</span>
        </button>
      )}

      <div className="story-bar-container" ref={scrollRef} onScroll={updateScrollState}>
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
          const hasUnseenStory = !isMe && authorStories.some(story => !isViewedByCurrentUser(story.storyId));
          const ringClass = hasUnseenStory ? 'unseen' : 'seen';

          return (
            <button
              key={authorId}
              type="button"
              className="story-item story-item-button story-card"
              onClick={() => openStoryGroup(authorStories)}
              style={coverUrl ? { backgroundImage: `url(${coverUrl})` } : undefined}
            >
              <div className={`story-avatar-ring ${isMe ? 'me' : ''} ${ringClass}`}>
                <UserAvatar imageUrl={authorProfiles[authorId]?.avatarUrl ?? null} name={authorProfiles[authorId]?.displayName || authorId} size="sm" className="story-avatar-img" />
              </div>

              <div className="story-card-footer">
                <span className="story-author-name">{displayName}</span>
              </div>
            </button>
          );
        })}
      </div>

      {canScrollRight && (
        <button type="button" className="story-bar-nav story-bar-nav-right" aria-label="Cuộn phải" onClick={() => scrollStories('right')}>
          <span className="story-bar-nav-glyph">›</span>
        </button>
      )}
    </div>
  );
}
