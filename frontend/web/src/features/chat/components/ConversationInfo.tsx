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
  LogOut,
  Settings,
  ChevronLeft,
  Key,
  Lock,
  Plus,
  Users,
  Search,
  MoreHorizontal,
  Camera,
  HelpCircle,
  Copy,
  Share2,
  RotateCw,
  ChevronRight,
  ShieldCheck,
  Check,
  X
} from 'lucide-react';

import { useAuth } from '../../auth/useAuth';
import type { ChatMessage, ConversationSummary } from '../chat.types';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { Modal } from '../../../shared/components/ui/Modal';
import { useUserStore } from '../context/UserStoreContext';
import { getGroupCollageData } from '../../../shared/utils/avatarUtils';
import type { Friend } from '../../friends/friends.types';
import { GroupBulletin } from './GroupBulletin';

type ConversationInfoProps = {
  conversation: ConversationSummary;
  messages: ChatMessage[];
  onAddMembersClick?: () => void;
  onLeaveGroupClick?: () => void;
  onEditGroupName?: () => void;
  onEditNickname?: () => void;
  onDeleteHistoryClick?: () => void;
  onRemoveMember?: (userId: string, block?: boolean) => void;
  onUpdateMemberRole?: (userId: string, role: string) => void;
  onTransferOwnerAndLeave?: (newOwnerId: string) => void;
  onUpdateGroupAvatar?: (file: File) => void;
  onUpdateGroupSettings?: (settings: Partial<any>) => void;
  onDisbandGroup?: () => void;
  onJumpToMessage?: (messageId: string) => void;
  onSendPoll?: (poll: any) => void;
  friends?: Friend[];
};

