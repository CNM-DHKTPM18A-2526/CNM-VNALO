import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { sendRegisterOtp, register as registerAccount, updateProfile } from '../features/auth/auth.api'
import type { Gender } from '../features/auth/auth.types'
import { OtpCodeInput } from '../features/auth/components/OtpCodeInput'
import { isNormalizedVietnamPhone, normalizeVietnamPhone } from '../features/auth/phone.util'
import { validatePassword } from '../features/auth/password.util'
import { AuthPageControls } from '../shared/components/AuthPageControls'
import { useLanguage } from '../shared/i18n/LanguageContext'

function PasswordToggleIcon({ visible }: { visible: boolean }) {
  if (visible) {
    return (
      <svg viewBox='0 0 24 24' aria-hidden='true'>
        <path
          d='M3 3l18 18M10.6 10.6a2 2 0 102.8 2.8M9.9 4.2A10.7 10.7 0 0112 4c5.5 0 9.8 4.1 10.9 7.8a1 1 0 010 .4 12 12 0 01-3.6 5.1M6.7 6.7A12.3 12.3 0 001.1 12a1 1 0 000 .4C2.2 16.1 6.5 20.2 12 20.2c1.7 0 3.2-.4 4.6-1.1'
          fill='none'
          stroke='currentColor'
          strokeWidth='1.8'
          strokeLinecap='round'
          strokeLinejoin='round'
        />
      </svg>
    )
  }

  return (
    <svg viewBox='0 0 24 24' aria-hidden='true'>
      <path
        d='M1.1 12.2a1 1 0 010-.4C2.2 8.1 6.5 4 12 4s9.8 4.1 10.9 7.8a1 1 0 010 .4C21.8 15.9 17.5 20 12 20S2.2 15.9 1.1 12.2z'
        fill='none'
        stroke='currentColor'
        strokeWidth='1.8'
      />
      <circle cx='12' cy='12' r='3' fill='none' stroke='currentColor' strokeWidth='1.8' />
    </svg>
  )
}

type RegisterStep = 'form' | 'otp'

type RegisterFormState = {
  displayName: string
  phone: string
  dob: string
  gender: Gender | ''
  password: string
  confirmPassword: string
}

type RegisterErrors = Partial<Record<keyof RegisterFormState | 'otpCode', string>>

function validateRegisterForm(values: RegisterFormState): RegisterErrors {
  const errors: RegisterErrors = {}
  const normalizedPhone = normalizeVietnamPhone(values.phone)
  const todayIso = new Date(new Date().getTime() - new Date().getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 10)

  // Validate displayName
  if (!values.displayName.trim()) {
    errors.displayName = 'Tên người dùng'
  } else if (values.displayName.trim().length < 2) {
    errors.displayName = 'Tên người dùng phải tối thiểu 2 ký tự'
  }

  // Validate phone
  if (!values.phone.trim()) {
    errors.phone = 'Số điện thoại'
  } else if (!isNormalizedVietnamPhone(normalizedPhone)) {
    errors.phone = 'Số điện thoại không hợp lệ. Dùng dạng 091..., 849... hoặc +849...'
  }

  if (!values.dob) {
    errors.dob = 'Vui lòng chọn ngày sinh'
  } else if (values.dob > todayIso) {
    errors.dob = 'Ngày sinh không được ở tương lai'
  }

  if (!values.gender) {
    errors.gender = 'Vui lòng chọn giới tính'
  }

  // Validate password with policy
  const passwordError = validatePassword(values.password)
  if (passwordError) {
    errors.password = passwordError
  }

  // Validate confirmPassword
  if (!values.confirmPassword) {
    errors.confirmPassword = 'Vui lòng xác nhận mật khẩu'
  } else if (values.confirmPassword !== values.password) {
    errors.confirmPassword = 'Mật khẩu xác nhận chưa khớp'
  }

  return errors
}

function validateOtpCode(value: string): string | null {
  if (!value.trim()) {
    return 'Vui lòng nhập mã OTP'
  }

  if (!/^\d{6}$/.test(value)) {
    return 'Mã OTP phải gồm đúng 6 chữ số'
  }

  return null
}

