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

    return (
      <span className={`${mergedClassName} relative overflow-hidden bg-gray-100`}>
        {/* 2 Members: Overlapping offset */}
        {count === 2 && (
          <>
            <img src={avatars[0]!} className="absolute top-0 left-0 w-[65%] h-[65%] rounded-full border-2 border-white object-cover z-10" />
            <img src={avatars[1]!} className="absolute bottom-0 right-0 w-[65%] h-[65%] rounded-full border-2 border-white object-cover" />
          </>
        )}

        {/* 3 Members: 1 top center, 2 bottom side-by-side */}
        {count === 3 && extraCount === 0 && (
          <>
            <img src={avatars[0]!} className="absolute top-0 left-1/2 -translate-x-1/2 w-[55%] h-[55%] rounded-full border-2 border-white object-cover z-20" />
            <img src={avatars[1]!} className="absolute bottom-0 left-0 w-[55%] h-[55%] rounded-full border-2 border-white object-cover z-10" />
            <img src={avatars[2]!} className="absolute bottom-0 right-0 w-[55%] h-[55%] rounded-full border-2 border-white object-cover" />
          </>
        )}

        {/* 4+ Members: 3 Avatars + Badge */}
        {extraCount > 0 && (
          <div className="grid grid-cols-2 grid-rows-2 w-full h-full gap-0.5 p-0.5">
            <img src={avatars[0]!} className="w-full h-full rounded-full border border-white object-cover" />
            <img src={avatars[1]!} className="w-full h-full rounded-full border border-white object-cover" />
            <img src={avatars[2]!} className="w-full h-full rounded-full border border-white object-cover" />
            <div className="w-full h-full rounded-full bg-gray-500/80 flex items-center justify-center text-white border border-white">
               <span className="text-[10px] font-bold">+{extraCount + (avatars.length === 3 ? 0 : 4 - avatars.length)}</span>
            </div>
          </div>
        )}
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
