import { useEffect, useRef } from 'react';
import type { StoryDraft } from '../../store/story.store';

export function StoryPreview({
  draft,
  mediaPreviewUrl,
  previewAspectRatio,
  onOverlayChange,
}: {
  draft: StoryDraft;
  mediaPreviewUrl?: string | null;
  previewAspectRatio?: number | null;
  onOverlayChange?: (next: { overlayX: number; overlayY: number }) => void;
}) {
  const frameRef = useRef<HTMLDivElement>(null);
  const dragStateRef = useRef<{
    startX: number;
    startY: number;
    startOverlayX: number;
    startOverlayY: number;
    frameWidth: number;
    frameHeight: number;
  } | null>(null);

  useEffect(() => {
    if (!onOverlayChange) return;

    const handlePointerMove = (event: PointerEvent) => {
      const dragState = dragStateRef.current;
      if (!dragState) return;

      const deltaX = ((event.clientX - dragState.startX) / dragState.frameWidth) * 100;
      const deltaY = ((event.clientY - dragState.startY) / dragState.frameHeight) * 100;

      onOverlayChange({
        overlayX: clampPercent(dragState.startOverlayX + deltaX),
        overlayY: clampPercent(dragState.startOverlayY + deltaY),
      });
    };

    const handlePointerEnd = () => {
      dragStateRef.current = null;
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerEnd);
    window.addEventListener('pointercancel', handlePointerEnd);

    return () => {
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerEnd);
      window.removeEventListener('pointercancel', handlePointerEnd);
    };
  }, [onOverlayChange]);

  const startDrag = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!onOverlayChange) return;
    event.preventDefault();
    event.stopPropagation();

    const frame = frameRef.current?.getBoundingClientRect();
    dragStateRef.current = {
      startX: event.clientX,
      startY: event.clientY,
      startOverlayX: draft.overlayX,
      startOverlayY: draft.overlayY,
      frameWidth: frame?.width ?? 1,
      frameHeight: frame?.height ?? 1,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const isDraggable = draft.mode === 'media';
  const resolvedAspectRatio = draft.mode === 'media' && draft.mediaType === 'image' && previewAspectRatio
    ? previewAspectRatio
    : 9 / 16;

  return (
    <div
      className="story-preview-stage"
      style={{ background: draft.mode === 'text' ? draft.background : '#030712' }}
    >
      <div ref={frameRef} className="story-preview-frame" style={{ aspectRatio: `${resolvedAspectRatio}` }}>
        {draft.mode === 'media' && draft.mediaUrl ? (
          draft.mediaType === 'video' ? (
            <video
              src={draft.mediaUrl}
              className="story-preview-media"
              style={{ objectFit: 'cover' }}
              controls
              playsInline
            />
          ) : (
            <img
              src={mediaPreviewUrl ?? draft.mediaUrl}
              alt="Story preview"
              className="story-preview-media"
              style={{ objectFit: 'contain', objectPosition: 'center center', background: '#020617' }}
            />
          )
        ) : null}

        {draft.caption ? (
          <div
            className={`story-preview-caption${isDraggable ? ' draggable' : ''}`}
            style={{
              color: draft.textColor,
              fontSize: `${draft.fontSize}px`,
              fontWeight: draft.fontWeight,
              textAlign: draft.textAlign,
              left: `${draft.overlayX}%`,
              top: `${draft.overlayY}%`,
              transform: `translate(-50%, -50%) scale(${draft.overlayScale ?? 1}) rotate(${draft.overlayRotation ?? 0}deg)`,
            }}
            onPointerDown={isDraggable ? startDrag : undefined}
            onPointerUp={isDraggable ? () => {
              dragStateRef.current = null;
            } : undefined}
            onPointerCancel={isDraggable ? () => {
              dragStateRef.current = null;
            } : undefined}
          >
            {draft.caption}
          </div>
        ) : null}
      </div>
    </div>
  );
}

function clampPercent(value: number) {
  return Math.min(97, Math.max(3, value));
}
