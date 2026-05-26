export function StoryTextOverlay({
  value,
  onChange,
  textColor,
  onTextColorChange,
  fontSize,
  onFontSizeChange,
  fontWeight,
  onFontWeightChange,
  textAlign,
  onTextAlignChange,
  overlayX,
  onOverlayXChange,
  overlayY,
  onOverlayYChange,
}: {
  value: string;
  onChange: (value: string) => void;
  textColor: string;
  onTextColorChange: (value: string) => void;
  fontSize: number;
  onFontSizeChange: (value: number) => void;
  fontWeight: number;
  onFontWeightChange: (value: number) => void;
  textAlign: 'left' | 'center' | 'right';
  onTextAlignChange: (value: 'left' | 'center' | 'right') => void;
  overlayX?: number;
  onOverlayXChange?: (value: number) => void;
  overlayY?: number;
  onOverlayYChange?: (value: number) => void;
}) {
  return (
    <div className="story-text-overlay-editor">
      <textarea
        className="story-text-input"
        value={value}
        onChange={event => onChange(event.target.value)}
        placeholder="Viết nội dung story..."
      />
      <div className="story-text-controls">
        <label className="story-field">
          <span className="story-field-label">Màu chữ</span>
          <input className="story-color-input" type="color" value={textColor} onChange={event => onTextColorChange(event.target.value)} />
        </label>
        <label className="story-field story-field-wide">
          <span className="story-field-label">Font size</span>
          <input className="story-range-input" type="range" min="18" max="52" value={fontSize} onChange={event => onFontSizeChange(Number(event.target.value))} />
        </label>
        <label className="story-field story-field-wide">
          <span className="story-field-label">Weight</span>
          <input className="story-range-input" type="range" min="300" max="900" step="100" value={fontWeight} onChange={event => onFontWeightChange(Number(event.target.value))} />
        </label>
        <div className="story-field story-field-wide">
          <span className="story-field-label">Align</span>
          <div className="story-align-group" role="group" aria-label="Text alignment">
            <button type="button" className={`story-align-btn ${textAlign === 'left' ? 'active' : ''}`} onClick={() => onTextAlignChange('left')}>
              Left
            </button>
            <button type="button" className={`story-align-btn ${textAlign === 'center' ? 'active' : ''}`} onClick={() => onTextAlignChange('center')}>
              Center
            </button>
            <button type="button" className={`story-align-btn ${textAlign === 'right' ? 'active' : ''}`} onClick={() => onTextAlignChange('right')}>
              Right
            </button>
          </div>
        </div>
        {typeof overlayX === 'number' && onOverlayXChange && typeof overlayY === 'number' && onOverlayYChange ? (
          <>
            <label className="story-field story-field-wide">
              <span className="story-field-label">Vị trí ngang</span>
              <input className="story-range-input" type="range" min="0" max="100" value={overlayX} onChange={event => onOverlayXChange(Number(event.target.value))} />
            </label>
            <label className="story-field story-field-wide">
              <span className="story-field-label">Vị trí dọc</span>
              <input className="story-range-input" type="range" min="0" max="100" value={overlayY} onChange={event => onOverlayYChange(Number(event.target.value))} />
            </label>
          </>
        ) : null}
      </div>
    </div>
  );
}
