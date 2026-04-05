import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { sendRegisterOtp, register as registerAccount } from '../features/auth/auth.api'
import { OtpCodeInput } from '../features/auth/components/OtpCodeInput'
import { isNormalizedVietnamPhone, normalizeVietnamPhone } from '../features/auth/phone.util'
import { validatePassword } from '../features/auth/password.util'
import { useLanguage } from '../shared/i18n/LanguageContext'

type RegisterStep = 'form' | 'otp'

type RegisterFormState = {
  displayName: string
  phone: string
  password: string
  confirmPassword: string
  agreeTerms: boolean
}

type RegisterErrors = Partial<Record<keyof RegisterFormState | 'otpCode', string>>

function validateRegisterForm(values: RegisterFormState): RegisterErrors {
  const errors: RegisterErrors = {}
  const normalizedPhone = normalizeVietnamPhone(values.phone)

  // Validate displayName
  if (!values.displayName.trim()) {
    errors.displayName = 'Vui lòng nhập tên hiển thị'
  } else if (values.displayName.trim().length < 2) {
    errors.displayName = 'Tên hiển thị phải tối thiểu 2 ký tự'
  }

  // Validate phone
  if (!values.phone.trim()) {
    errors.phone = 'Vui lòng nhập số điện thoại'
  } else if (!isNormalizedVietnamPhone(normalizedPhone)) {
    errors.phone = 'Số điện thoại không hợp lệ. Dùng dạng 091..., 849... hoặc +849...'
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

  // Validate terms agreement
  if (!values.agreeTerms) {
    errors.agreeTerms = 'Bạn cần đồng ý điều khoản để tiếp tục'
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
    password: '',
    confirmPassword: '',
    agreeTerms: false,
  })
  const [otpCode, setOtpCode] = useState('')
  const [normalizedPhone, setNormalizedPhone] = useState('')
  const [errors, setErrors] = useState<RegisterErrors>({})
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
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
      <div className='auth-card auth-card-register'>
        <section className='auth-visual'>
          <p className='auth-brand'>{t('common.appName')}</p>
          <h1>{t('auth.registerHeroTitle')}</h1>
          <p className='auth-copy'>{t('auth.registerHeroCopy')}</p>

          <div className='auth-points'>
            <div>
              <span className='auth-point-kicker'>01</span>
              <p>{t('auth.registerPoint1')}</p>
            </div>
            <div>
              <span className='auth-point-kicker'>02</span>
              <p>{t('auth.registerPoint2')}</p>
            </div>
            <div>
              <span className='auth-point-kicker'>03</span>
              <p>{t('auth.registerPoint3')}</p>
            </div>
          </div>
        </section>

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
                  {t('auth.passwordLabel')}
                  <input
                    type='password'
                    placeholder={t('auth.passwordCreatePlaceholder')}
                    value={form.password}
                    onChange={(event) => setField('password', event.target.value)}
                    autoComplete='new-password'
                  />
                  {errors.password ? <span className='auth-field-error'>{errors.password}</span> : null}
                </label>

                <label>
                  {t('auth.confirmPasswordLabel')}
                  <input
                    type='password'
                    placeholder={t('auth.confirmPasswordPlaceholder')}
                    value={form.confirmPassword}
                    onChange={(event) => setField('confirmPassword', event.target.value)}
                    autoComplete='new-password'
                  />
                  {errors.confirmPassword ? (
                    <span className='auth-field-error'>{errors.confirmPassword}</span>
                  ) : null}
                </label>
              </div>

              <label className='auth-checkbox-row'>
                <input
                  type='checkbox'
                  checked={form.agreeTerms}
                  onChange={(event) => setField('agreeTerms', event.target.checked)}
                />
                <span>{t('auth.termsLabel')}</span>
              </label>
              {errors.agreeTerms ? <p className='auth-form-error'>{errors.agreeTerms}</p> : null}

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
                  await registerAccount({
                    displayName: form.displayName.trim(),
                    phone: normalizedPhone,
                    password: form.password,
                    otpCode,
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
  )
}
