import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { resetPassword, sendForgotPasswordOtp } from '../features/auth/auth.api'
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

type ForgotStep = 'phone' | 'reset'

export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const { t } = useLanguage()

  const [step, setStep] = useState<ForgotStep>('phone')
  const [phoneInput, setPhoneInput] = useState('')
  const [normalizedPhone, setNormalizedPhone] = useState('')
  const [otpCode, setOtpCode] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmNewPassword, setConfirmNewPassword] = useState('')
  const [showNewPassword, setShowNewPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isResendingOtp, setIsResendingOtp] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  const resetToPhoneStep = () => {
    setStep('phone')
    setOtpCode('')
    setNewPassword('')
    setConfirmNewPassword('')
    setErrorMessage(null)
    setSuccessMessage(null)
  }

  return (
    <div className='auth-page'>
      <AuthPageControls />
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>{t('common.appName')}</span>
          <h1 className='auth-brand-title'>{t('auth.forgotHeroTitle')}</h1>
          <p className='auth-brand-subtitle'>{t('auth.forgotHeroCopy')}</p>
        </header>

        <div className='auth-card auth-card-register'>
          <section className='auth-content'>
            <div className='auth-copy-block'>
              <p className='auth-eyebrow'>{t('auth.forgotEyebrow')}</p>
              <h2>{step === 'phone' ? t('auth.forgotWelcome') : t('auth.resetWelcome')}</h2>
              <p>
                {step === 'phone'
                  ? t('auth.forgotSubtitle')
                  : `${t('auth.resetSubtitlePrefix')} ${normalizedPhone}.`}
              </p>
            </div>

            {step === 'phone' ? (
              <form
                className='auth-form auth-form-register'
                onSubmit={async (event) => {
                  event.preventDefault()

                  setErrorMessage(null)
                  setSuccessMessage(null)

                  const normalized = normalizeVietnamPhone(phoneInput)

                  if (!isNormalizedVietnamPhone(normalized)) {
                    setErrorMessage(t('auth.forgotInvalidPhone'))
                    return
                  }

                  setIsSubmitting(true)

                  try {
                    await sendForgotPasswordOtp({ phone: normalized })
                    setNormalizedPhone(normalized)
                    setStep('reset')
                    setSuccessMessage(t('auth.otpSentSuccess'))
                  } catch (error) {
                    setErrorMessage(error instanceof Error ? error.message : t('auth.sendOtpFail'))
                  } finally {
                    setIsSubmitting(false)
                  }
                }}
              >
                <label>
                  {t('auth.identifierLabel')}
                  <input
                    type='tel'
                    placeholder={t('auth.identifierPlaceholder')}
                    value={phoneInput}
                    onChange={(event) => setPhoneInput(event.target.value)}
                    autoComplete='tel'
                  />
                </label>

                {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
                {successMessage ? <p className='auth-form-success'>{successMessage}</p> : null}

                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.sendingResetOtp') : t('auth.sendResetOtpButton')}
                </button>

                <p className='auth-switch-copy'>
                  <Link to='/login'>{t('auth.backToLogin')}</Link>
                </p>
              </form>
            ) : (
              <form
                className='auth-form auth-form-register'
                onSubmit={async (event) => {
                  event.preventDefault()

                  setErrorMessage(null)
                  setSuccessMessage(null)

                  if (!/^\d{6}$/.test(otpCode)) {
                    setErrorMessage(t('auth.forgotOtpInvalid'))
                    return
                  }

                  const passwordError = validatePassword(newPassword)
                  if (passwordError) {
                    setErrorMessage(passwordError)
                    return
                  }

                  if (!confirmNewPassword) {
                    setErrorMessage(t('auth.forgotConfirmPasswordRequired'))
                    return
                  }

                  if (confirmNewPassword !== newPassword) {
                    setErrorMessage(t('auth.forgotConfirmPasswordMismatch'))
                    return
                  }

                  setIsSubmitting(true)

                  try {
                    await resetPassword({
                      phone: normalizedPhone,
                      otp: otpCode,
                      newPassword,
                    })

                    setSuccessMessage(t('auth.forgotPasswordSuccessRedirect'))

                    setTimeout(() => {
                      navigate('/login', { replace: true })
                    }, 1000)
                  } catch (error) {
                    setErrorMessage(error instanceof Error ? error.message : t('auth.resetPasswordFail'))
                  } finally {
                    setIsSubmitting(false)
                  }
                }}
              >
                <OtpCodeInput
                  value={otpCode}
                  onChange={setOtpCode}
                  disabled={isSubmitting}
                  autoFocus
                  label={t('auth.otpCodeLabel')}
                  placeholder={t('auth.otpCodePlaceholder')}
                  helperText={t('auth.otpCodeHelper')}
                />

                <label>
                  {t('auth.newPasswordLabel')}
                  <div className='auth-password-wrap'>
                    <input
                      type={showNewPassword ? 'text' : 'password'}
                      placeholder={t('auth.newPasswordPlaceholder')}
                      value={newPassword}
                      onChange={(event) => setNewPassword(event.target.value)}
                      autoComplete='new-password'
                    />
                    <button
                      type='button'
                      className='auth-password-toggle'
                      onClick={() => setShowNewPassword((prev) => !prev)}
                      aria-label={showNewPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                      title={showNewPassword ? t('auth.hidePassword') : t('auth.showPassword')}
                    >
                      <PasswordToggleIcon visible={showNewPassword} />
                    </button>
                  </div>
                </label>

                <label>
                  {t('auth.confirmNewPasswordLabel')}
                  <div className='auth-password-wrap'>
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder={t('auth.confirmNewPasswordPlaceholder')}
                      value={confirmNewPassword}
                      onChange={(event) => setConfirmNewPassword(event.target.value)}
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
                </label>

                {errorMessage ? <p className='auth-form-error'>{errorMessage}</p> : null}
                {successMessage ? <p className='auth-form-success'>{successMessage}</p> : null}

                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.resettingPassword') : t('auth.resetPasswordButton')}
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
                        await sendForgotPasswordOtp({ phone: normalizedPhone })
                        setSuccessMessage(t('auth.otpSentSuccess'))
                      } catch (error) {
                        setErrorMessage(error instanceof Error ? error.message : t('auth.resendOtpFail'))
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
                    onClick={resetToPhoneStep}
                  >
                    {t('auth.changePhoneButton')}
                  </button>
                </div>

                <p className='auth-switch-copy'>
                  <Link to='/login'>{t('auth.backToLogin')}</Link>
                </p>
              </form>
            )}
          </section>
        </div>
      </div>
    </div>
  )
}
