import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import type { Story } from '../../api/social.api';
import { Icon } from '../../../../shared/components/Icon';
import { CreateStoryCard } from './CreateStoryCard';
import { StoryList } from './StoryList';
import type { StoryGroupItem } from './StoryListItem';
import { useStoryStore } from '../../store/story.store';

export function StoriesSidebar({
  stories,
  currentStoryId,
  currentUserId,
  authorProfiles,
  onSelectStory,
  onClose,
}: {
  stories: Story[];
  currentStoryId: string;
  currentUserId: string | null;
  authorProfiles: Record<string, { displayName: string; avatarUrl: string | null }>;
  onSelectStory: (storyId: string) => void;
  onClose: () => void;
}) {
  const navigate = useNavigate();
  const viewersByStoryId = useStoryStore(state => state.viewersByStoryId);

  const isViewedByCurrentUser = (storyId: string, authorId: string) => {
    if (!currentUserId || authorId === currentUserId) return true;

    const viewedByStore = (viewersByStoryId[storyId] ?? []).some(viewer => viewer.viewerId === currentUserId);
    if (viewedByStore) return true;

    try {
      return localStorage.getItem(`story:viewed:${currentUserId}:${storyId}`) === '1';
    } catch {
      return false;
    }
  };

  const groupedStories = useMemo<StoryGroupItem[]>(() => {
    const byAuthor = new Map<string, Story[]>();

    stories.forEach(story => {
      const items = byAuthor.get(story.authorId) ?? [];
      items.push(story);
      byAuthor.set(story.authorId, items);
    });

    return [...byAuthor.entries()]
      .map(([authorId, authorStories]) => ({
        authorId,
        stories: authorStories.slice().sort((left, right) => left.createdAt.localeCompare(right.createdAt)),
        latestStoryAt: authorStories.reduce((latest, item) => (item.createdAt > latest ? item.createdAt : latest), authorStories[0]?.createdAt ?? ''),
        unreadCount: authorStories.reduce((count, item) => {
          if (!currentUserId || authorId === currentUserId) return count;
          const viewedByCurrentUser = isViewedByCurrentUser(item.storyId, authorId);
          return viewedByCurrentUser ? count : count + 1;
        }, 0),
      }))
      .sort((left, right) => {
        if (left.authorId === currentUserId && right.authorId !== currentUserId) return -1;
        if (right.authorId === currentUserId && left.authorId !== currentUserId) return 1;
        return right.latestStoryAt.localeCompare(left.latestStoryAt);
      });
  }, [stories, currentUserId, viewersByStoryId]);

  const activeUserGroup = groupedStories.find(group => group.authorId === currentUserId) ?? null;
  const otherGroups = groupedStories.filter(group => group.authorId !== currentUserId);

  return (
    <aside className="stories-sidebar" onClick={event => event.stopPropagation()}>
      <div className="stories-sidebar-header">
        <button type="button" className="stories-sidebar-close" onClick={onClose} aria-label="Đóng story">
          <Icon name="close" size={20} />
        </button>
        <div className="stories-sidebar-logo">VNALO</div>
      </div>

      <div className="stories-sidebar-sticky">
        <h1 className="stories-sidebar-title">Tin</h1>
        <div className="stories-sidebar-links">
          <button type="button" className="stories-sidebar-link" onClick={() => navigate('/social')}>Kho lưu trữ</button>
          <span className="stories-sidebar-link-separator">·</span>
          <button type="button" className="stories-sidebar-link" onClick={() => navigate('/social')}>Cài đặt</button>
        </div>
      </div>

      <section className="stories-sidebar-section">
        <h2 className="stories-sidebar-section-title">Tin của bạn</h2>
        <CreateStoryCard onClick={() => navigate('/stories/create')} />
        {activeUserGroup ? (
          <>
            <StoryList
              groups={[activeUserGroup]}
              currentStoryId={currentStoryId}
              currentUserId={currentUserId}
              authorProfiles={authorProfiles}
              onSelectStory={onSelectStory}
            />
          </>
        ) : null}
      </section>

      <section className="stories-sidebar-section stories-sidebar-section-list">
        <h2 className="stories-sidebar-section-title">Tất cả tin</h2>
        <StoryList
          groups={otherGroups}
          currentStoryId={currentStoryId}
          currentUserId={currentUserId}
          authorProfiles={authorProfiles}
          onSelectStory={onSelectStory}
        />
      </section>
    </aside>
  );
}
