import React from 'react';
import { X, Plus, Settings } from 'lucide-react';
import type { PollMetadata } from '../chat.types';

interface CreatePollModalProps {
  onClose: () => void;
  onCreate: (poll: PollMetadata) => void;
}

export function CreatePollModal({ onClose, onCreate }: CreatePollModalProps) {
  const [question, setQuestion] = React.useState('');
  const [options, setOptions] = React.useState(['', '']);
  const [allowMultiple, setAllowMultiple] = React.useState(false);
  const [allowAddOption, setAllowAddOption] = React.useState(false);
  const [isAnonymous, setIsAnonymous] = React.useState(false);
  // const [expiresAt, setExpiresAt] = React.useState<string | null>(null);

  const handleAddField = () => {
    setOptions([...options, '']);
  };

  const handleUpdateOption = (index: number, value: string) => {
    const newOptions = [...options];
    newOptions[index] = value;
    setOptions(newOptions);
  };

  const filledOptions = options.filter(opt => opt.trim().length > 0);
  const isValid = question.trim().length > 0 && filledOptions.length >= 2;

  const handleCreate = () => {
    if (!isValid) return;

    const poll: PollMetadata = {
      id: `p${Date.now()}`,
      question: question.trim(),
      options: filledOptions.map((opt, idx) => ({
        id: `o${idx}`,
        label: opt.trim(),
        votes: []
      })),
      allowMultiple,
      allowAddOption,
      isAnonymous,
      expiresAt: null,
      totalVotes: 0
    };

    onCreate(poll);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-[var(--surface)] w-[500px] rounded-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh] border border-[var(--border)]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--border)]">
          <h2 className="text-[17px] font-bold text-[var(--text)]">Tạo bình chọn</h2>
          <button 
            onClick={onClose}
            className="p-1 hover:bg-[var(--surface-hover)] rounded-full transition-colors border-none bg-transparent cursor-pointer"
          >
            <X size={20} className="text-[var(--muted)] hover:text-[var(--text)]" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-6 custom-scrollbar">
          {/* Question Section */}
          <div className="space-y-2">
            <label className="text-[14px] font-medium text-[var(--muted)]">Chủ đề bình chọn</label>
            <div className="relative">
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value.slice(0, 200))}
                placeholder="Đặt câu hỏi bình chọn"
                className="w-full h-32 px-4 py-3 rounded-lg border border-blue-500 bg-[var(--bg)] focus:outline-none resize-none text-[15px] placeholder:text-[var(--muted)] opacity-80 text-[var(--text)]"
              />
              <span className="absolute bottom-2 right-3 text-[12px] text-[var(--muted)]">
                {question.length}/200
              </span>
            </div>
          </div>

          {/* Options Section */}
          <div className="space-y-3">
            <label className="text-[14px] font-medium text-[var(--muted)]">Các lựa chọn</label>
            <div className="space-y-3">
              {options.map((opt, idx) => (
                <input
                  key={idx}
                  type="text"
                  value={opt}
                  onChange={(e) => handleUpdateOption(idx, e.target.value)}
                  placeholder={`Lựa chọn ${idx + 1}`}
                  className="w-full h-11 px-4 rounded-md border border-[var(--border)] bg-[var(--bg)] focus:border-blue-400 focus:outline-none text-[15px] text-[var(--text)] transition-colors"
                />
              ))}
            </div>
            
            <button 
              onClick={handleAddField}
              className="flex items-center gap-2 text-blue-600 dark:text-sky-400 font-medium text-[15px] py-2 hover:underline bg-transparent border-none cursor-pointer outline-none"
            >
              <Plus size={20} strokeWidth={2.5} />
              Thêm lựa chọn
            </button>
          </div>

          {/* Settings Section */}
          <div className="pt-4 border-t border-[var(--border)] space-y-4">
            <label className="text-[14px] font-medium text-[var(--muted)] flex items-center gap-2">
              <Settings size={16} />
              Cài đặt bình chọn
            </label>
            
            <div className="space-y-3">
              <label className="flex items-center gap-3 cursor-pointer group">
                <input 
                  type="checkbox" 
                  checked={allowMultiple}
                  onChange={(e) => setAllowMultiple(e.target.checked)}
                  className="w-5 h-5 rounded border-[var(--border)] text-blue-600 focus:ring-blue-500 cursor-pointer" 
                />
                <span className="text-[15px] text-[var(--text)] group-hover:text-blue-600 transition-colors">Cho phép chọn nhiều phương án</span>
              </label>

              <label className="flex items-center gap-3 cursor-pointer group">
                <input 
                  type="checkbox" 
                  checked={allowAddOption}
                  onChange={(e) => setAllowAddOption(e.target.checked)}
                  className="w-5 h-5 rounded border-[var(--border)] text-blue-600 focus:ring-blue-500 cursor-pointer" 
                />
                <span className="text-[15px] text-[var(--text)] group-hover:text-blue-600 transition-colors">Có thể thêm phương án</span>
              </label>

              <label className="flex items-center gap-3 cursor-pointer group">
                <input 
                  type="checkbox" 
                  checked={isAnonymous}
                  onChange={(e) => setIsAnonymous(e.target.checked)}
                  className="w-5 h-5 rounded border-[var(--border)] text-blue-600 focus:ring-blue-500 cursor-pointer" 
                />
                <span className="text-[15px] text-[var(--text)] group-hover:text-blue-600 transition-colors">Bình chọn ẩn danh</span>
              </label>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[var(--border)] flex items-center justify-between bg-[var(--surface-hover)]/30">
          <button className="p-2 hover:bg-[var(--surface-hover)] rounded-md transition-colors border-none bg-transparent cursor-pointer outline-none">
            <Settings size={22} className="text-[var(--muted)] hover:text-[var(--text)]" />
          </button>

          <div className="flex items-center gap-3">
            <button 
              onClick={onClose}
              className="px-6 h-10 rounded-md bg-[var(--bg)] hover:bg-[var(--surface-hover)] text-[var(--text)] font-bold text-[15px] transition-colors border-none cursor-pointer outline-none"
            >
              Hủy
            </button>
            <button 
              disabled={!isValid}
              onClick={handleCreate}
              className={`px-8 h-10 rounded-md font-bold text-[15px] transition-all border-none cursor-pointer outline-none active:scale-95 ${
                isValid 
                  ? 'bg-blue-600 text-white hover:bg-blue-700 shadow-md' 
                  : 'bg-blue-100 dark:bg-blue-900/20 text-white dark:text-[var(--muted)] cursor-not-allowed'
              }`}
            >
              Tạo bình chọn
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
