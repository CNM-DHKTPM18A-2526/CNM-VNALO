/**
 * Local search index for hybrid search functionality
 * Maintains in-memory and localStorage caches of messages, conversations, and users
 * for fast searching without backend queries
 */

import type { ConversationSummary } from './chat.types'

const SEARCH_CACHE_KEY = 'vnalo_search_index'
const SEARCH_EXPIRE_TIME = 1000 * 60 * 60 // 1 hour

export interface CachedMessage {
  id: string
  conversationId: string
  senderId: string
  content?: string | null
  createdAt?: string
  messageType?: string | null
  conversationName?: string
}

export interface CachedUser {
  id: string
  phone?: string
  email?: string
  displayName?: string
  avatarUrl?: string
  bio?: string
}

export interface SearchIndex {
  messages: CachedMessage[]
  conversations: ConversationSummary[]
  users: CachedUser[]
  updatedAt: number
}

// In-memory cache
let memoryCache: SearchIndex = {
  messages: [],
  conversations: [],
  users: [],
  updatedAt: 0,
}

/**
 * Load search index from localStorage
 */
function loadFromStorage(): SearchIndex | null {
  try {
    const stored = localStorage.getItem(SEARCH_CACHE_KEY)
    if (!stored) return null

    const parsed = JSON.parse(stored) as SearchIndex
    const age = Date.now() - parsed.updatedAt

    // Invalidate cache if older than 1 hour
    if (age > SEARCH_EXPIRE_TIME) {
      localStorage.removeItem(SEARCH_CACHE_KEY)
      return null
    }

    return parsed
  } catch {
    return null
  }
}

/**
 * Save search index to localStorage
 */
function saveToStorage(index: SearchIndex): void {
  try {
    localStorage.setItem(SEARCH_CACHE_KEY, JSON.stringify(index))
  } catch {
    // Storage quota exceeded or disabled
    console.warn('Failed to save search index to localStorage')
  }
}

/**
 * Initialize search index from storage or memory
 */
export function initializeSearchIndex(): void {
  const stored = loadFromStorage()
  if (stored) {
    memoryCache = stored
  }
}

/**
 * Update conversations in the search index
 */
export function updateSearchIndexConversations(conversations: ConversationSummary[]): void {
  memoryCache.conversations = conversations
  memoryCache.updatedAt = Date.now()
  saveToStorage(memoryCache)
}

/**
 * Add a message to the search index
 */
export function addMessageToSearchIndex(message: CachedMessage): void {
  const exists = memoryCache.messages.some((m) => m.id === message.id)
  if (!exists) {
    memoryCache.messages.unshift(message) // Add to beginning for recent messages first
  }
  memoryCache.updatedAt = Date.now()
  saveToStorage(memoryCache)
}

/**
 * Add multiple messages to the search index
 */
export function addMessagesToSearchIndex(messages: CachedMessage[]): void {
  const existing = new Set(memoryCache.messages.map((m) => m.id))
  const newMessages = messages.filter((m) => !existing.has(m.id))

  if (newMessages.length > 0) {
    memoryCache.messages = [...newMessages, ...memoryCache.messages].slice(0, 5000) // Keep latest 5000 messages
    memoryCache.updatedAt = Date.now()
    saveToStorage(memoryCache)
  }
}

/**
 * Update users in the search index
 */
export function updateSearchIndexUsers(users: CachedUser[]): void {
  const existing = new Set(memoryCache.users.map((u) => u.id))
  const newUsers = users.filter((u) => !existing.has(u.id))

  if (newUsers.length > 0) {
    memoryCache.users = [...memoryCache.users, ...newUsers]
    memoryCache.updatedAt = Date.now()
    saveToStorage(memoryCache)
  }
}

/**
 * Search messages by keyword
 */
export function searchMessagesLocal(keyword: string): CachedMessage[] {
  if (!keyword || keyword.length < 2) return []

  const lowerKeyword = keyword.toLowerCase()
  return memoryCache.messages.filter((message) => {
    const content = (message.content ?? '').toLowerCase()
    return content.includes(lowerKeyword)
  })
}

/**
 * Search conversations by name
 */
export function searchConversationsLocal(keyword: string): ConversationSummary[] {
  if (!keyword || keyword.length < 2) return []

  const lowerKeyword = keyword.toLowerCase()
  return memoryCache.conversations.filter((conv) => {
    const name = (conv.name ?? '').toLowerCase()
    return name.includes(lowerKeyword)
  })
}

export function searchUsersByPhoneLocal(phoneNumber: string): CachedUser[] {
  if (!phoneNumber || phoneNumber.length < 2) return []

  const normalize = (p: string) => {
    let digits = p.replace(/\D/g, '')
    if (digits.startsWith('0')) {
      digits = '84' + digits.substring(1)
    }
    return digits
  }

  const searchDigits = normalize(phoneNumber)
  if (!searchDigits) return []

  return memoryCache.users.filter((user) => {
    const userPhone = normalize(user.phone ?? '')
    if (!userPhone) return false // Skip users without phone numbers

    return userPhone.includes(searchDigits) || searchDigits.includes(userPhone)
  })
}

/**
 * Search users by name/keyword
 */
export function searchUsersLocal(keyword: string): CachedUser[] {
  if (!keyword || keyword.length < 2) return []

  const lowerKeyword = keyword.toLowerCase()
  return memoryCache.users.filter((user) => {
    const name = (user.displayName ?? '').toLowerCase()
    const email = (user.email ?? '').toLowerCase()
    const bio = (user.bio ?? '').toLowerCase()
    const phone = (user.phone ?? '').toLowerCase()

    return name.includes(lowerKeyword) || email.includes(lowerKeyword) || bio.includes(lowerKeyword) || phone.includes(lowerKeyword)
  })
}

/**
 * Clear the entire search index
 */
export function clearSearchIndex(): void {
  memoryCache = {
    messages: [],
    conversations: [],
    users: [],
    updatedAt: 0,
  }
  localStorage.removeItem(SEARCH_CACHE_KEY)
}

/**
 * Get cache statistics
 */
export function getSearchIndexStats(): {
  messageCount: number
  conversationCount: number
  userCount: number
  ageSeconds: number
} {
  return {
    messageCount: memoryCache.messages.length,
    conversationCount: memoryCache.conversations.length,
    userCount: memoryCache.users.length,
    ageSeconds: Math.floor((Date.now() - memoryCache.updatedAt) / 1000),
  }
}
