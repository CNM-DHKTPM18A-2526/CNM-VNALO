import { useEffect, useMemo, useState } from 'react'

import { Icon } from '../../../shared/components/Icon'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import type { ChatMessage, ConversationSummary } from '../chat.types'
import { formatMessageContent } from '../utils/messageUtils'

type SearchSenderFilter = 'all' | 'me' | 'other'
type SearchDateFilter = 'all' | 'today' | '7d' | '30d'

type SearchMessagesPanelProps = {
  conversation: ConversationSummary
  onSearchConversation: (conversationId: string, keyword: string) => Promise<{ messages: ChatMessage[]; files: ChatMessage[] }>
  onSelectMessage: (messageId: string) => void
}

function getFileName(url?: string | null): string {
  if (!url) {
    return 'Tệp đính kèm'
  }

  try {
    const pathname = new URL(url).pathname
    const fileName = pathname.split('/').filter(Boolean).pop()
    return fileName || 'Tệp đính kèm'
  } catch {
    return 'Tệp đính kèm'
  }
}

function getFileSearchText(message: ChatMessage): string {
  return [
    message.text,
    message.attachments?.[0]?.name ?? '',
    message.mediaUrl ?? '',
    message.mediaMimeType ?? '',
    getFileName(message.mediaUrl ?? message.attachments?.[0]?.url),
  ]
    .join(' ')
    .toLowerCase()
}

function isSameLocalDay(left: Date, right: Date): boolean {
  return (
    left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate()
  )
}

function matchDateFilter(message: ChatMessage, filter: SearchDateFilter): boolean {
  if (filter === 'all') {
    return true
  }

  if (!message.createdAt) {
    return false
  }

  const date = new Date(message.createdAt)
  if (Number.isNaN(date.getTime())) {
    return false
  }

  const now = new Date()
  if (filter === 'today') {
    return isSameLocalDay(date, now)
  }

  const days = filter === '7d' ? 7 : 30
  const cutoff = new Date(now)
  cutoff.setDate(cutoff.getDate() - days)
  return date >= cutoff
}

