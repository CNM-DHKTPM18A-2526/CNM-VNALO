type UserAvatarProps = {
  name: string
  size?: 'sm' | 'md' | 'lg'
}

const sizeClass: Record<NonNullable<UserAvatarProps['size']>, string> = {
  sm: 'avatar-sm',
  md: 'avatar-md',
  lg: 'avatar-lg',
}

function getFallback(name: string) {
  return name
    .split(' ')
    .slice(0, 2)
    .map((chunk) => chunk[0]?.toUpperCase() ?? '')
    .join('')
}

export function UserAvatar({ name, size = 'md' }: UserAvatarProps) {
  return <span className={`user-avatar ${sizeClass[size]}`}>{getFallback(name)}</span>
}