type SectionKey = 'media' | 'files' | 'links' | 'security' | 'bulletin';

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
  onRemoveMember,
  onUpdateMemberRole,
  onTransferOwnerAndLeave,
  onUpdateGroupAvatar,
  onUpdateGroupSettings,
  onDisbandGroup,
  onJumpToMessage,
  onSendPoll,
  friends,
  currentUserId
}: ConversationInfoProps & {
  currentUserId?: string;
  onCreateGroupClick?: () => void;
  onTogglePinConversation?: () => void;
  onJumpToMessage?: (messageId: string) => void;
  onSendPoll?: (poll: any) => void;
}) {
  const { userMap, ensureUser } = useUserStore();
  const { accessToken } = useAuth();
  const [expanded, setExpanded] = useState<Record<SectionKey, boolean>>({
    media: true,
    files: true,
    links: true,
    security: false,
    bulletin: true,
  });
  const [isHidden, setIsHidden] = useState(false);
  const [membersExpanded, setMembersExpanded] = useState(true);
  const [showGroupManagement, setShowGroupManagement] = useState(false);
  const [showMembersView, setShowMembersView] = useState(false);
  const [showLeaderDeputyView, setShowLeaderDeputyView] = useState(false);
  const [showBulletinView, setShowBulletinView] = useState(false);
  const [showKickModal, setShowKickModal] = useState(false);
  const [targetKickUserId, setTargetKickUserId] = useState<string | null>(null);
  const [blockOnKick, setBlockOnKick] = useState(false);
  const [showTransferModal, setShowTransferModal] = useState(false);

  const isOwner = useMemo(() => {
    if (!currentUserId || !conversation.members) return false;
    return conversation.members.some(m => m.userId === currentUserId && String(m.role || '').toUpperCase() === 'ADMIN');
  }, [currentUserId, conversation.members]);

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
  }, [accessToken, allDisplayMemberIds, ensureUser]); 

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
    <div className="h-full overflow-y-auto bg-[#F1F1F4] pb-20 scrollbar-hide">
      {/* Header */}
      <header className="sticky top-0 z-10 border-b border-gray-200 bg-white px-5 py-4 flex items-center gap-3">
        {(showGroupManagement || showMembersView || showBulletinView || showLeaderDeputyView) && (
          <button
            className="mr-2 bg-white border-0 outline-none ring-0 hover:bg-gray-100 rounded-full transition-colors cursor-pointer flex items-center justify-center h-8 w-8 shadow-none"
            onClick={() => {
              if (showLeaderDeputyView) {
                setShowLeaderDeputyView(false);
                return;
              }
              setShowGroupManagement(false);
              setShowMembersView(false);
              setShowBulletinView(false);
            }}
          >
            <ChevronLeft size={24} strokeWidth={2} className="text-slate-700" />
          </button>
        )}
        <h3 className="text-[18px] font-semibold text-slate-800 flex-1">
          {showBulletinView ? 'Bảng tin nhóm' : 
           showLeaderDeputyView ? 'Trưởng & phó nhóm' :
           showGroupManagement ? 'Quản lý nhóm' : 
           showMembersView ? 'Thành viên' : 'Thông tin hội thoại'}
        </h3>
        {showBulletinView && (
          <button className="bg-transparent border-none outline-none cursor-pointer flex items-center justify-center h-8 w-8 hover:bg-gray-100 rounded-full transition-colors" title="Thêm">
            <Plus size={24} className="text-slate-600" />
          </button>
        )}
      </header>

      {showLeaderDeputyView ? (
        <LeaderDeputyView 
          conversation={conversation} 
          onUpdateRole={onUpdateMemberRole}
          currentUserId={currentUserId}
          userMap={userMap}
        />
      ) : showBulletinView ? (
        <GroupBulletin 
          conversationId={conversation.id}
          token={accessToken || ''}
          messages={messages}
          onClose={() => setShowBulletinView(false)}
          onJumpToMessage={onJumpToMessage}
          onSendPoll={onSendPoll}
        />
      ) : showMembersView ? (
        <MemberListView 
          conversation={conversation} 
          currentUserId={currentUserId}
          onAddMembers={onAddMembersClick}
          onKickMember={(userId) => {
            setTargetKickUserId(userId);
            setShowKickModal(true);
          }}
          onPromoteDeputy={onUpdateMemberRole}
          friends={friends}
        />
      ) : showGroupManagement ? (
        <GroupManagementView
          isOwner={isOwner}
          conversation={conversation}
          onUpdateSettings={onUpdateGroupSettings}
          onDisband={onDisbandGroup}
          onShowLeaderDeputy={() => setShowLeaderDeputyView(true)}
        />
      ) : (
        <>
          {/* Profile Section */}
          <section className="bg-white px-5 pb-6 pt-6">
            <div className="flex justify-center">
              {(() => {
                const collageData = conversation.isGroup && !conversation.avatarUrl
                  ? getGroupCollageData(conversation, userMap)
                  : { avatars: [], extraCount: 0 };

                return (
                  <div className="relative group/avatar">
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
                    
                    {conversation.isGroup && isOwner && (
                      <label className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-full cursor-pointer opacity-0 group-hover/avatar:opacity-100 transition-opacity">
                        <Camera className="text-white" size={24} />
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                              onUpdateGroupAvatar?.(file);
                            }
                            // Reset input value so the same file can be chosen again
                            e.target.value = '';
                          }}
                        />
                      </label>
                    )}
                  </div>
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
                  <button className="w-full mt-4 py-2 border border-gray-200 rounded-lg text-[14px] font-medium hover:bg-gray-50 transition-colors cursor-pointer">
                    Xem và dọn dẹp My Documents
                  </button>
                </div>
              </div>
            ) : (
              <div className={`mt-6 grid ${conversation.isGroup ? 'grid-cols-4' : 'grid-cols-3'} gap-3`}>
                <ActionButton icon={BellOff} label="Tắt thông báo" />
                <ActionButton
                  icon={Pin}
                  label={conversation.isPinned ? "Bỏ ghim hội thoại" : "Ghim hội thoại"}
                  isActive={conversation.isPinned}
                  onClick={onTogglePinConversation}
                />

                {conversation.isGroup ? (
                  <>
                    <ActionButton icon={UserPlus2} label="Thêm thành viên" onClick={onAddMembersClick} />
                    <ActionButton icon={Settings} label="Quản lý nhóm" onClick={() => setShowGroupManagement(true)} />
                  </>
                ) : (
                  <ActionButton icon={UserPlus} label="Tạo nhóm trò chuyện" onClick={onCreateGroupClick} />
                )}
              </div>
            )}
          </section>

          {/* Group Management Sections */}
          <section className="mt-3 space-y-3">
            {conversation.isGroup && (
              <Section title="Thành viên nhóm" expanded={membersExpanded} onToggle={() => setMembersExpanded(!membersExpanded)}>
                <div 
                  className="flex items-center gap-3 py-1 cursor-pointer hover:bg-gray-50 rounded-xl transition-colors"
                  onClick={() => setShowMembersView(true)}
                >
                  <div className="h-10 w-10 flex items-center justify-center rounded-full bg-gray-100">
                    <Users size={20} className="text-slate-600" />
                  </div>
                  <span className="text-[15px] font-medium text-slate-700">
                    {conversation.memberCount || allDisplayMemberIds.length} thành viên
                  </span>
                </div>
              </Section>
            )}

            {conversation.isGroup && (
              <Section 
                title="Bảng tin nhóm" 
                expanded={expanded.bulletin}
                onToggle={() => toggleSection('bulletin')}
              >
                <div className="-mx-2 space-y-1">
                  <InfoRow 
                    icon={AlarmClock} 
                    text="Danh sách nhắc hẹn" 
                    onClick={() => {}} 
                  />
                  <InfoRow 
                    icon={FileText} 
                    text="Ghi chú, ghim, bình chọn" 
                    onClick={() => setShowBulletinView(true)} 
                  />
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
              <FooterAction 
                icon={LogOut} 
                label="Rời nhóm" 
                color="text-red-500" 
                onClick={() => {
                  const activeMembers = (conversation.members || []).filter(m => !m.leftAt);
                  if (isOwner) {
                    if (activeMembers.length <= 1) {
                      onDisbandGroup?.();
                    } else {
                      setShowTransferModal(true);
                    }
                  } else {
                    onLeaveGroupClick?.();
                  }
                }} 
              />
            )}
          </section>
        </>
      )}

      {/* Kick Confirmation Modal */}
      <Modal
        isOpen={showKickModal}
        onClose={() => setShowKickModal(false)}
        title="Xác nhận"
        variant="confirm"
        footer={
          <div className="flex gap-3 justify-end w-full">
            <button 
              className="px-6 py-2 rounded-lg bg-[#EBEBEF] text-slate-700 font-bold text-[15px] hover:bg-gray-200 border-0 outline-none cursor-pointer"
              onClick={() => setShowKickModal(false)}
            >
              Đóng
            </button>
            <button 
              className="px-6 py-2 rounded-lg bg-[#0091FF] text-white font-bold text-[15px] hover:bg-blue-600 border-0 outline-none cursor-pointer" 
              onClick={() => {
                if (targetKickUserId) {
                  onRemoveMember?.(targetKickUserId, blockOnKick);
                }
                setShowKickModal(false);
                setTargetKickUserId(null);
              }}
            >
              Đồng ý
            </button>
          </div>
        }
      >
        <div className="py-2 space-y-4">
          <p className="text-[15px] text-slate-700">Xoá thành viên này khỏi nhóm?</p>
          <label className="flex items-center gap-3 cursor-pointer group">
            <input 
              type="checkbox" 
              className="h-5 w-5 rounded border-gray-300 text-[#0091FF] focus:ring-[#0091FF]" 
              checked={blockOnKick}
              onChange={(e) => setBlockOnKick(e.target.checked)}
            />
            <span className="text-[15px] text-slate-700">Chặn người này tham gia lại</span>
          </label>
        </div>
      </Modal>

      {/* Transfer Owner Modal */}
      <TransferOwnerModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        members={conversation.members || []}
        currentUserId={currentUserId}
        onConfirm={(newOwnerId) => {
          setShowTransferModal(false);
          onTransferOwnerAndLeave?.(newOwnerId);
        }}
      />
    </div>
  );
}

