import { useMemo } from 'react'

import { Icon } from './Icon'
import { useTheme } from '../contexts/ThemeContext'

type ToggleSwitchProps = {
  enabled: boolean
  onChange: (enabled: boolean) => void
  disabled?: boolean
}

export function ToggleSwitch({ enabled, onChange, disabled = false }: ToggleSwitchProps) {
  return (
    <button
      role='switch'
      aria-checked={enabled}
      className={`toggle-switch ${enabled ? 'toggle-on' : 'toggle-off'}`}
      onClick={() => onChange(!enabled)}
      disabled={disabled}
      type='button'
    >
      <span className='toggle-thumb' />
    </button>
  )
}

type ThemeSwitcherProps = {
  onChange?: (theme: 'light' | 'dark') => void
}

export function ThemeSwitcher({ onChange }: ThemeSwitcherProps) {
  const { theme, toggleTheme } = useTheme()

  const handleToggle = () => {
    toggleTheme()
    onChange?.(theme === 'light' ? 'dark' : 'light')
  }

  return (
    <button
      className='theme-switcher'
      onClick={handleToggle}
      title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}
      type='button'
      aria-label={`Switch theme (current: ${theme})`}
    >
      {theme === 'light' ? <Icon name='spark' /> : <Icon name='bell' />}
    </button>
  )
}

type SegmentedControlProps = {
  options: Array<{ label: string; value: string }>
  value: string
  onChange: (value: string) => void
  disabled?: boolean
}

export function SegmentedControl({ options, value, onChange, disabled = false }: SegmentedControlProps) {
  const isSelected = useMemo(
    () => (optValue: string) => optValue === value,
    [value]
  )

  return (
    <div className='segmented-control' role='group'>
      {options.map((option) => (
        <button
          key={option.value}
          className={`segmented-option ${isSelected(option.value) ? 'selected' : ''}`}
          onClick={() => onChange(option.value)}
          disabled={disabled}
          type='button'
          role='radio'
          aria-checked={isSelected(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  )
}
