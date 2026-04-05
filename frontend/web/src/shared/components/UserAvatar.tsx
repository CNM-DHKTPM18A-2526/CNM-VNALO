type UserAvatarProps = {
  name: string
  size?: 'sm' | 'md' | 'lg'
  imageUrl?: string | null
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

export function UserAvatar({ name, size = 'md', imageUrl }: UserAvatarProps) {
  if (imageUrl) {
    return (
      <span className={`user-avatar ${sizeClass[size]}`}>
        <img alt={name} className='user-avatar-image' src={imageUrl} />
      </span>
    )
  }

  return <span className={`user-avatar ${sizeClass[size]}`}>{getFallback(name)}</span>
}
