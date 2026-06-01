import { Icon } from './Icon'

type SearchInputProps = {
  placeholder?: string
  value: string
  onChange: (value: string) => void
  className?: string
}

export function SearchInput({ placeholder = 'Tìm kiếm...', value, onChange, className }: SearchInputProps) {
  return (
    <label className={className ? `search-input ${className}` : 'search-input'} aria-label='Tìm kiếm hội thoại'>
      <span aria-hidden className='search-input-icon'>
        <Icon name='search' />
      </span>
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
      />
    </label>
  )
}
