type IconName =
  | 'search'
  | 'chevronDown'
  | 'chat'
  | 'bell'
  | 'user'
  | 'userPlus'
  | 'group'
  | 'settings'
  | 'send'
  | 'logout'
  | 'spark'

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

  return (
    <svg {...commonProps}>
      <path d='m12 3 2.2 4.7L19 8.3l-3.5 3.4.9 4.9L12 14.1 7.6 16.6l.9-4.9L5 8.3l4.8-.6L12 3Z' />
    </svg>
  )
}
