import { useEffect, useState } from 'react';

export default function MediaLightbox({
  items,
  startIndex = 0,
  onClose,
}: {
  items: string[];
  startIndex?: number;
  onClose: () => void;
}) {
  const [index, setIndex] = useState(Math.max(0, Math.min(startIndex, items.length - 1)));

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowRight') setIndex(i => Math.min(items.length - 1, i + 1));
      if (e.key === 'ArrowLeft') setIndex(i => Math.max(0, i - 1));
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [items.length, onClose]);

  if (!items || items.length === 0) return null;

  const url = items[index];
  const isVideo = /\.(mp4|webm|ogg)(\?.*)?$/i.test(url);

  const prev = () => setIndex(i => (i - 1 + items.length) % items.length);
  const next = () => setIndex(i => (i + 1) % items.length);

  return (
    <div className="media-lightbox-overlay" onClick={onClose} role="dialog" aria-modal="true">
      <div className="media-lightbox-content" onClick={e => e.stopPropagation()}>
        <button className="lightbox-close" onClick={onClose} aria-label="Đóng">✕</button>
        <div className="lightbox-media-wrapper">
          {isVideo ? (
            <video src={url} controls className="lightbox-media" />
          ) : (
            // eslint-disable-next-line jsx-a11y/img-redundant-alt
            <img src={url} alt={`Media ${index + 1}`} className="lightbox-media" />
          )}
        </div>

        <div className="lightbox-controls">
          <button onClick={prev} aria-label="Trước" className="lightbox-nav">‹</button>
          <span className="lightbox-counter">{index + 1} / {items.length}</span>
          <button onClick={next} aria-label="Sau" className="lightbox-nav">›</button>
        </div>
      </div>
    </div>
  );
}
