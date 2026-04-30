import { useEffect } from 'react'
import { createPortal } from 'react-dom'

type ModalVariant = 'default' | 'image' | 'confirm' | 'none' | 'custom'

type ModalProps = {
  isOpen: boolean
  title: string
  description?: string
  onClose: () => void
  children: React.ReactNode
  footer?: React.ReactNode
  closeAriaLabel?: string
  variant?: ModalVariant
}

export function Modal({
  isOpen,
  title,
  description,
  onClose,
  children,
  footer,
  closeAriaLabel,
  variant = 'default',
}: ModalProps) {
  useEffect(() => {
    if (!isOpen) {
      return
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [isOpen, onClose])

  if (!isOpen) {
    return null
  }

  return createPortal(
    <div className='modal-overlay' onMouseDown={onClose}>
      <div
        aria-modal='true'
        className={`modal-card${variant === 'image' ? ' modal-card-image' : ''}`}
        onMouseDown={(event) => event.stopPropagation()}
        role='dialog'
      >
        <div className='modal-header'>
          <div>
            <h3>{title}</h3>
            {description ? <p>{description}</p> : null}
          </div>
          <button aria-label={closeAriaLabel ?? 'Close'} className='modal-close-btn' onClick={onClose} type='button'>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M1 1L13 13M1 13L13 1" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </button>
        </div>
        <div className={
          variant === 'confirm' ? 'modal-body-confirm' : 
          variant === 'none' ? 'p-0 overflow-hidden' :
          variant === 'custom' ? '' :
          'modal-body'
        }>
          {children}
        </div>
        {footer ? <div className='modal-footer'>{footer}</div> : null}
      </div>
    </div>,
    document.body,
  )
}
