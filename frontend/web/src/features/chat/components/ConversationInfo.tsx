import { useEffect, useMemo, useState } from 'react';
import {
  AlarmClock,
  BellOff,
  ChevronDown,
  CheckCircle2,
  EyeOff,
  FileText,
  Link2,
  Pencil,
  Pin,
  Timer,
  Trash2,
  TriangleAlert,
  UserPlus,
  UserPlus2,
  LogOut
} from 'lucide-react';

import { useAuth } from '../../auth/useAuth';
import type { ChatMessage, ConversationSummary } from '../chat.types';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { useUserStore } from '../context/UserStoreContext';
import { getGroupCollageData } from '../../../shared/utils/avatarUtils';

type ConversationInfoProps = {
  conversation: ConversationSummary;
  messages: ChatMessage[];
  onAddMembersClick?: () => void;
  onLeaveGroupClick?: () => void;
  onEditGroupName?: () => void;
  onEditNickname?: () => void;
  onDeleteHistoryClick?: () => void;
};

type SectionKey = 'media' | 'files' | 'links' | 'security';

export function ConversationInfo({
  conversation,
  messages,
  onAddMembersClick,
  onLeaveGroupClick,
  onEditGroupName,
  onEditNickname,
  onDeleteHistoryClick,
  onTogglePinConversation,
  onCreateGroupClick,
  currentUserId
}: ConversationInfoProps & {
  currentUserId?: string;
  onCreateGroupClick?: () => void;
  onTogglePinConversation?: () => void;
}) {
  const { userMap, ensureUser } = useUserStore();
  const { accessToken } = useAuth();
  const [expanded, setExpanded] = useState<Record<SectionKey, boolean>>({
    media: true,
    files: true,
    links: true,
    security: true,
  });
  const [isHidden, setIsHidden] = useState(false);
  const [membersExpanded, setMembersExpanded] = useState(true);

  const allDisplayMemberIds = useMemo(() => {
    const ids = [...(conversation.participantUserIds || [])];
    if (currentUserId && !ids.includes(currentUserId)) {
      ids.unshift(currentUserId);
    }
    return ids;
  }, [conversation.participantUserIds, currentUserId]);

  // Proactively fetch profiles for all members shown in the list
  useEffect(() => {
    if (!accessToken || allDisplayMemberIds.length === 0) return;
    allDisplayMemberIds.forEach((id) => {
      if (!userMap[id]) {
        void ensureUser(accessToken, id);
      }
    });
  }, [accessToken, allDisplayMemberIds, ensureUser]); // userMap is purposely omitted to avoid re-triggering while fetching

  const mediaItems = useMemo(() => {
    return messages
      .filter((m) => m.type === 'image')
      .map((m) => ({
        id: m.id,
        url: m.mediaUrl ?? m.attachments?.[0]?.url ?? null,
      }))
      .filter((item): item is { id: string; url: string } => Boolean(item.url))
      .slice(0, 6);
  }, [messages]);

  const fileItems = useMemo(() => {
    return messages
      .filter((m) => m.type === 'file')
      .map((m) => {
        const url = m.mediaUrl ?? m.attachments?.[0]?.url ?? null;
        return {
          id: m.id,
          url,
          name: m.attachments?.[0]?.name || getFileName(url),
          sizeText: formatSize(m.mediaSizeBytes ?? m.attachments?.[0]?.sizeBytes),
          sentDate: formatDate(m.createdAt),
        };
      })
      .filter((item): item is { id: string; url: string; name: string; sizeText: string; sentDate: string } => Boolean(item.url))
      .slice(0, 5);
  }, [messages]);

  const linkItems = useMemo(() => {
    const links: Array<{ id: string; url: string }> = [];
    for (const msg of messages) {
      const matches = msg.text?.match(/https?:\/\/[^\s]+/g) ?? [];
      for (const url of matches) {
        if (isHttpUrl(url)) links.push({ id: `${msg.id}-${url}`, url });
      }
    }
    return links.slice(0, 8);
  }, [messages]);

  const toggleSection = (section: SectionKey) => {
    setExpanded((prev) => ({ ...prev, [section]: !prev[section] }));
  };

  return (
    <div className="h-full overflow-y-auto bg-[#F1F1F4] pb-20">
      {/* Header */}
      <header className="sticky top-0 z-10 border-b border-gray-200 bg-white px-5 py-4 text-center">
        <h3 className="text-[20px] font-semibold text-slate-800">Thông tin hội thoại</h3>
      </header>

      {/* Profile Section */}
      <section className="bg-white px-5 pb-6 pt-6">
        <div className="flex justify-center">
          {(() => {
            const collageData = conversation.isGroup && !conversation.avatarUrl 
              ? getGroupCollageData(conversation, userMap) 
              : { avatars: [], extraCount: 0 };
            
            return (
              <UserAvatar
                name={conversation.name}
                imageUrl={conversation.avatarUrl ?? null}
                size="lg"
                className="h-20 w-20 shadow-lg ring-2 ring-white"
                isGroup={conversation.isGroup}
                isCloud={conversation.isCloud}
                memberAvatars={collageData.avatars}
                extraCount={collageData.extraCount}
              />
            );
          })()}
        </div>

        <div className="mt-3 flex items-center justify-center gap-2">
          <h4 className="text-[22px] font-semibold text-slate-900">{conversation.name}</h4>
          <button 
            className="rounded-full border-0 p-1 shadow-none outline-none ring-0 hover:bg-gray-100 focus:outline-none cursor-pointer"
            onClick={() => conversation.isGroup ? onEditGroupName?.() : onEditNickname?.()}
          >
            <Pencil size={18} className="text-gray-500" />
          </button>
        </div>

        {conversation.isCloud ? (
          <div className="mt-4 px-6 text-center">
            <p className="text-[14px] text-gray-500 leading-relaxed">
              Lưu trữ và truy cập nhanh những nội dung quan trọng của bạn ngay trên VNALO
            </p>
            {/* Mock storage UI similar to Zalo */}
            <div className="mt-6 text-left">
              <div className="flex justify-between text-[13px] mb-2 font-medium">
                <span className="text-gray-600">Dung lượng</span>
                <span className="text-gray-400">291 MB / 500 MB</span>
              </div>
              <div className="h-2 w-full bg-gray-100 rounded-full overflow-hidden flex">
                <div className="h-full bg-orange-400" style={{ width: '40%' }}></div>
                <div className="h-full bg-green-400" style={{ width: '15%' }}></div>
              </div>
              <div className="mt-2 flex gap-3 text-[11px] text-gray-400">
                <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-orange-400"></span>Ảnh</span>
                <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-400"></span>Video</span>
              </div>
              <button className="w-full mt-4 py-2 border border-gray-200 rounded-lg text-[14px] font-medium hover:bg-gray-50">
                Xem và dọn dẹp My Documents
              </button>
            </div>
          </div>
        ) : (
          <div className="mt-6 grid grid-cols-3 gap-3">
            <ActionButton icon={BellOff} label="Tắt thông báo" />
            <ActionButton 
              icon={Pin} 
              label={conversation.isPinned ? "Bỏ ghim hội thoại" : "Ghim hội thoại"} 
              isActive={conversation.isPinned}
              onClick={onTogglePinConversation} 
            />
            
            {conversation.isGroup ? (
              <ActionButton icon={UserPlus2} label="Thêm thành viên" onClick={onAddMembersClick} />
            ) : (
              <ActionButton icon={UserPlus} label="Tạo nhóm trò chuyện" onClick={onCreateGroupClick} />
            )}
          </div>
        )}
      </section>

      {/* Common Info */}
      <section className="mt-3 bg-white px-5 py-2">
        <InfoRow icon={AlarmClock} text="Danh sách nhắc hẹn" />
        {conversation.isGroup && (
          <Section title={`Thành viên nhóm (${conversation.memberCount || allDisplayMemberIds.length})`} expanded={membersExpanded} onToggle={() => setMembersExpanded(!membersExpanded)}>
            <div className="space-y-3">
              {allDisplayMemberIds.map(userId => {
                const profile = userMap[userId];
                const member = conversation.members?.find(m => m.userId === userId);
                const isOwner = member?.role === 'OWNER';
                
                return (
                  <div key={userId} className="flex items-center gap-3">
                    <UserAvatar name={profile?.displayName || 'Thành viên'} imageUrl={profile?.avatarUrl} size="sm" />
                    <div className="flex flex-col">
                      <span className="text-[15px] text-slate-700">{profile?.displayName || `Người dùng ${userId.slice(0, 6)}`}</span>
                      {isOwner && <span className="text-[12px] text-slate-400 font-medium">Trưởng nhóm</span>}
                    </div>
                  </div>
                );
              })}
            </div>
          </Section>
        )}
      </section>

      {/* Ảnh/Video */}
      <Section title="Ảnh/Video" expanded={expanded.media} onToggle={() => toggleSection('media')}>
        {mediaItems.length > 0 ? (
          <div className="grid grid-cols-3 gap-2">
            {mediaItems.map((item) => (
              <a
                key={item.id}
                href={item.url}
                target="_blank"
                rel="noreferrer"
                className="aspect-square overflow-hidden rounded-lg border border-gray-200"
              >
                <img src={item.url} alt="" className="h-full w-full object-cover" />
              </a>
            ))}
          </div>
        ) : (
          <EmptyState text="Chưa có ảnh/video được chia sẻ" />
        )}
        <ViewAllButton />
      </Section>

      {/* File */}
      <Section title="File" expanded={expanded.files} onToggle={() => toggleSection('files')}>
        {fileItems.length > 0 ? (
          <div className="space-y-3">
            {fileItems.map((file) => (
              <a
                key={file.id}
                href={file.url}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-3 rounded-xl p-3 hover:bg-gray-50 active:bg-gray-100"
              >
                <div className="h-12 w-12 flex-shrink-0 rounded-lg bg-[#E6F3FF] p-2">
                  <FileText className="h-full w-full text-[#0091FF]" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[15px] font-medium text-slate-800">{file.name}</p>
                  <div className="mt-1 flex items-center gap-1.5 text-xs text-slate-500">
                    <span>{file.sizeText}</span>
                    <CheckCircle2 size={14} className="text-green-500" />
                    <span className="text-gray-300">•</span>
                    <span>{file.sentDate}</span>
                  </div>
                </div>
              </a>
            ))}
          </div>
        ) : (
          <EmptyState text="Chưa có file được chia sẻ" />
        )}
        <ViewAllButton />
      </Section>

      {/* Link */}
      <Section title="Link" expanded={expanded.links} onToggle={() => toggleSection('links')}>
        {linkItems.length > 0 ? (
          <div className="space-y-2">
            {linkItems.map((item) => (
              <a
                key={item.id}
                href={item.url}
                target="_blank"
                rel="noreferrer"
                className="flex items-start gap-3 rounded-xl px-3 py-3 text-sky-700 hover:bg-slate-50"
              >
                <Link2 size={20} className="mt-0.5" />
                <span className="break-all text-[15px]">{item.url}</span>
              </a>
            ))}
          </div>
        ) : (
          <p className="py-8 text-center text-[15px] text-slate-500">
            Chưa có Link được chia sẻ trong hội thoại này
          </p>
        )}
      </Section>

      {/* Bảo mật */}
      <Section title="Thiết lập bảo mật" expanded={expanded.security} onToggle={() => toggleSection('security')}>
        <div className="space-y-4">
          <div className="flex items-center gap-3 px-3 py-2">
            <Timer size={20} className="text-slate-600" />
            <div>
              <p className="text-[15px] font-medium">Tin nhắn tự xóa</p>
              <p className="text-sm text-slate-500">Không bao giờ</p>
            </div>
          </div>

          <div className="flex items-center justify-between px-3 py-2">
            <div className="flex items-center gap-3">
              <EyeOff size={20} className="text-slate-600" />
              <span className="text-[15px] font-medium">Ẩn trò chuyện</span>
            </div>
            <ToggleSwitch checked={isHidden} onChange={setIsHidden} />
          </div>
        </div>
      </Section>

      {/* Footer Actions */}
      <section className="mt-3 bg-white px-5 py-3">
        <FooterAction icon={TriangleAlert} label="Báo xấu" color="text-red-500" />
        <FooterAction icon={Trash2} label="Xóa lịch sử trò chuyện" color="text-red-500" onClick={onDeleteHistoryClick} />
        {conversation.isGroup && (
          <FooterAction icon={LogOut} label="Rời nhóm" color="text-red-500" onClick={onLeaveGroupClick} />
        )}
      </section>
    </div>
  );
}

