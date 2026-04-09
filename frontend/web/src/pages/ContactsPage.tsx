import { useEffect, useMemo, useState } from 'react'

import { useAuth } from '../features/auth/useAuth'
import { ContactList } from '../features/contacts/components/ContactList'
import { ContactsTabs, type ContactsTab } from '../features/contacts/components/ContactsTabs'
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
  unfriend,
} from '../features/friends/friends.api'
import type { Friend, FriendRequest, FriendStats } from '../features/friends/friends.types'
import { EmptyState } from '../shared/components/EmptyState'
import { Icon } from '../shared/components/Icon'
import { LoadingState } from '../shared/components/LoadingState'
import { SearchInput } from '../shared/components/SearchInput'
import { Button } from '../shared/components/ui/Button'
import { Card } from '../shared/components/ui/Card'
import { Modal } from '../shared/components/ui/Modal'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { contactGroups } from '../shared/mock/data'

type FeedbackState = {
  type: 'success' | 'error'
  message: string
}

type ConfirmAction =
  | { kind: 'decline'; requestId: string; displayName: string }
  | { kind: 'cancelSent'; requestId: string; displayName: string }
  | { kind: 'unfriend'; friendId: string; displayName: string }
  | null

export function ContactsPage() {
  const { accessToken } = useAuth()
  const { t } = useLanguage()

  const [tab, setTab] = useState<ContactsTab>('all')
  const [keyword, setKeyword] = useState('')

  const [friends, setFriends] = useState<Friend[]>([])
  const [incomingRequests, setIncomingRequests] = useState<FriendRequest[]>([])
  const [sentRequests, setSentRequests] = useState<FriendRequest[]>([])
  const [stats, setStats] = useState<FriendStats | null>(null)

  const [isLoadingFriends, setIsLoadingFriends] = useState(true)
  const [isLoadingIncoming, setIsLoadingIncoming] = useState(true)
  const [isLoadingSent, setIsLoadingSent] = useState(true)
  const [isLoadingStats, setIsLoadingStats] = useState(true)

  const [feedback, setFeedback] = useState<FeedbackState | null>(null)
  const [confirmAction, setConfirmAction] = useState<ConfirmAction>(null)
  const [isConfirmSubmitting, setIsConfirmSubmitting] = useState(false)
  const [activeAction, setActiveAction] = useState<{ id: string | null; type: string | null }>({
    id: null,
    type: null,
  })

  const [showAddFriendModal, setShowAddFriendModal] = useState(false)
  const [addFriendTarget, setAddFriendTarget] = useState<AddFriendTarget | null>(null)

  const normalizedKeyword = keyword.trim().toLowerCase()

  const refreshFriends = async (token: string) => {
    setIsLoadingFriends(true)
    try {
      const nextFriends = await getFriends(token)
      setFriends(nextFriends)
    } finally {
      setIsLoadingFriends(false)
    }
  }

  const refreshIncoming = async (token: string) => {
    setIsLoadingIncoming(true)
    try {
      const nextIncoming = await getIncomingFriendRequests(token)
      setIncomingRequests(nextIncoming)
    } finally {
      setIsLoadingIncoming(false)
    }
  }

  const refreshSent = async (token: string) => {
    setIsLoadingSent(true)
    try {
      const nextSent = await getSentFriendRequests(token)
      setSentRequests(nextSent)
    } finally {
      setIsLoadingSent(false)
    }
  }

  const refreshStats = async (token: string) => {
    setIsLoadingStats(true)
    try {
      const nextStats = await getFriendStats(token)
      setStats(nextStats)
    } finally {
      setIsLoadingStats(false)
    }
  }

  useEffect(() => {
    if (!accessToken) {
      setFriends([])
      setIncomingRequests([])
      setSentRequests([])
      setStats(null)
      setIsLoadingFriends(false)
      setIsLoadingIncoming(false)
      setIsLoadingSent(false)
      setIsLoadingStats(false)
      return
    }

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

  const filteredContacts = useMemo(
    () =>
      friends.filter(
        (item) =>
          (item.displayName ?? '').toLowerCase().includes(normalizedKeyword) ||
          (item.statusMessage ?? '').toLowerCase().includes(normalizedKeyword) ||
          item.friendId.toLowerCase().includes(normalizedKeyword),
      ),
    [friends, normalizedKeyword],
  )

  const filteredIncomingRequests = useMemo(
    () =>
      incomingRequests.filter(
        (item) =>
          (item.fromUserDisplayName ?? '').toLowerCase().includes(normalizedKeyword) ||
          item.fromUserId.toLowerCase().includes(normalizedKeyword) ||
          (item.message ?? '').toLowerCase().includes(normalizedKeyword),
      ),
    [incomingRequests, normalizedKeyword],
  )

  const filteredSentRequests = useMemo(
    () =>
      sentRequests.filter(
        (item) =>
          (item.toUserDisplayName ?? '').toLowerCase().includes(normalizedKeyword) ||
          item.toUserId.toLowerCase().includes(normalizedKeyword) ||
          (item.message ?? '').toLowerCase().includes(normalizedKeyword),
      ),
    [normalizedKeyword, sentRequests],
  )

  const filteredGroups = useMemo(
    () =>
      contactGroups.filter(
        (item) =>
          item.name.toLowerCase().includes(normalizedKeyword) ||
          item.description.toLowerCase().includes(normalizedKeyword),
      ),
    [normalizedKeyword],
  )

  const labels = {
    chat: t('contacts.actions.chat'),
    unfriend: t('contacts.actions.unfriend'),
    friend: t('contacts.status.friend'),
    unknownUser: t('contacts.common.unknownUser'),
  }

  const menuItems = [
    {
      key: 'friends',
      icon: 'user' as const,
      label: t('contacts.menu.friends'),
      active: tab === 'all',
      onClick: () => setTab('all'),
    },
    {
      key: 'groups',
      icon: 'group' as const,
      label: t('contacts.menu.groupsCommunities'),
      active: tab === 'groups',
      onClick: () => setTab('groups'),
    },
    {
      key: 'requests',
      icon: 'userPlus' as const,
      label: t('contacts.menu.friendRequests'),
      active: tab === 'requests',
      onClick: () => setTab('requests'),
    },
    {
      key: 'group-invite',
      icon: 'chat' as const,
      label: t('contacts.menu.groupInvites'),
      active: false,
      onClick: () => {},
    },
  ]

  const openAddFriendModal = (target: AddFriendTarget | null = null) => {
    setAddFriendTarget(target)
    setShowAddFriendModal(true)
  }

  const closeAddFriendModal = () => {
    setShowAddFriendModal(false)
    setAddFriendTarget(null)
  }

  const refreshAll = async (token: string) => {
    await Promise.all([refreshFriends(token), refreshIncoming(token), refreshSent(token), refreshStats(token)])
  }

  const handleAcceptRequest = async (requestId: string) => {
    if (!accessToken) {
      return
    }

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
    if (!accessToken || !confirmAction) {
      return
    }

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

  return (
    <section className='panel-page contacts-page'>
      <div className='contacts-shell'>
        <aside className='contacts-menu'>
          {menuItems.map((item) => (
            <button
              key={item.key}
              className={item.active ? 'contacts-menu-item contacts-menu-item-active' : 'contacts-menu-item'}
              onClick={item.onClick}
              type='button'
            >
              <Icon name={item.icon} />
              <span>{item.label}</span>
            </button>
          ))}
        </aside>

        <div className='contacts-main'>
          <header className='contacts-header'>
            <div>
              <h2>{t('pages.contacts.title')}</h2>
              <p className='panel-subtitle'>{t('pages.contacts.subtitle')}</p>
              {stats || isLoadingStats ? (
                <p className='contacts-stats-line'>
                  {isLoadingStats || !stats
                    ? t('contacts.common.processing')
                    : `${t('contacts.stats.friendsCount')}: ${stats.friendCount} · ${t('contacts.stats.pendingCount')}: ${stats.pendingRequestCount}`}
                </p>
              ) : null}
            </div>
            <Button onClick={() => openAddFriendModal()} variant='subtle'>
              {t('contacts.actions.addFriend')}
            </Button>
          </header>

          {feedback ? (
            <p
              className={
                feedback.type === 'success'
                  ? 'contacts-feedback contacts-feedback-success'
                  : 'contacts-feedback contacts-feedback-error'
              }
            >
              {feedback.message}
            </p>
          ) : null}

          <div className='contacts-toolbar'>
            <SearchInput placeholder={t('contacts.searchDirectoryPlaceholder')} value={keyword} onChange={setKeyword} />
            <ContactsTabs
              labels={{
                all: t('contacts.tabs.allContacts'),
                requests: t('contacts.tabs.friendRequests'),
                groups: t('contacts.tabs.groupsOnly'),
              }}
              onChange={setTab}
              value={tab}
            />
          </div>

          {tab === 'all' ? (
            isLoadingFriends ? (
              <LoadingState label={t('contacts.loading.friends')} />
            ) : filteredContacts.length > 0 ? (
              <ContactList
                actionLoadingId={activeAction.type === 'unfriend' ? activeAction.id : null}
                items={filteredContacts}
                labels={labels}
                onUnfriend={(friendId, displayName) => setConfirmAction({ kind: 'unfriend', friendId, displayName })}
              />
            ) : (
              <EmptyState title={t('contacts.empty.noFriendsTitle')} description={t('contacts.empty.noFriendsDesc')} />
            )
          ) : null}

          {tab === 'requests' ? (
            <div className='contacts-request-sections'>
              <section className='contacts-request-section'>
                <div className='contacts-request-section-head'>
                  <h3>{t('contacts.sections.incomingRequests')}</h3>
                </div>
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
                  <EmptyState
                    title={t('contacts.empty.noIncomingRequestsTitle')}
                    description={t('contacts.empty.noIncomingRequestsDesc')}
                  />
                )}
              </section>

              <section className='contacts-request-section'>
                <div className='contacts-request-section-head'>
                  <h3>{t('contacts.sections.sentRequests')}</h3>
                </div>
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
                  <EmptyState
                    title={t('contacts.empty.noSentRequestsTitle')}
                    description={t('contacts.empty.noSentRequestsDesc')}
                  />
                )}
              </section>
            </div>
          ) : null}

          {tab === 'groups' ? (
            filteredGroups.length > 0 ? (
              <section className='contacts-list'>
                {filteredGroups.map((group) => (
                  <Card as='article' className='contacts-item contacts-group-item' key={group.id}>
                    <div className='contacts-item-copy'>
                      <h3>{group.name}</h3>
                      <p>{group.description}</p>
                      <p className='contacts-request-meta'>
                        {group.memberCount} {t('contacts.groups.members')}
                      </p>
                    </div>
                  </Card>
                ))}
              </section>
            ) : (
              <EmptyState title={t('contacts.empty.noGroupsTitle')} description={t('contacts.empty.noGroupsDesc')} />
            )
          ) : null}
        </div>
      </div>

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
        description={`${confirmDescription} ${confirmAction?.displayName ?? ''}`.trim()}
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
        <p className='contacts-request-meta'>{t('contacts.confirm.irreversibleWarning')}</p>
      </Modal>
    </section>
  )
}
