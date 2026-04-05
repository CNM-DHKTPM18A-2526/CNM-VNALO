import { SegmentedControl } from '../../../shared/components/SettingsControls'

export type ContactsTab = 'all' | 'requests' | 'groups'

type ContactsTabsProps = {
  value: ContactsTab
  onChange: (tab: ContactsTab) => void
  labels: {
    all: string
    requests: string
    groups: string
  }
}

export function ContactsTabs({ value, onChange, labels }: ContactsTabsProps) {
  return (
    <SegmentedControl
      options={[
        { label: labels.all, value: 'all' },
        { label: labels.requests, value: 'requests' },
        { label: labels.groups, value: 'groups' },
      ]}
      value={value}
      onChange={(next) => onChange(next as ContactsTab)}
    />
  )
}
