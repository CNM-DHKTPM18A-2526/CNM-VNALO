import type { InputHTMLAttributes, ReactNode } from 'react'

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  leadingIcon?: ReactNode
  trailingSlot?: ReactNode
  wrapperClassName?: string
}

export function TextField({
  leadingIcon,
  trailingSlot,
  wrapperClassName = '',
  className = '',
  ...props
}: TextFieldProps) {
  const wrapper = ['ui-textfield', wrapperClassName].filter(Boolean).join(' ')
  const inputClass = ['ui-textfield-input', className].filter(Boolean).join(' ')

  return (
    <label className={wrapper}>
      {leadingIcon ? <span className='ui-textfield-leading'>{leadingIcon}</span> : null}
      <input {...props} className={inputClass} />
      {trailingSlot ? <span className='ui-textfield-trailing'>{trailingSlot}</span> : null}
    </label>
  )
}
