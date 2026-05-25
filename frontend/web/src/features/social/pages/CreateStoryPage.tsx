import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../auth/useAuth';
import { StoryTypeSelector } from '../components/story/StoryTypeSelector';
import { StoryEditor } from '../components/story/StoryEditor';
import { storyStore, type StoryDraft } from '../store/story.store';
import { useRealtimeStories } from '../hooks/useRealtimeStories';
import '../../social/styles/social.css';
import '../styles/story.css';

export default function CreateStoryPage() {
  const navigate = useNavigate();
  const { accessToken, user } = useAuth();
  const [draft, setDraft] = useState<StoryDraft>(storyStore.defaultDraft);
  const [type, setType] = useState<'media' | 'text'>('media');

  useRealtimeStories();

  useEffect(() => {
    storyStore.setDraft(draft);
  }, [draft]);

  const currentUserProfile = useMemo(() => ({
    displayName: user?.name?.trim() || user?.email || 'Tôi',
    avatarUrl: user?.avatarUrl ?? null,
  }), [user]);

  useEffect(() => {
    setDraft(current => ({ ...current, mode: type }));
  }, [type]);

  if (!accessToken) {
    return null;
  }

  return (
    <div className="story-page-shell">
      <aside className="story-page-sidebar">
        <button type="button" className="story-page-back" onClick={() => navigate('/social')}>← Quay về Nhật ký</button>
        <div className="story-page-user">
          <img
            src={currentUserProfile.avatarUrl ?? undefined}
            alt={currentUserProfile.displayName}
            className="story-page-user-avatar"
          />
          <div>
            <div className="story-page-user-name">{currentUserProfile.displayName}</div>
            <div className="story-page-user-subtitle">Tin của bạn</div>
          </div>
        </div>
        <StoryTypeSelector value={type} onChange={value => setType(value)} />
        <div className="story-page-caption">Ảnh/Video sẽ được crop trước khi upload. Story tự hết hạn sau 24 giờ.</div>
      </aside>

      <main className="story-page-main">
        <StoryEditor
          token={accessToken}
          draft={draft}
          onDraftChange={nextDraft => setDraft(nextDraft)}
          onPublished={() => {
            storyStore.resetDraft();
            navigate('/social');
          }}
        />
      </main>
    </div>
  );
}
