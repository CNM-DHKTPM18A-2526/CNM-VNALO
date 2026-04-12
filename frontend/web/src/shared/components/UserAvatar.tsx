type UserAvatarProps = {
  name: string
  size?: 'sm' | 'md' | 'lg'
  imageUrl?: string | null
  className?: string
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

export function UserAvatar({ name, size = 'md', imageUrl, className }: UserAvatarProps) {
  const mergedClassName = `user-avatar ${sizeClass[size]}${className ? ` ${className}` : ''}`

  if (imageUrl) {
    return (
      <span className={mergedClassName}>
        <img alt={name} className='user-avatar-image' src={imageUrl} />
      </span>
    )
  }

  return <span className={mergedClassName}>{getFallback(name)}</span>
}
