import { useEffect, useState } from 'react';
import { Modal } from '../../../shared/components/ui/Modal';
import { UserAvatar } from '../../../shared/components/UserAvatar';

type EditConversationNameModalProps = {
  isOpen: boolean;
  mode: 'group' | 'nickname';
  defaultValue: string;
  avatarUrl?: string | null;
  conversationName?: string;
  onClose: () => void;
  onSubmit: (newName: string) => Promise<void>;
};

export function EditConversationNameModal({
  isOpen,
  mode,
  defaultValue,
  avatarUrl,
  conversationName,
  onClose,
  onSubmit,
}: EditConversationNameModalProps) {
  const [name, setName] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Reset/sync value when modal opens
  useEffect(() => {
    if (isOpen) {
      setName(defaultValue || '');
    }
  }, [isOpen, defaultValue]);

  const isValid = name.trim().length > 0;
  const canSubmit = isValid && !isSubmitting;

  const handleSubmit = async () => {
    if (!canSubmit) return;
    setIsSubmitting(true);
    try {
      await onSubmit(name.trim());
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  const title = mode === 'group' ? 'Đổi tên nhóm' : 'Đặt tên gợi nhớ';
  const description = mode === 'group'
    ? 'Bạn có chắc chắn muốn đổi tên nhóm, khi xác nhận tên nhóm mới sẽ hiển thị với tất cả thành viên.'
    : `Hãy đặt cho ${conversationName || 'người dùng'} một cái tên dễ nhớ. Lưu ý: Tên gợi nhớ sẽ chỉ hiển thị riêng với bạn.`;

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title}>
      <div className="flex flex-col bg-[var(--surface)] -m-5">
        <div className="px-5 py-6 flex flex-col items-center">
          <UserAvatar 
            name={defaultValue || (mode === 'group' ? 'Nhóm' : 'Người dùng')} 
            imageUrl={avatarUrl} 
            size="lg" 
            className="w-[60px] h-[60px] mb-4 shadow-sm border-2 border-[var(--border)]"
            isGroup={mode === 'group'} 
          />
          <p className="text-[14px] text-center text-[var(--muted)] mb-6 px-4">
            {description}
          </p>
          <div className="w-full px-2">
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={isSubmitting}
              className="w-full text-center border-b-2 border-[var(--primary)] text-[16px] font-medium py-2 focus:outline-none placeholder-[var(--muted)] text-[var(--text)] bg-transparent transition-colors disabled:opacity-60"
              placeholder={mode === 'group' ? 'Nhập tên nhóm' : 'Nhập tên gợi nhớ'}
              maxLength={100}
              autoFocus
            />
          </div>
        </div>

        <div className="flex justify-end gap-3 px-5 py-4 border-t border-[var(--border)] bg-[var(--surface)]">
          <button
            className="px-6 py-2.5 rounded font-semibold text-[15px] text-[var(--text)] bg-[var(--surface-muted)] hover:opacity-80 transition-all duration-200 cursor-pointer border-none"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Hủy
          </button>
          <button
            className={`px-6 py-2.5 rounded font-semibold text-[15px] transition-all duration-200 border-none ${canSubmit
              ? 'bg-[var(--primary)] text-white hover:opacity-90 shadow-sm cursor-pointer'
              : 'bg-[var(--primary)] opacity-40 text-white cursor-not-allowed'
              }`}
            onClick={handleSubmit}
            disabled={!canSubmit}
          >
            {isSubmitting ? 'Đang xử lý...' : 'Xác nhận'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
