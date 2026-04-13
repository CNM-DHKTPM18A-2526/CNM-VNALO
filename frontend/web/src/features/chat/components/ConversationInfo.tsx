import { useMemo, useState } from 'react';
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
  Users,
} from 'lucide-react';

import type { ChatMessage, ConversationSummary } from '../chat.types';
import { UserAvatar } from '../../../shared/components/UserAvatar';

type ConversationInfoProps = {
  conversation: ConversationSummary;
  messages: ChatMessage[];
};

type SectionKey = 'media' | 'files' | 'links' | 'security';

export function ConversationInfo({ conversation, messages }: ConversationInfoProps) {
  const [expanded, setExpanded] = useState<Record<SectionKey, boolean>>({
    media: true,
    files: true,
    links: true,
    security: true,
  });
  const [isHidden, setIsHidden] = useState(false);

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
          <UserAvatar
            name={conversation.name}
            imageUrl={conversation.avatarUrl ?? null}
            size="lg"
            className="h-20 w-20 shadow-lg ring-2 ring-white"
          />
        </div>

        <div className="mt-3 flex items-center justify-center gap-2">
          <h4 className="text-[22px] font-semibold text-slate-900">{conversation.name}</h4>
          <button className="rounded-full border-0 p-1 shadow-none outline-none ring-0 hover:bg-gray-100 focus:outline-none">
            <Pencil size={18} className="text-gray-500" />
          </button>
        </div>

        {/* Action Buttons */}
        <div className="mt-6 grid grid-cols-3 gap-3">
          <ActionButton icon={BellOff} label="Tắt thông báo" />
          <ActionButton icon={Pin} label="Ghim hội thoại" />
          <ActionButton icon={UserPlus} label="Tạo nhóm trò chuyện" />
        </div>
      </section>

      {/* Common Info */}
      <section className="mt-3 bg-white px-5 py-2">
        <InfoRow icon={AlarmClock} text="Danh sách nhắc hẹn" />
        <InfoRow icon={Users} text="5 nhóm chung" />
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
        <FooterAction icon={Trash2} label="Xóa lịch sử trò chuyện" color="text-red-500" />
      </section>
    </div>
  );
}

/* ====================== Helper Components ====================== */

function ActionButton({ icon: Icon, label }: { icon: React.ElementType; label: string }) {
  return (
    <button
      type="button"
      className="flex flex-col items-center rounded-xl border-0 bg-transparent px-1 py-2 shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none"
    >
      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-200">
        <Icon size={16} className="text-slate-600" />
      </div>
      <span className="mt-2 text-center text-[11px] font-medium leading-[1.25] text-slate-700">{label}</span>
    </button>
  );
}

function InfoRow({ icon: Icon, text }: { icon: React.ElementType; text: string }) {
  return (
    <button
      type="button"
      className="flex w-full items-center gap-4 rounded-xl border-0 bg-transparent px-3 py-[13px] text-left shadow-none outline-none ring-0 hover:bg-gray-50 focus:outline-none active:bg-gray-100"
    >
      <Icon size={20} className="text-slate-700" />   {/* giảm từ 22 → 20 */}
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

function FooterAction({ icon: Icon, label, color }: { icon: React.ElementType; label: string; color: string }) {
  return (
    <button
      type="button"
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