import { Users, Cloud } from 'lucide-react'

type UserAvatarProps = {
  name: string
  size?: 'sm' | 'md' | 'lg'
  imageUrl?: string | null
  className?: string
  isGroup?: boolean
  isCloud?: boolean
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

export function UserAvatar({ name, size = 'md', imageUrl, className, isGroup, isCloud }: UserAvatarProps) {
  const mergedClassName = `user-avatar ${sizeClass[size]}${className ? ` ${className}` : ''}`

  if (isCloud) {
    const iconSize = size === 'sm' ? 16 : size === 'lg' ? 40 : 24
    return (
      <span className={`${mergedClassName} flex items-center justify-center bg-blue-500 text-white`} style={{ backgroundColor: '#005ae0' }}>
        <Cloud size={iconSize} />
      </span>
    )
  }

  if (imageUrl) {
    return (
      <span className={mergedClassName}>
        <img alt={name} className='user-avatar-image' src={imageUrl} />
      </span>
    )
  }

  if (isGroup) {
    const iconSize = size === 'sm' ? 14 : size === 'lg' ? 40 : 20
    return (
      <span className={`${mergedClassName} flex items-center justify-center bg-gray-200`}>
        <Users size={iconSize} className="text-gray-500" />
      </span>
    )
  }

  return <span className={mergedClassName}>{getFallback(name)}</span>
}
