import React, { useEffect, useState } from 'react';
import { UserAvatar } from '../../../shared/components/UserAvatar';

interface MentionPopoverProps {
  members: Array<{ userId: string; displayName: string; avatarUrl?: string | null }>;
  filter: string;
  onSelect: (member: { userId: string; displayName: string }) => void;
  onClose: () => void;
  position: { top: number; left: number };
}

export const MentionPopover: React.FC<MentionPopoverProps> = ({ 
  members, 
  filter, 
  onSelect, 
  onClose,
  position 
}) => {
  const [selectedIndex, setSelectedIndex] = useState(0);

  const specialOptions = [
    { userId: 'all', displayName: 'All', subText: 'Báo cho cả nhóm', icon: 'at' },
  ];

  const filteredMembers = (members || []).filter(m => 
    (m.displayName || '').toLowerCase().includes((filter || '').toLowerCase())
  );

  const allOptions = [
    ...(filter === '' || 'all'.includes(filter.toLowerCase()) ? specialOptions : []),
    ...filteredMembers
  ];

  useEffect(() => {
    setSelectedIndex(0);
  }, [filter]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelectedIndex(prev => (prev + 1) % allOptions.length);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelectedIndex(prev => (prev - 1 + allOptions.length) % allOptions.length);
      } else if (e.key === 'Enter' || e.key === 'Tab') {
        if (allOptions[selectedIndex]) {
          e.preventDefault();
          onSelect(allOptions[selectedIndex]);
        }
      } else if (e.key === 'Escape') {
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [allOptions, selectedIndex, onSelect, onClose]);

  if (allOptions.length === 0) return null;

  return (
    <div 
      className="absolute z-50 bg-white dark:bg-[#1E1E2E] rounded-lg shadow-xl border border-slate-200 dark:border-white/10 w-72 overflow-hidden mb-2"
      style={{ 
        bottom: '100%', 
        left: position.left,
        maxHeight: '320px'
      }}
    >
      <div className="overflow-y-auto">
        {allOptions.map((option, index) => (
          <div
            key={option.userId}
            className={`flex items-center gap-3 p-3 cursor-pointer transition-colors ${
              index === selectedIndex ? 'bg-blue-50 dark:bg-blue-500/10' : 'hover:bg-slate-50 dark:hover:bg-white/5 transition-colors'
            }`}
            onClick={() => onSelect(option)}
            onMouseEnter={() => setSelectedIndex(index)}
          >
            { (option as any).icon === 'at' ? (
              <div className="w-10 h-10 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold">
                @
              </div>
            ) : (
              <UserAvatar 
                name={option.displayName} 
                imageUrl={(option as any).avatarUrl} 
                size="md" 
              />
            )}
            <div className="flex flex-col min-w-0">
              <span className="font-semibold text-slate-800 dark:text-slate-100 text-[15px] truncate">
                {option.userId === 'all' ? `@${option.displayName}` : option.displayName}
              </span>
              {(option as any).subText && (
                <span className="text-[12px] text-slate-500 dark:text-slate-400 truncate">{(option as any).subText}</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
