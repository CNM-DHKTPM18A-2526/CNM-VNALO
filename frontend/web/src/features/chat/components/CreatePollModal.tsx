import React, { useState } from 'react';
import { X, Plus, Settings } from 'lucide-react';
import type { PollMetadata } from '../chat.types';

interface CreatePollModalProps {
  onClose: () => void;
  onCreate: (poll: PollMetadata) => void;
}

export function CreatePollModal({ onClose, onCreate }: CreatePollModalProps) {
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);

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
      id: `poll-${Date.now()}`,
      question: question.trim(),
      options: filledOptions.map((opt, idx) => ({
        id: `opt-${idx}-${Date.now()}`,
        label: opt.trim(),
        votes: []
      })),
      totalVotes: 0
    };

    onCreate(poll);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 animate-in fade-in duration-200">
      <div className="bg-white w-[500px] rounded-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100">
          <h2 className="text-[17px] font-bold text-slate-800">Tạo bình chọn</h2>
          <button 
            onClick={onClose}
            className="p-1 hover:bg-slate-100 rounded-full transition-colors border-none bg-transparent cursor-pointer"
          >
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-6 custom-scrollbar">
          {/* Question Section */}
          <div className="space-y-2">
            <label className="text-[14px] font-medium text-slate-600">Chủ đề bình chọn</label>
            <div className="relative">
              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value.slice(0, 200))}
                placeholder="Đặt câu hỏi bình chọn"
                className="w-full h-32 px-4 py-3 rounded-lg border border-blue-500 focus:outline-none resize-none text-[15px] placeholder:text-slate-400"
              />
              <span className="absolute bottom-2 right-3 text-[12px] text-slate-400">
                {question.length}/200
              </span>
            </div>
          </div>

          {/* Options Section */}
          <div className="space-y-3">
            <label className="text-[14px] font-medium text-slate-600">Các lựa chọn</label>
            <div className="space-y-3">
              {options.map((opt, idx) => (
                <input
                  key={idx}
                  type="text"
                  value={opt}
                  onChange={(e) => handleUpdateOption(idx, e.target.value)}
                  placeholder={`Lựa chọn ${idx + 1}`}
                  className="w-full h-11 px-4 rounded-md border border-slate-200 focus:border-blue-400 focus:outline-none text-[15px] transition-colors"
                />
              ))}
            </div>
            
            <button 
              onClick={handleAddField}
              className="flex items-center gap-2 text-blue-600 font-medium text-[15px] py-2 hover:underline bg-transparent border-none cursor-pointer"
            >
              <Plus size={20} strokeWidth={2.5} />
              Thêm lựa chọn
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-100 flex items-center justify-between">
          <button className="p-2 hover:bg-slate-100 rounded-md transition-colors border-none bg-transparent cursor-pointer">
            <Settings size={22} className="text-slate-600" />
          </button>

          <div className="flex items-center gap-3">
            <button 
              onClick={onClose}
              className="px-6 h-10 rounded-md bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-[15px] transition-colors border-none cursor-pointer"
            >
              Hủy
            </button>
            <button 
              disabled={!isValid}
              onClick={handleCreate}
              className={`px-6 h-10 rounded-md font-bold text-[15px] transition-all border-none cursor-pointer ${
                isValid 
                  ? 'bg-blue-300 text-white hover:bg-blue-400' 
                  : 'bg-blue-100 text-white cursor-not-allowed opacity-70'
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
