import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { type Story, type StoryReaction, type StoryViewer as StoryViewerEntry, socialApi } from '../../api/social.api';
import { StoryViewerListModal } from './StoryViewerListModal';
import { storyStore } from '../../store/story.store';
import { useUserStore } from '../../../chat/context/UserStoreContext';
import { StoryHeader } from './StoryHeader';
import { StoryProgress } from './StoryProgress';
import { StoryNavigation } from './StoryNavigation';
import { StoryContent } from './StoryContent';
import { formatStoryAge } from '../../utils/storyTime';

export function StoryViewer({
  stories,
  startStoryId,
  token,
  currentUserId,
  authorProfiles = {},
  onSelectStory,
  onClose,
  onDeleteStory,
}: {
  stories: Story[];
  startStoryId: string;
  token: string;
  currentUserId: string | null;
  authorProfiles?: Record<string, { displayName: string; avatarUrl: string | null }>;
  onSelectStory?: (storyId: string) => void;
  onClose: () => void;
  onDeleteStory: (storyId: string) => void;
}) {
  const navigate = useNavigate();
  const initialIndex = Math.max(0, stories.findIndex(story => story.storyId === startStoryId));
  const [index, setIndex] = useState(initialIndex >= 0 ? initialIndex : 0);
  const [isPaused, setIsPaused] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [isOptionsOpen, setIsOptionsOpen] = useState(false);
  const [viewers, setViewers] = useState<StoryViewerEntry[]>([]);
  const [reactions, setReactions] = useState<StoryReaction[]>([]);

  const [isViewerOpen, setIsViewerOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { ensureUser, userMap } = useUserStore();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const optionsMenuRef = useRef<HTMLDivElement | null>(null);

  const story = stories[index];
  const isVideoStory = Boolean(story && /\.(mp4|webm|ogg)(\?.*)?$/i.test(story.mediaUrl));
  const storyAuthor = story ? (authorProfiles[story.authorId] ?? null) : null;
  const activeAuthorStories = useMemo(() => {
    if (!story) return [];

    return stories
      .filter(item => item.authorId === story.authorId)
      .slice()
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }, [stories, story?.authorId]);
  const activeAuthorStoryIndex = useMemo(
    () => activeAuthorStories.findIndex(item => item.storyId === story?.storyId),
    [activeAuthorStories, story?.storyId],
  );
  const storyName = useMemo(() => {
    if (!story) return 'Story';
    if (currentUserId && story.authorId === currentUserId) return 'Bạn';
    return storyAuthor?.displayName?.trim() || userMap[story.authorId]?.displayName?.trim() || `User ${story.authorId.substring(0, 4)}`;
  }, [story, storyAuthor, currentUserId, userMap]);
  const storyAvatar = storyAuthor?.avatarUrl ?? userMap[story?.authorId ?? '']?.avatarUrl ?? null;
  const elapsedLabel = useMemo(() => formatStoryAge(story?.createdAt ?? ''), [story?.createdAt]);
  const isReactedByCurrentUser = useMemo(
    () => Boolean(currentUserId && reactions.some(reaction => reaction.userId === currentUserId)),
    [currentUserId, reactions],
  );

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

  // Keep track of the last startStoryId we observed so we can detect when the
  // parent/route initiated a change (clicking sidebar) vs when the viewer
  // itself changed the active story (next/prev or auto-advance). If the
  // parent changed `startStoryId`, skip navigating back to avoid a toggle loop.
  const prevStartRef = useRef<string | null>(startStoryId ?? null);

  useEffect(() => {
    if (!story) return;

    // If the active story already matches the requested startStoryId, update
    // our prevStartRef and do nothing.
    if (story.storyId === startStoryId) {
      prevStartRef.current = startStoryId;
      return;
    }

    // If the startStoryId prop recently changed (parent/route initiated the
    // navigation) then skip navigating here — the parent will control the
    // route. We detect that by comparing the incoming startStoryId with the
    // last observed value.
    if (startStoryId && startStoryId !== prevStartRef.current) {
      prevStartRef.current = startStoryId;
      return;
    }

    // Otherwise, this change was initiated inside the viewer (next/prev/auto),
    // so inform the parent or update the route.
    if (onSelectStory) {
      onSelectStory(story.storyId);
    } else {
      navigate(`/stories/${story.storyId}`, { replace: false });
    }

    prevStartRef.current = story.storyId;
  }, [onSelectStory, story?.storyId, startStoryId, navigate]);

  const canDelete = useMemo(() => Boolean(story && currentUserId && story.authorId === currentUserId), [story, currentUserId]);

  const canSeeViewers = canDelete;

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
    if (currentUserId) {
      const existing = storyStore.getState().viewersByStoryId[story.storyId] ?? [];
      if (!existing.some(viewer => viewer.viewerId === currentUserId)) {
        const optimisticViewer: StoryViewerEntry = {
          viewId: `${story.storyId}:${currentUserId}:local`,
          storyId: story.storyId,
          viewerId: currentUserId,
          viewedAt: new Date().toISOString(),
        };
        storyStore.setViewers(story.storyId, [optimisticViewer, ...existing]);
      }
      try {
        localStorage.setItem(`story:viewed:${currentUserId}:${story.storyId}`, '1');
      } catch {
        // ignore storage errors
      }
    }
    void socialApi.viewStory(token, story.storyId).catch(() => null);
    void socialApi.getStoryViews(token, story.storyId)
      .then(list => {
        setViewers(list);
        storyStore.setViewers(story.storyId, list);
        void Promise.all(list.map(viewer => ensureUser(token, viewer.viewerId).catch(() => null)));
      })
      .catch(() => setViewers([]));
    void socialApi.getStoryReactions(token, story.storyId)
      .then(list => {
        setReactions(list);
        void Promise.all(list.map(reaction => ensureUser(token, reaction.userId).catch(() => null)));
      })
      .catch(() => setReactions([]));

    // reactions endpoint removed — do not call
  }, [story?.storyId, token, ensureUser]);

  useEffect(() => {
    setIsOptionsOpen(false);
    setIsPaused(false);
    setIsMuted(true);
  }, [story?.storyId]);

  useEffect(() => {
    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as HTMLElement | null;
      if (!target) return;
      if (optionsMenuRef.current && !optionsMenuRef.current.contains(target)) {
        setIsOptionsOpen(false);
      }
    };

    window.addEventListener('pointerdown', handlePointerDown);
    return () => window.removeEventListener('pointerdown', handlePointerDown);
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !isVideoStory) return;

    if (isPaused) {
      video.pause();
      return;
    }

    void video.play().catch(() => null);
  }, [isPaused, isVideoStory, story?.storyId]);

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

  const toggleReaction = async () => {
    if (!story || !token || !currentUserId) return;

    if (isReactedByCurrentUser) {
      await socialApi.unreactStory(token, story.storyId).catch(() => null);
      setReactions(current => current.filter(reaction => reaction.userId !== currentUserId));
      return;
    }

    try {
      const reaction = await socialApi.reactStory(token, story.storyId, 'LOVE');
      setReactions(current => [reaction, ...current.filter(item => item.userId !== reaction.userId)]);
    } catch {
      // ignore reaction errors
    }
  };

  // reactions removed — no toggleReaction

  return (
    <div className="story-viewer-stage-shell">
      <StoryNavigation direction="left" onClick={() => setIndex(current => Math.max(0, current - 1))} />

      <section className="story-viewer-stage">
        <div className="story-viewer-backdrop">
          {isVideoStory ? (
            <video key={story.storyId} src={story.mediaUrl} className="story-viewer-backdrop-media" muted playsInline autoPlay loop />
          ) : (
            <img key={story.storyId} src={story.mediaUrl} className="story-viewer-backdrop-media" alt="Story background" />
          )}
        </div>

        <div className="story-viewer-frame">
          <StoryProgress stories={activeAuthorStories} activeIndex={Math.max(0, activeAuthorStoryIndex)} isPaused={isPaused} />
          <StoryHeader
            avatarUrl={storyAvatar}
            title={storyName}
            subtitle={elapsedLabel}
            isMuted={isMuted}
            isPaused={isPaused}
            canDelete={canDelete}
            isOptionsOpen={isOptionsOpen}
            onToggleMuted={() => setIsMuted(prev => !prev)}
            onTogglePaused={() => setIsPaused(prev => !prev)}
            onToggleOptions={() => setIsOptionsOpen(prev => !prev)}
            onDelete={() => {
              setIsOptionsOpen(false);
              void deleteCurrentStory();
            }}
            onClose={onClose}
            optionsMenuRef={optionsMenuRef}
          />
          <StoryContent
            story={story}
            isVideoStory={isVideoStory}
            isMuted={isMuted}
            videoRef={videoRef}
            canSeeViewers={canSeeViewers}
            viewers={viewers}
            currentUserId={currentUserId}
            userMap={userMap}
            onOpenViewers={() => setIsViewerOpen(true)}
            isReacted={isReactedByCurrentUser}
            onToggleReaction={() => void toggleReaction()}
          />
        </div>
      </section>

      <StoryNavigation direction="right" onClick={() => setIndex(current => Math.min(stories.length - 1, current + 1))} />
      {isViewerOpen && <StoryViewerListModal viewers={viewers.filter(v => v.viewerId !== currentUserId)} reactions={reactions} onClose={() => setIsViewerOpen(false)} />}
    </div>
  );
}
