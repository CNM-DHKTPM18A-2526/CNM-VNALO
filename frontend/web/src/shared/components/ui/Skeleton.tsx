type SkeletonProps = {
  className?: string
}

export function Skeleton({ className = '' }: SkeletonProps) {
  const mergedClassName = ['ui-skeleton', className].filter(Boolean).join(' ')

  return <span className={mergedClassName} aria-hidden />
}
