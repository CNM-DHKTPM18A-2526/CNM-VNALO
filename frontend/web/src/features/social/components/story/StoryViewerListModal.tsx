import type { StoryReaction, StoryViewer } from '../../api/social.api';
import { useUserStore } from '../../../chat/context/UserStoreContext';
import { UserAvatar } from '../../../../shared/components/UserAvatar';

export function StoryViewerListModal({
  viewers,
  reactions = [],
  onClose,
}: {
  viewers: StoryViewer[];
  reactions?: StoryReaction[];
  onClose: () => void;
}) {
  const { userMap } = useUserStore();
  const reactedUserIds = new Set(reactions.map(reaction => reaction.userId));

  return (
    <div className="story-viewer-drawer-backdrop" onClick={onClose}>
      <div className="story-viewer-drawer" onClick={event => event.stopPropagation()}>
        <div className="story-viewer-drawer-header">
          <h3 className="story-viewer-drawer-title">👁 {viewers.length} người xem</h3>
          <button type="button" className="story-viewer-close-btn" onClick={onClose}>✕</button>
        </div>
        <div className="story-viewer-drawer-body">
          {viewers.length === 0 ? (
            <div className="story-viewer-empty">Chưa có lượt xem.</div>
          ) : (
            viewers.map(viewer => (
              <div key={viewer.viewId} className="story-viewer-row">
                <UserAvatar
                  imageUrl={userMap[viewer.viewerId]?.avatarUrl ?? null}
                  name={userMap[viewer.viewerId]?.displayName || 'Người dùng'}
                  size="md"
                  className="story-viewer-avatar"
                />
                <div className="story-viewer-meta">
                  <div className="story-viewer-name">{userMap[viewer.viewerId]?.displayName || 'Người dùng'}</div>
                  <div className="story-viewer-time">{new Date(viewer.viewedAt).toLocaleString()}</div>
                </div>
                {reactedUserIds.has(viewer.viewerId) ? (
                  <div className="story-viewer-reaction-badge">❤️</div>
                ) : null}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
