import { useCallback, useMemo, useState, useEffect } from 'react'
import { ChevronRight, MessageCircle, Phone, Search, User, X } from 'lucide-react'
import type { GlobalSearchResults, GlobalSearchResult } from '../chat.api'
import {
  searchMessagesLocal,
  searchConversationsLocal,
  searchUsersByPhoneLocal,
  searchUsersLocal,
  updateSearchIndexUsers,
} from '../searchIndex'
import { searchUsers, getUserByPhone } from '../../friends/friends.api'

function normalizeText(value?: string | null): string | undefined {
  return value ?? undefined
}

interface SearchGlobalPanelProps {
  accessToken?: string
  onSelectMessage?: (messageId: string, conversationId: string) => void
  onSelectConversation?: (conversationId: string) => void
  onSelectUser?: (userId: string) => void
  onClose?: () => void
}

export function SearchGlobalPanel({
  accessToken,
  onSelectMessage,
  onSelectConversation,
  onSelectUser,
  onClose,
}: SearchGlobalPanelProps) {
  const [query, setQuery] = useState('')
  const [isSearching, setIsSearching] = useState(false)
  const [results, setResults] = useState<GlobalSearchResults | null>(null)
  const [selectedIndex, setSelectedIndex] = useState(-1)

  // Determine if query looks like a phone number
  const isPhoneQuery = useMemo(() => {
    const normalized = query.replace(/\D/g, '')
    return normalized.length >= 2
  }, [query])

  // Perform search with hybrid approach (local + backend)
  const performSearch = useCallback(
    async (searchQuery: string) => {
      if (!searchQuery || searchQuery.length < 2) {
        setResults(null)
        return
      }

      setIsSearching(true)
      const mergedResults: GlobalSearchResult[] = []
      const seenIds = new Set<string>()
      const cachedUsers: Array<{ id: string; phone?: string; email?: string; displayName?: string; avatarUrl?: string; bio?: string }> = []

      try {
        // Step 1: Search local index (fast)
        if (isPhoneQuery) {
          // Phone number search
          const localUsers = searchUsersByPhoneLocal(searchQuery)
          localUsers.forEach((user) => {
            if (!seenIds.has(user.id)) {
              seenIds.add(user.id)
              mergedResults.push({
                type: 'user',
                id: user.id,
                phone: normalizeText(user.phone),
                displayName: normalizeText(user.displayName),
                displayText: `${user.displayName || user.phone} (${user.phone})`,
                email: normalizeText(user.email),
                avatarUrl: normalizeText(user.avatarUrl),
                bio: normalizeText(user.bio),
              })
              cachedUsers.push({
                id: user.id,
                phone: normalizeText(user.phone),
                email: normalizeText(user.email),
                displayName: normalizeText(user.displayName),
                avatarUrl: normalizeText(user.avatarUrl),
                bio: normalizeText(user.bio),
              })
            }
          })
        } else {
          // Keyword search
          const localMessages = searchMessagesLocal(searchQuery)
          localMessages.forEach((msg) => {
            if (!seenIds.has(msg.id)) {
              seenIds.add(msg.id)
              mergedResults.push({
                type: 'message',
                id: msg.id,
                conversationId: msg.conversationId,
                conversationName: msg.conversationName,
                content: msg.content?.substring(0, 100),
                createdAt: msg.createdAt,
                displayText: msg.content?.substring(0, 50) || '[Media]',
              })
            }
          })

          const localConversations = searchConversationsLocal(searchQuery)
          localConversations.forEach((conv) => {
            if (!seenIds.has(conv.id)) {
              seenIds.add(conv.id)
              mergedResults.push({
                type: 'conversation',
                id: conv.id,
                displayName: conv.name,
                displayText: conv.name || `Cuộc trò chuyện ${conv.id.slice(0, 8)}`,
              })
            }
          })

          // Search local users
          const localUsers = searchUsersLocal(searchQuery)
          localUsers.forEach((user) => {
            if (!seenIds.has(user.id)) {
              seenIds.add(user.id)
              mergedResults.push({
                type: 'user',
                id: user.id,
                displayName: user.displayName,
                displayText: user.displayName || 'Người dùng',
                email: user.email,
                phone: user.phone,
                avatarUrl: user.avatarUrl,
                bio: user.bio,
              })
            }
          })
        }

        // Step 2: Backend search (if token available and not too many local results)
        if (accessToken && mergedResults.length < 30) {
          try {
            if (isPhoneQuery) {
              // Phone number search via backend
              const backendUser = await getUserByPhone(accessToken, searchQuery)
              if (backendUser && !seenIds.has(backendUser.id)) {
                seenIds.add(backendUser.id)
                mergedResults.push({
                  type: 'user',
                  id: backendUser.id,
                  phone: normalizeText(backendUser.phone),
                  displayName: normalizeText(backendUser.displayName),
                  displayText: `${backendUser.displayName || backendUser.phone} (${backendUser.phone})`,
                  email: normalizeText(backendUser.email),
                  avatarUrl: normalizeText(backendUser.avatarUrl),
                  bio: normalizeText(backendUser.bio),
                })
                cachedUsers.push({
                  id: backendUser.id,
                  phone: normalizeText(backendUser.phone),
                  email: normalizeText(backendUser.email),
                  displayName: normalizeText(backendUser.displayName),
                  avatarUrl: normalizeText(backendUser.avatarUrl),
                  bio: normalizeText(backendUser.bio),
                })
              }
            } else {
              // Keyword search via backend
              const backendUsers = await searchUsers(accessToken, searchQuery)
              backendUsers.forEach((user) => {
                if (!seenIds.has(user.id)) {
                  seenIds.add(user.id)
                  mergedResults.push({
                    type: 'user',
                    id: user.id,
                    displayName: normalizeText(user.displayName),
                    displayText: user.displayName || 'Người dùng',
                    email: normalizeText(user.email),
                    phone: normalizeText(user.phone),
                    avatarUrl: normalizeText(user.avatarUrl),
                    bio: normalizeText(user.bio),
                  })
                  cachedUsers.push({
                    id: user.id,
                    phone: normalizeText(user.phone),
                    email: normalizeText(user.email),
                    displayName: normalizeText(user.displayName),
                    avatarUrl: normalizeText(user.avatarUrl),
                    bio: normalizeText(user.bio),
                  })
                }
              })
            }
          } catch (error) {
            console.warn('[SearchGlobalPanel] Backend search failed:', error)
            // Continue with local results only
          }
        }

        // Sort results: conversations and users first, then messages
        mergedResults.sort((a, b) => {
          const typeOrder = { conversation: 0, user: 1, message: 2 }
          return typeOrder[a.type] - typeOrder[b.type]
        })

        setResults({
          query: searchQuery,
          queryType: isPhoneQuery ? 'phone' : 'keyword',
          results: mergedResults.slice(0, 100), // Limit to 100 results
          hasLocalResults: mergedResults.length > 0,
          totalCount: mergedResults.length,
        })

        if (cachedUsers.length > 0) {
          updateSearchIndexUsers(cachedUsers)
        }

        setSelectedIndex(-1)
      } finally {
        setIsSearching(false)
      }
    },
    [accessToken, isPhoneQuery],
  )

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      performSearch(query)
    }, 300)

    return () => clearTimeout(timer)
  }, [query, performSearch])

  // Handle keyboard navigation
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (!results) return

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          setSelectedIndex((prev) => (prev < results.results.length - 1 ? prev + 1 : prev))
          break
        case 'ArrowUp':
          e.preventDefault()
          setSelectedIndex((prev) => (prev > 0 ? prev - 1 : -1))
          break
        case 'Enter': {
          e.preventDefault()
          if (selectedIndex >= 0 && results.results[selectedIndex]) {
            const result = results.results[selectedIndex]
            handleSelectResult(result)
          }
          break
        }
        case 'Escape':
          e.preventDefault()
          onClose?.()
          break
        default:
          break
      }
    },
    [results, selectedIndex, onClose],
  )

  const handleSelectResult = useCallback(
    (result: GlobalSearchResult) => {
      switch (result.type) {
        case 'message':
          onSelectMessage?.(result.id, result.conversationId!)
          break
        case 'conversation':
          onSelectConversation?.(result.id)
          break
        case 'user':
          onSelectUser?.(result.id)
          break
      }
      onClose?.()
    },
    [onSelectMessage, onSelectConversation, onSelectUser, onClose],
  )

  // Group results by type
  const groupedResults = useMemo(() => {
    if (!results) return null

    return {
      messages: results.results.filter((r) => r.type === 'message'),
      conversations: results.results.filter((r) => r.type === 'conversation'),
      users: results.results.filter((r) => r.type === 'user'),
    }
  }, [results])

  return (
    <div className="flex flex-col h-full bg-white dark:bg-slate-950 border-l border-gray-200 dark:border-slate-700">
      {/* Header */}
      <div className="flex items-center gap-3 p-4 border-b border-gray-200 dark:border-slate-700">
        <Search className="w-5 h-5 text-gray-400" />
        <input
          autoFocus
          type="text"
          placeholder={isPhoneQuery ? 'Nhập số điện thoại...' : 'Tìm kiếm tin nhắn, nhóm, người...'}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={handleKeyDown}
          className="flex-1 outline-none bg-transparent text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400"
        />
        {query && (
          <button onClick={() => setQuery('')} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Results */}
      <div className="flex-1 overflow-y-auto">
        {isSearching ? (
          <div className="p-4 text-center text-sm text-gray-500 dark:text-gray-400">Đang tìm kiếm...</div>
        ) : !query ? (
          <div className="p-4 text-center text-sm text-gray-500 dark:text-gray-400">
            Nhập từ khóa hoặc số điện thoại để tìm kiếm
          </div>
        ) : !results || results.totalCount === 0 ? (
          <div className="p-4 text-center text-sm text-gray-500 dark:text-gray-400">Không tìm thấy kết quả</div>
        ) : (
          <div className="space-y-1 p-2">
            {/* Conversations */}
            {groupedResults?.conversations && groupedResults.conversations.length > 0 && (
              <>
                <div className="px-2 py-1 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Nhóm & Cuộc trò chuyện</div>
                {groupedResults.conversations.map((result) => (
                  <SearchResultItem
                    key={result.id}
                    result={result}
                    isSelected={selectedIndex === results.results.indexOf(result)}
                    onClick={() => handleSelectResult(result)}
                  />
                ))}
              </>
            )}

            {/* Users */}
            {groupedResults?.users && groupedResults.users.length > 0 && (
              <>
                <div className="px-2 py-1 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Người dùng</div>
                {groupedResults.users.map((result) => (
                  <SearchResultItem
                    key={result.id}
                    result={result}
                    isSelected={selectedIndex === results.results.indexOf(result)}
                    onClick={() => handleSelectResult(result)}
                  />
                ))}
              </>
            )}

            {/* Messages */}
            {groupedResults?.messages && groupedResults.messages.length > 0 && (
              <>
                <div className="px-2 py-1 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Tin nhắn</div>
                {groupedResults.messages.map((result) => (
                  <SearchResultItem
                    key={result.id}
                    result={result}
                    isSelected={selectedIndex === results.results.indexOf(result)}
                    onClick={() => handleSelectResult(result)}
                  />
                ))}
              </>
            )}
          </div>
        )}
      </div>

      {/* Footer */}
      {results && results.totalCount > 0 && (
        <div className="p-2 border-t border-gray-200 dark:border-slate-700 text-xs text-gray-500 dark:text-gray-400 text-center">
          Tìm thấy {results.totalCount} kết quả
        </div>
      )}
    </div>
  )
}

