import type { RefObject } from 'react';
import { Icon } from '../../../../shared/components/Icon';
import type { Story, StoryViewer as StoryViewerEntry } from '../../api/social.api';

type StoryContentProps = {
  story: Story;
  isVideoStory: boolean;
  isMuted: boolean;
  videoRef: RefObject<HTMLVideoElement | null>;
  canSeeViewers: boolean;
  viewers: StoryViewerEntry[];
  currentUserId: string | null;
  userMap: Record<string, { displayName?: string; avatarUrl?: string | null }>;
  onOpenViewers: () => void;
  isReacted: boolean;
  onToggleReaction: () => void;
};

export function StoryContent({
  story,
  isVideoStory,
  isMuted,
  videoRef,
  canSeeViewers,
  viewers,
  currentUserId,
  userMap,
  onOpenViewers,
  isReacted,
  onToggleReaction,
}: StoryContentProps) {
  return (
    <div className="story-viewer-content">
      <div className="story-viewer-media-wrap">
        {isVideoStory ? (
          <video ref={videoRef} src={story.mediaUrl} className="story-viewer-media story-viewer-media-video" muted={isMuted} autoPlay playsInline />
        ) : (
          <img src={story.mediaUrl} className="story-viewer-media story-viewer-media-image" alt="Story" />
        )}
        {canSeeViewers && (
          <button type="button" className="story-viewer-views" onClick={onOpenViewers}>
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
        {story.authorId !== currentUserId && (
          <button
            type="button"
            className={`story-btn-reaction ${isReacted ? 'active' : ''}`}
            onClick={onToggleReaction}
            aria-label={isReacted ? 'Bỏ tim story' : 'Thả tim story'}
            title={isReacted ? 'Bỏ tim story' : 'Thả tim story'}
          >
            <Icon name={isReacted ? 'heartFill' : 'heart'} size={20} />
          </button>
        )}
      </div>
    </div>
  );
}
