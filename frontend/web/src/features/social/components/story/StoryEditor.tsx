import { useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react';
import { StoryCropper } from './StoryCropper';
import { StoryPreview } from './StoryPreview';
import { StoryTextOverlay } from './StoryTextOverlay';
import { getCroppedImage } from '../../utils/storyCrop';
import type { StoryDraft } from '../../store/story.store';
import { uploadStoryMedia, socialApi } from '../../api/social.api';

const STORY_WIDTH = 1080;
const STORY_HEIGHT = 1920;

export function StoryEditor({
  token,
  draft,
  onDraftChange,
  onPublished,
}: {
  token: string;
  draft: StoryDraft;
  onDraftChange: (draft: StoryDraft) => void;
  onPublished: () => void;
}) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<{ x: number; y: number; width: number; height: number } | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [previewCroppedUrl, setPreviewCroppedUrl] = useState<string | null>(null);
  const [previewTextUrl, setPreviewTextUrl] = useState<string | null>(null);

  const gradientOptions = [
    'linear-gradient(180deg, #0f172a 0%, #111827 50%, #030712 100%)',
    'linear-gradient(180deg, #1d4ed8 0%, #0f172a 50%, #111827 100%)',
    'linear-gradient(180deg, #7c3aed 0%, #1f2937 50%, #111827 100%)',
    'linear-gradient(180deg, #ef4444 0%, #7c2d12 50%, #1f2937 100%)',
    'linear-gradient(180deg, #059669 0%, #064e3b 50%, #111827 100%)',
  ];

  const canPublish = useMemo(() => {
    if (draft.mode === 'text') {
      return draft.caption.trim().length > 0;
    }
    return Boolean(draft.mediaUrl);
  }, [draft]);

  const previewAspectRatio = croppedAreaPixels && draft.mode === 'media' && draft.mediaType === 'image'
    ? croppedAreaPixels.width / croppedAreaPixels.height
    : null;

  const handlePickFile = () => fileInputRef.current?.click();

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    const url = URL.createObjectURL(file);
    const mediaType = file.type.startsWith('video/') ? 'video' : 'image';
    setCroppedAreaPixels(null);
    setPreviewCroppedUrl(current => {
      if (current) URL.revokeObjectURL(current);
      return null;
    });
    onDraftChange({ ...draft, mode: 'media', mediaUrl: url, mediaType, caption: draft.caption });
  };

  useEffect(() => {
    let cancelled = false;

    async function updatePreviewCrop() {
      if (draft.mode !== 'media' || draft.mediaType !== 'image' || !draft.mediaUrl || !croppedAreaPixels) {
        setPreviewCroppedUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return null;
        });
        return;
      }

      try {
        const blob = await getCroppedImage(draft.mediaUrl, croppedAreaPixels, 'image/jpeg', 0.92);
        if (cancelled) return;

        const nextUrl = URL.createObjectURL(blob);
        setPreviewCroppedUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return nextUrl;
        });
      } catch {
        if (cancelled) return;
        setPreviewCroppedUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return null;
        });
      }
    }

    void updatePreviewCrop();

    return () => {
      cancelled = true;
    };
  }, [draft.mode, draft.mediaType, draft.mediaUrl, croppedAreaPixels]);

  useEffect(() => {
    let cancelled = false;

    async function updateTextPreview() {
      if (draft.mode !== 'text' || !draft.caption.trim()) {
        setPreviewTextUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return null;
        });
        return;
      }

      try {
        const blob = await renderTextStoryBlob(draft);
        if (cancelled) return;

        const nextUrl = URL.createObjectURL(blob);
        setPreviewTextUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return nextUrl;
        });
      } catch {
        if (cancelled) return;
        setPreviewTextUrl(current => {
          if (current) URL.revokeObjectURL(current);
          return null;
        });
      }
    }

    void updateTextPreview();

    return () => {
      cancelled = true;
    };
  }, [draft]);

  const publishStory = async () => {
    if (!canPublish || isSaving) return;
    setIsSaving(true);
    try {
      let mediaUrl = draft.mediaUrl;

      if (draft.mode === 'text') {
        const storyBlob = await renderTextStoryBlob(draft);
        const storyFile = new File([storyBlob], `story-${Date.now()}.jpg`, { type: 'image/jpeg' });
        mediaUrl = await uploadStoryMedia(token, storyFile);
      } else if (draft.mode === 'media' && draft.mediaUrl && draft.mediaType === 'image') {
        const storyBlob = await renderMediaStoryBlob(draft, croppedAreaPixels);
        const storyFile = new File([storyBlob], `story-${Date.now()}.jpg`, { type: 'image/jpeg' });
        mediaUrl = await uploadStoryMedia(token, storyFile);
      } else if (draft.mode === 'media' && draft.mediaUrl && draft.mediaType === 'video' && draft.mediaUrl.startsWith('blob:')) {
        const response = await fetch(draft.mediaUrl);
        const blob = await response.blob();
        const file = new File([blob], `story-${Date.now()}.mp4`, { type: blob.type || 'video/mp4' });
        mediaUrl = await uploadStoryMedia(token, file);
      }

      if (!mediaUrl) {
        throw new Error('Media URL is missing.');
      }

      await socialApi.createStory(token, {
        mediaUrl,
        caption: draft.caption,
        visibility: 'PUBLIC',
      });
      onPublished();
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="story-editor-shell">
      <div className="story-editor-topbar">
        <div className="story-editor-title">Tạo tin</div>
        <div className="story-editor-actions">
          <button type="button" className="story-btn" onClick={handlePickFile}>Chọn ảnh/video</button>
          <button type="button" className="story-btn primary" onClick={publishStory} disabled={!canPublish || isSaving}>
            {isSaving ? 'Đang đăng...' : 'Đăng tin'}
          </button>
        </div>
        <input ref={fileInputRef} type="file" accept="image/*,video/*" hidden onChange={handleFileChange} />
      </div>

      <div className="story-editor-body">
        <div className="story-editor-left">
          <div className="story-editor-card">
            <div className="story-editor-section-title">Ảnh/Video</div>
            {draft.mode === 'media' && draft.mediaUrl ? (
              <>
                <div className="story-overlay-editor-block">
                  <div className="story-editor-section-subtitle">Nhập chữ đè lên ảnh</div>
                  <StoryTextOverlay
                    value={draft.caption}
                    onChange={caption => onDraftChange({ ...draft, caption })}
                    textColor={draft.textColor}
                    onTextColorChange={textColor => onDraftChange({ ...draft, textColor })}
                    fontSize={draft.fontSize}
                    onFontSizeChange={fontSize => onDraftChange({ ...draft, fontSize })}
                    fontWeight={draft.fontWeight}
                    onFontWeightChange={fontWeight => onDraftChange({ ...draft, fontWeight })}
                    textAlign={draft.textAlign}
                    onTextAlignChange={textAlign => onDraftChange({ ...draft, textAlign })}
                    overlayX={draft.overlayX}
                    onOverlayXChange={overlayX => onDraftChange({ ...draft, overlayX })}
                    overlayY={draft.overlayY}
                    onOverlayYChange={overlayY => onDraftChange({ ...draft, overlayY })}
                  />
                </div>
              </>
            ) : draft.mode === 'text' ? (
              <>
                <div className="story-type-selector story-type-selector-inline">
                  {gradientOptions.map(option => (
                    <button
                      key={option}
                      type="button"
                      className={`story-type-card gradient-chip ${draft.background === option ? 'active' : ''}`}
                      onClick={() => onDraftChange({ ...draft, background: option })}
                      style={{ background: option }}
                    >
                      <span className="story-type-title">&nbsp;</span>
                    </button>
                  ))}
                </div>
                <StoryTextOverlay
                  value={draft.caption}
                  onChange={caption => onDraftChange({ ...draft, caption })}
                  textColor={draft.textColor}
                  onTextColorChange={textColor => onDraftChange({ ...draft, textColor })}
                  fontSize={draft.fontSize}
                  onFontSizeChange={fontSize => onDraftChange({ ...draft, fontSize })}
                  fontWeight={draft.fontWeight}
                  onFontWeightChange={fontWeight => onDraftChange({ ...draft, fontWeight })}
                  textAlign={draft.textAlign}
                  onTextAlignChange={textAlign => onDraftChange({ ...draft, textAlign })}
                  overlayX={draft.overlayX}
                  onOverlayXChange={overlayX => onDraftChange({ ...draft, overlayX })}
                  overlayY={draft.overlayY}
                  onOverlayYChange={overlayY => onDraftChange({ ...draft, overlayY })}
                />
              </>
            ) : (
              <div className="story-empty-placeholder">Chọn ảnh/video hoặc chuyển sang tin dạng văn bản để bắt đầu</div>
            )}
          </div>
        </div>

        <div className="story-editor-right">
          <div className="story-editor-card story-editor-crop-card">
            <div className="story-editor-section-title">{draft.mode === 'text' ? 'Preview' : 'Crop ảnh'}</div>
            {draft.mode === 'text' ? (
              <div className="story-preview-section story-preview-section-text">
                <div className="story-preview-stage story-preview-stage-text">
                  <div className="story-preview-text-frame">
                    {previewTextUrl ? (
                      <img src={previewTextUrl} alt="Story text preview" className="story-preview-media story-preview-media-image" />
                    ) : null}
                  </div>
                </div>
              </div>
            ) : draft.mode === 'media' && draft.mediaUrl ? (
              draft.mediaType === 'image' ? (
                <>
                  <div className="story-cropper-wrap story-cropper-top">
                    <StoryCropper
                      image={draft.mediaUrl}
                      onCropComplete={pixels => setCroppedAreaPixels(pixels)}
                    />
                  </div>
                  <div className="story-crop-hint">Kéo khung để di chuyển, kéo 4 góc để crop tự do.</div>
                  <div className="story-preview-section">
                    <div className="story-editor-section-title">Preview</div>
                    <StoryPreview
                      draft={draft}
                      mediaPreviewUrl={previewCroppedUrl}
                      previewAspectRatio={previewAspectRatio}
                      onOverlayChange={(next: { overlayX: number; overlayY: number }) =>
                        onDraftChange({ ...draft, overlayX: next.overlayX, overlayY: next.overlayY })}
                    />
                  </div>
                </>
              ) : (
                <div className="story-preview-section">
                  <div className="story-editor-section-title">Preview</div>
                  <StoryPreview
                    draft={draft}
                    previewAspectRatio={null}
                    onOverlayChange={(next: { overlayX: number; overlayY: number }) =>
                      onDraftChange({ ...draft, overlayX: next.overlayX, overlayY: next.overlayY })}
                  />
                </div>
              )
            ) : (
              <div className="story-empty-placeholder">Chọn ảnh/video để bắt đầu crop và preview.</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

async function renderTextStoryBlob(draft: StoryDraft): Promise<Blob> {
  const canvas = document.createElement('canvas');
  canvas.width = STORY_WIDTH;
  canvas.height = STORY_HEIGHT;

  const context = canvas.getContext('2d');
  if (!context) {
    throw new Error('Canvas 2D context is not available.');
  }

  const gradient = context.createLinearGradient(0, 0, 0, STORY_HEIGHT);
  const colorStops = extractGradientStops(draft.background);
  if (colorStops.length >= 2) {
    colorStops.forEach(([offset, color]) => gradient.addColorStop(offset, color));
  } else {
    gradient.addColorStop(0, '#0f172a');
    gradient.addColorStop(1, '#030712');
  }

  context.fillStyle = gradient;
  context.fillRect(0, 0, STORY_WIDTH, STORY_HEIGHT);

  context.fillStyle = 'rgba(255, 255, 255, 0.08)';
  context.fillRect(72, 72, STORY_WIDTH - 144, STORY_HEIGHT - 144);

  context.textAlign = draft.textAlign;
  context.textBaseline = 'middle';
  context.fillStyle = draft.textColor || '#ffffff';
  context.font = `${draft.fontWeight} ${draft.fontSize * 2}px Inter, system-ui, sans-serif`;

  const lines = wrapCanvasText(context, draft.caption.trim(), STORY_WIDTH * 0.66);
  const lineHeight = draft.fontSize * 2.25;
  const blockHeight = (lines.length - 1) * lineHeight;
  const startY = STORY_HEIGHT * (draft.overlayY / 100) - blockHeight / 2;
  const centerX = STORY_WIDTH * (draft.overlayX / 100);

  lines.forEach((line, index) => {
    context.fillText(line, centerX, startY + index * lineHeight);
  });

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(blob => {
      if (!blob) {
        reject(new Error('Failed to render text story.'));
        return;
      }
      resolve(blob);
    }, 'image/jpeg', 0.95);
  });
}

async function renderMediaStoryBlob(
  draft: StoryDraft,
  croppedAreaPixels: { x: number; y: number; width: number; height: number } | null,
): Promise<Blob> {
  if (!draft.mediaUrl) {
    throw new Error('Media URL is missing.');
  }

  const image = await loadImage(draft.mediaUrl);
  const canvas = document.createElement('canvas');
  canvas.width = STORY_WIDTH;
  canvas.height = STORY_HEIGHT;

  const context = canvas.getContext('2d');
  if (!context) {
    throw new Error('Canvas 2D context is not available.');
  }

  context.fillStyle = '#020617';
  context.fillRect(0, 0, STORY_WIDTH, STORY_HEIGHT);

  const source = croppedAreaPixels ?? {
    x: 0,
    y: 0,
    width: image.naturalWidth,
    height: image.naturalHeight,
  };

  const mediaBounds = drawContainedImage(context, image, source);

  if (draft.caption.trim()) {
    drawCaption(context, draft, mediaBounds);
  }

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(blob => {
      if (!blob) {
        reject(new Error('Failed to render media story.'));
        return;
      }
      resolve(blob);
    }, 'image/jpeg', 0.92);
  });
}

