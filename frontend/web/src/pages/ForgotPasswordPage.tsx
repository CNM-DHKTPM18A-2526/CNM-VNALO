import React from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { resetPassword, sendForgotPasswordOtp } from '../features/auth/auth.api'
import { OtpCodeInput } from '../features/auth/components/OtpCodeInput'
import { validatePassword } from '../features/auth/password.util'
import { useLanguage } from '../shared/i18n/LanguageContext'

type ForgotStep = 'email' | 'reset'

export function ForgotPasswordPage() {
  const navigate = useNavigate()
  const { t, setLanguage, language } = useLanguage()

  const [step, setStep] = React.useState<ForgotStep>('email')
  const [emailInput, setEmailInput] = React.useState('')
  const [normalizedEmail, setNormalizedEmail] = React.useState('')
  const [otpCode, setOtpCode] = React.useState('')
  const [newPassword, setNewPassword] = React.useState('')
  const [confirmNewPassword, setConfirmNewPassword] = React.useState('')
  const [isSubmitting, setIsSubmitting] = React.useState(false)
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)
  const [successMessage, setSuccessMessage] = React.useState<string | null>(null)

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    const normalized = emailInput.trim().toLowerCase()
    if (!normalized) {
      setErrorMessage(t('auth.forgotEmailRequired'))
      return
    }
    setIsSubmitting(true)
    try {
      await sendForgotPasswordOtp({ email: normalized })
      setNormalizedEmail(normalized)
      setStep('reset')
      setSuccessMessage(t('auth.otpSentSuccess'))
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('auth.sendOtpFail'))
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleResetPassword = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    if (otpCode.length < 6) {
      setErrorMessage(t('auth.forgotOtpInvalid'))
      return
    }
    const passwordError = validatePassword(newPassword)
    if (passwordError) {
      setErrorMessage(passwordError)
      return
    }
    if (confirmNewPassword !== newPassword) {
      setErrorMessage(t('auth.forgotConfirmPasswordMismatch'))
      return
    }
    setIsSubmitting(true)
    try {
      await resetPassword({ email: normalizedEmail, otp: otpCode, newPassword })
      setSuccessMessage(t('auth.forgotPasswordSuccessRedirect'))
      setTimeout(() => navigate('/login', { replace: true }), 1500)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : t('auth.resetPasswordFail'))
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className='auth-page'>
      <div className='auth-shell'>
        <header className='auth-branding'>
          <span className='auth-brand-badge'>Vnalo</span>
          <p className='auth-brand-subtitle'>
            {t('auth.forgotHeroTitle')}<br/>
            <span style={{ fontSize: 13, color: '#666' }}>{t('auth.forgotHeroCopy')}</span>
          </p>
        </header>

        <div className='auth-card'>
          <div className='auth-content'>
            <div className='auth-copy-block'>
               <h2 style={{ fontSize: 16, fontWeight: 500, textAlign: 'center', marginBottom: 20 }}>
                 {step === 'email' ? t('auth.forgotWelcome') : t('auth.resetWelcome')}
               </h2>
            </div>

            {step === 'email' ? (
              <form className='auth-form' onSubmit={handleSendOtp}>
                <input
                  type='email'
                  placeholder={t('auth.registerEmailPlaceholder')}
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  autoComplete='email'
                />
                
                {errorMessage && <p className='auth-form-error'>{errorMessage}</p>}
                {successMessage && <p className='auth-form-success'>{successMessage}</p>}

                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.sendingResetOtp') : t('auth.sendResetOtpButton')}
                </button>

                <p className='auth-switch-copy'>
                  <Link to='/login' style={{ color: '#0068ff', textDecoration: 'none', fontWeight: 500 }}>{t('auth.backToLogin')}</Link>
                </p>
              </form>
            ) : (
              <form className='auth-form' onSubmit={handleResetPassword}>
                <p style={{ textAlign: 'center', fontSize: 14, color: '#333' }}>
                  {t('auth.resetSubtitlePrefix')}<br/>
                  <b>{normalizedEmail}</b>
                </p>
                
                <div style={{ display: 'flex', justifyContent: 'center', margin: '15px 0' }}>
                  <OtpCodeInput value={otpCode} onChange={setOtpCode} disabled={isSubmitting} autoFocus />
                </div>

                <input
                  type='password'
                  placeholder={t('auth.newPasswordPlaceholder')}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                />

                <input
                  type='password'
                  placeholder={t('auth.confirmNewPasswordPlaceholder')}
                  value={confirmNewPassword}
                  onChange={(e) => setConfirmNewPassword(e.target.value)}
                />

                {errorMessage && <p className='auth-form-error'>{errorMessage}</p>}
                {successMessage && <p className='auth-form-success'>{successMessage}</p>}

                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.resettingPassword') : t('auth.resetPasswordButton')}
                </button>
                
                <div style={{ display: 'flex', justifyContent: 'center', gap: 15, marginTop: 10 }}>
                    <button 
                        type='button' 
                        className='auth-text-action' 
                        style={{ color: '#0068ff', border: 'none', background: 'transparent', padding: 0, cursor: 'pointer', fontWeight: 500 }} 
                        onClick={() => setStep('email')}
                    >
                       {t('auth.changeEmailButton')}
                    </button>
                    <Link to='/login' className='auth-text-action' style={{ textDecoration: 'none', color: '#0068ff', fontWeight: 500 }}>
                        {t('auth.backToLogin')}
                    </Link>
                </div>
              </form>
            )}
          </div>
        </div>

        <div className='auth-lang-selector'>
            <button 
              className={`auth-lang-btn ${language === 'vi' ? 'active' : ''}`}
              onClick={() => setLanguage('vi')}
            >
              Tiếng Việt
            </button>
            <button 
              className={`auth-lang-btn ${language === 'en' ? 'active' : ''}`}
              onClick={() => setLanguage('en')}
            >
              English
            </button>
        </div>
      </div>
    </div>
  )
}