/* ====================== Helper Components ====================== */

function ActionButton({ 
  icon: Icon, 
  label, 
  onClick, 
  isActive 
}: { 
  icon: React.ElementType; 
  label: string; 
  onClick?: () => void;
  isActive?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex flex-col items-center rounded-xl border-0 bg-transparent px-1 py-2 shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none group"
    >
      <div className={`flex h-10 w-10 items-center justify-center rounded-full transition-colors ${isActive ? 'bg-[#E6F3FF]' : 'bg-gray-200 group-hover:bg-gray-300'}`}>
        <Icon size={16} className={isActive ? 'text-[#0091FF]' : 'text-slate-600'} />
      </div>
      <span className={`mt-2 text-center text-[11px] font-medium leading-[1.25] ${isActive ? 'text-[#0091FF]' : 'text-slate-700'}`}>
        {label}
      </span>
    </button>
  );
}

function InfoRow({ icon: Icon, text }: { icon: React.ElementType; text: string }) {
  return (
    <button
      type="button"
      className="flex w-full items-center gap-4 rounded-xl border-0 bg-transparent px-3 py-[13px] text-left shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none active:bg-gray-100"
    >
      <Icon size={20} className="text-slate-700" />
      <span className="text-[16px] font-medium text-slate-700">{text}</span>
    </button>
  );
}