interface SearchResultItemProps {
  result: GlobalSearchResult
  isSelected: boolean
  onClick: () => void
}

function SearchResultItem({ result, isSelected, onClick }: SearchResultItemProps) {
  const Icon = {
    message: MessageCircle,
    conversation: MessageCircle,
    user: User,
  }[result.type]

  return (
    <button
      onClick={onClick}
      className={`w-full px-2 py-2 text-left text-sm rounded transition-colors flex items-center gap-2 ${
        isSelected
          ? 'bg-blue-100 dark:bg-blue-900 text-blue-900 dark:text-blue-100'
          : 'hover:bg-gray-100 dark:hover:bg-slate-800 text-gray-800 dark:text-gray-200'
      }`}
    >
      <Icon className="w-4 h-4 flex-shrink-0" />
      <div className="flex-1 min-w-0">
        {result.type === 'message' ? (
          <div className="text-xs">
            <div className="font-medium text-gray-600 dark:text-gray-300">{result.conversationName}</div>
            <div className="text-gray-500 dark:text-gray-400 truncate">{result.displayText}</div>
          </div>
        ) : result.type === 'user' && result.phone ? (
          <div>
            <div className="inline-flex items-center gap-1">
              {result.type === 'user' && <Phone className="w-3 h-3" />}
              <span className="font-medium">{result.displayName || result.phone}</span>
            </div>
            {result.phone && <div className="text-xs text-gray-500 dark:text-gray-400">{result.phone}</div>}
          </div>
        ) : (
          <div className="font-medium">{result.displayText}</div>
        )}
      </div>
      <ChevronRight className="w-4 h-4 flex-shrink-0 text-gray-400" />
    </button>
  )
}
