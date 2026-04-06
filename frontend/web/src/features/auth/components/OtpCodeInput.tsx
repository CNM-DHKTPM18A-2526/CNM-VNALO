type OtpCodeInputProps = {
  value: string
  onChange: (value: string) => void
  disabled?: boolean
  minLength?: number
  maxLength?: number
  autoFocus?: boolean
  label?: string
  placeholder?: string
  helperText?: string
}

export function OtpCodeInput({
  value,
  onChange,
  disabled = false,
  minLength = 6,
  maxLength = 6,
  autoFocus = false,
  label = 'Mã OTP',
  placeholder = 'Nhập mã OTP',
  helperText,
}: OtpCodeInputProps) {
  const safeMinLength = Math.max(6, minLength)
  const safeMaxLength = Math.min(6, Math.max(safeMinLength, maxLength))

  return (
    <label className='auth-otp-input'>
      {label}
      <input
        type='text'
        inputMode='numeric'
        pattern='[0-9]*'
        placeholder={placeholder}
        value={value}
        onChange={(event) => onChange(event.target.value.replace(/\D/g, '').slice(0, safeMaxLength))}
        disabled={disabled}
        maxLength={safeMaxLength}
        autoComplete='one-time-code'
        autoFocus={autoFocus}
      />
      <span className='auth-helper-text'>{helperText ?? `Mã gồm ${safeMaxLength} chữ số.`}</span>
    </label>
  )
}