function Section({
  title,
  expanded,
  onToggle,
  children,
}: {
  title: string;
  expanded: boolean;
  onToggle: () => void;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-3 border-y border-gray-200 bg-white px-5 py-4">
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center justify-between border-0 bg-transparent text-left shadow-none outline-none ring-0 focus:outline-none"
      >
        <span className="text-[16px] font-semibold text-slate-800">{title}</span>
        <ChevronDown
          size={20}
          className={`text-slate-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
        />
      </button>

      {expanded && <div className="mt-4">{children}</div>}
    </section>
  );
}

function ViewAllButton() {
  return (
    <button
      type="button"
      className="mt-4 w-full rounded-xl border-0 bg-gray-200 py-3 text-[15px] font-semibold text-slate-700 shadow-none outline-none ring-0 hover:bg-gray-300 focus:outline-none active:bg-gray-300"
    >
      Xem tất cả
    </button>
  );
}

function EmptyState({ text }: { text: string }) {
  return <p className="py-8 text-center text-sm text-slate-500">{text}</p>;
}

function FooterAction({ icon: Icon, label, color, onClick }: { icon: React.ElementType; label: string; color: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-3 rounded-xl border-0 bg-transparent px-3 py-[13px] text-left shadow-none outline-none ring-0 ${color} hover:bg-red-50 focus:outline-none active:bg-red-100`}
    >
      <Icon size={20} />
      <span className="text-[15px] font-medium">{label}</span>
    </button>
  );
}