export function SearchMessagesPanel({ conversation, onSearchConversation, onSelectMessage }: SearchMessagesPanelProps) {
  const [searchKeyword, setSearchKeyword] = useState('')
  const [debouncedKeyword, setDebouncedKeyword] = useState('')
  const [searchMessages, setSearchMessages] = useState<ChatMessage[]>([])
  const [searchFiles, setSearchFiles] = useState<ChatMessage[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const [searchError, setSearchError] = useState('')
  const [showAllResults, setShowAllResults] = useState(false)
  const [senderFilter, setSenderFilter] = useState<SearchSenderFilter>('all')
  const [dateFilter, setDateFilter] = useState<SearchDateFilter>('all')

  useEffect(() => {
    const timerId = window.setTimeout(() => {
      setDebouncedKeyword(searchKeyword.trim())
    }, 260)

    return () => {
      window.clearTimeout(timerId)
    }
  }, [searchKeyword])

  useEffect(() => {
    let active = true
    
    // Set loading state in next tick to avoid cascading render warning
    const timeoutId = setTimeout(() => {
      if (active) {
        setIsSearching(true)
        setSearchError('')
      }
    }, 0)

    onSearchConversation(conversation.id, debouncedKeyword)
      .then((result) => {
        if (!active) {
          return
        }

        setSearchMessages(result.messages)
        setSearchFiles(result.files)
      })
      .catch((error) => {
        if (!active) {
          return
        }
        console.error('[SearchMessagesPanel.search] Failed to search conversation messages', error)
        setSearchError('Không thể tìm kiếm. Vui lòng thử lại.')
      })
      .finally(() => {
        if (active) {
          setIsSearching(false)
        }
      })

    return () => {
      active = false
      clearTimeout(timeoutId)
    }
  }, [conversation.id, debouncedKeyword, onSearchConversation])

  const filteredSearchMessages = useMemo(
    () =>
      searchMessages.filter((message) => {
        const senderOk = senderFilter === 'all' || message.sender === senderFilter
        const dateOk = matchDateFilter(message, dateFilter)
        return senderOk && dateOk
      }),
    [dateFilter, searchMessages, senderFilter],
  )

  const filteredSearchFiles = useMemo(
    () =>
      searchFiles.filter((message) => {
        const senderOk = senderFilter === 'all' || message.sender === senderFilter
        const dateOk = matchDateFilter(message, dateFilter)
        const keywordOk = !debouncedKeyword || getFileSearchText(message).includes(debouncedKeyword.toLowerCase())
        return senderOk && dateOk && keywordOk
      }),
    [dateFilter, debouncedKeyword, searchFiles, senderFilter],
  )

  const visibleMessageResults = useMemo(() => {
    if (showAllResults) {
      return filteredSearchMessages
    }
    return filteredSearchMessages.slice(0, 5)
  }, [filteredSearchMessages, showAllResults])

  return (
    <div className='chat-search-panel'>
      <div className='chat-search-panel-head'>
        <h3>Tìm kiếm trong trò chuyện</h3>
      </div>

      <div className='chat-search-input-wrap'>
        <Icon name='search' />
        <input
          type='text'
          value={searchKeyword}
          onChange={(event) => {
            setSearchKeyword(event.target.value)
            setShowAllResults(false)
          }}
          placeholder='Nhập từ khóa'
        />
        {searchKeyword ? (
          <button type='button' className='chat-search-clear' onClick={() => setSearchKeyword('')}>
            Xóa
          </button>
        ) : null}
      </div>

      <div className='chat-search-filters'>
        <label className='chat-search-filter'>
          <span>Người gửi</span>
          <select
            value={senderFilter}
            onChange={(event) => {
              setSenderFilter(event.target.value as SearchSenderFilter)
              setShowAllResults(false)
            }}
          >
            <option value='all'>Tất cả</option>
            <option value='me'>Bạn</option>
            <option value='other'>Đối phương</option>
          </select>
        </label>
        <label className='chat-search-filter'>
          <span>Ngày gửi</span>
          <select
            value={dateFilter}
            onChange={(event) => {
              setDateFilter(event.target.value as SearchDateFilter)
              setShowAllResults(false)
            }}
          >
            <option value='all'>Tất cả</option>
            <option value='today'>Hôm nay</option>
            <option value='7d'>7 ngày qua</option>
            <option value='30d'>30 ngày qua</option>
          </select>
        </label>
      </div>

      {isSearching ? <p className='chat-search-state'>Đang tìm...</p> : null}
      {searchError ? <p className='chat-search-state chat-search-state-error'>{searchError}</p> : null}

      <div className='chat-search-section'>
        <h4>Tin nhắn</h4>
        {visibleMessageResults.length === 0 && !isSearching ? (
          <p className='chat-search-empty'>Không tìm thấy tin nhắn phù hợp.</p>
        ) : (
          visibleMessageResults.map((message) => (
            <article
              key={`search-message-${message.id}`}
              className='chat-search-item'
              role='button'
              tabIndex={0}
              onClick={() => onSelectMessage(message.id)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  onSelectMessage(message.id)
                }
              }}
            >
              <UserAvatar name={message.sender === 'me' ? 'Bạn' : conversation.name} size='sm' />
              <div className='chat-search-item-copy'>
                <div className='chat-search-item-top'>
                  <strong>{message.sender === 'me' ? 'Bạn' : conversation.name}</strong>
                  <time>{message.timestamp}</time>
                </div>
                <p>{formatMessageContent(message.text) || (message.type === 'image' ? 'Ảnh' : message.type === 'sticker' ? 'Sticker' : 'Tin nhắn')}</p>
              </div>
            </article>
          ))
        )}

        {!showAllResults && filteredSearchMessages.length > visibleMessageResults.length ? (
          <button className='chat-search-more' type='button' onClick={() => setShowAllResults(true)}>
            Xem thêm
          </button>
        ) : null}
      </div>

      <div className='chat-search-section'>
        <h4>File</h4>
        {searchFiles.length === 0 && !isSearching ? (
          <p className='chat-search-empty'>Không có file phù hợp.</p>
        ) : (
          filteredSearchFiles.slice(0, 8).map((message) => (
            <article
              key={`search-file-${message.id}`}
              className='chat-search-file-item'
              role='button'
              tabIndex={0}
              onClick={() => onSelectMessage(message.id)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  onSelectMessage(message.id)
                }
              }}
            >
              <span className='chat-search-file-icon'>
                <Icon name='file' />
              </span>
              <div className='chat-search-item-copy'>
                <strong>{getFileName(message.mediaUrl ?? message.attachments?.[0]?.url)}</strong>
                <p>{message.attachments?.[0]?.name ?? message.text ?? message.timestamp}</p>
              </div>
            </article>
          ))
        )}
      </div>
    </div>
  )
}
