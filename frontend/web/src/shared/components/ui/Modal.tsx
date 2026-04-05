import { useEffect } from 'react'
import { createPortal } from 'react-dom'

type ModalProps = {
  isOpen: boolean
  title: string
  description?: string
  onClose: () => void
  children: React.ReactNode
  footer?: React.ReactNode
}

export function Modal({ isOpen, title, description, onClose, children, footer }: ModalProps) {
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
        className='modal-card'
        onMouseDown={(event) => event.stopPropagation()}
        role='dialog'
      >
        <div className='modal-header'>
          <div>
            <h3>{title}</h3>
            {description ? <p>{description}</p> : null}
          </div>
          <button className='modal-close-btn' onClick={onClose} type='button'>
            ×
          </button>
        </div>
        <div className='modal-body'>{children}</div>
        {footer ? <div className='modal-footer'>{footer}</div> : null}
      </div>
    </div>,
    document.body,
  )
}
