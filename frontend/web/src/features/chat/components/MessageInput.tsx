import React, { type ChangeEvent } from 'react'
import {
  AtSign,
  Ellipsis,
  ImageIcon,
  Mic,
  Paperclip,
  Smile,
  Sticker,
  ThumbsUp,
  History,
  Search,
  Minimize2,
  ChevronLeft,
  ChevronRight,
  Settings,
  Plus,
  X,
} from 'lucide-react'

import type { ChatComposePayload } from '../chat.types'
import { useAuth } from '../../auth/useAuth'
import { fetchStickerPacks, fetchStickerPackDetails, fetchMediaByCategory } from '../chat.api'

type PickerTab = 'STICKER' | 'EMOJI' | 'GIF'

import { MentionPopover } from './MentionPopover'

type MessageInputProps = {
  onSend: (message: ChatComposePayload) => void
  recipientName?: string
  placeholder?: string
  disabled?: boolean
  replyMessage?: any | null
  onCancelReply?: () => void
  members?: Array<{ userId: string; displayName: string; avatarUrl?: string | null }>
  suggestedReplies?: string[]
  onSelectSuggestedReply?: (reply: string) => void
  initialText?: string
}

type FilePreviewItem = {
  file: File
  previewUrl: string | null
}

function getFileIdentity(file: File) {
  return `${file.name}-${file.size}-${file.lastModified}`
}

