type IconName =
  | 'search'
  | 'chevronDown'
  | 'chat'
  | 'bell'
  | 'user'
  | 'addressBook'
  | 'userPlus'
  | 'userPlusZalo'
  | 'group'
  | 'groupPlusZalo'
  | 'settings'
  | 'send'
  | 'logout'
  | 'phone'
  | 'video'
  | 'info'
  | 'attach'
  | 'smile'
  | 'image'
  | 'file'
  | 'more'
  | 'spark'
  | 'bot'
  | 'database'
  | 'layoutDashboard'
  | 'help'
  | 'close'
  | 'play'
  | 'layoutSidebar'
  | 'checkSquare'
  | 'capture'
  | 'cloud'
  | 'briefcase'
  | 'folder'
  | 'pin'
  | 'copy'
  | 'chevronUp'
  | 'unfold_more'
  | 'mic'
  | 'micOff'
  | 'phoneOff'
  | 'cameraOff'
  | 'clock'
  | 'heart'
  | 'heartFill'
  | 'pause'
  | 'volumeOff'
  | 'volume'

type IconProps = {
  name: IconName
  className?: string
  size?: number | string
}

export function Icon({ name, className, size = 24 }: IconProps) {
  const commonProps = {
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    className,
    width: size,
    height: size,
    'aria-hidden': true,
  }

  if (name === 'search') {
    return (
      <svg {...commonProps}>
        <circle cx='11' cy='11' r='7' />
        <line x1='20' y1='20' x2='16.65' y2='16.65' />
      </svg>
    )
  }

  if (name === 'chevronDown') {
    return (
      <svg {...commonProps}>
        <polyline points='6 9 12 15 18 9' />
      </svg>
    )
  }

  if (name === 'chat') {
    return (
      <svg {...commonProps}>
        <path d='M21 11.5a8.5 8.5 0 0 1-8.5 8.5c-1.4 0-2.72-.34-3.88-.95L3 21l1.95-5.28A8.47 8.47 0 0 1 3.5 11.5 8.5 8.5 0 0 1 12 3a8.5 8.5 0 0 1 9 8.5Z' />
      </svg>
    )
  }


  if (name === 'play') {
    return (
      <svg {...commonProps}>
        <path d='M8 5v14l11-7Z' />
      </svg>
    )
  }
  if (name === 'volumeOff') {
    return (
      <svg {...commonProps}>
        <path d='M11 5 6.5 8.5H3v7h3.5L11 19V5Z' />
        <path d='M15 9a4 4 0 0 1 0 6' />
        <path d='M17.5 6.5a7 7 0 0 1 0 11' />
        <line x1='4' y1='4' x2='20' y2='20' />
      </svg>
    )
  }
  if (name === 'bell') {
    return (
      <svg {...commonProps}>
        <path d='M15 18H5l1.2-1.2c.5-.5.8-1.18.8-1.9V10a5 5 0 0 1 10 0v4.9c0 .72.29 1.4.8 1.9L19 18h-4' />
        <path d='M10 20a2 2 0 0 0 4 0' />
      </svg>
    )
  }

  if (name === 'user') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='8' r='4' />
        <path d='M5.5 20a6.5 6.5 0 0 1 13 0' />
      </svg>
    )
  }

  if (name === 'addressBook') {
    return (
      <svg {...commonProps}>
        <rect x='4' y='4.5' width='16' height='15' rx='2.4' />
        <path d='M8 4.5v15' />
        <circle cx='13.6' cy='10.3' r='2' />
        <path d='M11.4 15a3.4 3.4 0 0 1 4.4 0' />
        <path d='M17.2 9.2h1.3' />
        <path d='M17.2 12.1h1.3' />
      </svg>
    )
  }

  if (name === 'userPlus') {
    return (
      <svg {...commonProps}>
        <circle cx='10' cy='8' r='3.5' />
        <path d='M4.8 19a5.2 5.2 0 0 1 10.4 0' />
        <path d='M18 8v6' />
        <path d='M15 11h6' />
      </svg>
    )
  }

  if (name === 'userPlusZalo') {
    return (
      <svg {...commonProps}>
        <circle cx='9' cy='11' r='3.5' />
        <path d='M3 20a6 6 0 0 1 12 0' />
        <path d='M16 6h5' strokeWidth='2' />
        <path d='M18.5 3.5v5' strokeWidth='2' />
      </svg>
    )
  }

  if (name === 'group') {
    return (
      <svg {...commonProps}>
        <circle cx='9' cy='9' r='3' />
        <circle cx='16.5' cy='10' r='2.5' />
        <path d='M3.8 19a5.2 5.2 0 0 1 10.4 0' />
        <path d='M14 19a4 4 0 0 1 6 0' />
      </svg>
    )
  }

  if (name === 'groupPlusZalo') {
    return (
      <svg {...commonProps}>
        <circle cx='8' cy='12' r='3' />
        <path d='M2 21a6 6 0 0 1 12 0' />
        <circle cx='15' cy='13' r='2.5' />
        <path d='M10 21a5 5 0 0 1 10 0' />
        <path d='M16 5h5' strokeWidth='2' />
        <path d='M18.5 2.5v5' strokeWidth='2' />
      </svg>
    )
  }

  if (name === 'settings') {
    return (
      <svg {...commonProps}>
        <path d='M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Z' />
        <path d='M18.9 13.8c.08-.58.08-1.02 0-1.6l2-1.55-2-3.46-2.36.95a7.2 7.2 0 0 0-1.38-.8L14.8 4.8h-5.6l-.36 2.54c-.5.2-.96.47-1.38.8L5.1 7.19l-2 3.46 2 1.55a6.4 6.4 0 0 0 0 1.6l-2 1.55 2 3.46 2.36-.95c.42.33.88.6 1.38.8l.36 2.54h5.6l.36-2.54c.5-.2.96-.47 1.38-.8l2.36.95 2-3.46-2-1.55Z' />
      </svg>
    )
  }

  if (name === 'send') {
    return (
      <svg {...commonProps}>
        <path d='m22 2-7 20-4-9-9-4Z' />
        <path d='M22 2 11 13' />
      </svg>
    )
  }

  if (name === 'logout') {
    return (
      <svg {...commonProps}>
        <path d='M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4' />
        <polyline points='16 17 21 12 16 7' />
        <line x1='21' y1='12' x2='9' y2='12' />
      </svg>
    )
  }

  if (name === 'phone') {
    return (
      <svg {...commonProps}>
        <path d='M5.3 3.9h3.5l1.3 3.5-2 1.7a14.2 14.2 0 0 0 6.8 6.8l1.7-2 3.5 1.3v3.5a1.6 1.6 0 0 1-1.7 1.6 16.5 16.5 0 0 1-15-15A1.6 1.6 0 0 1 5.3 3.9Z' />
      </svg>
    )
  }

  if (name === 'video') {
    return (
      <svg {...commonProps}>
        <rect x='3' y='6' width='13' height='12' rx='2.5' />
        <path d='m16 10 5-3v10l-5-3Z' />
      </svg>
    )
  }

  if (name === 'info') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='12' r='9' />
        <path d='M12 10v6' />
        <path d='M12 7.2h.01' />
      </svg>
    )
  }

  if (name === 'attach') {
    return (
      <svg {...commonProps}>
        <path d='m14.5 6.5-6.6 6.6a3 3 0 0 0 4.2 4.2l7.1-7.1a5 5 0 1 0-7-7l-7.1 7.1' />
      </svg>
    )
  }

  if (name === 'smile') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='12' r='9' />
        <path d='M9 15a4.4 4.4 0 0 0 6 0' />
        <path d='M9 10h.01' />
        <path d='M15 10h.01' />
      </svg>
    )
  }

  if (name === 'image') {
    return (
      <svg {...commonProps}>
        <rect x='3' y='5' width='18' height='14' rx='2.5' />
        <circle cx='9' cy='10' r='1.2' />
        <path d='m21 15-4.5-4.5L8 19' />
      </svg>
    )
  }

  if (name === 'file') {
    return (
      <svg {...commonProps}>
        <path d='M7 3h7l5 5v13H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z' />
        <path d='M14 3v5h5' />
      </svg>
    )
  }

  if (name === 'more') {
    return (
      <svg {...commonProps}>
        <circle cx='6' cy='12' r='1.3' />
        <circle cx='12' cy='12' r='1.3' />
        <circle cx='18' cy='12' r='1.3' />
      </svg>
    )
  }

  if (name === 'layoutDashboard') {
    return (
      <svg {...commonProps}>
        <rect x='3.5' y='4' width='7' height='7' rx='1.8' />
        <rect x='13.5' y='4' width='7' height='4.8' rx='1.6' />
        <rect x='13.5' y='11.8' width='7' height='8.2' rx='1.8' />
        <rect x='3.5' y='14' width='7' height='6' rx='1.8' />
      </svg>
    )
  }

  if (name === 'database') {
    return (
      <svg {...commonProps}>
        <ellipse cx='12' cy='5' rx='8' ry='3' />
        <path d='M4 5v7c0 1.66 3.58 3 8 3s8-1.34 8-3V5' />
        <path d='M4 12v7c0 1.66 3.58 3 8 3s8-1.34 8-3v-7' />
      </svg>
    )
  }

  if (name === 'help') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='12' r='9' />
        <path d='M12 18.5v.5' />
        <path d='M9 8.5a3 3 0 1 1 3.15 2.95' />
      </svg>
    )
  }

  if (name === 'close') {
    return (
      <svg {...commonProps}>
        <line x1='18' y1='6' x2='6' y2='18' />
        <line x1='6' y1='6' x2='18' y2='18' />
      </svg>
    )
  }

  if (name === 'layoutSidebar') {
    return (
      <svg {...commonProps}>
        <rect x='3.5' y='4.5' width='17' height='15' rx='2.5' />
        <line x1='10' y1='4.5' x2='10' y2='19.5' />
        <line x1='13.5' y1='9' x2='18' y2='9' />
        <line x1='13.5' y1='12' x2='18' y2='12' />
        <line x1='13.5' y1='15' x2='16.8' y2='15' />
      </svg>
    )
  }

  if (name === 'checkSquare') {
    return (
      <svg {...commonProps}>
        <polyline points='9 11 12 14 22 4' />
        <path d='M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11' />
      </svg>
    )
  }

  if (name === 'capture') {
    return (
      <svg {...commonProps}>
        <rect x='4' y='4' width='16' height='16' rx='2' strokeDasharray='3 2' />
        <path d='M10 12h4m-2-2v4' />
      </svg>
    )
  }

  if (name === 'cloud') {
    return (
      <svg {...commonProps}>
        <path d='M17.5 19c2.5 0 4.5-2 4.5-4.5 0-2.3-1.7-4.2-3.9-4.5-1.1-3.6-4.5-6-8.1-6-3.3 0-6.2 2-7.4 5-2.1.2-3.8 2-3.8 4.2C0 16.5 2 18.5 4.5 18.5h13' />
        <path d='M9 11h3l-2.5 3h3' strokeWidth='1.2' />
      </svg>
    )
  }

  if (name === 'briefcase') {
    return (
      <svg {...commonProps}>
        <rect x='2' y='7' width='20' height='14' rx='2' />
        <path d='M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16' />
      </svg>
    )
  }

  if (name === 'folder') {
    return (
      <svg {...commonProps}>
        <path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />
      </svg>
    )
  }

  if (name === 'pin') {
    return (
      <svg {...commonProps}>
        <line x1='12' x2='12' y1='17' y2='22' />
        <path d='M5 17h14v-1.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6a3 3 0 0 0-3-3 3 3 0 0 0-3 3v4.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24Z' />
      </svg>
    )
  }

  if (name === 'copy') {
    return (
      <svg {...commonProps}>
        <rect x='9' y='9' width='13' height='13' rx='2' ry='2' />
        <path d='M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1' />
      </svg>
    )
  }

  if (name === 'chevronUp') {
    return (
      <svg {...commonProps}>
        <polyline points='18 15 12 9 6 15' />
      </svg>
    )
  }

  if (name === 'unfold_more') {
    return (
      <svg {...commonProps}>
        <polyline points='7 15 12 20 17 15' />
        <polyline points='7 9 12 4 17 9' />
      </svg>
    )
  }

  if (name === 'mic') {
    return (
      <svg {...commonProps}>
        <path d='M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3Z' />
        <path d='M19 10v2a7 7 0 0 1-14 0v-2' />
        <line x1='12' y1='19' x2='12' y2='23' />
        <line x1='8' y1='23' x2='16' y2='23' />
      </svg>
    )
  }

  if (name === 'micOff') {
    return (
      <svg {...commonProps}>
        <line x1='1' y1='1' x2='23' y2='23' />
        <path d='M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6' />
        <path d='M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23' />
        <line x1='12' y1='19' x2='12' y2='23' />
        <line x1='8' y1='23' x2='16' y2='23' />
      </svg>
    )
  }

  if (name === 'phoneOff') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='12' r='10' fill='#ff4d4f' stroke='none' />
        <path d='M7 12h10' stroke='white' strokeWidth='2.5' />
      </svg>
    )
  }

  if (name === 'cameraOff') {
    return (
      <svg {...commonProps}>
        <line x1='1' y1='1' x2='23' y2='23' />
        <path d='M16 16v1.25c0 .41-.34.75-.75.75H3.75c-.41 0-.75-.34-.75-.75V7c0-.41.34-.75.75-.75H5m3.75 0h6.5c.41 0 .75.34.75.75V11' />
        <path d='m16 10 5-3v10l-2.43-1.46' />
      </svg>
    )
  }

  if (name === 'clock') {
    return (
      <svg {...commonProps}>
        <circle cx="12" cy="12" r="10" />
        <polyline points="12 6 12 12 16 14" />
      </svg>
    )
  }

  if (name === 'heart') {
    return (
      <svg {...commonProps}>
        <path d='M20.8 4.6c-1.8-1.7-4.6-1.8-6.5-.2L12 6.5l-2.3-2.1C7.9 2.8 5.1 2.9 3.3 4.6A5.6 5.6 0 0 0 3 9c0 3.3 2.7 6 6 9l3 2 3-2c3.3-3 6-5.7 6-9 0-1.6-.6-3.1-1.2-3.4z' strokeWidth='1.6' fill='none' />
      </svg>
    )
  }

  if (name === 'heartFill') {
    return (
      <svg {...commonProps}>
        <path d='M20.8 4.6c-1.8-1.7-4.6-1.8-6.5-.2L12 6.5l-2.3-2.1C7.9 2.8 5.1 2.9 3.3 4.6A5.6 5.6 0 0 0 3 9c0 3.3 2.7 6 6 9l3 2 3-2c3.3-3 6-5.7 6-9 0-1.6-.6-3.1-1.2-3.4z' fill='currentColor' stroke='none' />
      </svg>
    )
  }

  if (name === 'bot') {
    return (
      <svg {...commonProps}>
        <rect x='5' y='7' width='14' height='11' rx='3' />
        <path d='M12 7V4' />
        <circle cx='9.5' cy='12.5' r='1' fill='currentColor' stroke='none' />
        <circle cx='14.5' cy='12.5' r='1' fill='currentColor' stroke='none' />
        <path d='M9 16h6' />
        <path d='M4 11h1' />
        <path d='M19 11h1' />
      </svg>
    )
  }

  if (name === 'pause') {
    return (
      <svg {...commonProps}>
        <rect x='6.5' y='4.5' width='4' height='15' rx='1.2' />
        <rect x='13.5' y='4.5' width='4' height='15' rx='1.2' />
      </svg>
    )
  }

  if (name === 'volume') {
    return (
      <svg {...commonProps}>
        <path d='M11 5 6.5 9H3v6h3.5L11 19V5Z' />
        <path d='M15 9a4 4 0 0 1 0 6' />
        <path d='M17.8 6.2a8 8 0 0 1 0 11.6' />
      </svg>
    )
  }

  return (
    <svg {...commonProps}>
      <path d='m12 3 2.2 4.7L19 8.3l-3.5 3.4.9 4.9L12 14.1 7.6 16.6l.9-4.9L5 8.3l4.8-.6L12 3Z' />
    </svg>
  )
}
