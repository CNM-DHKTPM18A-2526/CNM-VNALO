import type { HTMLAttributes, ReactNode } from 'react'

type CardProps = HTMLAttributes<HTMLElement> & {
  as?: 'article' | 'section' | 'div'
  children: ReactNode
}

export function Card({ as = 'div', className = '', children, ...props }: CardProps) {
  const Tag = as
  const mergedClassName = ['ui-card', className].filter(Boolean).join(' ')

  return (
    <Tag className={mergedClassName} {...props}>
      {children}
    </Tag>
  )
}
