import { Icon } from './Icon'

type SearchInputProps = {
  placeholder?: string
  value: string
  onChange: (value: string) => void
}

export function SearchInput({ placeholder = 'Tìm kiếm...', value, onChange }: SearchInputProps) {
  return (
    <label className='search-input' aria-label='Tìm kiếm hội thoại'>
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
