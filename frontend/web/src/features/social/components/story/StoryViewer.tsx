import { useEffect, useMemo, useRef, useState, useLayoutEffect } from 'react';
import { type Story, type StoryViewer as StoryViewerEntry, socialApi } from '../../api/social.api';
import { StoryViewerListModal } from './StoryViewerListModal';
import { storyStore } from '../../store/story.store';
import { useUserStore } from '../../../chat/context/UserStoreContext';
import { UserAvatar } from '../../../../shared/components/UserAvatar';

export function StoryViewer({
  stories,
  startStoryId,
  token,
  currentUserId,
  sidebarStories = stories,
  authorProfiles = {},
  onSelectStory,
  onClose,
  onDeleteStory,
}: {
  stories: Story[];
  startStoryId: string;
  token: string;
  currentUserId: string | null;
  sidebarStories?: Story[];
  authorProfiles?: Record<string, { displayName: string; avatarUrl: string | null }>;
  onSelectStory?: (storyId: string) => void;
  onClose: () => void;
  onDeleteStory: (storyId: string) => void;
}) {
  const initialIndex = Math.max(0, stories.findIndex(story => story.storyId === startStoryId));
  const [index, setIndex] = useState(initialIndex >= 0 ? initialIndex : 0);
  const [isPaused, setIsPaused] = useState(false);
  const [viewers, setViewers] = useState<StoryViewerEntry[]>([]);
  
  const [isViewerOpen, setIsViewerOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { ensureUser, userMap } = useUserStore();

  // Refs and state to compute available area for the media so it can be vertically centered
  const bodyRef = useRef<HTMLDivElement | null>(null);
  const headerRef = useRef<HTMLDivElement | null>(null);
  const progressRef = useRef<HTMLDivElement | null>(null);
  const [mediaHeight, setMediaHeight] = useState<number | null>(null);

  const story = stories[index];

  useEffect(() => {
    // When the desired startStoryId or the stories list changes, update the active index
    const found = stories.findIndex(s => s.storyId === startStoryId);
    if (found >= 0) {
      setIndex(found);
      return;
    }

    // If the startStoryId isn't present, ensure index is within bounds
    if (stories.length === 0) {
      setIndex(0);
    } else if (index >= stories.length) {
      setIndex(0);
    }
  }, [startStoryId, stories]);

  // Measure available media area and update on resize / content change
  useLayoutEffect(() => {
    const measure = () => {
      const bodyEl = bodyRef.current;
      if (!bodyEl) return setMediaHeight(null);

      const bodyRect = bodyEl.getBoundingClientRect();
      const headerH = headerRef.current?.getBoundingClientRect().height ?? 0;
      const progressH = progressRef.current?.getBoundingClientRect().height ?? 0;

      // Reserve a few pixels of breathing room
      const reserved = Math.ceil(headerH + progressH + 24);
      const available = Math.max(0, Math.floor(bodyRect.height - reserved));
      setMediaHeight(available > 0 ? available : null);
    };

    measure();

    // Observe size changes on body, header, and progress to recompute when layout shifts
    const observers: ResizeObserver[] = [];
    try {
      const ro = new ResizeObserver(measure);
      if (bodyRef.current) ro.observe(bodyRef.current);
      if (headerRef.current) ro.observe(headerRef.current);
      if (progressRef.current) ro.observe(progressRef.current);
      observers.push(ro);
    } catch (e) {
      // ResizeObserver may not be available in some envs; fallback to window resize
      window.addEventListener('resize', measure);
      return () => window.removeEventListener('resize', measure);
    }

    return () => {
      observers.forEach(o => o.disconnect());
    };
  }, [stories.length, index]);

  const canDelete = useMemo(() => Boolean(story && currentUserId && story.authorId === currentUserId), [story, currentUserId]);

  const authorName = useMemo(() => {
    if (!story) return 'Story';
    if (currentUserId && story.authorId === currentUserId) return 'Bạn';
    return userMap[story.authorId]?.displayName?.trim() || `User ${story.authorId.substring(0, 4)}`;
  }, [story, userMap]);

  const elapsedLabel = useMemo(() => formatStoryAge(story?.createdAt ?? ''), [story?.createdAt]);

  const canSeeViewers = canDelete;

  const sidebarGroups = useMemo(() => {
    const byAuthor = new Map<string, Story[]>();

    sidebarStories.forEach(item => {
      const items = byAuthor.get(item.authorId) ?? [];
      items.push(item);
      byAuthor.set(item.authorId, items);
    });

    return [...byAuthor.entries()]
      .map(([authorId, authorStories]) => ({
        authorId,
        stories: authorStories.sort((left, right) => left.createdAt.localeCompare(right.createdAt)),
        latestStoryAt: authorStories.reduce((latest, item) => (item.createdAt > latest ? item.createdAt : latest), authorStories[0]?.createdAt ?? ''),
      }))
      .sort((left, right) => right.latestStoryAt.localeCompare(left.latestStoryAt));
  }, [sidebarStories]);

  // Ensure current user's group appears first
  const orderedSidebarGroups = useMemo(() => {
    if (!currentUserId) return sidebarGroups;
    const idx = sidebarGroups.findIndex(g => g.authorId === currentUserId);
    if (idx <= 0) return sidebarGroups;
    const copy = sidebarGroups.slice();
    const [me] = copy.splice(idx, 1);
    copy.unshift(me);
    return copy;
  }, [sidebarGroups, currentUserId]);

  const openStory = (storyId: string) => {
    if (onSelectStory) {
      onSelectStory(storyId);
      return;
    }

    const nextIndex = stories.findIndex(item => item.storyId === storyId);
    if (nextIndex >= 0) setIndex(nextIndex);
  };

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
      if (event.key === 'ArrowRight') setIndex(current => Math.min(stories.length - 1, current + 1));
      if (event.key === 'ArrowLeft') setIndex(current => Math.max(0, current - 1));
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [stories.length, onClose]);

  useEffect(() => {
    if (!story || !token) return;
    storyStore.setActiveStory(story.storyId);
    void socialApi.viewStory(token, story.storyId).catch(() => null);
    void socialApi.getStoryViews(token, story.storyId)
      .then(list => {
        setViewers(list);
        storyStore.setViewers(story.storyId, list);
        void Promise.all(list.map(viewer => ensureUser(token, viewer.viewerId).catch(() => null)));
      })
      .catch(() => setViewers([]));

    // reactions endpoint removed — do not call
  }, [story?.storyId, token, ensureUser]);

  useEffect(() => {
    if (!story || isPaused) return;
    const timer = window.setTimeout(() => {
      setIndex(current => (current + 1 < stories.length ? current + 1 : current));
    }, 5000);
    return () => window.clearTimeout(timer);
  }, [story?.storyId, isPaused, stories.length]);

  if (!story) return null;

  const deleteCurrentStory = async () => {
    if (!canDelete || isDeleting) return;
    const confirmed = window.confirm('Xóa tin này?');
    if (!confirmed) return;
    setIsDeleting(true);
    try {
      await socialApi.deleteStory(token, story.storyId);
      onDeleteStory(story.storyId);
      onClose();
    } finally {
      setIsDeleting(false);
    }
  };

  // reactions removed — no toggleReaction

  return (
    <div className="story-viewer-overlay" onClick={onClose}>
      <div className="story-viewer-shell" onClick={event => event.stopPropagation()} onMouseEnter={() => setIsPaused(true)} onMouseLeave={() => setIsPaused(false)}>
        <aside className="story-viewer-sidebar">
          <div className="story-viewer-sidebar-header">
            <div className="story-viewer-sidebar-title">Tin</div>
            <button type="button" className="story-btn ghost" onClick={onClose}>Đóng</button>
          </div>

          <div className="story-viewer-sidebar-list">
            {orderedSidebarGroups.map(group => {
              const activeStory = group.stories.some(item => item.storyId === story.storyId);
              const profile = authorProfiles[group.authorId] ?? null;

              const displayName = (group.authorId === currentUserId) ? 'Bạn' : (profile?.displayName || `User ${group.authorId.substring(0, 4)}`);

              return (
                <button
                  key={group.authorId}
                  type="button"
                  className={`story-viewer-sidebar-item ${activeStory ? 'active' : ''}`}
                  onClick={() => openStory(group.stories[group.stories.length - 1].storyId)}
                >
                  <div className="story-viewer-sidebar-avatar-wrap">
                    <UserAvatar
                      imageUrl={profile?.avatarUrl ?? null}
                      name={profile?.displayName || `User ${group.authorId.substring(0, 4)}`}
                      size="lg"
                      className="story-viewer-sidebar-avatar"
                    />
                  </div>
                  <div className="story-viewer-sidebar-meta">
                    <div className="story-viewer-sidebar-name">{displayName}</div>
                    <div className="story-viewer-sidebar-subtitle">{group.stories.length} thẻ mới · {formatStoryAge(group.latestStoryAt)}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </aside>

        <section className="story-viewer-main">
          <div className="story-viewer-progress" ref={progressRef}>
            {stories.map((item, storyIndex) => (
              <div key={item.storyId} className={`story-viewer-progress-bar ${storyIndex === index ? 'active' : ''} ${storyIndex < index ? 'done' : ''}`} />
            ))}
          </div>

            <div className="story-viewer-header" ref={headerRef}>
            <div>
              <div className="story-viewer-title">{authorName}</div>
              <div className="story-viewer-subtitle">{elapsedLabel}</div>
            </div>
            <div className="story-viewer-header-actions">
              {/* reaction UI removed */}
              {/* viewers button moved to bottom-left overlay per UX */}
              {canDelete && (
                <button type="button" className="story-btn ghost danger" onClick={deleteCurrentStory} disabled={isDeleting}>
                  {isDeleting ? 'Đang xóa...' : 'Xóa tin'}
                </button>
              )}
              <button type="button" className="story-btn ghost" onClick={onClose}>Đóng</button>
            </div>
          </div>

          <div className="story-viewer-body" ref={bodyRef}>
            <button type="button" className="story-nav-arrow left" onClick={() => setIndex(current => Math.max(0, current - 1))}>‹</button>
            <div className="story-viewer-media-wrap" style={mediaHeight ? { height: `${mediaHeight}px` } : undefined}>
              {story.mediaUrl.endsWith('.mp4') || story.mediaUrl.endsWith('.webm') || story.mediaUrl.endsWith('.ogg') ? (
                <video src={story.mediaUrl} className="story-viewer-media story-viewer-media-video" controls autoPlay playsInline />
              ) : (
                <img src={story.mediaUrl} className="story-viewer-media story-viewer-media-image" alt="Story" />
              )}
              {(story.mediaUrl.endsWith('.mp4') || story.mediaUrl.endsWith('.webm') || story.mediaUrl.endsWith('.ogg')) && story.caption ? (
                <div className="story-viewer-caption">{story.caption}</div>
              ) : null}
              {/* Bottom-left viewers button (exclude current user) */}
              {canSeeViewers && (
                <button type="button" className="story-viewer-views" onClick={() => setIsViewerOpen(true)}>
                  <div className="story-viewer-views-count">Đã xem ({viewers.filter(v => v.viewerId !== currentUserId).length})</div>
                  <div className="story-viewer-views-avatars">
                    {viewers
                      .filter(v => v.viewerId !== currentUserId)
                      .slice(0, 5)
                      .map(v => (
                        <img
                          key={v.viewerId}
                          src={userMap[v.viewerId]?.avatarUrl ?? undefined}
                          alt={userMap[v.viewerId]?.displayName ?? v.viewerId}
                          className="story-viewer-views-avatar"
                        />
                      ))}
                  </div>
                </button>
              )}
            </div>
            <button type="button" className="story-nav-arrow right" onClick={() => setIndex(current => Math.min(stories.length - 1, current + 1))}>›</button>
          </div>
        </section>
      </div>

      {isViewerOpen && <StoryViewerListModal viewers={viewers.filter(v => v.viewerId !== currentUserId)} onClose={() => setIsViewerOpen(false)} />}
    </div>
  );
}

function formatStoryAge(createdAt: string) {
  const time = new Date(createdAt).getTime();
  if (Number.isNaN(time)) return '';

  const elapsed = Date.now() - time;
  if (elapsed < 60_000) return 'Vừa xong';

  const minutes = Math.floor(elapsed / 60_000);
  if (minutes < 60) return `${minutes} phút`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} giờ`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} ngày`;

  const weeks = Math.floor(days / 7);
  if (weeks < 5) return `${weeks} tuần`;

  const months = Math.floor(days / 30);
  if (months < 12) return `${months} tháng`;

  return `${Math.floor(days / 365)} năm`;
}