export function RegisterPage() {
  const navigate = useNavigate()
  const { t } = useLanguage()
  const [step, setStep] = useState<RegisterStep>('form')
  const [form, setForm] = useState<RegisterFormState>({
    displayName: '',
    phone: '',
    dob: '',
    gender: '',
    password: '',
    confirmPassword: '',
  })
  const [otpCode, setOtpCode] = useState('')
  const [normalizedPhone, setNormalizedPhone] = useState('')
  const [errors, setErrors] = useState<RegisterErrors>({})
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isResendingOtp, setIsResendingOtp] = useState(false)

  const hasErrors = useMemo(() => Object.keys(errors).length > 0, [errors])

  const setField = <T extends keyof RegisterFormState>(field: T, value: RegisterFormState[T]) => {
    setForm((prev) => ({ ...prev, [field]: value }))
    setErrors((prev) => {
      if (!prev[field]) {
        return prev
      }

      const next = { ...prev }
      delete next[field]
      return next
    })
  }

  const resetToFormStep = () => {
    setStep('form')
    setOtpCode('')
    setErrorMessage(null)
    setSuccessMessage(null)
    setErrors((prev) => {
      const next = { ...prev }
      delete next.otpCode
      return next
    })
  }

  return (
    <div className='auth-page'>
      <AuthPageControls />
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>{t('common.appName')}</span>
          <h1 className='auth-brand-title'>{t('auth.registerHeroTitle')}</h1>
          <p className='auth-brand-subtitle'>{t('auth.registerHeroCopy')}</p>
        </header>

        <div className='auth-card auth-card-register'>
          <section className='auth-content'>
            <div className='auth-copy-block'>
              <p className='auth-eyebrow'>{t('auth.registerEyebrow')}</p>
              <h2>{step === 'form' ? t('auth.registerWelcome') : t('auth.otpVerifyTitle')}</h2>
              <p>
                {step === 'form'
                  ? t('auth.registerSubtitle')
                  : `${t('auth.otpSubtitlePrefix')} ${normalizedPhone}.`}
              </p>
            </div>

          {step === 'form' ? (
            <form
              className='auth-form auth-form-register'
              onSubmit={async (event) => {
                event.preventDefault()

                const nextErrors = validateRegisterForm(form)
                setErrors(nextErrors)

                if (Object.keys(nextErrors).length > 0) {
                  return
                }

                setErrorMessage(null)
                setSuccessMessage(null)
                setIsSubmitting(true)

                const phoneValue = normalizeVietnamPhone(form.phone)

                try {
                  await sendRegisterOtp({ phone: phoneValue })
                  setNormalizedPhone(phoneValue)
                  setStep('otp')
                } catch (error) {
                  setErrorMessage(
                    error instanceof Error ? error.message : t('auth.sendOtpFail'),
                  )
                } finally {
                  setIsSubmitting(false)
                }
              }}
            >
              <label>
                {t('auth.displayNameLabel')}
                <input
                  type='text'
                  placeholder={t('auth.displayNamePlaceholder')}
                  value={form.displayName}
                  onChange={(event) => setField('displayName', event.target.value)}
                  autoComplete='name'
                />
                {errors.displayName ? <span className='auth-field-error'>{errors.displayName}</span> : null}
              </label>

              <label>
                {t('auth.identifierLabel')}
                <input
                  type='tel'
                  placeholder={t('auth.identifierPlaceholder')}
                  value={form.phone}
                  onChange={(event) => setField('phone', event.target.value)}
                  autoComplete='tel'
                />
                {errors.phone ? <span className='auth-field-error'>{errors.phone}</span> : null}
              </label>

              <div className='auth-form-two-columns'>
                <label>
                  {t('profile.dateOfBirth')}
                  <input
                    type='date'
                    value={form.dob}
                    max={new Date(new Date().getTime() - new Date().getTimezoneOffset() * 60000)
                      .toISOString()
                      .slice(0, 10)}
                    onChange={(event) => setField('dob', event.target.value)}
                  />
                  {errors.dob ? <span className='auth-field-error'>{errors.dob}</span> : null}
                </label>

                <label>
                  {t('profile.gender')}
                  <select value={form.gender} onChange={(event) => setField('gender', event.target.value as Gender | '')}>
                    <option value=''>--</option>
                    <option value='MALE'>{t('profile.genderLabels.male')}</option>
                    <option value='FEMALE'>{t('profile.genderLabels.female')}</option>
                    <option value='OTHER'>{t('profile.genderLabels.other')}</option>
                  </select>
                  {errors.gender ? <span className='auth-field-error'>{errors.gender}</span> : null}
                </label>
              </div>

              <div className='auth-form-two-columns'>
                <label>
                  {t('auth.passwordLabel')}
                  <div className='auth-password-wrap'>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      placeholder={t('auth.passwordCreatePlaceholder')}
                      value={form.password}
                      onChange={(event) => setField('password', event.target.value)}
                      autoComplete='new-password'
                    />
                    <button
                      type='button'
                      className='auth-password-toggle'
                      onClick={() => setShowPassword((prev) => !prev)}
                      aria-label={showPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                      title={showPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    >
                      <PasswordToggleIcon visible={showPassword} />
                    </button>
                  </div>
                  {errors.password ? <span className='auth-field-error'>{errors.password}</span> : null}
                </label>

                <label>
                  {t('auth.confirmPasswordLabel')}
                  <div className='auth-password-wrap'>
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder={t('auth.confirmPasswordPlaceholder')}
                      value={form.confirmPassword}
                      onChange={(event) => setField('confirmPassword', event.target.value)}
                      autoComplete='new-password'
                    />
                    <button
                      type='button'
                      className='auth-password-toggle'
                      onClick={() => setShowConfirmPassword((prev) => !prev)}
                      aria-label={showConfirmPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                      title={showConfirmPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    >
                      <PasswordToggleIcon visible={showConfirmPassword} />
                    </button>
                  </div>
                  {errors.confirmPassword ? (
                    <span className='auth-field-error'>{errors.confirmPassword}</span>
                  ) : null}
                </label>
              </div>

              {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}

              <button type='submit' disabled={isSubmitting}>
                {isSubmitting ? t('auth.sendingOtp') : t('auth.receiveOtpButton')}
              </button>

              <p className='auth-switch-copy'>
                {t('auth.alreadyHaveAccount')} <Link to='/login'>{t('auth.signInNow')}</Link>
              </p>
              {hasErrors ? <p className='auth-helper-text'>{t('auth.checkMissingFields')}</p> : null}
            </form>
          ) : (
            <form
              className='auth-form auth-form-register'
              onSubmit={async (event) => {
                event.preventDefault()

                const otpError = validateOtpCode(otpCode)
                setErrors((prev) => ({ ...prev, otpCode: otpError ?? undefined }))

                if (otpError) {
                  return
                }

                setErrorMessage(null)
                setSuccessMessage(null)
                setIsSubmitting(true)

                try {
                  const accessToken = await registerAccount({
                    displayName: form.displayName.trim(),
                    phone: normalizedPhone,
                    password: form.password,
                    otpCode,
                  })

                  await updateProfile(accessToken, {
                    dob: form.dob,
                    gender: form.gender || undefined,
                  })

                  setSuccessMessage(t('auth.registerSuccessRedirect'))

                  setTimeout(() => {
                    navigate('/login', {
                      replace: true,
                      state: {
                        registered: true,
                        phone: normalizedPhone,
                      },
                    })
                  }, 1000)
                } catch (error) {
                  setErrorMessage(
                    error instanceof Error ? error.message : t('auth.registerFail'),
                  )
                } finally {
                  setIsSubmitting(false)
                }
              }}
            >
              <OtpCodeInput value={otpCode} onChange={setOtpCode} disabled={isSubmitting} autoFocus />
              {errors.otpCode ? <p className='auth-form-error'>{errors.otpCode}</p> : null}

              {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
              {successMessage ? <p className='auth-form-success'>{successMessage}</p> : null}

              <button type='submit' disabled={isSubmitting}>
                {isSubmitting ? t('auth.verifying') : t('auth.verifyButton')}
              </button>

              <div className='auth-otp-actions'>
                <button
                  type='button'
                  className='auth-secondary-button'
                  disabled={isResendingOtp || isSubmitting}
                  onClick={async () => {
                    setErrorMessage(null)
                    setSuccessMessage(null)
                    setIsResendingOtp(true)

                    try {
                      await sendRegisterOtp({ phone: normalizedPhone })
                      setSuccessMessage(t('auth.resendOtpSuccess'))
                    } catch (error) {
                      setErrorMessage(
                        error instanceof Error ? error.message : t('auth.resendOtpFail'),
                      )
                    } finally {
                      setIsResendingOtp(false)
                    }
                  }}
                >
                  {isResendingOtp ? t('auth.resendingOtp') : t('auth.resendOtpButton')}
                </button>

                <button
                  type='button'
                  className='auth-secondary-button'
                  disabled={isSubmitting || isResendingOtp}
                  onClick={resetToFormStep}
                >
                  {t('auth.editInfoButton')}
                </button>
              </div>

              <p className='auth-switch-copy'>
                {t('auth.alreadyHaveAccount')} <Link to='/login'>{t('auth.signInNow')}</Link>
              </p>
            </form>
          )}
          </section>
        </div>
      </div>
    </div>
  )
}
