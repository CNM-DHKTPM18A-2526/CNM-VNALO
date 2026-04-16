import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { useAuth } from '../features/auth/useAuth'
import { fetchInbox, getOrCreateDirectConversation } from '../features/chat/chat.api'
import type { ConversationSummary } from '../features/chat/chat.types'
import {
  initializeSearchIndex,
  searchUsersByPhoneLocal,
  searchUsersLocal,
  updateSearchIndexUsers,
  type CachedUser,
} from '../features/chat/searchIndex'
import { FriendRequestList } from '../features/contacts/components/FriendRequestList'
import { SentRequestList } from '../features/contacts/components/SentRequestList'
import { AddFriendModal, type AddFriendTarget } from '../features/friends/components/AddFriendModal'
import {
  acceptFriendRequest,
  cancelSentFriendRequest,
  declineFriendRequest,
  getFriends,
  getFriendStats,
  getIncomingFriendRequests,
  getSentFriendRequests,
  getUserById,
  getUserByPhone,
  searchUsers,
  unfriend,
} from '../features/friends/friends.api'
import type { Friend, FriendRequest, FriendStats, UserLookupResult } from '../features/friends/friends.types'
import { EmptyState } from '../shared/components/EmptyState'
import { Icon } from '../shared/components/Icon'
import { LoadingState } from '../shared/components/LoadingState'
import { UserAvatar } from '../shared/components/UserAvatar'
import { Button } from '../shared/components/ui/Button'
import { Card } from '../shared/components/ui/Card'
import { Modal } from '../shared/components/ui/Modal'
import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/contacts-page.css'

type FeedbackState = {
  type: 'success' | 'error'
  message: string
}

type ConfirmAction =
  | { kind: 'decline'; requestId: string; displayName: string }
  | { kind: 'cancelSent'; requestId: string; displayName: string }
  | { kind: 'unfriend'; friendId: string; displayName: string }
  | null

type ContactsSection = 'friends' | 'groups' | 'requests' | 'groupInvites'
type SortMode = 'az' | 'za'
type FriendFilter = 'all' | 'status'
type FriendMenuAction = 'info' | 'classify' | 'nickname' | 'block' | 'unfriend'

type SidebarItem = {
  key: ContactsSection
  icon: 'user' | 'group' | 'userPlus' | 'chat'
  label: string
}

const SECTION_STORAGE_KEY = 'vnalo_contacts_section'

function normalizeNameForGrouping(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[đĐ]/g, 'D')
}

function getFriendLabel(friend: Friend, fallback: string): string {
  return friend.displayName?.trim() || friend.nickname?.trim() || fallback
}

function getFriendGroupKey(friend: Friend, fallback: string): string {
  const label = getFriendLabel(friend, fallback)
  const normalized = normalizeNameForGrouping(label)
  const firstChar = normalized.charAt(0).toUpperCase()
  return /^[A-Z]$/.test(firstChar) ? firstChar : '#'
}

function sortByName(items: Friend[], fallback: string, mode: SortMode): Friend[] {
  const next = [...items].sort((left, right) => {
    const leftName = getFriendLabel(left, fallback)
    const rightName = getFriendLabel(right, fallback)
    return leftName.localeCompare(rightName, 'vi', { sensitivity: 'base' })
  })

  return mode === 'az' ? next : next.reverse()
}

function toCachedUserFromFriend(friend: Friend, fallback: string): CachedUser {
  return {
    id: friend.friendId,
    phone: undefined,
    email: undefined,
    displayName: getFriendLabel(friend, fallback),
    avatarUrl: friend.avatarUrl ?? undefined,
    bio: friend.statusMessage?.trim() || undefined,
  }
}

function toCachedUserFromLookup(user: UserLookupResult): CachedUser {
  return {
    id: user.id,
    phone: user.phone ?? undefined,
    email: user.email ?? undefined,
    displayName: user.displayName ?? undefined,
    avatarUrl: user.avatarUrl ?? undefined,
    bio: user.bio ?? undefined,
  }
}

