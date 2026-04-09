import { useCallback, useEffect, useMemo, useState } from 'react'

import { useAuth } from '../../auth/useAuth'
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

function maskPhone(phone: string): string {
  const cleaned = phone.replace(/\s+/g, '')
  if (cleaned.length <= 5) {
    return cleaned
  }

  return `${cleaned.slice(0, 3)}***${cleaned.slice(-2)}`
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

export function AddFriendModal({ isOpen, onClose, initialTarget = null, onCompleted }: AddFriendModalProps) {
  const { accessToken, user } = useAuth()
  const { t } = useLanguage()

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

  const isInConfirmStep = Boolean(selectedUser)

  const submitLabel = useMemo(() => {
    if (isSubmitting) {
      return t('contacts.common.processing')
    }

    return t('contacts.modals.sendRequestAction')
  }, [isSubmitting, t])

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
  }

  const handleClose = () => {
    resetModalState()
    onClose()
  }

  const resolveRelationship = useCallback(async (targetUserId: string) => {
    if (!accessToken) {
      return
    }

    if (user?.id === targetUserId) {
      setRelation('self')
      return
    }

    const [friendshipStatus, incomingRequests, sentRequests] = await Promise.all([
      checkFriendshipStatus(accessToken, targetUserId),
      getIncomingFriendRequests(accessToken),
      getSentFriendRequests(accessToken),
    ])

    if (friendshipStatus.areFriends) {
      setRelation('already-friend')
      return
    }

    const incoming = incomingRequests.find((item) => item.fromUserId === targetUserId && item.status === 'PENDING')
    if (incoming) {
      setRelation('incoming')
      return
    }

    const sent = sentRequests.find((item) => item.toUserId === targetUserId && item.status === 'PENDING')
    if (sent) {
      setRelation('sent')
      return
    }

    setRelation('none')
  }, [accessToken, user?.id])

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

  const openConfirmForUser = useCallback(async (matchedUser: UserLookupResult) => {
    setSelectedUser(matchedUser)
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

      await openConfirmForUser(matchedUser)
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
  }, [isOpen, t])

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

          await openConfirmForUser(resolved)
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

        await openConfirmForUser(resolved)
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
  }, [accessToken, findUserByIdentifier, initialTarget, isOpen, openConfirmForUser, t])

  const runPostActionRefresh = async () => {
    if (onCompleted) {
      await onCompleted()
    }
  }

  const handlePrimaryAction = async () => {
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
      setSuccessMessage(t('contacts.feedback.requestSentSuccess'))
      setRelation('sent')
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('contacts.feedback.genericError'))
    } finally {
      setIsSubmitting(false)
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

  const profileName =
    selectedUser?.displayName?.trim() || selectedUser?.email || selectedUser?.phone || t('contacts.modals.accountTitle')

  const profileContact = selectedUser?.phone
    ? maskPhone(selectedUser.phone)
    : selectedUser?.email
      ? maskEmail(selectedUser.email)
      : null

  const profileSubline =
    selectedUser?.statusMessage?.trim() || profileContact

  return (
    <Modal
      description={isInConfirmStep ? t('contacts.modals.confirmDescription') : t('contacts.modals.searchDescription')}
      footer={
        <>
          <Button variant='ghost' onClick={handleClose}>
            {t('contacts.common.cancel')}
          </Button>
          <Button
            disabled={
              isSubmitting ||
              isSearching ||
              isPreparingTarget ||
              isAutoSearching ||
              !selectedUser ||
              relation !== 'none'
            }
            onClick={handlePrimaryAction}
            variant='primary'
          >
            {submitLabel}
          </Button>
        </>
      }
      isOpen={isOpen}
      onClose={handleClose}
      title={isInConfirmStep ? t('contacts.modals.confirmTitle') : t('contacts.modals.searchTitle')}
    >
      {!isInConfirmStep ? (
        <label className='modal-field'>
          <span>{t('contacts.modals.identifierLabel')}</span>
          <div className='contacts-add-friend-search-row'>
            <input
              placeholder={t('contacts.modals.identifierPlaceholder')}
              value={identifier}
              onChange={(event) => {
                setIdentifier(event.target.value)
                setSelectedUser(null)
                setRelation('none')
                setErrorMessage(null)
                setSuccessMessage(null)
              }}
            />
            <Button disabled={isSearching || isSubmitting || isAutoSearching} onClick={handleSearchUser} variant='subtle'>
              {isSearching || isAutoSearching ? t('contacts.modals.searching') : t('contacts.modals.searchAction')}
            </Button>
          </div>
        </label>
      ) : null}

      {isInConfirmStep && selectedUser ? (
        <div className='friend-request-confirm'>
          <div className='friend-request-profile'>
            {selectedUser.coverUrl ? (
              <img alt={profileName} className='friend-request-cover-image' src={selectedUser.coverUrl} />
            ) : (
              <div className='friend-request-cover-fallback' />
            )}
            <div className='friend-request-avatar-wrap'>
              <UserAvatar imageUrl={selectedUser.avatarUrl} name={profileName} size='lg' />
            </div>
            <div className='friend-request-profile-copy'>
              <h4>{profileName}</h4>
              {profileSubline ? <p>{profileSubline}</p> : null}
              {selectedUser.bio?.trim() ? <p className='friend-request-bio'>{selectedUser.bio}</p> : null}
            </div>
          </div>

          <label className='modal-field'>
            <span>{t('contacts.modals.messageLabel')}</span>
            <textarea
              placeholder={t('contacts.modals.messagePlaceholder')}
              rows={3}
              value={requestMessage}
              onChange={(event) => setRequestMessage(event.target.value)}
            />
          </label>

          <div className='friend-request-confirm-meta'>
            {relationMessage ? <p className='contacts-request-meta'>{relationMessage}</p> : null}
            <Button
              disabled={isSubmitting || isSearching || isPreparingTarget}
              onClick={() => {
                setSelectedUser(null)
                setRelation('none')
                setErrorMessage(null)
                setSuccessMessage(null)
              }}
              variant='ghost'
            >
              {t('contacts.modals.changeTargetAction')}
            </Button>
          </div>
        </div>
      ) : null}

      {successMessage ? <p className='contacts-feedback contacts-feedback-success'>{successMessage}</p> : null}
      {errorMessage ? <p className='contacts-feedback contacts-feedback-error'>{errorMessage}</p> : null}
    </Modal>
  )
}
