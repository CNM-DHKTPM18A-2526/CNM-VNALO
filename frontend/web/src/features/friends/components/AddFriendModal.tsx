import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { useAuth } from '../../auth/useAuth'
import { getOrCreateDirectConversation } from '../../chat/chat.api'
import {
  checkFriendshipStatus,
  getIncomingFriendRequests,
  getSentFriendRequests,
  getUserById,
  getUserByPhone,
  searchUsers,
  sendFriendRequest,
} from '../friends.api'
import type { UserLookupResult } from '../friends.types'
import { UserAvatar } from '../../../shared/components/UserAvatar'
import { Button } from '../../../shared/components/ui/Button'
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
}

type RelationState = 'none' | 'already-friend' | 'incoming' | 'sent' | 'self'
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

export function AddFriendModal({ isOpen, onClose, initialTarget = null, onCompleted }: AddFriendModalProps) {
  const { accessToken, user } = useAuth()
  const { t } = useLanguage()
  const navigate = useNavigate()

  const [identifier, setIdentifier] = useState('')
  const [requestMessage, setRequestMessage] = useState(() => t('contacts.modals.defaultMessage'))
  const [selectedUser, setSelectedUser] = useState<UserLookupResult | null>(null)
  const [relation, setRelation] = useState<RelationState>('none')

  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  const [isSearching, setIsSearching] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isPreparingTarget, setIsPreparingTarget] = useState(false)
  const [isAutoSearching, setIsAutoSearching] = useState(false)
  const [isOpeningConversation, setIsOpeningConversation] = useState(false)
  const [isLoadingSuggestions, setIsLoadingSuggestions] = useState(false)
  const [isComposingFriendRequest, setIsComposingFriendRequest] = useState(false)
  const [recentResults, setRecentResults] = useState<UserLookupResult[]>([])
  const [suggestedResults, setSuggestedResults] = useState<UserLookupResult[]>([])

  const resetModalState = () => {
    setIdentifier('')
    setRequestMessage(t('contacts.modals.defaultMessage'))
    setSelectedUser(null)
    setRelation('none')
    setErrorMessage(null)
    setSuccessMessage(null)
    setIsSearching(false)
    setIsSubmitting(false)
    setIsPreparingTarget(false)
    setIsAutoSearching(false)
    setIsOpeningConversation(false)
    setIsLoadingSuggestions(false)
    setIsComposingFriendRequest(false)
  }

  const handleClose = () => {
    resetModalState()
    onClose()
  }

  const getRelationForUser = useCallback(async (targetUserId: string): Promise<RelationState> => {
    if (!accessToken) {
      return 'none'
    }

    if (user?.id === targetUserId) {
      return 'self'
    }

    const [friendshipStatus, incomingRequests, sentRequests] = await Promise.all([
      checkFriendshipStatus(accessToken, targetUserId),
      getIncomingFriendRequests(accessToken),
      getSentFriendRequests(accessToken),
    ])

    if (friendshipStatus.areFriends) {
      return 'already-friend'
    }

    const incoming = incomingRequests.find((item) => item.fromUserId === targetUserId && item.status === 'PENDING')
    if (incoming) {
      return 'incoming'
    }

    const sent = sentRequests.find((item) => item.toUserId === targetUserId && item.status === 'PENDING')
    if (sent) {
      return 'sent'
    }

    return 'none'
  }, [accessToken, user?.id])

  const resolveRelationship = useCallback(async (targetUserId: string) => {
    const relationState = await getRelationForUser(targetUserId)
    setRelation(relationState)
  }, [getRelationForUser])

  const pushRecentResult = useCallback((target: UserLookupResult) => {
    setRecentResults((prev) => {
      const next = [target, ...prev.filter((item) => item.id !== target.id)].slice(0, 4)
      persistRecentResultsToStorage(next)
      return next
    })
  }, [])

  const findUserByIdentifier = useCallback(async (query: string): Promise<UserLookupResult | null> => {
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

  const openProfileForUser = useCallback(async (matchedUser: UserLookupResult) => {
    setSelectedUser(matchedUser)
    setIsComposingFriendRequest(false)
    setErrorMessage(null)
    setSuccessMessage(null)
    await resolveRelationship(matchedUser.id)
  }, [resolveRelationship])

  const handleSearchUser = async () => {
    if (!accessToken) {
      return
    }

    const query = identifier.trim()

    if (!query) {
      setErrorMessage(t('contacts.modals.searchRequired'))
      setSelectedUser(null)
      return
    }

    setIsSearching(true)
    setErrorMessage(null)
    setSuccessMessage(null)
    setSelectedUser(null)

    try {
      const matchedUser = await findUserByIdentifier(query)

      if (!matchedUser) {
        setErrorMessage(t('contacts.modals.notFound'))
        setRelation('none')
        return
      }

      await openProfileForUser(matchedUser)
      pushRecentResult(matchedUser)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
      setSelectedUser(null)
      setRelation('none')
    } finally {
      setIsSearching(false)
    }
  }

  useEffect(() => {
    if (!isOpen) {
      return
    }

    setRequestMessage(t('contacts.modals.defaultMessage'))
    setRecentResults(loadRecentResultsFromStorage())
  }, [isOpen, t])

  useEffect(() => {
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

  useEffect(() => {
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
          if (seeded && active) {
            setSelectedUser(seeded)
          }

          const profile = await getUserById(accessToken, initialTarget.userId)
          const resolved = profile ?? seeded

          if (!resolved || !active) {
            return
          }

          await openProfileForUser(resolved)
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

        await openProfileForUser(resolved)
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
  }, [accessToken, findUserByIdentifier, initialTarget, isOpen, openProfileForUser, t])

  const runPostActionRefresh = async () => {
    if (onCompleted) {
      await onCompleted()
    }
  }

  const handleSendFriendRequest = async () => {
    if (!accessToken || !selectedUser) {
      return
    }

    if (relation !== 'none') {
      return
    }

    setIsSubmitting(true)
    setErrorMessage(null)
    setSuccessMessage(null)

    try {
      await sendFriendRequest(accessToken, {
        toUserId: selectedUser.id,
        message: requestMessage,
        source: 'SEARCH',
      })

      await runPostActionRefresh()
      pushRecentResult(selectedUser)
      setSuccessMessage(t('contacts.feedback.requestSentSuccess'))
      setIsComposingFriendRequest(false)
      setRelation('sent')
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleOpenComposer = () => {
    if (relation !== 'none') {
      return
    }

    setIsComposingFriendRequest(true)
    setErrorMessage(null)
    setSuccessMessage(null)
  }

  const handleCallUser = () => {
    if (!selectedUser?.phone) {
      return
    }

    const dialNumber = selectedUser.phone.replace(/[^\d+]/g, '')
    if (!dialNumber) {
      return
    }

    window.location.href = `tel:${dialNumber}`
  }

  const handleBackToResults = () => {
    setSelectedUser(null)
    setIsComposingFriendRequest(false)
    setRelation('none')
    setErrorMessage(null)
    setSuccessMessage(null)
  }

  const handleOpenConversation = async () => {
    if (!accessToken || !selectedUser) {
      return
    }

    setErrorMessage(null)
    setSuccessMessage(null)
    setIsOpeningConversation(true)

    try {
      const conversationId = await getOrCreateDirectConversation(accessToken, selectedUser.id)
      handleClose()
      navigate(`/chat/${conversationId}`)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsOpeningConversation(false)
    }
  }

  const relationMessage =
    relation === 'already-friend'
      ? t('contacts.feedback.alreadyFriends')
      : relation === 'sent'
        ? t('contacts.feedback.requestAlreadySent')
        : relation === 'incoming'
          ? t('contacts.feedback.requestIncomingPending')
          : relation === 'self'
            ? t('contacts.feedback.cannotAddSelf')
            : null

  const visibleRecentResults = useMemo(() => {
    if (!selectedUser) {
      return recentResults
    }

    return [selectedUser, ...recentResults.filter((item) => item.id !== selectedUser.id)].slice(0, 4)
  }, [recentResults, selectedUser])

  const visibleSuggestedResults = useMemo(() => {
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

  const renderProfileContent = () => {
    if (!selectedUser) {
      return null
    }

    const displayName = renderDisplayName(selectedUser)
    const phoneDisplay = selectedUser.phone ? `(+84) ${selectedUser.phone.replace(/^\+?84/, '').replace(/^0/, '')}` : 'Chưa cập nhật'
    const emailDisplay = selectedUser.email ?? 'Chưa cập nhật'
    const bioDisplay = selectedUser.bio ?? selectedUser.statusMessage ?? 'Chưa có mô tả'
    const canCall = relation === 'already-friend' && Boolean(selectedUser.phone)

    return (
      <section className='add-friend-profile'>
        <button className='add-friend-profile-back' onClick={handleBackToResults} type='button'>
          Quay lại kết quả
        </button>

        <div className='add-friend-profile-card'>
          <div
            className={`add-friend-profile-cover${selectedUser.coverUrl ? ' add-friend-profile-cover-image' : ''}`}
            style={selectedUser.coverUrl ? { backgroundImage: `url(${selectedUser.coverUrl})` } : undefined}
          />
          <div className='add-friend-profile-head'>
            <div className='add-friend-profile-avatar'>
              <UserAvatar imageUrl={selectedUser.avatarUrl} name={displayName} size='lg' />
            </div>
            <div className='add-friend-profile-copy'>
              <h4>{displayName}</h4>
              <p>{selectedUser.statusMessage ?? 'Đang hoạt động trên VNALO'}</p>
            </div>
          </div>

          <div className='add-friend-profile-info'>
            <div className='add-friend-profile-info-row'>
              <span>Số điện thoại</span>
              <strong>{phoneDisplay}</strong>
            </div>
            <div className='add-friend-profile-info-row'>
              <span>Email</span>
              <strong>{emailDisplay}</strong>
            </div>
            <div className='add-friend-profile-info-row'>
              <span>Giới thiệu</span>
              <strong>{bioDisplay}</strong>
            </div>
          </div>

          <div className='add-friend-profile-actions'>
            {relation === 'already-friend' ? (
              <>
                <Button
                  disabled={isOpeningConversation}
                  onClick={() => {
                    void handleOpenConversation()
                  }}
                  variant='primary'
                >
                  {isOpeningConversation ? 'Đang mở hội thoại...' : 'Nhắn tin'}
                </Button>
                <Button disabled={!canCall} onClick={handleCallUser} variant='subtle'>
                  Gọi điện
                </Button>
              </>
            ) : (
              <>
                <Button
                  disabled={isOpeningConversation}
                  onClick={() => {
                    void handleOpenConversation()
                  }}
                  variant='subtle'
                >
                  {isOpeningConversation ? 'Đang mở hội thoại...' : 'Nhắn tin'}
                </Button>
                <Button
                  disabled={relation !== 'none' || isSubmitting}
                  onClick={handleOpenComposer}
                  variant='primary'
                >
                  Kết bạn
                </Button>
              </>
            )}
          </div>

          {isComposingFriendRequest && relation === 'none' ? (
            <div className='add-friend-request-box'>
              <label htmlFor='add-friend-request-message'>Tin nhắn kết bạn</label>
              <textarea
                id='add-friend-request-message'
                maxLength={240}
                onChange={(event) => {
                  setRequestMessage(event.target.value)
                }}
                placeholder='Xin chào, mình muốn kết bạn với bạn.'
                rows={3}
                value={requestMessage}
              />
              <div className='add-friend-request-actions'>
                <Button
                  disabled={isSubmitting}
                  onClick={() => {
                    setIsComposingFriendRequest(false)
                  }}
                  variant='subtle'
                >
                  Hủy
                </Button>
                <Button disabled={isSubmitting} onClick={handleSendFriendRequest} variant='primary'>
                  {isSubmitting ? t('contacts.common.processing') : 'Kết bạn'}
                </Button>
              </div>
            </div>
          ) : null}
        </div>
      </section>
    )
  }

  return (
    <Modal
      description=''
      footer={
        selectedUser ? undefined : (
          <div className='add-friend-zalo-footer'>
            <button className='add-friend-zalo-btn add-friend-zalo-btn-cancel' onClick={handleClose} type='button'>
              Hủy
            </button>
            <button
              className='add-friend-zalo-btn add-friend-zalo-btn-search'
              disabled={isSearching || isSubmitting || isPreparingTarget || isAutoSearching}
              onClick={() => {
                void handleSearchUser()
              }}
              type='button'
            >
              {isSearching || isAutoSearching ? 'Đang tìm...' : 'Tìm kiếm'}
            </button>
          </div>
        )
      }
      isOpen={isOpen}
      onClose={handleClose}
      title='Thêm bạn'
    >
      <div className='add-friend-zalo'>
        {/* Search row with VN country code and underline input like Zalo */}
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
              setSuccessMessage(null)
            }}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault()
                void handleSearchUser()
              }
            }}
          />
        </div>

        {selectedUser ? (
          renderProfileContent()
        ) : (
          <>
            <section className='add-friend-zalo-section'>
              <h4>Kết quả gần nhất</h4>
              <div className='add-friend-zalo-list'>
                {visibleRecentResults.slice(0, 4).map((item) => (
                  <button
                    className='add-friend-zalo-recent-item'
                    key={`recent-${item.id}`}
                    type='button'
                    onClick={() => {
                      void openProfileForUser(item)
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
                      void openProfileForUser(item)
                    }}
                  >
                    <UserAvatar imageUrl={item.avatarUrl} name={renderDisplayName(item)} size='md' />
                    <span className='add-friend-zalo-item-copy'>
                      <strong>{renderDisplayName(item)}</strong>
                      <small>{index % 2 === 0 ? 'Từ số điện thoại' : 'Từ gợi ý kết bạn'}</small>
                    </span>
                  </button>
                ))}
                {!isLoadingSuggestions && visibleSuggestedResults.length === 0 ? (
                  <p className='contacts-request-meta'>Không có gợi ý phù hợp</p>
                ) : null}
              </div>
              <button
                className='add-friend-zalo-more'
                onClick={() => {
                  void handleSearchUser()
                }}
                type='button'
              >
                Xem thêm
              </button>
            </section>
          </>
        )}

        {!selectedUser && relationMessage ? <p className='contacts-request-meta'>{relationMessage}</p> : null}
      </div>

      {successMessage ? <p className='contacts-feedback contacts-feedback-success'>{successMessage}</p> : null}
      {errorMessage ? <p className='contacts-feedback contacts-feedback-error'>{errorMessage}</p> : null}
    </Modal>
  )
}
