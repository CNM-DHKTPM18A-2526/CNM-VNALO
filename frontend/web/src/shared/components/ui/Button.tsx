import type { ButtonHTMLAttributes } from 'react'

type ButtonVariant = 'primary' | 'ghost' | 'subtle'

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant
  className?: string
}

export function Button({ variant = 'primary', className = '', type = 'button', ...props }: ButtonProps) {
  const variantClass = `btn btn-${variant}`
  const mergedClassName = [variantClass, className].filter(Boolean).join(' ')

  return <button type={type} className={mergedClassName} {...props} />
}
