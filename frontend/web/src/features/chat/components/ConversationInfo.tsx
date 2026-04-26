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
  Users,
  Search,
  MoreHorizontal,
  Camera,
  HelpCircle,
  Copy,
  Share2,
  RotateCw,
  ChevronRight,
  ShieldCheck
} from 'lucide-react';

import { useAuth } from '../../auth/useAuth';
import type { ChatMessage, ConversationSummary } from '../chat.types';
import { UserAvatar } from '../../../shared/components/UserAvatar';
import { Modal } from '../../../shared/components/ui/Modal';
import { useUserStore } from '../context/UserStoreContext';
import { getGroupCollageData } from '../../../shared/utils/avatarUtils';
import type { Friend } from '../../friends/friends.types';

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
  friends?: Friend[];
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
  onRemoveMember,
  onUpdateMemberRole,
  onTransferOwnerAndLeave,
  onUpdateGroupAvatar,
  onUpdateGroupSettings,
  onDisbandGroup,
  friends,
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
  const [showGroupManagement, setShowGroupManagement] = useState(false);
  const [showMembersView, setShowMembersView] = useState(false);
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
    <div className="h-full overflow-y-auto bg-[#F1F1F4] pb-20">
      {/* Header */}
      <header className="sticky top-0 z-10 border-b border-gray-200 bg-white px-5 py-4 flex items-center gap-3">
        {(showGroupManagement || showMembersView) && (
          <button
            className="mr-2 bg-white border-0 outline-none ring-0 hover:bg-gray-50 rounded-full transition-colors cursor-pointer flex items-center justify-center h-8 w-8 shadow-none"
            onClick={() => {
              setShowGroupManagement(false);
              setShowMembersView(false);
            }}
          >
            <ChevronLeft size={24} strokeWidth={2} className="text-slate-700" />
          </button>
        )}
        <h3 className="text-[18px] font-semibold text-slate-800 flex-1">
          {showGroupManagement ? 'Quản lý nhóm' : showMembersView ? 'Thành viên' : 'Thông tin hội thoại'}
        </h3>
      </header>

      {showMembersView ? (
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
                  <button className="w-full mt-4 py-2 border border-gray-200 rounded-lg text-[14px] font-medium hover:bg-gray-50">
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

          {/* Common Info */}
          <section className="mt-3 bg-white px-5 py-2">
            <InfoRow icon={AlarmClock} text="Danh sách nhắc hẹn" />
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
                  if (isOwner) {
                    setShowTransferModal(true);
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
              className="px-6 py-2 rounded-lg bg-[#EBEBEF] text-slate-700 font-bold text-[15px] hover:bg-gray-200"
              onClick={() => setShowKickModal(false)}
            >
              Đóng
            </button>
            <button 
              className="px-6 py-2 rounded-lg bg-[#0091FF] text-white font-bold text-[15px] hover:bg-blue-600" 
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

function GroupManagementView({ 
  isOwner, 
  conversation, 
  onUpdateSettings,
  onDisband 
}: { 
  isOwner: boolean; 
  conversation: ConversationSummary;
  onUpdateSettings?: (s: any) => void;
  onDisband?: () => void;
}) {
  const [showDisbandConfirm, setShowDisbandConfirm] = useState(false);

  const handleToggle = (key: string, value: any) => {
    if (!isOwner) return;
    onUpdateSettings?.({ [key]: value });
  };

  const inviteLink = conversation.inviteLink ? `vnalo.me/g/${conversation.inviteLink}` : 'Đang tải...';

  return (
    <div className="flex flex-col bg-[#F1F1F4] h-full overflow-y-auto">
      {!isOwner && (
        <div className="bg-[#FFF9EA] px-4 py-2.5 flex items-center justify-center gap-2 border-b border-orange-100 sticky top-0 z-10">
          <Lock size={14} className="text-orange-600" />
          <span className="text-[13px] font-medium text-orange-700">Tính năng chỉ dành cho quản trị viên</span>
        </div>
      )}

      {/* Section 1: Member Permissions */}
      <div className="bg-white px-5 py-5 mt-2">
        <h4 className={`text-[14px] font-bold mb-5 ${!isOwner ? 'text-gray-400' : 'text-[#001A33]'}`}>
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
      <div className="mt-2 bg-white divide-y divide-gray-100">
        <SettingToggleRow 
          label="Chế độ phê duyệt thành viên mới" 
          description={true}
          checked={conversation.joinMode === 'APPROVAL'} 
          disabled={!isOwner}
          onChange={(val) => handleToggle('joinMode', val ? 'APPROVAL' : 'OPEN')}
        />
        <SettingToggleRow 
          label="Đánh dấu tin nhắn từ trưởng/phó nhóm" 
          description={true}
          checked={true} 
          disabled={!isOwner}
        />
        <SettingToggleRow 
          label="Cho phép thành viên mới đọc tin nhắn gần nhất" 
          description={true}
          checked={true}
          disabled={!isOwner}
        />
        <div className="px-5 py-5 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-1.5 flex-1 pr-4">
              <span className={`text-[15px] font-medium leading-normal ${!isOwner ? 'text-gray-400' : 'text-slate-700'}`}>
                Cho phép dùng link tham gia nhóm
              </span>
              <HelpCircle size={16} className="text-gray-400 flex-shrink-0" />
            </div>
            <ToggleSwitch 
              checked={!!conversation.inviteLink} 
              disabled={!isOwner}
            />
          </div>
          
          <div className="bg-[#F3F5F7] rounded-lg p-4 flex items-center justify-between gap-3 border border-gray-100">
            <span className="text-[#0068FF] text-[14px] font-medium truncate flex-1">
              {inviteLink}
            </span>
            <div className="flex items-center gap-4 text-[#0068FF]">
              <Copy size={18} className="cursor-pointer hover:opacity-70 transition-opacity" />
              <Share2 size={18} className="cursor-pointer hover:opacity-70 transition-opacity" />
              <RotateCw size={18} className="cursor-pointer hover:opacity-70 transition-opacity" />
            </div>
          </div>
        </div>
      </div>

      {/* Section 3: Management Links */}
      {isOwner && (
        <div className="mt-2 bg-white divide-y divide-gray-100">
           <button className="w-full px-5 py-[18px] flex items-center justify-between hover:bg-gray-50 border-0 bg-transparent transition-colors group">
              <div className="flex items-center gap-3">
                <UserPlus size={20} className="text-slate-600" />
                <span className="text-[15px] font-medium text-[#334155]">Chặn khỏi nhóm</span>
              </div>
              <ChevronRight size={18} className="text-slate-400 group-hover:translate-x-0.5 transition-transform" />
           </button>
           <button className="w-full px-5 py-[18px] flex items-center justify-between hover:bg-gray-50 border-0 bg-transparent transition-colors group">
              <div className="flex items-center gap-3">
                <ShieldCheck size={20} className="text-slate-600" />
                <span className="text-[15px] font-medium text-[#334155]">Trưởng & phó nhóm</span>
              </div>
              <ChevronRight size={18} className="text-slate-400 group-hover:translate-x-0.5 transition-transform" />
           </button>
        </div>
      )}

      {/* Footer: Disband */}
      {isOwner && (
        <div className="mt-8 px-5 pb-10">
          <button 
            className="w-full py-3.5 rounded-xl bg-[#FFEDED] text-[#D83A3A] font-bold text-[15px] hover:bg-[#FFD9D9] transition-all border-0 shadow-sm outline-none cursor-pointer"
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
              Không
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
    <label className={`flex items-center justify-between gap-4 py-0.5 ${disabled ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}`}>
      <span className={`text-[15px] leading-[1.3] flex-1 font-medium ${disabled ? 'text-gray-400' : 'text-[#334155]'}`}>{label}</span>
      <input 
        type="checkbox" 
        checked={checked} 
        disabled={disabled}
        onChange={(e) => onChange?.(e.target.checked)}
        className="h-[22px] w-[22px] rounded border-gray-300 text-[#0091FF] focus:ring-[#0091FF] transition-all cursor-pointer flex-shrink-0"
      />
    </label>
  );
}

function SettingToggleRow({ 
  label, 
  description, 
  checked, 
  onChange, 
  disabled 
}: { 
  label: string; 
  description?: boolean; 
  checked: boolean; 
  onChange?: (val: boolean) => void; 
  disabled?: boolean;
}) {
  return (
    <div className="px-5 py-[18px] flex items-center justify-between hover:bg-gray-50 transition-colors cursor-pointer" onClick={() => !disabled && onChange?.(!checked)}>
      <div className="flex items-center gap-1.5 flex-1 pr-6">
        <span className={`text-[15px] font-medium leading-normal ${disabled ? 'text-gray-400' : 'text-[#334155]'}`}>
          {label}
        </span>
        {description && <HelpCircle size={16} className="text-gray-400 flex-shrink-0" />}
      </div>
      <ToggleSwitch checked={checked} onChange={onChange} disabled={disabled} />
    </div>
  );
}

function MemberListView({ 
  conversation, 
  currentUserId,
  onAddMembers,
  onKickMember,
  onPromoteDeputy,
  friends
}: { 
  conversation: ConversationSummary;
  currentUserId?: string;
  onAddMembers?: () => void;
  onKickMember?: (userId: string) => void;
  onPromoteDeputy?: (userId: string, role: string) => void;
  friends?: Friend[];
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const { userMap } = useUserStore();

  const members = useMemo(() => {
    const list = [...(conversation.members || [])];
    return list.sort((a, b) => {
      const roles = { ADMIN: 0, DEPUTY: 1, MEMBER: 2 };
      const roleA = String(a.role || '').toUpperCase() as keyof typeof roles;
      const roleB = String(b.role || '').toUpperCase() as keyof typeof roles;
      return (roles[roleA] ?? 3) - (roles[roleB] ?? 3);
    }).filter(m => {
      const profile = userMap[m.userId];
      if (!searchTerm) return true;
      return profile?.displayName?.toLowerCase().includes(searchTerm.toLowerCase());
    });
  }, [conversation.members, userMap, searchTerm]);

  const isCurrentUserOwner = !!conversation.members?.some(m => m.userId === currentUserId && m.role === 'ADMIN');

  return (
    <div className="flex flex-col bg-[#F4F5F7] h-full overflow-hidden">
      <div className="bg-white px-5 py-4 flex-shrink-0">
        <button 
          onClick={onAddMembers}
          className="w-full py-2.5 rounded-lg bg-[#EBEBEF] text-slate-700 font-bold text-[15px] flex items-center justify-center gap-2 hover:bg-gray-200 transition-colors"
        >
          <UserPlus size={20} />
          Thêm thành viên
        </button>
      </div>

      <div className="mt-2 flex-1 overflow-y-auto bg-white px-5 py-4">
        <div className="flex items-center justify-between mb-4">
          <h4 className="text-[16px] font-bold text-slate-800">Danh sách thành viên ({conversation.members?.length || 0})</h4>
        </div>

        <div className="relative mb-6">
          <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input 
            type="text"
            placeholder="Tìm kiếm thành viên"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-gray-100 border-0 rounded-xl py-2.5 pl-10 pr-4 text-[15px] focus:ring-1 focus:ring-blue-400 outline-none"
          />
        </div>

        <div className="space-y-1">
          {members.map((member) => (
            <MemberRow 
              key={member.userId} 
              member={member} 
              isOwnerView={isCurrentUserOwner && member.userId !== currentUserId}
              onKick={() => onKickMember?.(member.userId)}
              onPromote={() => onPromoteDeputy?.(member.userId, 'ADMIN')}
              isFriend={!!friends?.some(f => f.friendId === member.userId)}
              currentUserId={currentUserId}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

function MemberRow({ 
  member, 
  isOwnerView, 
  onKick,
  onPromote,
  isFriend,
  currentUserId 
}: { 
  member: { userId: string; role: string }; 
  isOwnerView: boolean;
  onKick: () => void;
  onPromote: () => void;
  isFriend: boolean;
  currentUserId?: string;
}) {
  const [showMenu, setShowMenu] = useState(false);
  const { userMap } = useUserStore();
  const profile = userMap[member.userId];
  const role = String(member.role || '').toUpperCase();
  const isOwner = role === 'ADMIN';
  const isAdmin = role === 'DEPUTY';

  return (
    <div className="flex items-center gap-3 py-2 group">
      <div className="relative">
        <UserAvatar 
          name={profile?.displayName || 'Thành viên'} 
          imageUrl={profile?.avatarUrl} 
          size="md" 
        />
        {isOwner && (
          <div className="absolute -bottom-1 -right-1 bg-white rounded-full p-0.5 shadow-sm border border-gray-100">
            <Key size={12} className="text-yellow-600 fill-yellow-500" />
          </div>
        )}
      </div>

      <div className="flex-1 min-w-0">
        <p className="text-[16px] font-medium text-slate-900 truncate">
          {profile?.displayName || 'Đang tải...'}
        </p>
        {(isOwner || isAdmin) && (
          <p className="text-[13px] text-slate-500">{isOwner ? 'Trưởng nhóm' : 'Phó nhóm'}</p>
        )}
      </div>

      <div className="flex items-center gap-2">
        {!isFriend && member.userId !== currentUserId && (
          <button className="px-4 py-1.5 rounded-lg bg-[#E6F3FF] text-[#0091FF] text-[14px] font-bold border-0 hover:bg-blue-100 transition-colors shadow-none outline-none">
            Kết bạn
          </button>
        )}
        
        {isOwnerView && (
          <div className="relative">
            <button 
              onClick={() => setShowMenu(!showMenu)}
              className="p-2 rounded-lg bg-white hover:bg-gray-100 text-slate-500 border-0 transition-colors shadow-none outline-none"
            >
              <MoreHorizontal size={20} />
            </button>

            {showMenu && (
              <>
                <div className="fixed inset-0 z-10" onClick={() => setShowMenu(false)} />
                <div className="absolute right-0 top-full mt-1 w-48 bg-white rounded-xl shadow-lg border-0 z-20 py-1 animate-in fade-in zoom-in duration-100 overflow-hidden">
                  <button 
                    onClick={() => { onPromote(); setShowMenu(false); }}
                    className="w-full px-4 py-3 text-left text-[14px] text-slate-700 bg-white hover:bg-gray-50 flex items-center gap-2 border-0 outline-none transition-colors"
                  >
                    Thêm phó nhóm
                  </button>
                  <button 
                    onClick={() => { onKick(); setShowMenu(false); }}
                    className="w-full px-4 py-3 text-left text-[14px] text-red-600 bg-white hover:bg-red-50 flex items-center gap-2 border-0 outline-none transition-colors"
                  >
                    Xóa khỏi nhóm
                  </button>
                </div>
              </>
            )}
          </div>
        )}
      </div>
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
  members: { userId: string; role: string }[];
  currentUserId?: string;
  onConfirm: (newOwnerId: string) => void;
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const { userMap } = useUserStore();

  const otherMembers = useMemo(() => {
    return members
      .filter(m => m.userId !== currentUserId)
      .filter(m => {
        const profile = userMap[m.userId];
        if (!searchTerm) return true;
        return profile?.displayName?.toLowerCase().includes(searchTerm.toLowerCase());
      });
  }, [members, currentUserId, searchTerm, userMap]);

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Chọn trưởng nhóm mới trước khi rời"
      variant="confirm"
      footer={
        <div className="flex gap-3 justify-end w-full">
          <button 
            className="px-6 py-2 rounded-lg bg-gray-100 text-slate-700 font-semibold hover:bg-gray-200 transition-colors border-0 outline-none"
            onClick={onClose}
          >
            Hủy
          </button>
          <button 
            className={`px-6 py-2 rounded-lg font-semibold transition-colors border-0 outline-none ${
              selectedId 
                ? 'bg-[#0091FF] text-white hover:bg-blue-600' 
                : 'bg-blue-300 text-white cursor-not-allowed'
            }`}
            onClick={() => selectedId && onConfirm(selectedId)}
            disabled={!selectedId}
          >
            Chọn và tiếp tục
          </button>
        </div>
      }
    >
      <div className="flex flex-col gap-4 max-h-[60vh]">
        <div className="relative">
          <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input 
            type="text"
            placeholder="Tìm kiếm"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-gray-100 border border-gray-200 rounded-xl py-2.5 pl-10 pr-4 text-[15px] focus:ring-1 focus:ring-blue-400 outline-none"
          />
        </div>

        <div className="overflow-y-auto space-y-1 min-h-[200px]">
          {otherMembers.length > 0 ? (
            otherMembers.map((member) => {
              const profile = userMap[member.userId];
              const isSelected = selectedId === member.userId;
              
              return (
                <div 
                  key={member.userId}
                  className="flex items-center gap-3 p-3 rounded-xl hover:bg-gray-50 cursor-pointer transition-colors"
                  onClick={() => setSelectedId(member.userId)}
                >
                  <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
                    isSelected ? 'border-[#0091FF]' : 'border-gray-300'
                  }`}>
                    {isSelected && <div className="w-2.5 h-2.5 rounded-full bg-[#0091FF]" />}
                  </div>
                  <UserAvatar 
                    name={profile?.displayName || 'Thành viên'} 
                    imageUrl={profile?.avatarUrl} 
                    size="md" 
                  />
                  <span className="text-[15px] font-medium text-slate-800 truncate">
                    {profile?.displayName || 'Đang tải...'}
                  </span>
                </div>
              );
            })
          ) : (
            <div className="py-10 text-center text-slate-500 text-[14px]">
              Không tìm thấy thành viên
            </div>
          )}
        </div>
      </div>
    </Modal>
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
    <button
      type="button"
      onClick={() => !disabled && onChange?.(!checked)}
      disabled={disabled}
      className={`relative h-7 w-12 rounded-full border-0 shadow-none outline-none ring-0 transition-all focus:outline-none ${
        disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
      } ${checked ? 'bg-[#0091FF]' : 'bg-gray-300'}`}
    >
      <div
        className={`absolute top-0.5 h-6 w-6 rounded-full bg-white shadow transition-all ${
          checked ? 'translate-x-6' : 'translate-x-0.5'
        }`}
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