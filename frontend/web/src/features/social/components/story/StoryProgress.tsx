import type { Story } from '../../api/social.api';

type StoryProgressProps = {
  stories: Story[];
  activeIndex: number;
  isPaused: boolean;
};

export function StoryProgress({ stories, activeIndex, isPaused }: StoryProgressProps) {
  return (
    <div className="story-viewer-progress">
      {stories.map((story, storyIndex) => (
        <div
          key={story.storyId}
          className={`story-viewer-progress-track ${storyIndex === activeIndex ? 'active' : ''} ${storyIndex < activeIndex ? 'done' : ''}`}
        >
          <div
            className={`story-viewer-progress-fill ${storyIndex === activeIndex ? 'active' : ''} ${storyIndex < activeIndex ? 'done' : ''} ${isPaused && storyIndex === activeIndex ? 'paused' : ''}`}
            style={storyIndex === activeIndex ? { animationPlayState: isPaused ? 'paused' : 'running' } : undefined}
          />
        </div>
      ))}
    </div>
  );
}