export function ContactsPage() {
  const { accessToken, user } = useAuth()
  const { t } = useLanguage()
  const navigate = useNavigate()

  const [section, setSection] = useState<ContactsSection>(() => {
    if (typeof window === 'undefined') {
      return 'friends'
    }
    return (window.localStorage.getItem(SECTION_STORAGE_KEY) as ContactsSection | null) ?? 'friends'
  })
  const [keyword, setKeyword] = useState('')
  const [sortMode, setSortMode] = useState<SortMode>('az')
  const [friendFilter, setFriendFilter] = useState<FriendFilter>('all')
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)
  const [activeFriendMenuId, setActiveFriendMenuId] = useState<string | null>(null)
  const [isOpeningConversationId, setIsOpeningConversationId] = useState<string | null>(null)
  const [searchUserResults, setSearchUserResults] = useState<UserLookupResult[]>([])
  const [isSearchingUsers, setIsSearchingUsers] = useState(false)

  const [friends, setFriends] = useState<Friend[]>([])
  const [incomingRequests, setIncomingRequests] = useState<FriendRequest[]>([])
  const [sentRequests, setSentRequests] = useState<FriendRequest[]>([])
  const [stats, setStats] = useState<FriendStats | null>(null)
  const [groups, setGroups] = useState<ConversationSummary[]>([])
  const [isLoadingGroups, setIsLoadingGroups] = useState(true)

  const [isLoadingFriends, setIsLoadingFriends] = useState(true)
  const [isLoadingIncoming, setIsLoadingIncoming] = useState(true)
  const [isLoadingSent, setIsLoadingSent] = useState(true)

  const [feedback, setFeedback] = useState<FeedbackState | null>(null)
  const [confirmAction, setConfirmAction] = useState<ConfirmAction>(null)
  const [isConfirmSubmitting, setIsConfirmSubmitting] = useState(false)
  const [activeAction, setActiveAction] = useState<{ id: string | null; type: string | null }>({
    id: null,
    type: null,
  })

  const [showAddFriendModal, setShowAddFriendModal] = useState(false)
  const [addFriendTarget, setAddFriendTarget] = useState<AddFriendTarget | null>(null)
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false)
  const [isProfileLoading, setIsProfileLoading] = useState(false)
  const [isCreatingConversationFromProfile, setIsCreatingConversationFromProfile] = useState(false)
  const [profilePreview, setProfilePreview] = useState<UserLookupResult | null>(null)
  const [profileTargetUserId, setProfileTargetUserId] = useState<string | null>(null)
  const [profileError, setProfileError] = useState<string | null>(null)

  const menuRef = useRef<HTMLDivElement | null>(null)
  const normalizedKeyword = keyword.trim().toLowerCase()
  const normalizedPhoneKeyword = keyword.trim().replace(/\D/g, '')
  const isPhoneQuery = normalizedPhoneKeyword.length >= 2 && normalizedPhoneKeyword.length >= Math.max(2, keyword.trim().length - 2)
  const unknownUserLabel = t('contacts.common.unknownUser')

  useEffect(() => {
    initializeSearchIndex()
  }, [])

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(SECTION_STORAGE_KEY, section)
    }
  }, [section])

  useEffect(() => {
    const handlePointerDown = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) {
        setActiveFriendMenuId(null)
      }
    }

    document.addEventListener('pointerdown', handlePointerDown)
    return () => document.removeEventListener('pointerdown', handlePointerDown)
  }, [])

  const refreshFriends = async (token: string, options?: { silent?: boolean }) => {
    if (!options?.silent) {
      setIsLoadingFriends(true)
    }
    try {
      const nextFriends = await getFriends(token)
      setFriends(nextFriends)
    } finally {
      if (!options?.silent) {
        setIsLoadingFriends(false)
      }
    }
  }

  const refreshIncoming = async (token: string, options?: { silent?: boolean }) => {
    if (!options?.silent) {
      setIsLoadingIncoming(true)
    }
    try {
      const nextIncoming = await getIncomingFriendRequests(token)
      setIncomingRequests(nextIncoming)
    } finally {
      if (!options?.silent) {
        setIsLoadingIncoming(false)
      }
    }
  }

  const refreshSent = async (token: string, options?: { silent?: boolean }) => {
    if (!options?.silent) {
      setIsLoadingSent(true)
    }
    try {
      const nextSent = await getSentFriendRequests(token)
      setSentRequests(nextSent)
    } finally {
      if (!options?.silent) {
        setIsLoadingSent(false)
      }
    }
  }

  const refreshStats = async (token: string) => {
    try {
      const nextStats = await getFriendStats(token)
      setStats(nextStats)
    } finally {
      // No visible loading state for stats to keep background refresh silent.
    }
  }

  useEffect(() => {
    if (!accessToken) {
      setFriends([])
      setIncomingRequests([])
      setSentRequests([])
      setStats(null)
      setGroups([])
      setIsLoadingFriends(false)
      setIsLoadingIncoming(false)
      setIsLoadingSent(false)
      setIsLoadingGroups(false)
      return
    }

    // Fetch groups from inbox (filter GROUP type)
    setIsLoadingGroups(true)
    fetchInbox(accessToken, user?.id)
      .then((conversations) => {
        const groupConvs = conversations.filter((c) => c.isGroup && !c.isCloud)
        setGroups(groupConvs)
      })
      .catch(() => setGroups([]))
      .finally(() => setIsLoadingGroups(false))

    void Promise.all([
      refreshFriends(accessToken),
      refreshIncoming(accessToken),
      refreshSent(accessToken),
      refreshStats(accessToken),
    ]).catch((error) => {
      setFeedback({
        type: 'error',
        message: error instanceof Error ? error.message : t('contacts.feedback.genericError'),
      })
    })
  }, [accessToken, t])

  useEffect(() => {
    if (friends.length === 0) {
      return
    }

    updateSearchIndexUsers(friends.map((friend) => toCachedUserFromFriend(friend, unknownUserLabel)))
  }, [friends, unknownUserLabel])

  useEffect(() => {
    if (!accessToken) {
      return
    }

    let isDisposed = false

    const syncContactsData = async () => {
      if (isDisposed || (typeof document !== 'undefined' && document.visibilityState !== 'visible')) {
        return
      }

      try {
        await Promise.all([
          refreshFriends(accessToken, { silent: true }),
          refreshIncoming(accessToken, { silent: true }),
          refreshSent(accessToken, { silent: true }),
          refreshStats(accessToken),
        ])
      } catch {
        // Ignore background refresh errors to avoid noisy UX.
      }
    }

    const intervalId = window.setInterval(() => {
      void syncContactsData()
    }, 5000)

    const handleVisibility = () => {
      void syncContactsData()
    }

    window.addEventListener('focus', handleVisibility)
    document.addEventListener('visibilitychange', handleVisibility)

    return () => {
      isDisposed = true
      window.clearInterval(intervalId)
      window.removeEventListener('focus', handleVisibility)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [accessToken])

  useEffect(() => {
    const query = keyword.trim()

    if (!query) {
      setSearchUserResults([])
      setIsSearchingUsers(false)
      return
    }

    let active = true
    const timer = window.setTimeout(() => {
      void (async () => {
        setIsSearchingUsers(true)

        try {
          const localResults = isPhoneQuery ? searchUsersByPhoneLocal(normalizedPhoneKeyword) : searchUsersLocal(query)
          const localLookups = localResults.map((user) => ({
            id: user.id,
            phone: user.phone ?? null,
            email: user.email ?? null,
            displayName: user.displayName ?? null,
            avatarUrl: user.avatarUrl ?? null,
            coverUrl: null,
            bio: user.bio ?? null,
            statusMessage: user.bio ?? null,
          }))

          let remoteLookups: UserLookupResult[] = []
          if (accessToken) {
            try {
              if (isPhoneQuery) {
                const maybeUser = await getUserByPhone(accessToken, query)
                remoteLookups = maybeUser ? [maybeUser] : []
              } else {
                remoteLookups = await searchUsers(accessToken, query)
              }
            } catch {
              remoteLookups = []
            }
          }

          const merged = new Map<string, UserLookupResult>()
          for (const user of [...localLookups, ...remoteLookups]) {
            if (!merged.has(user.id)) {
              merged.set(user.id, user)
            }
          }

          if (!active) {
            return
          }

          const nextResults = [...merged.values()]
          setSearchUserResults(nextResults)

          if (nextResults.length > 0) {
            updateSearchIndexUsers(nextResults.map(toCachedUserFromLookup))
          }
        } finally {
          if (active) {
            setIsSearchingUsers(false)
          }
        }
      })()
    }, 250)

    return () => {
      active = false
      window.clearTimeout(timer)
    }
  }, [accessToken, isPhoneQuery, keyword, normalizedPhoneKeyword])

  const filteredFriends = useMemo(() => {
    return friends.filter((friend) => {
      const displayName = getFriendLabel(friend, unknownUserLabel)
      const searchable = `${displayName} ${friend.friendId} ${friend.statusMessage ?? ''}`.toLowerCase()
      const matchesKeyword = !normalizedKeyword || searchable.includes(normalizedKeyword)
      const matchesFilter = friendFilter === 'all' || Boolean(friend.statusMessage?.trim())
      return matchesKeyword && matchesFilter
    })
  }, [friendFilter, friends, normalizedKeyword, unknownUserLabel])

  const sortedFriends = useMemo(() => sortByName(filteredFriends, unknownUserLabel, sortMode), [filteredFriends, sortMode, unknownUserLabel])

  const groupedFriends = useMemo(() => {
    const groups = new Map<string, Friend[]>()

    for (const friend of sortedFriends) {
      const key = getFriendGroupKey(friend, unknownUserLabel)
      const current = groups.get(key)
      if (current) {
        current.push(friend)
      } else {
        groups.set(key, [friend])
      }
    }

    return Array.from(groups.entries()).sort(([left], [right]) => {
      if (left === '#' && right !== '#') return 1
      if (right === '#' && left !== '#') return -1

      const compared = left.localeCompare(right, 'vi', { sensitivity: 'base' })
      return sortMode === 'az' ? compared : -compared
    })
  }, [sortedFriends, sortMode, unknownUserLabel])

  const incomingCount = stats?.pendingRequestCount ?? incomingRequests.length

  const filteredIncomingRequests = useMemo(
    () =>
      incomingRequests.filter((item) => {
        const searchable = `${item.fromUserDisplayName ?? ''} ${item.fromUserId} ${item.message ?? ''}`.toLowerCase()
        return !normalizedKeyword || searchable.includes(normalizedKeyword)
      }),
    [incomingRequests, normalizedKeyword],
  )

  const filteredSentRequests = useMemo(
    () =>
      sentRequests.filter((item) => {
        const searchable = `${item.toUserDisplayName ?? ''} ${item.toUserId} ${item.message ?? ''}`.toLowerCase()
        return !normalizedKeyword || searchable.includes(normalizedKeyword)
      }),
    [normalizedKeyword, sentRequests],
  )

  const filteredGroups = useMemo(
    () =>
      groups.filter(
        (item) =>
          !normalizedKeyword ||
          (item.name ?? '').toLowerCase().includes(normalizedKeyword),
      ),
    [groups, normalizedKeyword],
  )

  const sidebarItems: SidebarItem[] = [
    { key: 'friends', icon: 'user', label: 'Danh sách bạn bè' },
    { key: 'groups', icon: 'group', label: 'Danh sách nhóm và cộng đồng' },
    { key: 'requests', icon: 'userPlus', label: 'Lời mời kết bạn' },
    { key: 'groupInvites', icon: 'chat', label: 'Lời mời nhóm và cộng đồng' },
  ]

  const friendMenuItems: Array<{ key: FriendMenuAction; label: string; danger?: boolean }> = [
    { key: 'info', label: 'Xem thông tin' },
    { key: 'classify', label: 'Phân loại' },
    { key: 'nickname', label: 'Đặt tên gợi nhớ' },
    { key: 'block', label: 'Chặn người này' },
    { key: 'unfriend', label: 'Xóa bạn', danger: true },
  ]

  const openAddFriendModal = (target: AddFriendTarget | null = null) => {
    setAddFriendTarget(target)
    setShowAddFriendModal(true)
  }

  const closeAddFriendModal = () => {
    setShowAddFriendModal(false)
    setAddFriendTarget(null)
  }

  const closeProfileModal = () => {
    setIsProfileModalOpen(false)
    setIsProfileLoading(false)
    setIsCreatingConversationFromProfile(false)
    setProfileTargetUserId(null)
    setProfileError(null)
  }

  const handleOpenProfileModal = async (friend: Friend) => {
    if (!accessToken) return

    setProfileError(null)
    setIsProfileLoading(true)
    setIsProfileModalOpen(true)
    setProfileTargetUserId(friend.friendId)
    setProfilePreview({
      id: friend.friendId,
      phone: null,
      email: null,
      displayName: friend.displayName,
      avatarUrl: friend.avatarUrl,
      coverUrl: null,
      bio: friend.statusMessage,
      statusMessage: friend.statusMessage,
    })

    try {
      const profile = await getUserById(accessToken, friend.friendId)
      if (profile) {
        setProfilePreview(profile)
      }
    } catch (error) {
      setProfileError(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsProfileLoading(false)
    }
  }

  const handleOpenLookupProfile = async (user: UserLookupResult) => {
    if (!accessToken) return

    setProfileError(null)
    setIsProfileLoading(true)
    setIsProfileModalOpen(true)
    setProfileTargetUserId(user.id)
    setProfilePreview(user)

    try {
      const profile = await getUserById(accessToken, user.id)
      if (profile) {
        setProfilePreview(profile)
      }
    } catch (error) {
      setProfileError(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsProfileLoading(false)
    }
  }

  const handleSendMessageFromProfile = async () => {
    if (!accessToken) return

    const targetUserId = profilePreview?.id ?? profileTargetUserId
    if (!targetUserId) {
      setProfileError(t('contacts.feedback.genericError'))
      return
    }

    setProfileError(null)
    setIsCreatingConversationFromProfile(true)

    try {
      const conversationId = await getOrCreateDirectConversation(accessToken, targetUserId)
      closeProfileModal()
      navigate(`/chat/${conversationId}`)
    } catch (error) {
      setProfileError(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsCreatingConversationFromProfile(false)
    }
  }

  const handleOpenConversationByUserId = async (targetUserId: string, loadingKey: string) => {
    if (!accessToken) return

    if (!targetUserId) {
      setFeedback({ type: 'error', message: t('contacts.feedback.genericError') })
      return
    }

    setFeedback(null)
    setIsOpeningConversationId(loadingKey)

    try {
      const conversationId = await getOrCreateDirectConversation(accessToken, targetUserId)
      navigate(`/chat/${conversationId}`)
    } catch (error) {
      setFeedback({
        type: 'error',
        message: error instanceof Error ? error.message : t('contacts.feedback.genericError'),
      })
    } finally {
      setIsOpeningConversationId(null)
    }
  }

  const handleCallFromProfile = () => {
    const phone = profilePreview?.phone?.trim()
    if (!phone) {
      setProfileError('Người dùng chưa cập nhật số điện thoại.')
      return
    }
    window.location.href = `tel:${phone}`
  }

  const refreshAll = async (token: string) => {
    await Promise.all([refreshFriends(token), refreshIncoming(token), refreshSent(token), refreshStats(token)])
  }

  const handleOpenConversation = async (friend: Friend) => {
    setActiveFriendMenuId(null)
    await handleOpenConversationByUserId(friend.friendId, friend.friendshipId)
  }

  const handleAcceptRequest = async (requestId: string) => {
    if (!accessToken) return

    setFeedback(null)
    setActiveAction({ id: requestId, type: 'accept' })

    try {
      await acceptFriendRequest(accessToken, requestId)
      setFeedback({ type: 'success', message: t('contacts.feedback.acceptSuccess') })
      await Promise.all([refreshFriends(accessToken), refreshIncoming(accessToken), refreshStats(accessToken)])
    } catch (error) {
      setFeedback({
        type: 'error',
        message: error instanceof Error ? error.message : t('contacts.feedback.genericError'),
      })
    } finally {
      setActiveAction({ id: null, type: null })
    }
  }

  const handleConfirmAction = async () => {
    if (!accessToken || !confirmAction) return

    setIsConfirmSubmitting(true)
    setFeedback(null)

    try {
      if (confirmAction.kind === 'decline') {
        await declineFriendRequest(accessToken, confirmAction.requestId)
        setFeedback({ type: 'success', message: t('contacts.feedback.declineSuccess') })
        await Promise.all([refreshIncoming(accessToken), refreshStats(accessToken)])
      }

      if (confirmAction.kind === 'cancelSent') {
        await cancelSentFriendRequest(accessToken, confirmAction.requestId)
        setFeedback({ type: 'success', message: t('contacts.feedback.cancelRequestSuccess') })
        await refreshSent(accessToken)
      }

      if (confirmAction.kind === 'unfriend') {
        await unfriend(accessToken, confirmAction.friendId)
        setFeedback({ type: 'success', message: t('contacts.feedback.unfriendSuccess') })
        await Promise.all([refreshFriends(accessToken), refreshStats(accessToken)])
      }

      setConfirmAction(null)
    } catch (error) {
      setFeedback({
        type: 'error',
        message: error instanceof Error ? error.message : t('contacts.feedback.genericError'),
      })
    } finally {
      setIsConfirmSubmitting(false)
    }
  }

  const confirmTitle =
    confirmAction?.kind === 'decline'
      ? t('contacts.confirm.declineTitle')
      : confirmAction?.kind === 'cancelSent'
        ? t('contacts.confirm.cancelRequestTitle')
        : t('contacts.confirm.unfriendTitle')

  const confirmDescription =
    confirmAction?.kind === 'decline'
      ? t('contacts.confirm.declineDescription')
      : confirmAction?.kind === 'cancelSent'
        ? t('contacts.confirm.cancelRequestDescription')
        : t('contacts.confirm.unfriendDescription')

  const openFriendMenu = (friend: Friend) => {
    setActiveFriendMenuId(friend.friendshipId)
  }

  const closeFriendMenu = () => {
    setActiveFriendMenuId(null)
  }

  return (
    <section className='contacts-page panel-page'>
      <div className='contacts-shell'>
        <aside
          className={`contacts-sidebar ${isSidebarOpen ? 'contacts-sidebar-open' : ''}`}
        >
          <div className='contacts-sidebar-head'>
            <div className='contacts-brand'>
              <div className='contacts-brand-icon'>
                <Icon name='chat' />
              </div>
              <div className='contacts-brand-copy'>
                <div className='contacts-brand-sub'>VNALO</div>
                <div className='contacts-brand-title'>Danh bạ</div>
              </div>
            </div>

            <div className='contacts-sidebar-search'>
              <Icon name='search' className='contacts-icon-sm' />
              <input
                className='contacts-input contacts-input-on-blue'
                placeholder='Tìm kiếm'
                value={keyword}
                onChange={(event) => setKeyword(event.target.value)}
              />
              <button
                type='button'
                className='contacts-icon-btn contacts-icon-btn-on-blue'
                title='Thêm bạn'
                onClick={() => openAddFriendModal()}
              >
                <Icon name='userPlus' />
              </button>
            </div>
          </div>

          <nav className='contacts-sidebar-nav'>
            {sidebarItems.map((item) => {
              const active = section === item.key
              return (
                <button
                  key={item.key}
                  type='button'
                  onClick={() => {
                    setSection(item.key)
                    closeFriendMenu()
                    setIsSidebarOpen(false)
                  }}
                  className={`contacts-sidebar-item ${active ? 'contacts-sidebar-item-active' : ''}`}
                >
                  <span className={`contacts-sidebar-item-icon ${active ? 'contacts-sidebar-item-icon-active' : ''}`}>
                    <Icon name={item.icon} />
                  </span>
                  <span className='contacts-sidebar-item-label'>{item.label}</span>
                  {item.key === 'requests' && incomingCount > 0 ? (
                    <span className='contacts-sidebar-item-badge' aria-label={`${incomingCount} lời mời kết bạn`}>
                      {incomingCount > 99 ? '99+' : incomingCount}
                    </span>
                  ) : null}
                </button>
              )
            })}
          </nav>
        </aside>

        <div className='contacts-main'>
          <div className='contacts-titlebar'>
            <Icon name={section === 'groups' ? 'group' : section === 'requests' ? 'userPlus' : 'user'} className='contacts-titlebar-icon' />
            <div className='contacts-titlebar-text'>
              {section === 'groups' ? 'Danh sách nhóm và cộng đồng' : section === 'requests' ? 'Lời mời kết bạn' : section === 'groupInvites' ? 'Lời mời nhóm và cộng đồng' : 'Danh sách bạn bè'}
            </div>
          </div>

          <div className='contacts-summarybar'>
            <div className='contacts-summarybar-text'>
              {section === 'groups'
                ? `Nhóm và cộng đồng (${groups.length})`
                : `Bạn bè (${stats?.friendCount ?? friends.length})`}
            </div>
          </div>

          <div className='contacts-filters-card'>
            <div className='contacts-toolbar-controls'>
              <div className='contacts-search-box'>
                <Icon name='search' className='contacts-icon-sm contacts-icon-muted' />
                <input
                  className='contacts-input contacts-input-default'
                  value={keyword}
                  onChange={(event) => setKeyword(event.target.value)}
                  placeholder='Tìm bạn'
                />
                <button
                  type='button'
                  onClick={() => openAddFriendModal()}
                  className='contacts-icon-btn contacts-icon-btn-muted'
                  title='Thêm bạn'
                >
                  <Icon name='userPlus' />
                </button>
                <button
                  type='button'
                  className='contacts-icon-btn contacts-icon-btn-muted'
                  title='Tạo nhóm chat'
                >
                  <Icon name='group' />
                </button>
              </div>

              <select
                className='contacts-select'
                value={sortMode}
                onChange={(event) => setSortMode(event.target.value as SortMode)}
              >
                <option value='az'>Tên (A-Z)</option>
                <option value='za'>Tên (Z-A)</option>
              </select>

              <select
                className='contacts-select'
                value={friendFilter}
                onChange={(event) => setFriendFilter(event.target.value as FriendFilter)}
              >
                <option value='all'>Tất cả</option>
                <option value='status'>Có trạng thái</option>
              </select>
            </div>
          </div>

          <div className='contacts-content'>
            {feedback ? (
              <div className={`contacts-feedback ${feedback.type === 'success' ? 'contacts-feedback-success' : 'contacts-feedback-error'}`}>
                {feedback.message}
              </div>
            ) : null}

            {section === 'friends' ? (
              isLoadingFriends ? (
                <div className='contacts-loading-wrap'>
                  <LoadingState label={t('contacts.loading.friends')} />
                </div>
              ) : sortedFriends.length === 0 && searchUserResults.length === 0 ? (
                <div className='contacts-empty-center'>
                  <div className='contacts-empty-icon-wrap'>
                    <Icon name='search' className='contacts-empty-icon' />
                  </div>
                  <div className='contacts-empty-title'>
                    {normalizedKeyword ? 'Không tìm thấy kết quả phù hợp' : 'Chưa có bạn bè nào'}
                  </div>
                  <p className='contacts-empty-description'>
                    {normalizedKeyword
                      ? 'Hãy thử thay đổi từ khóa hoặc xoá bộ lọc để xem toàn bộ danh bạ.'
                      : 'Kết nối thêm bạn bè để bắt đầu nhắn tin ngay.'}
                  </p>
                </div>
              ) : (
                <div className='contacts-friends-groups'>
                  {normalizedKeyword ? (
                    <section>
                      <div className='contacts-group-head'>
                        <div className='contacts-group-letter'>Kết quả tìm kiếm</div>
                      </div>
                      <div className='contacts-friends-list'>
                        {isSearchingUsers ? (
                          <div className='contacts-friend-row'>
                            <div className='contacts-friend-copy'>
                              <p className='contacts-friend-name'>Đang tìm kiếm...</p>
                            </div>
                          </div>
                        ) : null}
                        {searchUserResults.map((user) => {
                          const displayName = user.displayName?.trim() || user.phone || user.email || unknownUserLabel
                          const isFriend = friends.some((friend) => friend.friendId === user.id)
                          const friendMatch = friends.find((friend) => friend.friendId === user.id) ?? null
                          const subtitle = user.phone?.trim() || user.email?.trim() || user.bio?.trim() || 'Người dùng'

                          return (
                            <div key={user.id} className='contacts-friend-row'>
                              <button
                                type='button'
                                className='contacts-friend-main-btn'
                                onClick={() => {
                                  void handleOpenLookupProfile(user)
                                }}
                              >
                                <UserAvatar imageUrl={user.avatarUrl} name={displayName} size='md' />
                                <div className='contacts-friend-copy'>
                                  <p className='contacts-friend-name'>{displayName}</p>
                                  <p className='contacts-friend-status'>{subtitle}</p>
                                </div>
                              </button>

                              <div className='contacts-user-search-actions'>
                                {isFriend && friendMatch ? (
                                  <Button
                                    variant='ghost'
                                    onClick={() => {
                                      void handleOpenConversation(friendMatch)
                                    }}
                                  >
                                    Nhắn tin
                                  </Button>
                                ) : (
                                  <Button
                                    variant='ghost'
                                    onClick={() => {
                                      openAddFriendModal({
                                        userId: user.id,
                                        displayName,
                                        avatarUrl: user.avatarUrl ?? null,
                                        phone: user.phone ?? null,
                                        email: user.email ?? null,
                                        bio: user.bio ?? null,
                                        statusMessage: user.statusMessage ?? null,
                                      })
                                    }}
                                  >
                                    Kết bạn
                                  </Button>
                                )}
                              </div>

                              {isOpeningConversationId === user.id ? <div className='contacts-open-conversation-overlay' /> : null}
                            </div>
                          )
                        })}
                      </div>
                    </section>
                  ) : null}

                  {sortedFriends.length > 0 ? (
                    groupedFriends.map(([letter, items]) => (
                      <section key={letter}>
                        <div className='contacts-group-head'>
                          <div className='contacts-group-letter'>{letter}</div>
                        </div>

                        <div className='contacts-friends-list'>
                          {items.map((friend) => {
                            const displayName = getFriendLabel(friend, unknownUserLabel)
                            const statusText = friend.statusMessage?.trim()
                            const isOpen = activeFriendMenuId === friend.friendshipId
                            const isOpening = isOpeningConversationId === friend.friendshipId

                            return (
                              <div
                                key={friend.friendshipId}
                                className='contacts-friend-row'
                              >
                                <button
                                  type='button'
                                  className='contacts-friend-main-btn'
                                  onClick={() => {
                                    void handleOpenConversation(friend)
                                  }}
                                >
                                  <UserAvatar imageUrl={friend.avatarUrl} name={displayName} size='md' />
                                  <div className='contacts-friend-copy'>
                                    <p className='contacts-friend-name'>{displayName}</p>
                                    {statusText ? <p className='contacts-friend-status'>{statusText}</p> : null}
                                  </div>
                                </button>

                                <div ref={isOpen ? menuRef : undefined} className='contacts-friend-menu-wrap'>
                                  <button
                                    type='button'
                                    className='contacts-more-btn'
                                    onClick={() => {
                                      if (isOpen) {
                                        closeFriendMenu()
                                      } else {
                                        openFriendMenu(friend)
                                      }
                                    }}
                                  >
                                    <Icon name='more' />
                                  </button>

                                  {isOpen ? (
                                    <div className='contacts-friend-menu'>
                                      <div className='contacts-friend-menu-head'>{displayName}</div>
                                      <div className='contacts-friend-menu-divider' />
                                      <div className='contacts-friend-menu-items'>
                                        {friendMenuItems.map((item) => (
                                          <button
                                            key={item.key}
                                            type='button'
                                            className={`contacts-friend-menu-item ${item.danger ? 'contacts-friend-menu-item-danger' : ''}`}
                                            onClick={() => {
                                              if (item.key === 'info') {
                                                void handleOpenProfileModal(friend)
                                              }
                                              if (item.key === 'unfriend') {
                                                setConfirmAction({ kind: 'unfriend', friendId: friend.friendId, displayName })
                                              }
                                              closeFriendMenu()
                                            }}
                                          >
                                            <span>{item.label}</span>
                                            {item.key === 'classify' ? <Icon name='chevronDown' className='contacts-chevron-right' /> : null}
                                          </button>
                                        ))}
                                      </div>
                                    </div>
                                  ) : null}
                                </div>

                                {isOpening ? <div className='contacts-open-conversation-overlay' /> : null}
                              </div>
                            )
                          })}
                        </div>
                      </section>
                    ))
                  ) : null}
                </div>
              )
            ) : null}

            {section === 'groups' ? (
              isLoadingGroups ? (
                <div className='contacts-loading-wrap'>
                  <LoadingState label='Đang tải danh sách nhóm...' />
                </div>
              ) : filteredGroups.length > 0 ? (
                <div className='contacts-groups-flat-list'>
                  {filteredGroups.map((group) => (
                    <button
                      key={group.id}
                      type='button'
                      className='contacts-group-row'
                      onClick={() => navigate(`/chat/${group.id}`)}
                    >
                      <UserAvatar
                        imageUrl={group.avatarUrl ?? null}
                        name={group.name ?? 'Nhóm'}
                        size='md'
                        isGroup
                      />
                      <div className='contacts-friend-copy'>
                        <p className='contacts-friend-name'>{group.name ?? 'Nhóm không tên'}</p>
                        <p className='contacts-friend-status'>
                          {group.memberCount ? `${group.memberCount} thành viên` : 'Nhóm'}
                        </p>
                      </div>
                    </button>
                  ))}
                </div>
              ) : (
                <div className='contacts-empty-center'>
                  <div className='contacts-empty-icon-wrap'>
                    <Icon name='group' className='contacts-empty-icon' />
                  </div>
                  <div className='contacts-empty-title'>Chưa có nhóm nào</div>
                  <p className='contacts-empty-description'>Tạo nhóm chat để bắt đầu trò chuyện cùng bạn bè.</p>
                </div>
              )
            ) : null}

            {section === 'requests' ? (
              <div className='contacts-requests-wrap'>
                <Card className='contacts-request-card'>
                  <h3 className='contacts-request-card-title'>Lời mời kết bạn đến ({incomingCount})</h3>
                  {isLoadingIncoming ? (
                    <LoadingState label={t('contacts.loading.incomingRequests')} />
                  ) : filteredIncomingRequests.length > 0 ? (
                    <FriendRequestList
                      actionLoadingId={activeAction.id}
                      actionType={
                        activeAction.type === 'accept'
                          ? 'accept'
                          : activeAction.type === 'decline'
                            ? 'decline'
                            : null
                      }
                      items={filteredIncomingRequests}
                      labels={{
                        accept: t('contacts.requests.accept'),
                        decline: t('contacts.requests.decline'),
                        addFriend: t('contacts.actions.addFriend'),
                        unknownUser: t('contacts.common.unknownUser'),
                      }}
                      onAccept={handleAcceptRequest}
                      onDecline={(requestId) => {
                        const request = filteredIncomingRequests.find((item) => item.id === requestId)
                        setConfirmAction({
                          kind: 'decline',
                          requestId,
                          displayName: request?.fromUserDisplayName ?? t('contacts.common.unknownUser'),
                        })
                      }}
                      onOpenAddFriend={(target) => openAddFriendModal(target)}
                    />
                  ) : (
                    <EmptyState title={t('contacts.empty.noIncomingRequestsTitle')} description={t('contacts.empty.noIncomingRequestsDesc')} />
                  )}
                </Card>

                <Card className='contacts-request-card'>
                  <h3 className='contacts-request-card-title'>Lời mời kết bạn đã gửi</h3>
                  {isLoadingSent ? (
                    <LoadingState label={t('contacts.loading.sentRequests')} />
                  ) : filteredSentRequests.length > 0 ? (
                    <SentRequestList
                      actionLoadingId={activeAction.type === 'cancelSent' ? activeAction.id : null}
                      items={filteredSentRequests}
                      labels={{
                        cancelRequest: t('contacts.actions.cancelRequest'),
                        addFriend: t('contacts.actions.addFriend'),
                        unknownUser: t('contacts.common.unknownUser'),
                      }}
                      onCancel={(requestId) => {
                        const request = filteredSentRequests.find((item) => item.id === requestId)
                        setConfirmAction({
                          kind: 'cancelSent',
                          requestId,
                          displayName: request?.toUserDisplayName ?? t('contacts.common.unknownUser'),
                        })
                      }}
                      onOpenAddFriend={(target) => openAddFriendModal(target)}
                    />
                  ) : (
                    <EmptyState title={t('contacts.empty.noSentRequestsTitle')} description={t('contacts.empty.noSentRequestsDesc')} />
                  )}
                </Card>
              </div>
            ) : null}

            {section === 'groupInvites' ? (
              <EmptyState
                title='Chưa có lời mời nhóm và cộng đồng'
                description='Khi có lời mời vào nhóm và cộng đồng, bạn sẽ thấy tại đây.'
              />
            ) : null}
          </div>
        </div>
      </div>

      {isSidebarOpen ? (
        <button
          type='button'
          aria-label='Đóng danh bạ'
          className='contacts-sidebar-overlay'
          onClick={() => setIsSidebarOpen(false)}
        />
      ) : null}

      <AddFriendModal
        initialTarget={addFriendTarget}
        isOpen={showAddFriendModal}
        onClose={closeAddFriendModal}
        onCompleted={
          accessToken
            ? async () => {
                await refreshAll(accessToken)
              }
            : undefined
        }
      />

      <Modal
        isOpen={isProfileModalOpen}
        onClose={closeProfileModal}
        title='Thông tin tài khoản'
      >
        {isProfileLoading ? (
          <LoadingState label='Đang tải hồ sơ...' />
        ) : profilePreview ? (
          <div className='contacts-profile-modal'>
            {profilePreview.coverUrl ? (
              <img alt={profilePreview.displayName ?? 'Người dùng'} className='contacts-profile-cover' src={profilePreview.coverUrl} />
            ) : (
              <div className='contacts-profile-cover-fallback' />
            )}
            <div className='contacts-profile-head'>
              <div className='contacts-profile-avatar-wrap'>
                <UserAvatar
                  imageUrl={profilePreview.avatarUrl}
                  name={profilePreview.displayName ?? profilePreview.phone ?? profilePreview.email ?? 'Người dùng'}
                  size='lg'
                />
              </div>
              <div className='contacts-profile-name-row'>
                <h4>{profilePreview.displayName ?? profilePreview.phone ?? profilePreview.email ?? 'Người dùng'}</h4>
              </div>
            </div>

            <div className='contacts-profile-actions'>
              <button type='button' className='contacts-profile-action-btn' onClick={handleCallFromProfile}>
                Gọi điện
              </button>
              <button
                type='button'
                className='contacts-profile-action-btn contacts-profile-action-btn-primary'
                onClick={() => {
                  void handleSendMessageFromProfile()
                }}
                disabled={isCreatingConversationFromProfile}
              >
                {isCreatingConversationFromProfile ? 'Đang mở hội thoại...' : 'Nhắn tin'}
              </button>
            </div>

            <div className='contacts-profile-info'>
              <h5>Thông tin cá nhân</h5>
              <div className='contacts-profile-info-grid'>
                <div className='contacts-profile-info-label'>Bio</div>
                <div className='contacts-profile-info-value'>{profilePreview.bio?.trim() || profilePreview.statusMessage?.trim() || 'Chưa cập nhật'}</div>

                <div className='contacts-profile-info-label'>Giới tính</div>
                <div className='contacts-profile-info-value'>Chưa cập nhật</div>

                <div className='contacts-profile-info-label'>Ngày sinh</div>
                <div className='contacts-profile-info-value'>Chưa cập nhật</div>

                <div className='contacts-profile-info-label'>Điện thoại</div>
                <div className='contacts-profile-info-value'>{profilePreview.phone || 'Chưa cập nhật'}</div>

                <div className='contacts-profile-info-label'>Email</div>
                <div className='contacts-profile-info-value'>{profilePreview.email || 'Chưa cập nhật'}</div>
              </div>
            </div>
          </div>
        ) : (
          <EmptyState title='Không có dữ liệu hồ sơ' description='Không thể tải hồ sơ người dùng vào lúc này.' />
        )}
        {profileError ? <p className='contacts-confirm-note'>{profileError}</p> : null}
      </Modal>

      <Modal
        description={`${confirmAction?.kind === 'unfriend' ? 'Xác nhận thao tác này sẽ xóa bạn' : confirmDescription} ${confirmAction?.displayName ?? ''}`.trim()}
        footer={
          <>
            <Button disabled={isConfirmSubmitting} onClick={() => setConfirmAction(null)} variant='ghost'>
              {t('contacts.common.cancel')}
            </Button>
            <Button disabled={isConfirmSubmitting} onClick={handleConfirmAction} variant='primary'>
              {isConfirmSubmitting ? t('contacts.common.processing') : t('contacts.common.confirm')}
            </Button>
          </>
        }
        isOpen={Boolean(confirmAction)}
        onClose={() => setConfirmAction(null)}
        title={confirmTitle}
      >
        <p className='contacts-confirm-note'>{t('contacts.confirm.irreversibleWarning')}</p>
      </Modal>
    </section>
  )
}