function drawContainedImage(
  context: CanvasRenderingContext2D,
  image: HTMLImageElement,
  source: { x: number; y: number; width: number; height: number },
) {
  const scale = Math.min(STORY_WIDTH / source.width, STORY_HEIGHT / source.height);
  const drawWidth = source.width * scale;
  const drawHeight = source.height * scale;
  const drawX = (STORY_WIDTH - drawWidth) / 2;
  const drawY = (STORY_HEIGHT - drawHeight) / 2;

  context.drawImage(
    image,
    source.x,
    source.y,
    source.width,
    source.height,
    drawX,
    drawY,
    drawWidth,
    drawHeight,
  );

  return { x: drawX, y: drawY, width: drawWidth, height: drawHeight };
}

function drawCaption(
  context: CanvasRenderingContext2D,
  draft: StoryDraft,
  mediaBounds?: { x: number; y: number; width: number; height: number },
) {
  context.textAlign = draft.textAlign;
  context.textBaseline = 'middle';
  context.fillStyle = draft.textColor || '#ffffff';
  context.font = `${draft.fontWeight} ${draft.fontSize * 2}px Inter, system-ui, sans-serif`;

  const lines = wrapCanvasText(context, draft.caption.trim(), STORY_WIDTH * 0.66);
  const lineHeight = draft.fontSize * 2.25;
  const blockHeight = (lines.length - 1) * lineHeight;
  const availableWidth = mediaBounds?.width ?? STORY_WIDTH;
  const availableHeight = mediaBounds?.height ?? STORY_HEIGHT;
  const startX = mediaBounds?.x ?? 0;
  const startYOrigin = mediaBounds?.y ?? 0;
  const startY = startYOrigin + availableHeight * (draft.overlayY / 100) - blockHeight / 2;
  const centerX = startX + availableWidth * (draft.overlayX / 100);

  lines.forEach((line, index) => {
    context.fillText(line, centerX, startY + index * lineHeight);
  });
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = 'anonymous';
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('Failed to load image.'));
    image.src = src;
  });
}

function extractGradientStops(background: string): Array<[number, string]> {
  const matches = [...background.matchAll(/(rgba?\([^)]*\)|#[0-9a-fA-F]{3,8})/g)].map(match => match[1]);
  if (matches.length === 0) {
    return [];
  }

  if (matches.length === 1) {
    return [[0, matches[0]], [1, matches[0]]];
  }

  return matches.map((color, index) => [index / (matches.length - 1), color] as [number, string]);
}

function wrapCanvasText(context: CanvasRenderingContext2D, text: string, maxWidth: number): string[] {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length === 0) {
    return [''];
  }

  const lines: string[] = [];
  let currentLine = words[0];

  for (let index = 1; index < words.length; index += 1) {
    const nextLine = `${currentLine} ${words[index]}`;
    if (context.measureText(nextLine).width <= maxWidth) {
      currentLine = nextLine;
    } else {
      lines.push(currentLine);
      currentLine = words[index];
    }
  }

  lines.push(currentLine);
  return lines;
}