function ToggleSwitch({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={`relative h-7 w-12 rounded-full border-0 shadow-none outline-none ring-0 transition-colors focus:outline-none ${checked ? 'bg-[#0091FF]' : 'bg-gray-300'}`}
    >
      <div
        className={`absolute top-0.5 h-6 w-6 rounded-full bg-white shadow transition-all ${checked ? 'translate-x-6' : 'translate-x-0.5'}`}
      />
    </button>
  );
}

/* ====================== Utils ====================== */
function isHttpUrl(value?: string | null): boolean {
  if (!value) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function formatSize(bytes?: number | null): string {
  if (!bytes) return '0 KB';
  return bytes >= 1024 * 1024
    ? `${(bytes / (1024 * 1024)).toFixed(2)} MB`
    : `${(bytes / 1024).toFixed(2)} KB`;
}

function formatDate(dateValue?: string | null): string {
  if (!dateValue) return '';
  const date = new Date(dateValue);
  return isNaN(date.getTime()) ? '' : date.toLocaleDateString('vi-VN');
}

function getFileName(url?: string | null): string {
  if (!url) return 'Tệp đính kèm';
  try {
    return new URL(url).pathname.split('/').pop() || 'Tệp đính kèm';
  } catch {
    return 'Tệp đính kèm';
  }
}