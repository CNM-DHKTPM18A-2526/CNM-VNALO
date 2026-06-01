import { Icon } from '../../../../shared/components/Icon';

type StoryNavigationProps = {
  direction: 'left' | 'right';
  onClick: () => void;
};

export function StoryNavigation({ direction, onClick }: StoryNavigationProps) {
  return (
    <button type="button" className={`story-nav-arrow story-nav-arrow-${direction}`} onClick={onClick} aria-label={direction === 'left' ? 'Story trước' : 'Story tiếp theo'}>
      <Icon name="chevronDown" size={22} className={direction === 'left' ? 'story-nav-icon story-nav-icon-left' : 'story-nav-icon story-nav-icon-right'} />
    </button>
  );
}
