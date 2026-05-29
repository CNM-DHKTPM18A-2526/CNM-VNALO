import { useEffect, type RefObject } from 'react';
import { Icon } from '../../../../shared/components/Icon';
import { UserAvatar } from '../../../../shared/components/UserAvatar';

export type StoryHeaderProps = {
  avatarUrl: string | null;
  title: string;
  subtitle: string;
  isMuted: boolean;
  isPaused: boolean;
  canDelete: boolean;
  isOptionsOpen: boolean;
  onToggleMuted: () => void;
  onTogglePaused: () => void;
  onToggleOptions: () => void;
  onDelete: () => void;
  onClose: () => void;
  optionsMenuRef: RefObject<HTMLDivElement | null>;
};

export function StoryHeader({
  avatarUrl,
  title,
  subtitle,
  isMuted,
  isPaused,
  canDelete,
  isOptionsOpen,
  onToggleMuted,
  onTogglePaused,
  onToggleOptions,
  onDelete,
  onClose,
  optionsMenuRef,
}: StoryHeaderProps) {
  useEffect(() => {
    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as HTMLElement | null;
      if (!target) return;
      if (optionsMenuRef.current && !optionsMenuRef.current.contains(target)) {
        onToggleOptions();
      }
    };

    if (!isOptionsOpen) return undefined;
    window.addEventListener('pointerdown', handlePointerDown);
    return () => window.removeEventListener('pointerdown', handlePointerDown);
  }, [isOptionsOpen, onToggleOptions, optionsMenuRef]);

  return (
    <header className="story-viewer-header">
      <div className="story-viewer-header-left">
        <UserAvatar imageUrl={avatarUrl} name={title} size="md" className="story-viewer-header-avatar" />
        <div className="story-viewer-header-meta">
          <div className="story-viewer-title">{title}</div>
          <div className="story-viewer-subtitle">{subtitle}</div>
        </div>
      </div>

      <div className="story-viewer-header-actions" ref={optionsMenuRef}>
        <button
          type="button"
          className={`story-icon-btn ${isMuted ? 'muted' : ''}`}
          onClick={onToggleMuted}
          aria-label={isMuted ? 'Bật âm thanh' : 'Tắt âm thanh'}
          title={isMuted ? 'Bật âm thanh' : 'Tắt âm thanh'}
        >
          <Icon name={isMuted ? 'volumeOff' : 'volume'} size={20} />
        </button>
        <button
          type="button"
          className={`story-icon-btn ${isPaused ? 'active' : ''}`}
          onClick={onTogglePaused}
          aria-label={isPaused ? 'Tiếp tục story' : 'Tạm dừng story'}
          title={isPaused ? 'Tiếp tục story' : 'Tạm dừng story'}
        >
          <Icon name={isPaused ? 'play' : 'pause'} size={20} />
        </button>
        
        {canDelete ? (
          <div className="story-options-wrap">
            <button
              type="button"
              className="story-icon-btn"
              onClick={onToggleOptions}
              aria-haspopup="menu"
              aria-expanded={isOptionsOpen}
              title="Tùy chọn"
            >
              <Icon name="more" size={20} />
            </button>
            {isOptionsOpen && (
              <div className="story-options-menu" role="menu">
                <button
                  type="button"
                  className="story-options-item danger"
                  role="menuitem"
                  onClick={onDelete}
                >
                  Xóa tin
                </button>
              </div>
            )}
          </div>
        ) : null}

        <button type="button" className="story-icon-btn story-icon-btn-close" onClick={onClose} aria-label="Đóng story" title="Đóng story">
          <Icon name="close" size={20} />
        </button>
      </div>
    </header>
  );
}
