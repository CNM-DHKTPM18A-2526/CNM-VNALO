import { StoryListItem, type StoryGroupItem } from './StoryListItem';

export function StoryList({
  groups,
  currentStoryId,
  currentUserId,
  authorProfiles,
  onSelectStory,
}: {
  groups: StoryGroupItem[];
  currentStoryId: string;
  currentUserId: string | null;
  authorProfiles: Record<string, { displayName: string; avatarUrl: string | null }>;
  onSelectStory: (storyId: string) => void;
}) {
  return (
    <div className="story-list">
      {groups.map(group => {
        const profile = authorProfiles[group.authorId] ?? null;
        const displayName = group.authorId === currentUserId ? 'Bạn' : (profile?.displayName || `User ${group.authorId.substring(0, 4)}`);
        const avatarUrl = profile?.avatarUrl ?? null;

        return (
          <StoryListItem
            key={group.authorId}
            group={group}
            currentStoryId={currentStoryId}
            currentUserId={currentUserId}
            displayName={displayName}
            avatarUrl={avatarUrl}
            onClick={() => onSelectStory(group.stories[group.stories.length - 1].storyId)}
          />
        );
      })}
    </div>
  );
}
