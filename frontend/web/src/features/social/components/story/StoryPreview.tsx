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

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    if (!onOverlayChange || !frameRef.current) return;
    const rect = frameRef.current.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width) * 100;
    const y = ((event.clientY - rect.top) / rect.height) * 100;
    onOverlayChange({ overlayX: clampPercent(x), overlayY: clampPercent(y) });
  };

  // allow dragging when a handler is provided (media and text modes)
  const isDraggable = Boolean(onOverlayChange);
  const resolvedAspectRatio = draft.mode === 'media' && draft.mediaType === 'image' && previewAspectRatio
    ? previewAspectRatio
    : 9 / 16;

  return (
    <div
      className="story-preview-stage"
      style={{ background: draft.mode === 'text' ? draft.background : '#030712' }}
    >
      <div ref={frameRef} className="story-preview-frame" style={{ aspectRatio: `${resolvedAspectRatio}` }} onClick={handleClick}>
        {
          // If a rendered preview image is provided (text-mode), show it first
          mediaPreviewUrl ? (
            <img
              src={mediaPreviewUrl}
              alt="Story preview"
              className="story-preview-media"
              style={{ objectFit: 'contain', objectPosition: 'center center', background: '#020617' }}
            />
          ) : draft.mode === 'media' && draft.mediaUrl ? (
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
                src={draft.mediaUrl}
                alt="Story preview"
                className="story-preview-media"
                style={{ objectFit: 'contain', objectPosition: 'center center', background: '#020617' }}
              />
            )
          ) : null
        }

        {draft.caption ? (
          <div
            className={`story-preview-caption${isDraggable ? ' draggable' : ''}`}
            draggable={false}
            onDragStart={e => e.preventDefault()}
            style={{
              color: getReadablePreviewColor(draft.textColor),
              fontSize: `${draft.fontSize}px`,
              fontWeight: draft.fontWeight,
              textAlign: draft.textAlign,
              left: `${draft.overlayX}%`,
              top: `${draft.overlayY}%`,
              transform: `translate(-50%, -50%) scale(${draft.overlayScale ?? 1}) rotate(${draft.overlayRotation ?? 0}deg)`,
              userSelect: 'none',
              WebkitUserSelect: 'none',
              MozUserSelect: 'none',
              msUserSelect: 'none',
              touchAction: 'none',
              cursor: isDraggable ? 'grab' : undefined,
              textShadow: '0 2px 10px rgba(0, 0, 0, 0.45)',
            }}
            onPointerDown={isDraggable ? (e) => {
              startDrag(e);
              // change cursor to grabbing while dragging
              try { (e.currentTarget as HTMLElement).style.cursor = 'grabbing'; } catch {}
            } : undefined}
            onPointerUp={isDraggable ? (e) => {
              dragStateRef.current = null;
              try { (e.currentTarget as HTMLElement).style.cursor = 'grab'; } catch {}
            } : undefined}
            onPointerCancel={isDraggable ? (e) => {
              dragStateRef.current = null;
              try { (e.currentTarget as HTMLElement).style.cursor = 'grab'; } catch {}
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

function getReadablePreviewColor(color: string) {
  const hex = color.trim();

  if (!hex.startsWith('#') || (hex.length !== 4 && hex.length !== 7)) {
    return hex || '#ffffff';
  }

  const expanded = hex.length === 4
    ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`
    : hex;

  const red = Number.parseInt(expanded.slice(1, 3), 16);
  const green = Number.parseInt(expanded.slice(3, 5), 16);
  const blue = Number.parseInt(expanded.slice(5, 7), 16);
  const luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue);

  return luminance < 140 ? '#ffffff' : expanded;
}