function TransferOwnerModal({ 
  isOpen, 
  onClose, 
  members, 
  currentUserId, 
  onConfirm 
}: { 
  isOpen: boolean; 
  onClose: () => void; 
  members: any[]; 
  currentUserId?: string; 
  onConfirm: (newOwnerId: string) => void; 
}) {
  const [step, setStep] = useState<1 | 2>(1);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const { userMap } = useUserStore();

  const otherMembers = useMemo(() => {
    return members
      .filter(m => m.userId !== currentUserId)
      .filter(m => {
        const profile = userMap[m.userId];
        const name = (profile?.displayName || m.displayName || '').toLowerCase();
        return name.includes(searchTerm.toLowerCase());
      });
  }, [members, currentUserId, searchTerm, userMap]);

  useEffect(() => {
    if (isOpen) {
      setStep(1);
      setSearchTerm('');
      setSelectedId(null);
    }
  }, [isOpen]);

  useEffect(() => {
    if (step === 2 && otherMembers.length > 0 && !selectedId) {
      setSelectedId(otherMembers[0].userId);
    }
  }, [step, otherMembers, selectedId]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/50 animate-in fade-in duration-200">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-[440px] overflow-hidden flex flex-col transition-all">
        {/* Header */}
        <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between bg-white sticky top-0 z-10">
          <h3 className="text-[17px] font-bold text-[#001A33]">
            {step === 1 ? 'Chuyển quyền trưởng nhóm' : 'Chọn trưởng nhóm mới'}
          </h3>
          <button onClick={onClose} className="p-2 hover:bg-slate-50 rounded-full border-0 bg-transparent cursor-pointer">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        {/* Content */}
        <div className="p-5 overflow-y-auto" style={{ maxHeight: 'calc(100vh - 200px)' }}>
          {step === 1 ? (
            <div className="space-y-4">
              <p className="text-[15px] text-slate-700 leading-relaxed">
                Người được chọn sẽ trở thành trưởng nhóm và có mọi quyền quản lý nhóm. Bạn sẽ mất quyền quản lý nhưng vẫn là một thành viên của nhóm. Hành động này không thể phục hồi.
              </p>
            </div>
          ) : (
            <div className="flex flex-col gap-4">
              <div className="relative text-slate-400">
                <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2" />
                <input 
                  type="text"
                  placeholder="Tìm kiếm"
                  className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-transparent focus:border-blue-400 focus:bg-white rounded-xl outline-none text-[15px] transition-all"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>

              <div className="space-y-1 min-h-[200px]">
                {otherMembers.map((member) => {
                  const profile = userMap[member.userId];
                  const isSelected = selectedId === member.userId;
                  
                  return (
                    <div 
                      key={member.userId}
                      className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 cursor-pointer transition-colors group"
                      onClick={() => setSelectedId(member.userId)}
                    >
                      <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all ${
                        isSelected ? 'border-[#0091FF]' : 'border-slate-300'
                      }`}>
                        {isSelected && <div className="w-2.5 h-2.5 rounded-full bg-[#0091FF]" />}
                      </div>
                      <UserAvatar 
                        name={profile?.displayName || member.displayName || 'Thành viên'} 
                        imageUrl={profile?.avatarUrl || member.avatarUrl} 
                        size="md" 
                      />
                      <span className="text-[15px] font-medium text-slate-800 truncate flex-1">
                        {profile?.displayName || member.displayName}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-4 border-t border-gray-100 flex items-center justify-end gap-3 bg-slate-50/30">
          <button 
            className="px-6 py-2.5 rounded-lg text-slate-700 font-bold text-[15px] hover:bg-slate-100 border-0 bg-transparent cursor-pointer transition-colors"
            onClick={onClose}
          >
            Hủy
          </button>
          
          {step === 1 ? (
            <button 
              className="px-6 py-2.5 rounded-lg bg-[#FFEDED] text-[#D83A3A] font-bold text-[15px] hover:bg-[#FFD9D9] border-0 cursor-pointer transition-all active:scale-95"
              onClick={() => setStep(2)}
            >
              Tiếp tục
            </button>
          ) : (
            <button 
              className={`px-6 py-2.5 rounded-lg font-bold text-[15px] shadow-sm border-0 cursor-pointer transition-all active:scale-95 ${
                selectedId 
                  ? 'bg-[#0091FF] text-white hover:bg-blue-600' 
                  : 'bg-blue-300 text-white cursor-not-allowed'
              }`}
              disabled={!selectedId}
              onClick={() => selectedId && onConfirm(selectedId)}
            >
              Chọn và tiếp tục
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function GroupManagementView({ 
  isOwner, 
  conversation, 
  onUpdateSettings,
  onDisband,
  onShowLeaderDeputy
}: { 
  isOwner: boolean; 
  conversation: ConversationSummary;
  onUpdateSettings?: (s: any) => void; 
  onDisband?: () => void;
  onShowLeaderDeputy: () => void;
}) {
  const [showDisbandConfirm, setShowDisbandConfirm] = useState(false);

  const handleToggle = (key: string, value: any) => {
    if (!isOwner) return;
    onUpdateSettings?.({ [key]: value });
  };

  const inviteLink = conversation.inviteLink ? `vnalo.me/g/${conversation.inviteLink}` : 'Đang tải...';

  return (
    <div className="flex flex-col bg-[#F3F5F7] h-full overflow-y-auto scrollbar-hide pb-10">
      {!isOwner && (
        <div className="bg-[#FFF9EA] px-4 py-2.5 flex items-center justify-center gap-2 border-b border-orange-100 sticky top-0 z-10">
          <Lock size={14} className="text-orange-600" />
          <span className="text-[13px] font-medium text-orange-700">Tính năng chỉ dành cho quản trị viên</span>
        </div>
      )}

      {/* Section 1: Member Permissions */}
      <div className="bg-white px-5 py-5 border-b border-gray-100">
        <h4 className="text-[15px] font-bold text-[#001A33] mb-5">
          Cho phép các thành viên trong nhóm:
        </h4>
        <div className="space-y-6">
          <PermissionCheckbox 
            label="Thay đổi tên & ảnh đại diện của nhóm" 
            checked={conversation.allowMemberEditInfo ?? false} 
            disabled={!isOwner}
            onChange={(val) => handleToggle('allowMemberEditInfo', val)}
          />
          <PermissionCheckbox 
            label="Ghim tin nhắn, ghi chú, bình chọn lên đầu hội thoại" 
            checked={conversation.allowMemberPin ?? false} 
            disabled={!isOwner}
            onChange={(val) => handleToggle('allowMemberPin', val)}
          />
          <PermissionCheckbox 
            label="Tạo mới ghi chú, nhắc hẹn" 
            checked={true}
            disabled={!isOwner}
          />
          <PermissionCheckbox 
            label="Tạo mới bình chọn" 
            checked={true} 
            disabled={!isOwner}
          />
          <PermissionCheckbox 
            label="Gửi tin nhắn" 
            checked={!conversation.onlyAdminCanPost} 
            disabled={!isOwner}
            onChange={(val) => handleToggle('onlyAdminCanPost', !val)}
          />
        </div>
      </div>

      {/* Section 2: Advanced Settings */}
      <div className="mt-2 bg-white divide-y divide-gray-100 border-y border-gray-100">
        <SettingToggleRow 
          label="Chế độ phê duyệt thành viên mới" 
          showHelp
          checked={conversation.joinMode === 'APPROVAL'} 
          disabled={!isOwner}
          onChange={(val) => handleToggle('joinMode', val ? 'APPROVAL' : 'OPEN')}
        />
        <SettingToggleRow 
          label="Đánh dấu tin nhắn từ trưởng/phó nhóm" 
          showHelp
          checked={true} 
          disabled={!isOwner}
        />
        <SettingToggleRow 
          label="Cho phép thành viên mới đọc tin nhắn gần nhất" 
          showHelp
          checked={true}
          disabled={!isOwner}
        />
        <div className="flex flex-col">
          <SettingToggleRow 
            label="Cho phép dùng link tham gia nhóm" 
            showHelp
            checked={!!conversation.inviteLink} 
            disabled={!isOwner}
          />
          
          <div className="px-5 pb-5">
            <div className="bg-[#F0F7FF] rounded-lg p-3 flex items-center justify-between gap-3">
              <span className="text-[#0068FF] text-[15px] font-medium truncate flex-1">
                {inviteLink}
              </span>
              <div className="flex items-center gap-4 text-[#0068FF]">
                <Copy size={20} className="cursor-pointer hover:opacity-70 transition-opacity" />
                <Share2 size={20} className="cursor-pointer hover:opacity-70 transition-opacity" />
                <RotateCw size={20} className="cursor-pointer hover:opacity-70 transition-opacity" />
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Section 3: Bottom Actions */}
      <div className="mt-2 bg-white divide-y divide-gray-100 border-y border-gray-100">
         <button className="w-full px-5 py-4 flex items-center gap-4 hover:bg-gray-50 border-0 bg-transparent transition-colors group cursor-pointer outline-none">
            <Users size={22} className="text-[#4F5E71]" />
            <span className="text-[16px] font-medium text-[#001A33]">Chặn khỏi nhóm</span>
         </button>
         <button 
           className="w-full px-5 py-4 flex items-center gap-4 hover:bg-gray-50 border-0 bg-transparent transition-colors group cursor-pointer outline-none"
           onClick={onShowLeaderDeputy}
         >
            <Key size={22} className="text-[#4F5E71]" />
            <span className="text-[16px] font-medium text-[#001A33]">Trưởng & phó nhóm</span>
         </button>
      </div>

      {/* Disband Button */}
      {isOwner && (
        <div className="mt-6 px-5 mb-10">
          <button 
            className="w-full py-3 rounded-lg bg-[#FFEDED] text-[#D83A3A] font-bold text-[16px] hover:bg-[#FFD9D9] border-0 transition-all cursor-pointer active:scale-[0.98]"
            onClick={() => setShowDisbandConfirm(true)}
          >
            Giải tán nhóm
          </button>
        </div>
      )}

      {/* Disband Confirmation Modal */}
      <Modal
        isOpen={showDisbandConfirm}
        onClose={() => setShowDisbandConfirm(false)}
        title="Giải tán nhóm"
        variant="confirm"
        footer={
          <div className="flex gap-3 justify-end w-full">
            <button 
              className="px-6 py-2 rounded-lg bg-[#EBEBEF] text-slate-700 font-bold hover:bg-gray-200 border-0 outline-none cursor-pointer"
              onClick={() => setShowDisbandConfirm(false)}
            >
              Hủy
            </button>
            <button 
              className="px-6 py-2 rounded-lg bg-[#FFE9E9] text-[#E02424] font-bold hover:bg-red-100 border-0 outline-none cursor-pointer" 
              onClick={() => {
                onDisband?.();
                setShowDisbandConfirm(false);
              }}
            >
              Giải tán nhóm
            </button>
          </div>
        }
      >
        <p className="py-2 text-[15px] text-slate-600 leading-relaxed">
          Mời tất cả mọi người rời nhóm và xóa tin nhắn? Nhóm đã giải tán sẽ KHÔNG THỂ khôi phục.
        </p>
      </Modal>
    </div>
  );
}

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
      className="flex flex-col items-center rounded-xl border-0 bg-transparent px-1 py-2 shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none group cursor-pointer"
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

function InfoRow({ icon: Icon, text, onClick }: { icon: React.ElementType; text: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-4 rounded-xl border-0 bg-transparent px-3 py-[13px] text-left shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none active:bg-gray-100 cursor-pointer"
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
    <div className="mt-3 border-y border-gray-200 bg-white px-5 py-4">
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center justify-between border-0 bg-transparent text-left shadow-none outline-none ring-0 focus:outline-none cursor-pointer"
      >
        <span className="text-[16px] font-semibold text-slate-800">{title}</span>
        <ChevronDown
          size={20}
          className={`text-slate-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
        />
      </button>

      {expanded && <div className="mt-4">{children}</div>}
    </div>
  );
}

function ViewAllButton() {
  return (
    <button
      type="button"
      className="mt-4 w-full rounded-xl border-0 bg-gray-200 py-3 text-[15px] font-semibold text-slate-700 shadow-none outline-none ring-0 hover:bg-gray-300 focus:outline-none active:bg-gray-300 cursor-pointer shadow-none ring-0 outline-none"
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
      className={`flex w-full items-center gap-3 rounded-xl border-0 bg-transparent px-3 py-[13px] text-left shadow-none outline-none ring-0 ${color} hover:bg-red-50 focus:outline-none active:bg-red-100 cursor-pointer`}
    >
      <Icon size={20} />
      <span className="text-[15px] font-medium">{label}</span>
    </button>
  );
}

function ToggleSwitch({ 
  checked, 
  onChange, 
  disabled 
}: { 
  checked: boolean; 
  onChange?: (v: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div 
      className={`relative h-6 w-11 rounded-full transition-all duration-200 ${
        checked ? 'bg-[#0091FF]' : 'bg-gray-300 shadow-inner'
      } ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
      onClick={(e) => {
        e.stopPropagation();
        !disabled && onChange?.(!checked);
      }}
    >
      <div
        className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-all duration-200 transform ${
          checked ? 'translate-x-5' : 'translate-x-0'
        }`}
      />
    </div>
  );
}

function PermissionCheckbox({ 
  label, 
  checked, 
  onChange, 
  disabled 
}: { 
  label: string; 
  checked: boolean; 
  onChange?: (val: boolean) => void;
  disabled?: boolean;
}) {
  return (
    <div 
      className={`flex items-center justify-between gap-4 group ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
      onClick={() => !disabled && onChange?.(!checked)}
    >
      <span className="text-[15px] font-medium text-[#001A33] leading-relaxed flex-1">{label}</span>
      <div className={`w-[22px] h-[22px] rounded border-2 flex items-center justify-center transition-all ${
        checked ? 'bg-[#0068FF] border-[#0068FF]' : 'border-gray-300'
      }`}>
        {checked && <Check size={14} strokeWidth={4} className="text-white" />}
      </div>
    </div>
  );
}

function SettingToggleRow({ 
  label, 
  showHelp, 
  checked, 
  onChange, 
  disabled 
}: { 
  label: string; 
  showHelp?: boolean; 
  checked: boolean; 
  onChange?: (val: boolean) => void; 
  disabled?: boolean;
}) {
  return (
    <div 
      className={`px-5 py-[18px] flex items-center justify-between hover:bg-gray-50 transition-colors ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
      onClick={() => !disabled && onChange?.(!checked)}
    >
      <div className="flex items-center gap-1.5 min-w-0 flex-1">
        <span className="text-[15px] font-medium text-[#001A33] truncate">{label}</span>
        {showHelp && <HelpCircle size={16} className="text-gray-400 flex-shrink-0" />}
      </div>
      <ToggleSwitch checked={checked} disabled={disabled} />
    </div>
  );
}

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

/* ====================== Leader & Deputy Components ====================== */

function LeaderDeputyView({ 
  conversation, 
  onUpdateRole,
  currentUserId,
  userMap
}: { 
  conversation: ConversationSummary;
  onUpdateRole?: (userId: string, role: string) => void;
  currentUserId?: string;
  userMap: any;
}) {
  const [showAdjustModal, setShowAdjustModal] = useState(false);
  const [showTransferModal, setShowTransferModal] = useState(false);

  const admin = conversation.members?.find(m => String(m.role || '').toUpperCase() === 'ADMIN');
  const deputies = conversation.members?.filter(m => String(m.role || '').toUpperCase() === 'DEPUTY') || [];

  return (
    <div className="flex flex-col bg-white h-full overflow-y-auto pb-10 scrollbar-hide">
      <div className="p-4 space-y-6">
        {/* Leader Section */}
        <div>
          <div className="flex items-center gap-3 py-2 border-b border-gray-50">
            <UserAvatar 
              name={userMap[admin?.userId || '']?.displayName || admin?.displayName || ''} 
              imageUrl={userMap[admin?.userId || '']?.avatarUrl || admin?.avatarUrl} 
              size="lg" 
            />
            <div className="flex flex-col">
              <span className="font-semibold text-slate-800 text-[16px]">
                {userMap[admin?.userId || '']?.displayName || admin?.displayName}
              </span>
              <span className="text-[13px] text-slate-500">Trưởng nhóm</span>
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-3">
          <button 
            className="w-full py-3 bg-[#EBEBEF] text-[#001A33] font-bold rounded-lg hover:bg-gray-200 border-0 outline-none cursor-pointer transition-all active:scale-95"
            onClick={() => setShowAdjustModal(true)}
          >
            Thêm phó nhóm
          </button>
          <button 
            className="w-full py-3 bg-[#EBEBEF] text-[#001A33] font-bold rounded-lg hover:bg-gray-200 border-0 outline-none cursor-pointer transition-all active:scale-95"
            onClick={() => setShowTransferModal(true)}
          >
            Chuyển quyền trưởng nhóm
          </button>
        </div>

        {/* Deputies List */}
        {deputies.length > 0 && (
          <div className="mt-6">
            <h5 className="text-[14px] font-bold text-slate-400 mb-4 uppercase tracking-wider">Danh sách phó nhóm ({deputies.length}/3)</h5>
            <div className="space-y-4">
              {deputies.map(deputy => (
                <div key={deputy.userId} className="flex items-center justify-between group">
                  <div className="flex items-center gap-3">
                    <UserAvatar 
                      name={userMap[deputy.userId]?.displayName || deputy.displayName || ''} 
                      imageUrl={userMap[deputy.userId]?.avatarUrl || deputy.avatarUrl} 
                      size="md" 
                    />
                    <div className="flex flex-col">
                      <span className="font-medium text-slate-800">
                        {userMap[deputy.userId]?.displayName || deputy.displayName}
                      </span>
                      <span className="text-[13px] text-slate-500">Phó nhóm</span>
                    </div>
                  </div>
                  <button 
                    className="p-2 text-red-500 hover:bg-red-50 rounded-full border-0 outline-none cursor-pointer opacity-0 group-hover:opacity-100 transition-opacity"
                    onClick={() => onUpdateRole?.(deputy.userId, 'MEMBER')}
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Adjust Deputy Modal */}
      <AdjustDeputyModal 
        isOpen={showAdjustModal}
        onClose={() => setShowAdjustModal(false)}
        members={conversation.members?.filter(m => {
          const role = String(m.role || '').toUpperCase();
          return (role === 'MEMBER' || role === 'DEPUTY') && !m.leftAt;
        }) || []}
        currentDeputies={deputies}
        userMap={userMap}
        onConfirm={(selectedIds) => {
          const currentIds = deputies.map(d => d.userId);
          
          currentIds.forEach(id => {
            if (!selectedIds.includes(id)) {
              onUpdateRole?.(id, 'MEMBER');
            }
          });

          selectedIds.forEach(id => {
            if (!currentIds.includes(id)) {
              onUpdateRole?.(id, 'DEPUTY');
            }
          });
          
          setShowAdjustModal(false);
        }}
      />

      <TransferOwnerModal
        isOpen={showTransferModal}
        onClose={() => setShowTransferModal(false)}
        members={conversation.members || []}
        currentUserId={currentUserId}
        onConfirm={(newOwnerId) => {
          setShowTransferModal(false);
          onUpdateRole?.(newOwnerId, 'ADMIN');
        }}
      />
    </div>
  );
}

function AdjustDeputyModal({ 
  isOpen, 
  onClose, 
  members, 
  currentDeputies,
  userMap,
  onConfirm 
}: { 
  isOpen: boolean;
  onClose: () => void;
  members: any[];
  currentDeputies: any[];
  userMap: any;
  onConfirm: (ids: string[]) => void;
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

  useEffect(() => {
    if (isOpen) {
      setSelectedIds(currentDeputies.map(d => d.userId));
      setSearchTerm('');
    }
  }, [isOpen, currentDeputies]);

  const filteredMembers = members.filter(m => {
    const name = (userMap[m.userId]?.displayName || m.displayName || '').toLowerCase();
    return name.includes(searchTerm.toLowerCase());
  });

  const toggleSelect = (userId: string) => {
    if (selectedIds.includes(userId)) {
      setSelectedIds(prev => prev.filter(id => id !== userId));
    } else {
      if (selectedIds.length >= 3) {
        alert('Chỉ được phép có tối đa 3 phó nhóm. Vui lòng bỏ chọn bớt hoặc xóa phó nhóm cũ.');
        return;
      }
      setSelectedIds(prev => [...prev, userId]);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[110] flex items-center justify-center p-4 bg-black/50 animate-in fade-in duration-200">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-[700px] h-[600px] flex flex-col overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h3 className="text-[17px] font-bold text-slate-800">Điều chỉnh phó nhóm</h3>
          <button onClick={onClose} className="p-2 hover:bg-slate-50 rounded-full border-0 bg-transparent cursor-pointer transition-colors shadow-none outline-none">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="flex-1 flex overflow-hidden">
          <div className="flex-1 border-r border-gray-100 flex flex-col min-w-0">
            <div className="p-4">
              <div className="relative text-slate-400">
                <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2" />
                <input 
                  type="text"
                  placeholder="Tìm kiếm thành viên"
                  className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-transparent focus:border-blue-400 focus:bg-white rounded-lg outline-none text-[15px] transition-all"
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
            </div>
            <div className="flex-1 overflow-y-auto px-4 pb-4 scrollbar-hide">
              <div className="space-y-1">
                {filteredMembers.map(m => (
                  <div 
                    key={m.userId}
                    className="flex items-center gap-3 p-2 hover:bg-slate-50 rounded-lg cursor-pointer group transition-colors"
                    onClick={() => toggleSelect(m.userId)}
                  >
                    <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all ${
                      selectedIds.includes(m.userId) ? 'bg-blue-500 border-blue-500' : 'border-slate-300'
                    }`}>
                      {selectedIds.includes(m.userId) && <Check size={12} className="text-white" />}
                    </div>
                    <UserAvatar 
                      name={userMap[m.userId]?.displayName || m.displayName || ''} 
                      imageUrl={userMap[m.userId]?.avatarUrl || m.avatarUrl} 
                      size="md" 
                    />
                    <span className="text-[15px] font-medium text-slate-700 truncate flex-1">
                      {userMap[m.userId]?.displayName || m.displayName}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="w-[240px] bg-white flex flex-col min-w-0">
            <div className="p-4 border-b border-gray-50">
              <div className="flex items-center justify-between">
                <span className="text-[14px] font-bold text-slate-800">Đã chọn</span>
                <span className="bg-blue-50 text-blue-600 text-[12px] px-2 py-0.5 rounded-full font-bold">
                  {selectedIds.length}/3
                </span>
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-3 space-y-2 scrollbar-hide">
              {selectedIds.map(id => {
                const name = userMap[id]?.displayName || members.find(m => m.userId === id)?.displayName || 'Thành viên';
                const avatar = userMap[id]?.avatarUrl || members.find(m => m.userId === id)?.avatarUrl;
                return (
                  <div key={id} className="flex items-center gap-2 bg-blue-50/50 p-2 rounded-lg border border-blue-100/50 group transition-all">
                    <UserAvatar name={name} imageUrl={avatar} size="xs" />
                    <span className="text-[13px] font-medium text-blue-800 truncate flex-1">{name}</span>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        toggleSelect(id);
                      }}
                      className="p-1 hover:bg-blue-100 rounded-full border-0 bg-transparent cursor-pointer transition-colors shadow-none outline-none"
                    >
                      <X size={14} className="text-blue-600" />
                    </button>
                  </div>
                );
              })}
              {selectedIds.length === 0 && (
                <div className="h-full flex flex-col items-center justify-center opacity-40 py-10">
                  <Users size={32} className="mb-2" />
                  <p className="text-[13px]">Chưa chọn ai</p>
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-end gap-3 bg-slate-50/50">
          <button 
            className="px-6 py-2 rounded-lg text-slate-600 font-bold text-[14px] hover:bg-slate-100 border-0 bg-transparent cursor-pointer transition-colors shadow-none outline-none"
            onClick={onClose}
          >
            Hủy
          </button>
          <button 
            className={`px-8 py-2 rounded-lg font-bold text-[14px] shadow-sm border-0 outline-none cursor-pointer transition-all active:scale-95 ${
              selectedIds.length > 0
                ? 'bg-blue-600 text-white hover:bg-blue-700' 
                : 'bg-blue-300 text-white cursor-not-allowed'
            }`}
            disabled={selectedIds.length === 0}
            onClick={() => onConfirm(selectedIds)}
          >
            Xác nhận
          </button>
        </div>
      </div>
    </div>
  );
}

function MemberListView({ conversation, currentUserId, onAddMembers, onKickMember, onPromoteDeputy, friends }: { 
  conversation: ConversationSummary; 
  currentUserId?: string; 
  onAddMembers?: () => void;
  onKickMember?: (userId: string) => void;
  onPromoteDeputy?: (userId: string, role: string) => void;
  friends?: Friend[];
}) {
  const { userMap } = useUserStore();
  const [searchTerm, setSearchTerm] = useState('');

  const members = useMemo(() => {
    return (conversation.members || []).filter(m => !m.leftAt);
  }, [conversation.members]);

  const filteredMembers = useMemo(() => {
    if (!searchTerm) return members;
    return members.filter(m => {
      const name = (userMap[m.userId]?.displayName || m.displayName || '').toLowerCase();
      return name.includes(searchTerm.toLowerCase());
    });
  }, [members, searchTerm, userMap]);

  return (
    <div className="flex flex-col bg-white h-full overflow-hidden">
      <div className="p-4 border-b border-gray-100">
        <div className="relative text-slate-400">
          <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2" />
          <input 
            type="text"
            placeholder="Tìm kiếm thành viên"
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-transparent focus:border-blue-400 focus:bg-white rounded-xl outline-none text-[15px] transition-all"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-2 pb-10 scrollbar-hide">
        <div className="p-2">
          {filteredMembers.map((member) => {
             const role = String(member.role || '').toUpperCase();
             const isMe = member.userId === currentUserId;
             const profile = userMap[member.userId];
             
             return (
               <div key={member.userId} className="flex items-center justify-between p-3 rounded-xl hover:bg-gray-50 group transition-colors">
                  <div className="flex items-center gap-3">
                    <UserAvatar 
                      name={profile?.displayName || member.displayName || 'Thành viên'} 
                      imageUrl={profile?.avatarUrl || member.avatarUrl} 
                      size="md" 
                    />
                    <div className="flex flex-col">
                      <span className="font-medium text-slate-800">
                        {profile?.displayName || member.displayName} {isMe && '(Bạn)'}
                      </span>
                      {role !== 'MEMBER' && (
                        <span className="text-[12px] text-[#0068FF] font-medium">
                          {role === 'ADMIN' ? 'Trưởng nhóm' : 'Phó nhóm'}
                        </span>
                      )}
                    </div>
                  </div>
                  {!isMe && role === 'MEMBER' && (
                     <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button 
                          className="p-2 text-slate-500 hover:bg-white hover:shadow-sm rounded-full transition-all border-0 bg-transparent cursor-pointer"
                          onClick={() => onKickMember?.(member.userId)}
                          title="Xóa khỏi nhóm"
                        >
                          <Trash2 size={18} />
                        </button>
                        <button 
                          className="p-2 text-[#0068FF] hover:bg-blue-50 rounded-full transition-all border-0 bg-transparent cursor-pointer"
                          onClick={() => onPromoteDeputy?.(member.userId, 'DEPUTY')}
                          title="Bổ nhiệm phó nhóm"
                        >
                          <ShieldCheck size={18} />
                        </button>
                     </div>
                  )}
               </div>
             );
          })}
        </div>
      </div>

      <div className="p-4 mt-auto">
         <button 
            className="w-full py-3 bg-[#0091FF] text-white font-bold rounded-xl hover:bg-blue-600 transition-all flex items-center justify-center gap-2 border-0 shadow-md outline-none cursor-pointer active:scale-95"
            onClick={onAddMembers}
          >
            <UserPlus size={18} />
            Thêm thành viên
         </button>
      </div>
    </div>
  );
}