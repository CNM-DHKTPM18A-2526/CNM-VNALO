import { useEffect, useMemo, useRef, useState, type ChangeEvent, type ReactNode } from 'react'
import {
  AtSign,
  ChevronDown,
  Ellipsis,
  ImageIcon,
  Mic,
  Paperclip,
  SendHorizontal,
  Smile,
  Sticker,
  ThumbsUp,
  Type,
} from 'lucide-react'

import { DEFAULT_CHAT_STICKERS } from '../chat.stickers'
import type { ChatComposePayload, ChatSticker } from '../chat.types'

type EmojiTabKey = 'recent' | 'smileys' | 'hearts' | 'objects'

const RECENT_EMOJI_STORAGE_KEY = 'vnalo.recent-emojis'

const EMOJI_TAB_ITEMS: Array<{ key: EmojiTabKey; label: string }> = [
  { key: 'recent', label: 'Gần đây' },
  { key: 'smileys', label: 'Mặt cười' },
  { key: 'hearts', label: 'Trái tim' },
  { key: 'objects', label: 'Đồ vật' },
]

const EMOJI_BY_TAB: Record<Exclude<EmojiTabKey, 'recent'>, string[]> = {
  smileys: ['😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😎', '🤔', '😭', '😡', '🥳'],
  hearts: ['❤️', '🩷', '🧡', '💛', '💚', '💙', '💜', '🤍', '🖤', '💖', '💘', '💕'],
  objects: ['👍', '🙏', '👏', '🔥', '✨', '🎉', '📷', '🎵', '🎁', '💡', '📌', '✅'],
}

type MessageInputProps = {
  onSend: (message: ChatComposePayload) => void
  recipientName?: string
  placeholder?: string
  disabled?: boolean
}

