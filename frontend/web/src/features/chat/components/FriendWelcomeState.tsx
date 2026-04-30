import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { UserAvatar } from '../../../shared/components/UserAvatar';

import { DEFAULT_CHAT_STICKERS } from '../chat.stickers';

interface FriendWelcomeStateProps {
  currentUser: {
    displayName: string;
    avatarUrl?: string | null;
  };
  user: {
    id: string;
    displayName: string;
    avatarUrl?: string | null;
    bio?: string | null;
    recentImages?: string[];
  };
  onSendSticker: (sticker: { id: string; url: string; name: string }) => void;
  isStranger?: boolean;
}

export const FriendWelcomeState: React.FC<FriendWelcomeStateProps> = ({ currentUser, user, onSendSticker, isStranger }) => {
  const stickersToShow = DEFAULT_CHAT_STICKERS.slice(0, 3);
  return (
    <div className="friend-welcome-state flex flex-col items-center justify-center p-6 space-y-6 animate-in fade-in zoom-in duration-500">
      {/* Profile Card */}
      <div className="welcome-card rounded-2xl shadow-sm border overflow-hidden w-full max-w-[320px]">
        <div className="p-4 flex flex-col items-center text-center space-y-2">
          <UserAvatar name={user.displayName} imageUrl={user.avatarUrl} size="lg" className="w-16 h-16" />
          <h3 className="welcome-card-name font-bold">{user.displayName}</h3>
          <p className="welcome-card-bio text-xs line-clamp-2">
            {user.bio || 'Hãy bắt đầu cùng nhau chia sẻ những khoảnh khắc thú vị...'}
          </p>
        </div>
        
        {/* Gallery Preview (Optional) */}
        {user.recentImages && user.recentImages.length > 0 && (
          <div className="px-4 pb-4">
            <p className="welcome-gallery-label text-[10px] font-bold uppercase mb-2">Hình ảnh</p>
            <div className="grid grid-cols-3 gap-1.5">
              {user.recentImages.slice(0, 3).map((img, idx) => (
                <div key={idx} className="aspect-square rounded-lg overflow-hidden bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                  <img src={img} alt="" className="w-full h-full object-cover" />
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Date Separator */}
      <div className="flex items-center justify-center w-full">
        <span className="welcome-date-tag text-[10px] px-3 py-1 rounded-full font-medium">
          {new Date().toLocaleDateString('vi-VN')}
        </span>
      </div>

      {/* Welcome Banner */}
      <div className="welcome-banner rounded-2xl shadow-sm border p-6 w-full max-w-[400px] relative overflow-hidden">
        {/* Background Decorations */}
        <div className="absolute top-0 left-0 w-full h-full opacity-10 pointer-events-none">
          <div className="absolute top-2 left-4 rotate-12">💬</div>
          <div className="absolute bottom-4 right-6 -rotate-12">✨</div>
          <div className="absolute top-1/2 left-10 text-xl">🎈</div>
          <div className="absolute top-4 right-10 text-xl">🎉</div>
        </div>

        <div className="flex flex-col items-center text-center space-y-4 relative z-10">
          <div className="flex -space-x-2">
             <div className="w-10 h-10 rounded-full border-2 border-white dark:border-slate-800 overflow-hidden bg-slate-100 shadow-sm">
                <UserAvatar name={currentUser.displayName} imageUrl={currentUser.avatarUrl} size="sm" className="w-full h-full" />
             </div>
             <div className="w-10 h-10 rounded-full border-2 border-white dark:border-slate-800 overflow-hidden bg-slate-100 shadow-sm">
                <UserAvatar name={user.displayName} imageUrl={user.avatarUrl} size="sm" className="w-full h-full" />
             </div>
          </div>
          
          <div className="space-y-1">
            <h4 className="welcome-header-title font-bold">
              {isStranger 
                ? `Bắt đầu cuộc trò chuyện với ${user.displayName}`
                : `Bạn và ${user.displayName} đã trở thành bạn`}
            </h4>
            <p className="welcome-header-subtitle text-xs">Chọn một sticker dưới đây để bắt đầu trò chuyện</p>
          </div>

          {/* Sticker Selection */}
          <div className="flex items-center gap-2 w-full pt-2 group">
            <button className="welcome-sticker-nav p-1 text-slate-300 hover:text-slate-600 transition-colors opacity-0 group-hover:opacity-100">
              <ChevronLeft size={20} />
            </button>
            
            <div className="flex-1 flex justify-center gap-4">
              {stickersToShow.map((sticker) => (
                <button
                  key={sticker.id}
                  onClick={() => onSendSticker(sticker)}
                  className="w-16 h-16 transition-transform hover:scale-110 active:scale-95 bg-transparent border-0 cursor-pointer"
                >
                  <img src={sticker.url} alt={sticker.name} className="w-full h-full object-contain" />
                </button>
              ))}
            </div>

            <button className="welcome-sticker-nav p-1 text-slate-300 hover:text-slate-600 transition-colors opacity-0 group-hover:opacity-100">
              <ChevronRight size={20} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
