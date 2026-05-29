export function CreateStoryCard({ onClick }: { onClick: () => void }) {
  return (
    <button type="button" className="story-create-panel" onClick={onClick}>
      <div className="story-create-panel-avatar">
        +
      </div>
      <div className="story-create-panel-meta">
        <div className="story-create-panel-title">Tạo tin</div>
        <div className="story-create-panel-subtitle">Chia sẻ ảnh, video hoặc viết gì đó</div>
      </div>
    </button>
  );
}
