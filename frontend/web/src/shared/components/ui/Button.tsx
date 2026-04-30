import type { ButtonHTMLAttributes } from 'react'

type ButtonVariant = 'primary' | 'ghost' | 'subtle'

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant
  className?: string
  fullWidth?: boolean
}

export function Button({ 
  variant = 'primary', 
  className = '', 
  type = 'button', 
  fullWidth = false,
  ...props 
}: ButtonProps) {
  const variantClass = `btn btn-${variant}`
  const widthClass = fullWidth ? 'w-full' : ''
  const mergedClassName = [variantClass, widthClass, className].filter(Boolean).join(' ')

  return <button type={type} className={mergedClassName} {...props} />
}
