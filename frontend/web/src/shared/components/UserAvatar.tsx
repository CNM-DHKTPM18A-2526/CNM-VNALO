import { Users, Cloud } from 'lucide-react'
import { resolveMediaUrl } from '../../utils/mediaUtils'

type UserAvatarProps = {
  name: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  imageUrl?: string | null
  className?: string
  isGroup?: boolean
  isCloud?: boolean
  // New props for collage
  memberAvatars?: (string | null)[]
  extraCount?: number
}

const sizeClass: Record<NonNullable<UserAvatarProps['size']>, string> = {
  sm: 'avatar-sm',
  md: 'avatar-md',
  lg: 'avatar-lg',
  xl: 'avatar-xl',
}

function getFallback(name: string) {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((chunk) => chunk[0]?.toUpperCase() ?? '')
    .join('')
}

export function UserAvatar({ 
  name, 
  size = 'md', 
  imageUrl, 
  className, 
  isGroup, 
  isCloud,
  memberAvatars = [],
  extraCount = 0
}: UserAvatarProps) {
  const mergedClassName = `user-avatar ${sizeClass[size]}${className ? ` ${className}` : ''}`
  const resolvedImageUrl = resolveMediaUrl(imageUrl);

  if (isCloud) {
    const iconSize = size === 'sm' ? 16 : size === 'lg' ? 40 : size === 'xl' ? 64 : 24
    return (
      <span className={`${mergedClassName} flex items-center justify-center bg-blue-500 text-white`} style={{ backgroundColor: '#005ae0' }}>
        <Cloud size={iconSize} />
      </span>
    )
  }

  // Use provided group image if available
  if (resolvedImageUrl) {
    return (
      <span className={mergedClassName}>
        <img alt={name} className='user-avatar-image object-cover w-full h-full' src={resolvedImageUrl} />
      </span>
    )
  }

  // COLLAGE LOGIC FOR GROUPS
  if (isGroup && memberAvatars && memberAvatars.length >= 2) {
    const avatars = memberAvatars.filter(Boolean).map(a => resolveMediaUrl(a)).slice(0, 3);
    const count = avatars.length;
    const layoutCount = extraCount > 0 ? 4 : Math.max(2, Math.min(count, 3));

    return (
      <span className={`${mergedClassName} relative overflow-hidden group-avatar-collage`}>
        <div className={`group-collage group-collage-${layoutCount}`}>
          {avatars.map((src, i) => (
            <img key={i} src={src!} className={`group-collage-img slot-${i + 1}`} />
          ))}

          {extraCount > 0 && (
            <div className="group-collage-badge slot-4">
              <span className="badge-text">+{extraCount + (avatars.length === 3 ? 0 : 4 - avatars.length)}</span>
            </div>
          )}
        </div>
      </span>
    )
  }

  if (isGroup) {
    const iconSize = size === 'sm' ? 14 : size === 'lg' ? 40 : size === 'xl' ? 64 : 20
    return (
      <span className={`${mergedClassName} flex items-center justify-center bg-gray-200`}>
        <Users size={iconSize} className="text-gray-500" />
      </span>
    )
  }

  return <span className={mergedClassName}>{getFallback(name)}</span>
}
