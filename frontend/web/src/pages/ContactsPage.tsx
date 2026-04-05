import { useMemo, useState } from 'react'

import { ContactList } from '../features/contacts/components/ContactList'
import { ContactsTabs, type ContactsTab } from '../features/contacts/components/ContactsTabs'
import { FriendRequestList } from '../features/contacts/components/FriendRequestList'
import { EmptyState } from '../shared/components/EmptyState'
import { SearchInput } from '../shared/components/SearchInput'
import { Card } from '../shared/components/ui/Card'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { contactGroups, contacts, friendRequests } from '../shared/mock/data'

export function ContactsPage() {
  const { t } = useLanguage()
  const [tab, setTab] = useState<ContactsTab>('all')
  const [keyword, setKeyword] = useState('')
  const [pendingRequests, setPendingRequests] = useState(friendRequests)

  const normalizedKeyword = keyword.trim().toLowerCase()

  const filteredContacts = useMemo(
    () =>
      contacts.filter(
        (item) =>
          item.displayName.toLowerCase().includes(normalizedKeyword) ||
          item.subtitle.toLowerCase().includes(normalizedKeyword),
      ),
    [normalizedKeyword],
  )

  const filteredRequests = useMemo(
    () =>
      pendingRequests.filter(
        (item) =>
          item.displayName.toLowerCase().includes(normalizedKeyword) ||
          item.subtitle.toLowerCase().includes(normalizedKeyword),
      ),
    [normalizedKeyword, pendingRequests],
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
    addFriend: t('contacts.actions.addFriend'),
    more: t('contacts.actions.more'),
    online: t('contacts.status.online'),
    busy: t('contacts.status.busy'),
    offline: t('contacts.status.offline'),
  }

  return (
    <section className='panel-page contacts-page'>
      <h2>{t('pages.contacts.title')}</h2>
      <p className='panel-subtitle'>{t('pages.contacts.subtitle')}</p>

      <div className='contacts-toolbar'>
        <SearchInput placeholder={t('contacts.searchPlaceholder')} value={keyword} onChange={setKeyword} />
        <ContactsTabs
          labels={{
            all: t('contacts.tabs.all'),
            requests: t('contacts.tabs.requests'),
            groups: t('contacts.tabs.groups'),
          }}
          onChange={setTab}
          value={tab}
        />
      </div>

      {tab === 'all' ? (
        filteredContacts.length > 0 ? (
          <ContactList items={filteredContacts} labels={labels} />
        ) : (
          <EmptyState title={t('contacts.empty.noContactsTitle')} description={t('contacts.empty.noContactsDesc')} />
        )
      ) : null}

      {tab === 'requests' ? (
        filteredRequests.length > 0 ? (
          <FriendRequestList
            items={filteredRequests}
            labels={{
              mutualFriends: t('contacts.requests.mutualFriends'),
              accept: t('contacts.requests.accept'),
              decline: t('contacts.requests.decline'),
            }}
            onAccept={(id) => setPendingRequests((prev) => prev.filter((item) => item.id !== id))}
            onDecline={(id) => setPendingRequests((prev) => prev.filter((item) => item.id !== id))}
          />
        ) : (
          <EmptyState title={t('contacts.empty.noRequestsTitle')} description={t('contacts.empty.noRequestsDesc')} />
        )
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
    </section>
  )
}