export function MessageInput({
  onSend,
  recipientName,
  placeholder,
  disabled = false,
}: MessageInputProps) {
  const [messageText, setMessageText] = useState('')
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [isStickerOpen, setIsStickerOpen] = useState(false)
  const [isEmojiOpen, setIsEmojiOpen] = useState(false)
  const [activeEmojiTab, setActiveEmojiTab] = useState<EmojiTabKey>('smileys')
  const [recentEmojis, setRecentEmojis] = useState<string[]>([])
  const [error, setError] = useState('')
  const [fileInputMode, setFileInputMode] = useState<'image' | 'file'>('file')
  const [isFocused, setIsFocused] = useState(false)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const emojiPanelRef = useRef<HTMLDivElement | null>(null)
  const emojiTriggerRef = useRef<HTMLButtonElement | null>(null)

  const resolvedRecipientName = recipientName?.trim() || 'người nhận'
  const dynamicPlaceholder = placeholder || `Nhập @, tin nhắn tới ${resolvedRecipientName}`
  const hasTypedContent = messageText.trim().length > 0

  const canSend = useMemo(() => Boolean(messageText.trim() || selectedFile), [messageText, selectedFile])

  const filePreviewUrl = useMemo(() => (selectedFile ? URL.createObjectURL(selectedFile) : null), [selectedFile])

  const visibleEmojis = useMemo(() => {
    if (activeEmojiTab === 'recent') {
      return recentEmojis
    }

    return EMOJI_BY_TAB[activeEmojiTab]
  }, [activeEmojiTab, recentEmojis])

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(RECENT_EMOJI_STORAGE_KEY)
      if (!raw) {
        return
      }

      const parsed = JSON.parse(raw) as unknown
      if (Array.isArray(parsed)) {
        const validated = parsed.filter((item): item is string => typeof item === 'string').slice(0, 16)
        // Use requestAnimationFrame to avoid synchronous setState in effect warning
        requestAnimationFrame(() => {
          setRecentEmojis(validated)
        })
      }
    } catch {
      requestAnimationFrame(() => {
        setRecentEmojis([])
      })
    }
  }, [])

  useEffect(() => {
    if (!isEmojiOpen) {
      return
    }

    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as Node
      const inPanel = emojiPanelRef.current?.contains(target)
      const inTrigger = emojiTriggerRef.current?.contains(target)

      if (inPanel || inTrigger) {
        return
      }

      setIsEmojiOpen(false)
    }

    window.addEventListener('pointerdown', onPointerDown)
    return () => {
      window.removeEventListener('pointerdown', onPointerDown)
    }
  }, [isEmojiOpen])

  useEffect(() => {
    return () => {
      if (filePreviewUrl) {
        URL.revokeObjectURL(filePreviewUrl)
      }
    }
  }, [filePreviewUrl])

  const openFilePicker = (mode: 'image' | 'file') => {
    if (disabled) {
      return
    }

    setError('')
    setFileInputMode(mode)
    fileInputRef.current?.click()
  }

  const handleFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0] ?? null
    event.target.value = ''

    if (!file) {
      return
    }

    const isImage = file.type.startsWith('image/')
    const sizeLimit = isImage ? 8 * 1024 * 1024 : 20 * 1024 * 1024

    if (file.size > sizeLimit) {
      setError(isImage ? 'Ảnh/Video vượt quá 8 MB.' : 'Tệp vượt quá 20 MB.')
      return
    }

    setSelectedFile(file)
  }

  const submitMessage = (payload?: ChatComposePayload) => {
    const draft = payload ?? {
      text: messageText,
      file: selectedFile,
      sticker: null,
    }

    const trimmed = draft.text.trim()

    if (!trimmed && !draft.file && !draft.sticker) {
      return
    }

    if (disabled) {
      return
    }

    onSend({
      text: trimmed,
      file: draft.file ?? null,
      sticker: draft.sticker ?? null,
    })

    setMessageText('')
    setSelectedFile(null)
    setError('')
  }

  const handleStickerSend = (sticker: ChatSticker) => {
    if (disabled) {
      return
    }

    submitMessage({
      text: messageText,
      file: null,
      sticker,
    })

    setIsStickerOpen(false)
  }

  const handleSendClick = () => {
    submitMessage()
  }

  const onStickerClick = () => {
    if (disabled) {
      return
    }

    setIsStickerOpen((prev) => !prev)
    setIsEmojiOpen(false)
  }

  const onEmojiClick = () => {
    if (disabled) {
      return
    }

    setIsEmojiOpen((prev) => !prev)
    if (!isEmojiOpen) {
      setActiveEmojiTab((prev) => (recentEmojis.length > 0 ? 'recent' : prev))
    }
    setIsStickerOpen(false)
  }

  const handlePickEmoji = (emoji: string) => {
    setMessageText((prev) => `${prev}${emoji}`)
    setRecentEmojis((prev) => {
      const next = [emoji, ...prev.filter((item) => item !== emoji)].slice(0, 16)
      window.localStorage.setItem(RECENT_EMOJI_STORAGE_KEY, JSON.stringify(next))
      return next
    })
    setIsEmojiOpen(false)
  }

  const previewSrc = (filePreviewUrl ?? '').trim()
  const isSelectedImage = Boolean(selectedFile?.type.startsWith('image/'))

  return (
    <footer className='message-input'>
      <input
        ref={fileInputRef}
        type='file'
        className='message-input-file'
        accept={fileInputMode === 'image' ? 'image/*,video/*' : '*/*'}
        onChange={handleFileChange}
      />

      {selectedFile ? (
        <div className='message-input-preview'>
          {isSelectedImage && previewSrc ? (
            <img className='message-input-preview-image' src={previewSrc} alt={selectedFile.name} />
          ) : (
            <div className='message-input-preview-file'>
              <Paperclip size={16} />
              <div>
                <strong>{selectedFile.name}</strong>
                <span>{Math.ceil(selectedFile.size / 1024)} KB</span>
              </div>
            </div>
          )}
          <button
            className='message-input-preview-remove'
            type='button'
            onClick={() => setSelectedFile(null)}
            aria-label='Xóa tệp đính kèm'
          >
            ×
          </button>
        </div>
      ) : null}

      <div className='flex flex-col gap-2 rounded-[16px] bg-white p-2'>
        {/* Toolbar (row 1): horizontal, scrollable on mobile */}
        <div className='flex items-center gap-1 overflow-x-auto px-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden'>
          {/* Sticker button on toolbar (separate from emoji button on input right). */}
          <ToolIconButton label='Sticker' disabled={disabled} onClick={onStickerClick}>
            <Sticker size={24} />
          </ToolIconButton>
          <ToolIconButton label='Ảnh/Video' disabled={disabled} onClick={() => openFilePicker('image')}>
            <ImageIcon size={24} />
          </ToolIconButton>
          <ToolIconButton label='Đính kèm file' disabled={disabled} onClick={() => openFilePicker('file')}>
            <Paperclip size={24} />
          </ToolIconButton>
          <ToolIconButton label='Mention' disabled={disabled}>
            <AtSign size={24} />
          </ToolIconButton>
          <ToolIconButton label='Định dạng chữ' disabled={disabled} className='w-12'>
            <span className='inline-flex items-center gap-0.5'>
              <Type size={22} />
              <ChevronDown size={14} />
            </span>
          </ToolIconButton>
          <ToolIconButton label='Ghi âm' disabled={disabled}>
            <Mic size={24} />
          </ToolIconButton>
          <ToolIconButton label='Sticker nhanh' disabled={disabled} onClick={onStickerClick}>
            <Sticker size={24} />
          </ToolIconButton>
          <ToolIconButton label='Thêm' disabled={disabled}>
            <Ellipsis size={24} />
          </ToolIconButton>
        </div>

        {/* Input Bar (row 2): input in center, actions on the right */}
        <div
          className={`flex h-[50px] items-center gap-2 rounded-full border bg-white px-4 transition ${
            isFocused ? 'border-sky-300 shadow-[0_0_0_3px_rgba(0,122,255,0.12)]' : 'border-slate-200'
          } ${disabled ? 'opacity-70' : ''}`}
        >
          <div className='flex min-w-0 flex-1 items-center'>
            <input
              className='h-full w-full border-0 bg-transparent text-[15px] text-slate-800 outline-none placeholder:text-slate-400'
              placeholder={dynamicPlaceholder}
              value={messageText}
              disabled={disabled}
              onFocus={() => setIsFocused(true)}
              onBlur={() => setIsFocused(false)}
              onChange={(event) => setMessageText(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault()
                  handleSendClick()
                }
              }}
            />
          </div>

          <div className='flex shrink-0 items-center gap-1'>
            {/* Emoji button beside input (opens emoji picker). */}
            <button
              ref={emojiTriggerRef}
              type='button'
              className='inline-flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent text-slate-500 transition hover:bg-slate-100'
              aria-label='Mở emoji'
              disabled={disabled}
              onClick={onEmojiClick}
            >
              <Smile size={24} />
            </button>

            <button
              type='button'
              className={`inline-flex h-9 w-9 items-center justify-center rounded-full border-0 bg-transparent transition ${
                hasTypedContent ? 'text-[#007AFF] hover:bg-blue-50' : 'text-slate-500 hover:bg-slate-100'
              }`}
              onClick={hasTypedContent ? handleSendClick : undefined}
              disabled={disabled || (hasTypedContent ? !canSend : false)}
              aria-label={hasTypedContent ? 'Gửi tin nhắn' : 'Thả like nhanh'}
            >
              <span key={hasTypedContent ? 'send' : 'like'} className='inline-flex items-center justify-center animate-[reaction-pop_160ms_ease-out]'>
                {hasTypedContent ? <SendHorizontal size={24} /> : <ThumbsUp size={24} />}
              </span>
            </button>
          </div>
        </div>
      </div>

      {error ? <p className='message-input-error'>{error}</p> : null}

      {isEmojiOpen ? (
        <div ref={emojiPanelRef} className='message-input-sticker-panel'>
          <div className='mb-2 flex items-center gap-1 border-b border-slate-200 pb-2'>
            {EMOJI_TAB_ITEMS.map((tab) => (
              <button
                key={tab.key}
                type='button'
                onClick={() => setActiveEmojiTab(tab.key)}
                className={`rounded-full px-3 py-1 text-xs font-medium transition ${
                  activeEmojiTab === tab.key
                    ? 'bg-sky-100 text-sky-700'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className='flex flex-wrap gap-2 p-1'>
            {visibleEmojis.length > 0 ? (
              visibleEmojis.map((emoji) => (
                <button
                  key={`${activeEmojiTab}-${emoji}`}
                  type='button'
                  className='inline-flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 bg-white text-2xl transition hover:bg-slate-50'
                  onClick={() => handlePickEmoji(emoji)}
                  aria-label={`Chọn emoji ${emoji}`}
                >
                  {emoji}
                </button>
              ))
            ) : (
              <p className='px-2 py-3 text-sm text-slate-500'>Chưa có emoji gần đây</p>
            )}
          </div>
        </div>
      ) : null}

      {isStickerOpen ? (
        <div className='message-input-sticker-panel'>
          <div className='message-input-sticker-grid'>
            {DEFAULT_CHAT_STICKERS.map((sticker) => (
              <button
                key={sticker.id}
                className='message-input-sticker-option'
                type='button'
                disabled={disabled}
                onClick={() => handleStickerSend(sticker)}
                title={sticker.name}
              >
                {sticker.url ? <img src={sticker.url} alt={sticker.name} /> : null}
                <span>{sticker.name}</span>
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </footer>
  )
}

type ToolIconButtonProps = {
  children: ReactNode
  label: string
  disabled?: boolean
  className?: string
  onClick?: () => void
}

function ToolIconButton({ children, label, disabled = false, className, onClick }: ToolIconButtonProps) {
  return (
    <button
      type='button'
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-0 bg-transparent text-slate-500 transition hover:bg-slate-100 ${
        className ?? ''
      }`}
    >
      {children}
    </button>
  )
}
