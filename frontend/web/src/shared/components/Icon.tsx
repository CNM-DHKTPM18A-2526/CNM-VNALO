type IconName =
  | 'search'
  | 'chevronDown'
  | 'chat'
  | 'bell'
  | 'user'
  | 'addressBook'
  | 'userPlus'
  | 'group'
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
  | 'database'
  | 'help'
  | 'close'
  | 'layoutSidebar'

type IconProps = {
  name: IconName
  className?: string
}

export function Icon({ name, className }: IconProps) {
  const commonProps = {
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    className,
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

  if (name === 'settings') {
    return (
      <svg {...commonProps}>
        <circle cx='12' cy='12' r='3' />
        <path d='M19.4 15a1 1 0 0 0 .2 1.1l.03.03a1.5 1.5 0 0 1-2.12 2.12l-.03-.03a1 1 0 0 0-1.1-.2 1 1 0 0 0-.6.92V19a1.5 1.5 0 0 1-3 0v-.06a1 1 0 0 0-.6-.92 1 1 0 0 0-1.1.2l-.03.03a1.5 1.5 0 1 1-2.12-2.12l.03-.03a1 1 0 0 0 .2-1.1 1 1 0 0 0-.92-.6H5a1.5 1.5 0 0 1 0-3h.06a1 1 0 0 0 .92-.6 1 1 0 0 0-.2-1.1l-.03-.03a1.5 1.5 0 1 1 2.12-2.12l.03.03a1 1 0 0 0 1.1.2h0a1 1 0 0 0 .6-.92V5a1.5 1.5 0 0 1 3 0v.06a1 1 0 0 0 .6.92h0a1 1 0 0 0 1.1-.2l.03-.03a1.5 1.5 0 1 1 2.12 2.12l-.03.03a1 1 0 0 0-.2 1.1v0a1 1 0 0 0 .92.6H19a1.5 1.5 0 0 1 0 3h-.06a1 1 0 0 0-.92.6Z' />
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

  return (
    <svg {...commonProps}>
      <path d='m12 3 2.2 4.7L19 8.3l-3.5 3.4.9 4.9L12 14.1 7.6 16.6l.9-4.9L5 8.3l4.8-.6L12 3Z' />
    </svg>
  )
}
