import { useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';

export type FreeformCropArea = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type CropHandle = 'nw' | 'ne' | 'sw' | 'se';

const MIN_CROP_SIZE = 12;
const DEFAULT_CROP_MARGIN = 8;

export function StoryCropper({
  image,
  onCropComplete,
}: {
  image: string;
  onCropComplete: (croppedAreaPixels: FreeformCropArea) => void;
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const imageRef = useRef<HTMLImageElement | null>(null);
  const [containerSize, setContainerSize] = useState({ width: 0, height: 0 });
  const [naturalSize, setNaturalSize] = useState({ width: 0, height: 0 });
  const [cropRect, setCropRect] = useState<FreeformCropArea | null>(null);
  const onCropCompleteRef = useRef(onCropComplete);
  const dragStateRef = useRef<{
    type: 'move' | CropHandle;
    startX: number;
    startY: number;
    startRect: FreeformCropArea;
  } | null>(null);

  useEffect(() => {
    onCropCompleteRef.current = onCropComplete;
  }, [onCropComplete]);

  useEffect(() => {
    const element = containerRef.current;
    if (!element) return;

    const updateSize = () => {
      setContainerSize({ width: element.clientWidth, height: element.clientHeight });
    };

    updateSize();

    const observer = new ResizeObserver(updateSize);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    setCropRect(null);
  }, [image]);

  const imageBox = useMemo(() => {
    if (!containerSize.width || !containerSize.height || !naturalSize.width || !naturalSize.height) {
      return null;
    }

    const containerRatio = containerSize.width / containerSize.height;
    const imageRatio = naturalSize.width / naturalSize.height;

    if (imageRatio > containerRatio) {
      const width = containerSize.width;
      const height = width / imageRatio;
      return {
        x: 0,
        y: (containerSize.height - height) / 2,
        width,
        height,
      };
    }

    const height = containerSize.height;
    const width = height * imageRatio;
    return {
      x: (containerSize.width - width) / 2,
      y: 0,
      width,
      height,
    };
  }, [containerSize.height, containerSize.width, naturalSize.height, naturalSize.width]);

  useEffect(() => {
    if (!imageBox) return;

    const defaultRect: FreeformCropArea = {
      x: DEFAULT_CROP_MARGIN,
      y: DEFAULT_CROP_MARGIN,
      width: 100 - DEFAULT_CROP_MARGIN * 2,
      height: 100 - DEFAULT_CROP_MARGIN * 2,
    };

    setCropRect(current => current ?? defaultRect);
  }, [imageBox]);

  useEffect(() => {
    if (!imageBox || !cropRect || !naturalSize.width || !naturalSize.height) return;

    onCropCompleteRef.current({
      x: (cropRect.x / 100) * naturalSize.width,
      y: (cropRect.y / 100) * naturalSize.height,
      width: (cropRect.width / 100) * naturalSize.width,
      height: (cropRect.height / 100) * naturalSize.height,
    });
  }, [cropRect, imageBox, naturalSize.height, naturalSize.width]);

  const startInteraction = (type: 'move' | CropHandle, event: ReactPointerEvent<HTMLElement>) => {
    if (!cropRect) return;
    event.preventDefault();
    event.stopPropagation();
    (event.currentTarget as HTMLDivElement).setPointerCapture(event.pointerId);
    dragStateRef.current = {
      type,
      startX: event.clientX,
      startY: event.clientY,
      startRect: cropRect,
    };
  };

  const updateInteraction = (event: ReactPointerEvent<HTMLElement>) => {
    const dragState = dragStateRef.current;
    if (!dragState || !imageBox) return;

    const deltaXPercent = ((event.clientX - dragState.startX) / imageBox.width) * 100;
    const deltaYPercent = ((event.clientY - dragState.startY) / imageBox.height) * 100;

    setCropRect(current => {
      if (!current) return current;

      const base = dragState.startRect;

      if (dragState.type === 'move') {
        const nextX = clamp(base.x + deltaXPercent, 0, 100 - base.width);
        const nextY = clamp(base.y + deltaYPercent, 0, 100 - base.height);
        return { ...base, x: nextX, y: nextY };
      }

      const next = resizeRect(base, dragState.type, deltaXPercent, deltaYPercent);
      return clampRect(next);
    });
  };

  const endInteraction = () => {
    dragStateRef.current = null;
  };

  const cropStyle = cropRect && imageBox
    ? {
        left: `${imageBox.x + (cropRect.x / 100) * imageBox.width}px`,
        top: `${imageBox.y + (cropRect.y / 100) * imageBox.height}px`,
        width: `${(cropRect.width / 100) * imageBox.width}px`,
        height: `${(cropRect.height / 100) * imageBox.height}px`,
      }
    : undefined;

  return (
    <div ref={containerRef} className="story-cropper freeform-cropper">
      <img
        ref={imageRef}
        src={image}
        alt="Story crop"
        className="story-cropper-image"
        onLoad={event => {
          setNaturalSize({
            width: event.currentTarget.naturalWidth,
            height: event.currentTarget.naturalHeight,
          });
        }}
      />

      {cropStyle && (
        <div
          className="story-crop-frame"
          style={cropStyle}
          onPointerDown={event => startInteraction('move', event)}
          onPointerMove={updateInteraction}
          onPointerUp={endInteraction}
          onPointerCancel={endInteraction}
        >
          <span className="story-crop-grid" />
          <button type="button" className="story-crop-handle nw" onPointerDown={event => startInteraction('nw', event)} aria-label="Resize crop top left" />
          <button type="button" className="story-crop-handle ne" onPointerDown={event => startInteraction('ne', event)} aria-label="Resize crop top right" />
          <button type="button" className="story-crop-handle sw" onPointerDown={event => startInteraction('sw', event)} aria-label="Resize crop bottom left" />
          <button type="button" className="story-crop-handle se" onPointerDown={event => startInteraction('se', event)} aria-label="Resize crop bottom right" />
        </div>
      )}
    </div>
  );
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function clampRect(rect: FreeformCropArea): FreeformCropArea {
  const width = clamp(rect.width, MIN_CROP_SIZE, 100);
  const height = clamp(rect.height, MIN_CROP_SIZE, 100);
  const x = clamp(rect.x, 0, 100 - width);
  const y = clamp(rect.y, 0, 100 - height);
  return { x, y, width, height };
}

function resizeRect(rect: FreeformCropArea, handle: CropHandle, deltaX: number, deltaY: number): FreeformCropArea {
  switch (handle) {
    case 'nw': {
      const x = rect.x + deltaX;
      const y = rect.y + deltaY;
      const width = rect.width - deltaX;
      const height = rect.height - deltaY;
      return { x, y, width, height };
    }
    case 'ne': {
      const y = rect.y + deltaY;
      const width = rect.width + deltaX;
      const height = rect.height - deltaY;
      return { x: rect.x, y, width, height };
    }
    case 'sw': {
      const x = rect.x + deltaX;
      const width = rect.width - deltaX;
      const height = rect.height + deltaY;
      return { x, y: rect.y, width, height };
    }
    case 'se':
    default:
      return {
        x: rect.x,
        y: rect.y,
        width: rect.width + deltaX,
        height: rect.height + deltaY,
      };
  }
}
