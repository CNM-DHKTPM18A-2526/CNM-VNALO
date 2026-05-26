export type StoryTypeSelectorValue = 'media' | 'text';

export function StoryTypeSelector({
  value,
  onChange,
}: {
  value: StoryTypeSelectorValue;
  onChange: (value: StoryTypeSelectorValue) => void;
}) {
  return (
    <div className="story-type-selector">
      <button
        type="button"
        className={`story-type-card ${value === 'media' ? 'active' : ''}`}
        onClick={() => onChange('media')}
      >
        <span className="story-type-title">Tạo tin có ảnh hoặc video</span>
      </button>
      <button
        type="button"
        className={`story-type-card ${value === 'text' ? 'active' : ''}`}
        onClick={() => onChange('text')}
      >
        <span className="story-type-title">Tạo tin dạng văn bản</span>
      </button>
    </div>
  );
}