export function MessageInput({
  onSend,
  recipientName,
  placeholder,
  disabled = false,
  replyMessage,
  onCancelReply,
  members = [],
  suggestedReplies = [],
  onSelectSuggestedReply,
  initialText,
}: MessageInputProps) {
  const { accessToken } = useAuth()
  const [messageText, setMessageText] = React.useState('')
  const [mentions, setMentions] = React.useState<Array<{ displayName: string; userId: string }>>([])
  const [selectedFiles, setSelectedFiles] = React.useState<File[]>([])

  const handleSelectSuggestedReply = (reply: string) => {
    setMessageText(reply)
    onSelectSuggestedReply?.(reply)
    setTimeout(() => {
      messageInputRef.current?.focus()
    }, 50)
  }

  // Mention State
  const [mentionState, setMentionState] = React.useState<{
    isOpen: boolean;
    filter: string;
    cursorPos: number;
    left: number;
  }>({
    isOpen: false,
    filter: '',
    cursorPos: 0,
    left: 0
  });

  const messageInputRef = React.useRef<HTMLInputElement>(null);

  // Unified Picker State
  const [isPickerOpen, setIsPickerOpen] = React.useState(false)
  const [activeTab, setActiveTab] = React.useState<PickerTab>('STICKER')

  // Asset States
  const [stickerPacks, setStickerPacks] = React.useState<any[]>([])
  const [selectedPack, setSelectedPack] = React.useState<any | null>(null)
  const [emojis, setEmojis] = React.useState<any[]>([])
  const [gifs, setGifs] = React.useState<any[]>([])
  const [isLoadingAssets, setIsLoadingAssets] = React.useState(false)
  const [assetError, setAssetError] = React.useState<string | null>(null)

  const [error, setError] = React.useState('')
  const [isFocused, setIsFocused] = React.useState(false)
  const fileInputRef = React.useRef<HTMLInputElement | null>(null)

  React.useEffect(() => {
    const normalized = initialText?.trim()
    if (!normalized) return
    setMessageText(normalized)
    setTimeout(() => {
      messageInputRef.current?.focus()
    }, 50)
  }, [initialText])
  
  const handleTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    const pos = e.target.selectionStart || 0;
    setMessageText(value);

    // Mention logic
    const lastAtIdx = value.lastIndexOf('@', pos - 1);
    if (lastAtIdx !== -1) {
      const textAfterAt = value.substring(lastAtIdx + 1, pos);
      // Only trigger if there's no space between @ and cursor
      if (!textAfterAt.includes(' ')) {
        setMentionState({
          isOpen: true,
          filter: textAfterAt,
          cursorPos: lastAtIdx,
          left: Math.min(pos * 8, 300) 
        });
        return;
      }
    }
    
    if (mentionState.isOpen) {
      setMentionState(prev => ({ ...prev, isOpen: false }));
    }
  };

  const handleSelectMention = (member: { userId: string; displayName: string }) => {
    const before = messageText.substring(0, mentionState.cursorPos);
    const after = messageText.substring(messageInputRef.current?.selectionEnd || 0);
    const mentionText = `@${member.displayName} `;
    const newText = `${before}${mentionText}${after}`;
    setMessageText(newText);
    
    // Add to mentions list
    setMentions(prev => {
      // Avoid duplicate metadata entries for the exact same display name if it's already there
      const exists = prev.some(m => m.userId === member.userId && m.displayName === member.displayName);
      if (exists) return prev;
      return [...prev, { displayName: member.displayName, userId: member.userId }];
    });

    setMentionState(prev => ({ ...prev, isOpen: false }));
    
    // Focus back to input
    setTimeout(() => {
      messageInputRef.current?.focus();
      const newPos = before.length + mentionText.length;
      messageInputRef.current?.setSelectionRange(newPos, newPos);
    }, 0);
  };
  const pickerPanelRef = React.useRef<HTMLDivElement | null>(null)
  const stickerTriggerRef = React.useRef<HTMLButtonElement | null>(null)
  const emojiTriggerRef = React.useRef<HTMLButtonElement | null>(null)

  const dynamicPlaceholder = placeholder || `Nhập @, tin nhắn tới ${recipientName?.trim() || 'người nhận'}`
  const hasAttachments = selectedFiles.length > 0

  const canSend = React.useMemo(() => Boolean(messageText.trim() || hasAttachments), [messageText, hasAttachments])

  const filePreviewItems = React.useMemo<FilePreviewItem[]>(
    () =>
      selectedFiles.map((file) => ({
        file,
        previewUrl: file.type.startsWith('image/') ? URL.createObjectURL(file) : null,
      })),
    [selectedFiles],
  )

  // Close picker when clicking outside
  React.useEffect(() => {
    if (!isPickerOpen) return

    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as Node
      if (!pickerPanelRef.current?.contains(target) &&
        !stickerTriggerRef.current?.contains(target) &&
        !emojiTriggerRef.current?.contains(target)) {
        setIsPickerOpen(false)
      }
    }

    window.addEventListener('pointerdown', onPointerDown)
    return () => window.removeEventListener('pointerdown', onPointerDown)
  }, [isPickerOpen])

  // Fetch Assets when tab changes or picker opens
  React.useEffect(() => {
    if (!isPickerOpen || !accessToken) return

    const loadAssets = async () => {
      setIsLoadingAssets(true)
      setAssetError(null)
      try {
        if (activeTab === 'STICKER' && stickerPacks.length === 0) {
          const packs = await fetchStickerPacks(accessToken)
          setStickerPacks(packs)
          if (packs.length > 0) {
            const packId = packs[0].stickerPackId || packs[0].id
            const detail = await fetchStickerPackDetails(accessToken, packId)
            setSelectedPack(detail)
          }
        } else if (activeTab === 'EMOJI' && emojis.length === 0) {
          const list = await fetchMediaByCategory(accessToken, 'EMOJI')
          setEmojis(list)
        } else if (activeTab === 'GIF' && gifs.length === 0) {
          const list = await fetchMediaByCategory(accessToken, 'GIF')
          setGifs(list)
        }
      } catch (err) {
        console.error('Failed to load assets:', err)
        setAssetError('Không tải được dữ liệu. Vui lòng thử lại.')
      } finally {
        setIsLoadingAssets(false)
      }
    }

    void loadAssets()
  }, [isPickerOpen, activeTab, accessToken, stickerPacks.length, emojis.length, gifs.length])

  const handlePackSelect = async (pack: any) => {
    if (!accessToken) return
    setIsLoadingAssets(true)
    try {
      const packId = pack.stickerPackId || pack.id
      const detail = await fetchStickerPackDetails(accessToken, packId)
      setSelectedPack(detail)
    } finally {
      setIsLoadingAssets(false)
    }
  }

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files ?? [])
    event.target.value = ''
    if (files.length === 0) return

    const invalidFile = files.find((file) => {
      const isImage = file.type.startsWith('image/')
      return file.size > (isImage ? 8 : 20) * 1024 * 1024
    })

    if (invalidFile) {
      setError(invalidFile.type.startsWith('image/') ? 'Ảnh/Video vượt quá 8 MB.' : 'Tệp vượt quá 20 MB.')
      return
    }

    setError('')
    setSelectedFiles((prev) => [...prev, ...files])
  }

  const submitMessage = (payload?: ChatComposePayload) => {
    let processedText = messageText;
    if (!payload) {
      // Process mentions in the messageText
      mentions.forEach(m => {
        const target = `@${m.displayName}`;
        if (processedText.includes(target)) {
          processedText = processedText.replace(target, `\u200B@${m.displayName}|${m.userId}\u200B`);
        }
      });
    }

    const draft = payload ?? {
      text: processedText,
      files: selectedFiles,
      sticker: null,
    }

    if (!draft.text.trim() && !draft.files?.length && !draft.sticker) return
    if (disabled) return

    // Attach reply metadata if present
    if (replyMessage) {
      draft.replyTo = {
        id: replyMessage.id,
        senderId: replyMessage.senderId,
        senderName: replyMessage.sender === 'me' ? 'Bạn' : (replyMessage.senderName || 'Người dùng'),
        preview: replyMessage.text?.slice(0, 50) || (replyMessage.type === 'image' ? '[Hình ảnh]' : '[Tin nhắn]'),
        type: replyMessage.type
      }
      console.log('[MessageInput] Attached replyTo to draft:', draft.replyTo)
    }

    onSend(draft)
    setMessageText('')
    setMentions([])
    setSelectedFiles([])
    setError('')
  }

  const handleStickerClick = () => {
    if (disabled) return
    if (isPickerOpen && activeTab === 'STICKER') {
      setIsPickerOpen(false)
    } else {
      setIsPickerOpen(true)
      setActiveTab('STICKER')
    }
  }

  const handleEmojiTriggerClick = () => {
    if (disabled) return
    if (isPickerOpen && activeTab === 'EMOJI') {
      setIsPickerOpen(false)
    } else {
      setIsPickerOpen(true)
      setActiveTab('EMOJI')
    }
  }

  const handleAssetSelect = (type: 'STICKER' | 'EMOJI' | 'GIF', item: any) => {
    const assetId = item.stickerId || item.mediaId || item.id
    if (type === 'STICKER') {
      submitMessage({
        text: '',
        files: [],
        sticker: { id: assetId, name: item.name || 'Sticker', url: item.url }
      })
    } else if (type === 'GIF') {
      onSend({
        text: '',
        files: [],
        file: null,
        sticker: { id: assetId, name: 'GIF', url: item.url }
      } as any)
    } else if (type === 'EMOJI') {
      submitMessage({
        text: '',
        files: [],
        sticker: { id: assetId, name: 'Emoji', url: item.url }
      })
    }
    setIsPickerOpen(false)
  }

  const removeSelectedFile = (fileToRemove: File) => {
    const identity = getFileIdentity(fileToRemove)
    setSelectedFiles((prev) => prev.filter((file) => getFileIdentity(file) !== identity))
  }

  return (
    <footer className='message-input relative'>
      {suggestedReplies && suggestedReplies.length > 0 && (
        <div className="suggested-replies-container">
          {suggestedReplies.map((reply, index) => (
            <button
              key={index}
              type="button"
              className="suggested-reply-chip"
              onClick={() => handleSelectSuggestedReply(reply)}
            >
              {reply}
            </button>
          ))}
        </div>
      )}
      {mentionState.isOpen && (
        <MentionPopover 
          members={members}
          filter={mentionState.filter}
          position={{ top: 0, left: mentionState.left }}
          onSelect={handleSelectMention}
          onClose={() => setMentionState(prev => ({ ...prev, isOpen: false }))}
        />
      )}
      <input
        ref={fileInputRef}
        type='file'
        className='message-input-file'
        multiple
        style={{ display: 'none' }}
        onChange={handleFileChange}
      />

      {filePreviewItems.length > 0 && (
        <div className='message-input-preview'>
          <div className='flex flex-wrap gap-2'>
            {filePreviewItems.map((item) => (
              <div key={getFileIdentity(item.file)} className='relative h-20 w-20 overflow-hidden rounded-lg border bg-slate-100'>
                {item.previewUrl ? (
                  <img className='h-full w-full object-cover' src={item.previewUrl} alt='preview' />
                ) : (
                  <div className='flex h-full w-full items-center justify-center'><Paperclip size={20} /></div>
                )}
                <button
                  className='absolute right-1 top-1 flex h-5 w-5 items-center justify-center rounded-full bg-black/50 text-white text-xs'
                  onClick={() => removeSelectedFile(item.file)}
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {replyMessage && (
        <div className="flex items-center gap-3 bg-[var(--surface)] border-t border-[var(--border)] px-4 py-2 animate-in fade-in slide-in-from-bottom-1">
          <div className="flex-1 min-w-0 border-l-2 border-blue-500 pl-3">
            <p className="text-xs font-bold text-blue-600 dark:text-sky-400 truncate">
              Đang trả lời {replyMessage.sender === 'me' ? 'chính mình' : replyMessage.senderName}
            </p>
            <p className="text-sm text-[var(--muted)] truncate">
              {replyMessage.type === 'image' ? '[Hình ảnh]' : 
               replyMessage.type === 'sticker' ? '[Sticker]' : 
               replyMessage.type === 'file' ? '[Tệp tin]' : 
               replyMessage.text}
            </p>
          </div>
          <button 
            onClick={onCancelReply}
            className="p-1 hover:bg-[var(--surface-hover)] rounded-full transition-colors text-[var(--muted)]"
          >
            <X size={16} />
          </button>
        </div>
      )}

      <div className="flex flex-col gap-2 rounded-[16px] bg-[var(--surface)] p-2 border border-[var(--border)] shadow-sm">
        <div className='flex items-center gap-1 overflow-x-auto px-1 [scrollbar-width:none]'>
          <ToolIconButton ref={stickerTriggerRef} label='Sticker' disabled={disabled} onClick={handleStickerClick} active={isPickerOpen && activeTab === 'STICKER'}>
            <Sticker size={24} />
          </ToolIconButton>
          <ToolIconButton label='Image' disabled={disabled} onClick={() => openFilePicker('image')}>
            <ImageIcon size={24} />
          </ToolIconButton>
          <ToolIconButton label='File' disabled={disabled} onClick={() => openFilePicker('file')}>
            <Paperclip size={24} />
          </ToolIconButton>
          <ToolIconButton 
            label='Mention' 
            disabled={disabled}
            onClick={() => {
              if (disabled) return;
              const pos = messageInputRef.current?.selectionStart || messageText.length;
              const newText = messageText.substring(0, pos) + '@' + messageText.substring(pos);
              setMessageText(newText);
              setMentionState({
                isOpen: true,
                filter: '',
                cursorPos: pos,
                left: Math.min((pos + 1) * 8, 300)
              });
              setTimeout(() => {
                messageInputRef.current?.focus();
                messageInputRef.current?.setSelectionRange(pos + 1, pos + 1);
              }, 0);
            }}
          >
            <AtSign size={24} />
          </ToolIconButton>
          <ToolIconButton label='Voice' disabled={disabled}><Mic size={24} /></ToolIconButton>
          <div className='flex-1' />
          <ToolIconButton label='More' disabled={disabled}><Ellipsis size={24} /></ToolIconButton>
        </div>

        <div className={`flex h-[48px] items-center gap-2 rounded-full transition relative ${isFocused ? 'bg-[var(--surface)] ring-1 ring-[#0068ff]/30 shadow-sm' : 'bg-[var(--input-bg)] border-0 shadow-inner'}`}>
          <input
            ref={messageInputRef}
            className='h-full w-full border-0 bg-transparent text-[15px] outline-none placeholder:text-[var(--muted)] px-3 text-[var(--text)] relative'
            placeholder={dynamicPlaceholder}
            value={messageText}
            disabled={disabled}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            onChange={handleTextChange}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey && !mentionState.isOpen) {
                e.preventDefault()
                submitMessage()
              }
            }}
          />
          <div className="flex items-center gap-1 pr-1">
            <button
              ref={emojiTriggerRef}
              onClick={handleEmojiTriggerClick}
              className={`p-2 rounded-full transition-all border-0
              ${isPickerOpen
                  ? 'text-blue-500 bg-blue-50 dark:bg-blue-500/10'
                  : 'text-slate-600 dark:text-slate-400 bg-white dark:bg-transparent hover:bg-slate-100 dark:hover:bg-white/5'
                }`}
            >
              <Smile size={24} strokeWidth={1.5} />
            </button>
            <button
              onClick={() => {
                if (canSend) {
                  submitMessage();
                } else {
                  // Send like emoji
                  onSend({
                    text: '👍'
                  });
                }
              }}
              disabled={disabled}
              className={`p-2 rounded-full transition-all border-0 bg-transparent ${canSend ? 'text-blue-500 hover:bg-blue-50 hover:scale-105 active:scale-95' : 'text-slate-400 dark:text-slate-600 hover:bg-slate-100 dark:hover:bg-white/5'}`}
            >
              {canSend ? (
                <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
                </svg>
              ) : (
                <ThumbsUp size={24} strokeWidth={1.5} className="text-yellow-500" />
              )}
            </button>
          </div>
        </div>
      </div>

      {error ? <p className='px-2 text-red-500 text-xs mt-1'>{error}</p> : null}

      {isPickerOpen && (
        <div
          ref={pickerPanelRef}
          className='absolute bottom-full mb-2 left-0 w-[350px] h-[450px] animate-in fade-in slide-in-from-bottom-2 duration-200 shadow-2xl border border-slate-200 dark:border-white/10 rounded-xl overflow-hidden flex flex-col bg-white dark:bg-[#1E1E2E]'
          style={{ zIndex: 100 }}
        >
          {/* Zalo Tabs */}
          <div className='flex items-center border-b border-slate-100 dark:border-white/5 sticky top-0 z-10 bg-white dark:bg-[#1E1E2E]'>
            {(['STICKER', 'EMOJI', 'GIF'] as PickerTab[]).map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`flex-1 py-2.5 text-[13px] font-bold border-0 outline-none transition-all relative bg-transparent ${activeTab === tab ? 'text-blue-600 dark:text-sky-400' : 'text-slate-500 dark:text-slate-400'}`}
              >
                {tab === 'STICKER' ? 'STICKER' : tab === 'EMOJI' ? 'EMOJI' : 'GIF'}
                {activeTab === tab && (
                  <div className='absolute bottom-0 left-0 right-0 h-[2px] bg-blue-600 dark:bg-sky-400' />
                )}
              </button>
            ))}
            <div className='h-4 w-[1px] bg-slate-200 dark:bg-white/10 mx-1' />
            <button className='px-4 text-blue-500 dark:text-sky-400 border-0 bg-transparent cursor-pointer'><Minimize2 size={16} /></button>
          </div>

          {/* Search Bar */}
          {activeTab === 'STICKER' && (
            <div className='px-3 py-2 bg-white dark:bg-[#1E1E2E]'>
              <div className='relative flex items-center bg-slate-50 dark:bg-black/20 rounded-full px-3 py-1.5 border border-slate-100 dark:border-white/5'>
                <Search size={14} className='text-slate-400 mr-2' />
                <input
                  type='text'
                  placeholder='Tìm kiếm sticker'
                  className='bg-transparent border-none outline-none text-[13px] w-full text-slate-600 dark:text-slate-300'
                />
              </div>
            </div>
          )}

          {/* Content Area */}
          <div className='flex-1 zalo-picker-content overflow-y-auto [&::-webkit-scrollbar]:w-[6px] [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:bg-slate-300 dark:[&::-webkit-scrollbar-thumb]:bg-white/10 [&::-webkit-scrollbar-thumb]:rounded-full hover:[&::-webkit-scrollbar-thumb]:bg-slate-400 bg-white dark:bg-[#1E1E2E]'>
            {isLoadingAssets ? (
              <div className='flex h-full flex-col items-center justify-center gap-2 text-slate-400 text-sm'>
                <div className='h-5 w-5 animate-spin rounded-full border-2 border-blue-500 border-t-transparent' />
                Đang tải...
              </div>
            ) : assetError ? (
              <div className='flex h-full flex-col items-center justify-center gap-2 p-4 text-center'>
                <p className='text-slate-500 text-sm'>{assetError}</p>
                <button
                  onClick={() => {
                    setStickerPacks([]);
                    setEmojis([]);
                    setGifs([]);
                  }}
                  className='bg-blue-50 dark:bg-blue-500/10 text-blue-600 dark:text-sky-400 px-4 py-1.5 rounded-full text-sm font-medium hover:bg-blue-100 transition border-0 cursor-pointer'
                >
                  Thử lại
                </button>
              </div>
            ) : (
              <div className='p-3'>
                {activeTab === 'STICKER' && (
                  <div className='flex flex-col gap-5'>
                    <div>
                      <h4 className='text-[12px] font-bold text-slate-600 dark:text-slate-400 mb-2 px-1'>Gần đây</h4>
                      <div className='grid grid-cols-4 gap-2'>
                        {selectedPack?.stickers?.slice(0, 4).map((item: any) => (
                          <button
                            key={`rec-${item.stickerId || item.id}`}
                            onClick={() => handleAssetSelect('STICKER', item)}
                            className='aspect-square rounded-lg transition-all hover:scale-110 active:scale-95 border-0 bg-transparent cursor-pointer'
                          >
                            <img src={item.url} alt={item.name} className='h-full w-full object-contain' />
                          </button>
                        ))}
                      </div>
                    </div>

                    <div>
                      <h4 className='text-[12px] font-bold text-slate-600 dark:text-slate-400 mb-2 px-1'>{selectedPack?.name || 'Stickers'}</h4>
                      <div className='grid grid-cols-4 gap-2'>
                        {selectedPack?.stickers?.map((item: any) => (
                          <button
                            key={item.stickerId || item.id}
                            onClick={() => handleAssetSelect('STICKER', item)}
                            className='aspect-square rounded-lg transition-all hover:scale-110 active:scale-95 border-0 bg-transparent cursor-pointer'
                          >
                            <img src={item.url} alt={item.name} className='h-full w-full object-contain' />
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                {activeTab === 'EMOJI' && (
                  <div className='flex flex-col gap-6'>
                    {/* Recently Used Section */}
                    {emojis.length > 0 && (
                      <div>
                        <h4 className='text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-3 px-1'>Gần đây</h4>
                        <div className='grid grid-cols-9 gap-1'>
                          {emojis.slice(0, 9).map((item: any) => (
                            <button
                              key={`rec-${item.mediaId || item.id}`}
                              onClick={() => handleAssetSelect('EMOJI', item)}
                              className='aspect-square transition-all active:scale-95 border-0 bg-transparent cursor-pointer'
                            >
                              <img src={item.url} alt='Emoji' className='h-full w-full object-contain p-0.5' />
                            </button>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Standard Emotions Section (Zalo Style) */}
                    <div>
                      <h4 className='text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-3 px-1'>Cảm xúc</h4>
                      <div className='grid grid-cols-9 gap-1'>
                        {STANDARD_EMOJI_LIST.map((emojiChar, i) => (
                          <button
                            key={`std-${i}`}
                            onClick={() => {
                              setMessageText(prev => prev + emojiChar);
                            }}
                            className='aspect-square flex items-center justify-center text-3xl transition-all active:scale-75 select-none border-0 bg-transparent cursor-pointer'
                          >
                            {emojiChar}
                          </button>
                        ))}
                        {emojis.map((item: any) => (
                          <button
                            key={item.mediaId || item.id}
                            onClick={() => handleAssetSelect('EMOJI', item)}
                            className='aspect-square transition-all active:scale-95 border-0 bg-transparent cursor-pointer'
                          >
                            <img src={item.url} alt='Emoji' className='h-full w-full object-contain p-0.5' />
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                {activeTab === 'GIF' && (
                  <div className='grid grid-cols-2 gap-3'>
                    {gifs.map((item: any) => (
                      <button
                        key={item.mediaId || item.id}
                        onClick={() => handleAssetSelect('GIF', item)}
                        className='aspect-video rounded-xl overflow-hidden transition-all active:scale-95 border-0 bg-transparent cursor-pointer'
                      >
                        <img src={item.url} alt='GIF' className='h-full w-full object-cover' />
                      </button>
                    ))}
                    {gifs.length === 0 && (
                      <div className='col-span-2 flex flex-col items-center justify-center h-40 text-slate-400 dark:text-slate-500 text-sm'>
                        Chưa có GIF nào
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Zalo Footer Sticker Bar */}
          <div className='flex items-center bg-white dark:bg-[#1E1E2E] h-11 shrink-0 px-1 border-t border-slate-100 dark:border-white/5'>
            <button className='h-full px-2 text-slate-400 dark:text-slate-500 border-0 bg-transparent hover:text-slate-600 dark:hover:text-slate-300 transition'><ChevronLeft size={16} /></button>
            <button className='h-full px-2 text-blue-500 dark:text-sky-400 border-0 bg-transparent'><History size={20} /></button>

            <div className='flex-1 flex items-center overflow-x-auto [scrollbar-width:none] px-1 gap-1 bg-transparent'>
              {stickerPacks.map(pack => (
                <button
                  key={pack.stickerPackId || pack.id}
                  onClick={() => handlePackSelect(pack)}
                  className={`h-9 w-9 shrink-0 flex items-center justify-center rounded transition-all border-0 ${(selectedPack?.stickerPackId || selectedPack?.id) === (pack.stickerPackId || pack.id) ? 'bg-slate-100 dark:bg-white/10 shadow-inner' : 'bg-transparent hover:bg-slate-50 dark:hover:bg-white/5'}`}
                >
                  <img src={pack.coverUrl || pack.thumbnailUrl || pack.avatarUrl} className='h-6 w-6 object-contain' alt='pack' />
                </button>
              ))}
            </div>

            <button className='h-full px-2 text-slate-400 dark:text-slate-500 border-0 bg-transparent hover:text-slate-600 dark:hover:text-slate-300 transition'><Settings size={16} /></button>
            <button className='h-full px-2 text-slate-400 dark:text-slate-500 border-0 bg-transparent hover:text-slate-600 dark:hover:text-slate-300 transition'><ChevronRight size={16} /></button>
            <button className='h-full px-3 text-slate-400 dark:text-slate-500 border-0 bg-transparent hover:text-slate-600 dark:hover:text-slate-300 transition font-light text-xl'><Plus size={18} /></button>
          </div>
        </div>
      )}
    </footer>
  )
}

const ToolIconButton = ({ children, label, disabled = false, className, onClick, active }: any) => {
  return (
    <button
      type='button'
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-0 transition ${active ? 'bg-sky-50 text-sky-600' : 'bg-transparent text-slate-500 hover:bg-slate-100'} ${className ?? ''}`}
    >
      {children}
    </button>
  )
}

// Standards
const STANDARD_EMOJI_LIST = [
  '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '👻', '💀', '☠️', '👽', '👾', '🤖', '💩', '😺', '😸', '😻', '😼', '😽', '🙀', '😿', '😾'
];

function openFilePicker(mode: 'image' | 'file') {
  const input = document.querySelector('.message-input-file') as HTMLInputElement;
  if (input) {
    input.accept = mode === 'image' ? 'image/*,video/*' : '*/*';
    input.click();
  }
}
