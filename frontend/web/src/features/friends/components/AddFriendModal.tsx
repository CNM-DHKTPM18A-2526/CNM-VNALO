import React from 'react'
import { useAuth } from '../../auth/useAuth'
import {
  getUserById,
  getUserByPhone,
  searchUsers,
} from '../friends.api'
import type { UserLookupResult } from '../friends.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Modal } from '../../../shared/components/ui/Modal'
import { useLanguage } from '../../../shared/i18n/LanguageContext'

export type AddFriendTarget = {
  userId?: string | null
  displayName?: string | null
  avatarUrl?: string | null
  phone?: string | null
  email?: string | null
  bio?: string | null
  coverUrl?: string | null
  statusMessage?: string | null
  seedQuery?: string | null
}

type AddFriendModalProps = {
  isOpen: boolean
  onClose: () => void
  initialTarget?: AddFriendTarget | null
  onCompleted?: () => Promise<void> | void
  onUserFound?: (user: UserLookupResult) => void
}

const RECENT_RESULT_STORAGE_KEY = 'vnalo:add-friend:recent'

function isEmail(value: string) {
  return /^\S+@\S+\.\S+$/.test(value)
}

function toPhoneCandidates(raw: string): string[] {
  const compact = raw.replace(/[\s.-]/g, '')
  const digits = compact.replace(/[^\d+]/g, '')

  const candidates = new Set<string>()

  if (digits) {
    candidates.add(digits)
  }

  const noPlus = digits.startsWith('+') ? digits.slice(1) : digits

  if (noPlus) {
    candidates.add(noPlus)
  }

  if (noPlus.startsWith('0')) {
    const local = noPlus.slice(1)
    if (local) {
      candidates.add(`84${local}`)
      candidates.add(`+84${local}`)
    }
  }

  if (noPlus.startsWith('84')) {
    candidates.add(`+${noPlus}`)
  }

  return [...candidates].filter(Boolean)
}

function pickBestSearchResult(results: UserLookupResult[], query: string): UserLookupResult | null {
  if (results.length === 0) {
    return null
  }

  const normalized = query.trim().toLowerCase()
  const exactEmail = results.find((item) => (item.email ?? '').toLowerCase() === normalized)

  if (exactEmail) {
    return exactEmail
  }

  const compactPhone = query.replace(/[\s.-]/g, '')
  const phoneMatch = results.find((item) => (item.phone ?? '').replace(/[\s.-]/g, '') === compactPhone)

  if (phoneMatch) {
    return phoneMatch
  }

  return results[0]
}

function maskEmail(email: string): string {
  const [local, domain] = email.split('@')
  if (!local || !domain) {
    return email
  }

  if (local.length <= 2) {
    return `${local[0] ?? '*'}*@${domain}`
  }

  return `${local.slice(0, 2)}***@${domain}`
}

function toLookupFromTarget(target: AddFriendTarget): UserLookupResult | null {
  if (!target.userId) {
    return null
  }

  return {
    id: target.userId,
    displayName: target.displayName ?? null,
    avatarUrl: target.avatarUrl ?? null,
    phone: target.phone ?? null,
    email: target.email ?? null,
    bio: target.bio ?? null,
    coverUrl: target.coverUrl ?? null,
    statusMessage: target.statusMessage ?? null,
  }
}

function loadRecentResultsFromStorage(): UserLookupResult[] {
  try {
    const raw = window.localStorage.getItem(RECENT_RESULT_STORAGE_KEY)
    if (!raw) {
      return []
    }

    const parsed = JSON.parse(raw) as UserLookupResult[]
    if (!Array.isArray(parsed)) {
      return []
    }

    return parsed.filter((item) => typeof item?.id === 'string').slice(0, 4)
  } catch {
    return []
  }
}

function persistRecentResultsToStorage(results: UserLookupResult[]): void {
  try {
    window.localStorage.setItem(RECENT_RESULT_STORAGE_KEY, JSON.stringify(results.slice(0, 4)))
  } catch {
    // Ignore local storage failures.
  }
}

