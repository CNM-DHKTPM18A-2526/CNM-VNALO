import { useState } from 'react'

import { Icon } from '../../../shared/components/Icon'
import { Button } from '../../../shared/components/ui/Button'
import { TextField } from '../../../shared/components/ui/TextField'

type MessageInputProps = {
  onSend: (message: string) => void
  placeholder?: string
  disabled?: boolean
}

export function MessageInput({ onSend, placeholder = 'Nhập tin nhắn...', disabled = false }: MessageInputProps) {
  const [message, setMessage] = useState('')

  const submitMessage = () => {
    const trimmed = message.trim()

    if (!trimmed) {
      return
    }

    if (disabled) {
      return
    }

    onSend(trimmed)
    setMessage('')
  }

  return (
    <footer className='message-input'>
      <TextField
        className='message-input-field'
        placeholder={placeholder}
        value={message}
        disabled={disabled}
        onChange={(event) => setMessage(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            submitMessage()
          }
        }}
        trailingSlot={
          <Button className='message-send-btn' onClick={submitMessage} type='button' disabled={disabled}>
            <Icon name='send' />
          </Button>
        }
      />
    </footer>
  )
}
