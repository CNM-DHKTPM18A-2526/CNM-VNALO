import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../auth/useAuth';
import { useUserStore } from '../../chat/context/UserStoreContext';
import { socialApi } from '../api/social.api';
import { StoriesSidebar } from '../components/story/StoriesSidebar';
import { StoryViewer } from '../components/story/StoryViewer';
import { useRealtimeStories } from '../hooks/useRealtimeStories';
import { storyStore, useStoryStore } from '../store/story.store';
import '../styles/story.css';

export default function StoryViewerPage() {
  const navigate = useNavigate();
  const params = useParams<{ storyId: string }>();
  const storyId = params.storyId ?? '';
  const { accessToken, user } = useAuth();
  const { ensureUser, userMap } = useUserStore();
  const [isLoading, setIsLoading] = useState(true);
  const stories = useStoryStore(state => state.stories);

  useRealtimeStories();

  useEffect(() => {
    if (!accessToken) return;

    let cancelled = false;

    void socialApi.getStories(accessToken)
      .then(async list => {
        if (cancelled) return;
        const activeStories = list.filter(story => new Date(story.expiresAt).getTime() > Date.now());
        storyStore.hydrateStories(activeStories);

        const authorIds = [...new Set(activeStories.map(story => story.authorId))];
        await Promise.all(authorIds.map(authorId => ensureUser(accessToken, authorId).catch(() => null)));
      })
      .catch(() => {
        if (!cancelled) {
          storyStore.hydrateStories([]);
        }
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [accessToken, ensureUser]);

  const currentUserId = user?.id ?? null;

  const story = useMemo(() => stories.find(item => item.storyId === storyId), [stories, storyId]);
  const orderedStories = useMemo(() => {
    const byAuthor = new Map<string, typeof stories>();

    stories.forEach(item => {
      const authorStories = byAuthor.get(item.authorId) ?? [];
      authorStories.push(item);
      byAuthor.set(item.authorId, authorStories);
    });

    return [...byAuthor.entries()]
      .map(([authorId, authorStories]) => ({
        authorId,
        latestStoryAt: authorStories.reduce((latest, item) => (item.createdAt > latest ? item.createdAt : latest), authorStories[0]?.createdAt ?? ''),
        stories: authorStories.slice().sort((left, right) => left.createdAt.localeCompare(right.createdAt)),
      }))
      .sort((left, right) => {
        if (left.authorId === currentUserId && right.authorId !== currentUserId) return -1;
        if (right.authorId === currentUserId && left.authorId !== currentUserId) return 1;
        return right.latestStoryAt.localeCompare(left.latestStoryAt);
      })
      .flatMap(group => group.stories);
  }, [stories, currentUserId]);

  if (!accessToken) {
    return null;
  }

  if (isLoading) {
    return <div className="story-page-loading">Đang tải story...</div>;
  }

  if (!story && stories.length === 0) {
    return (
      <div className="story-page-empty">
        <div className="story-page-empty-card">
          <h2>Chưa có story</h2>
          <p>Không tìm thấy story khả dụng hoặc story đã hết hạn.</p>
          <button type="button" className="story-btn primary" onClick={() => navigate('/social')}>Quay về Nhật ký</button>
        </div>
      </div>
    );
  }

  return (
    <div className="story-viewer-page-shell" onClick={() => navigate('/social')}>
      <StoriesSidebar
        stories={stories}
        currentStoryId={story?.storyId ?? storyId}
        currentUserId={currentUserId}
        authorProfiles={userMap as Record<string, { displayName: string; avatarUrl: string | null }>}
        onSelectStory={(nextStoryId) => navigate(`/stories/${nextStoryId}`)}
        onClose={() => navigate('/social')}
      />

      <main className="story-viewer-page-main" onClick={event => event.stopPropagation()}>
        <StoryViewer
          stories={orderedStories}
          authorProfiles={userMap as Record<string, { displayName: string; avatarUrl: string | null }>}
          startStoryId={story?.storyId ?? storyId}
          token={accessToken}
          currentUserId={currentUserId}
          onSelectStory={(nextStoryId) => navigate(`/stories/${nextStoryId}`)}
          onClose={() => navigate('/social')}
          onDeleteStory={(deletedStoryId) => {
            storyStore.removeStory(deletedStoryId);
            navigate('/social');
          }}
        />
      </main>
    </div>
  );
}