export function AddFriendModal({ isOpen, onClose, initialTarget = null, onCompleted, onUserFound }: AddFriendModalProps) {
  const { accessToken, user } = useAuth()
  const { t } = useLanguage()

  const [identifier, setIdentifier] = React.useState('')
  const [selectedUser, setSelectedUser] = React.useState<UserLookupResult | null>(null)

  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)
  const [successMessage, setSuccessMessage] = React.useState<string | null>(null)

  const [isSearching, setIsSearching] = React.useState(false)
  const [isPreparingTarget, setIsPreparingTarget] = React.useState(false)
  const [isAutoSearching, setIsAutoSearching] = React.useState(false)
  const [isLoadingSuggestions, setIsLoadingSuggestions] = React.useState(false)
  const [recentResults, setRecentResults] = React.useState<UserLookupResult[]>([])
  const [suggestedResults, setSuggestedResults] = React.useState<UserLookupResult[]>([])

  const resetModalState = () => {
    setIdentifier('')
    setSelectedUser(null)
    setErrorMessage(null)
    setSuccessMessage(null)
    setIsSearching(false)
    setIsPreparingTarget(false)
    setIsAutoSearching(false)
    setIsLoadingSuggestions(false)
  }

  const handleClose = () => {
    resetModalState()
    onClose()
  }

  const pushRecentResult = React.useCallback((target: UserLookupResult) => {
    setRecentResults((prev) => {
      const next = [target, ...prev.filter((item) => item.id !== target.id)].slice(0, 4)
      persistRecentResultsToStorage(next)
      return next
    })
  }, [])

  const findUserByIdentifier = React.useCallback(async (query: string): Promise<UserLookupResult | null> => {
    if (!accessToken) {
      return null
    }

    if (isEmail(query)) {
      const results = await searchUsers(accessToken, query)
      return pickBestSearchResult(results, query)
    }

    const phoneCandidates = toPhoneCandidates(query)

    for (const candidate of phoneCandidates) {
      const maybeUser = await getUserByPhone(accessToken, candidate)
      if (maybeUser) {
        return maybeUser
      }
    }

    const fallbackResults = await searchUsers(accessToken, query)
    return pickBestSearchResult(fallbackResults, query)
  }, [accessToken])

  const handleSearchUser = async (target?: UserLookupResult) => {
    if (!accessToken) {
      return
    }

    const query = identifier.trim()
    const finalTarget = target ?? (query ? await findUserByIdentifier(query) : null)

    if (!finalTarget && !query) {
      setErrorMessage(t('contacts.modals.searchRequired'))
      return
    }

    setIsSearching(true)
    setErrorMessage(null)
    setSuccessMessage(null)

    try {
      const matchedUser = finalTarget ?? await findUserByIdentifier(query)

      if (!matchedUser) {
        setErrorMessage(t('contacts.modals.notFound'))
        return
      }

      pushRecentResult(matchedUser)
      
      if (onUserFound) {
        onUserFound(matchedUser)
        handleClose()
      } else {
        setSelectedUser(matchedUser)
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsSearching(false)
    }
  }

  React.useEffect(() => {
    if (!isOpen) {
      return
    }

    setRecentResults(loadRecentResultsFromStorage())
  }, [isOpen, t])

  React.useEffect(() => {
    if (!isOpen || !accessToken) {
      return
    }

    const query = identifier.trim()
    if (!query) {
      setSuggestedResults(recentResults)
      return
    }

    let cancelled = false
    setIsLoadingSuggestions(true)

    const timerId = window.setTimeout(() => {
      void (async () => {
        try {
          const results = await searchUsers(accessToken, query)
          if (cancelled) {
            return
          }

          const normalized = results
            .filter((item) => item.id !== user?.id)
            .slice(0, 8)

          setSuggestedResults(normalized)
        } catch {
          if (!cancelled) {
            setSuggestedResults([])
          }
        } finally {
          if (!cancelled) {
            setIsLoadingSuggestions(false)
          }
        }
      })()
    }, 250)

    return () => {
      cancelled = true
      window.clearTimeout(timerId)
    }
  }, [accessToken, identifier, isOpen, recentResults, user?.id])

  React.useEffect(() => {
    if (!isOpen || !accessToken) {
      return
    }

    let active = true

    const prepareTarget = async () => {
      if (!initialTarget) {
        return
      }

      if (initialTarget.userId) {
        setIsPreparingTarget(true)
        setErrorMessage(null)
        setSuccessMessage(null)

        try {
          const seeded = toLookupFromTarget(initialTarget)
          const profile = await getUserById(accessToken, initialTarget.userId)
          const resolved = profile ?? seeded

          if (!resolved || !active) {
            return
          }

          if (onUserFound) {
            onUserFound(resolved)
            handleClose()
          } else {
            setSelectedUser(resolved)
          }
        } catch (error) {
          if (!active) {
            return
          }
          setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
        } finally {
          if (active) {
            setIsPreparingTarget(false)
          }
        }
        return
      }

      const seedQuery = initialTarget.seedQuery?.trim() ?? ''
      if (!seedQuery) {
        return
      }

      setIdentifier(seedQuery)
      setIsAutoSearching(true)
      setErrorMessage(null)
      setSuccessMessage(null)

      try {
        const resolved = await findUserByIdentifier(seedQuery)
        if (!active) {
          return
        }

        if (!resolved) {
          setErrorMessage(t('contacts.modals.notFound'))
          return
        }

        if (onUserFound) {
          onUserFound(resolved)
          handleClose()
        } else {
          setSelectedUser(resolved)
        }
      } catch (error) {
        if (!active) {
          return
        }
        setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
      } finally {
        if (active) {
          setIsAutoSearching(false)
        }
      }
    }

    void prepareTarget()

    return () => {
      active = false
    }
  }, [accessToken, findUserByIdentifier, initialTarget, isOpen, onUserFound, t])

  const visibleRecentResults = React.useMemo(() => {
    return recentResults
  }, [recentResults])

  const visibleSuggestedResults = React.useMemo(() => {
    return suggestedResults
      .filter((item) => !visibleRecentResults.some((recent) => recent.id === item.id))
      .slice(0, 4)
  }, [suggestedResults, visibleRecentResults])

  const formatLookupLabel = (item: UserLookupResult): string => {
    if (item.phone) {
      return `(+84) ${item.phone.replace(/^\+?84/, '').replace(/^0/, '')}`
    }

    if (item.email) {
      return maskEmail(item.email)
    }

    return t('contacts.common.unknownUser')
  }

  const renderDisplayName = (item: UserLookupResult): string => {
    return item.displayName?.trim() || item.phone || item.email || t('contacts.common.unknownUser')
  }

  return (
    <Modal
      description=''
      footer={
        <div className='add-friend-zalo-footer'>
          <button className='add-friend-zalo-btn add-friend-zalo-btn-cancel' onClick={handleClose} type='button'>
            Hủy
          </button>
          <button
            className='add-friend-zalo-btn add-friend-zalo-btn-search'
            disabled={isSearching || isPreparingTarget || isAutoSearching}
            onClick={() => {
              void handleSearchUser()
            }}
            type='button'
          >
            {isSearching || isAutoSearching ? 'Đang tìm...' : 'Tìm kiếm'}
          </button>
        </div>
      }
      isOpen={isOpen}
      onClose={handleClose}
      title='Thêm bạn'
    >
      <div className='add-friend-zalo'>
        <div className='add-friend-zalo-search'>
          <div className='add-friend-zalo-prefix'>
            <span className='add-friend-zalo-flag' aria-hidden='true'>
              🇻🇳
            </span>
            <span>(+84)</span>
            <span className='add-friend-zalo-caret'>▼</span>
          </div>
          <input
            className='add-friend-zalo-input'
            placeholder='Số điện thoại'
            value={identifier}
            onChange={(event) => {
              setIdentifier(event.target.value)
              setErrorMessage(null)
            }}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault()
                void handleSearchUser()
              }
            }}
          />
        </div>

        {errorMessage && <p className='text-red-500 text-sm mt-2'>{errorMessage}</p>}

        <section className='add-friend-zalo-section'>
          <h4>Kết quả gần nhất</h4>
          <div className='add-friend-zalo-list'>
            {visibleRecentResults.map((item) => (
              <button
                className='add-friend-zalo-recent-item'
                key={`recent-${item.id}`}
                type='button'
                onClick={() => {
                  void handleSearchUser(item)
                }}
              >
                <UserAvatar imageUrl={item.avatarUrl} name={renderDisplayName(item)} size='md' />
                <span className='add-friend-zalo-item-copy'>
                  <strong>{renderDisplayName(item)}</strong>
                  <small>{formatLookupLabel(item)}</small>
                </span>
              </button>
            ))}
            {visibleRecentResults.length === 0 ? <p className='contacts-request-meta'>Chưa có kết quả gần nhất</p> : null}
          </div>
        </section>

        <section className='add-friend-zalo-section'>
          <h4>Có thể bạn quen</h4>
          <div className='add-friend-zalo-list'>
            {visibleSuggestedResults.map((item, index) => (
              <button
                className='add-friend-zalo-recent-item'
                key={`suggest-${item.id}`}
                type='button'
                onClick={() => {
                  void handleSearchUser(item)
                }}
              >
                <UserAvatar imageUrl={item.avatarUrl} name={renderDisplayName(item)} size='md' />
                <span className='add-friend-zalo-item-copy'>
                  <strong>{renderDisplayName(item)}</strong>
                  <small>{index % 2 === 0 ? 'Từ số điện thoại' : 'Từ gợi ý kết bạn'}</small>
                </span>
              </button>
            ))}
            {isLoadingSuggestions && suggestedResults.length === 0 && <p className='contacts-request-meta'>Đang tải gợi ý...</p>}
          </div>
        </section>
      </div>
    </Modal>
  )
}
