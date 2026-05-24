import React from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { sendRegisterOtp, register as registerAccount } from '../features/auth/auth.api'
import type { Gender } from '../features/auth/auth.types'
import { OtpCodeInput } from '../features/auth/components/OtpCodeInput'
import { isNormalizedVietnamPhone, normalizeVietnamPhone } from '../features/auth/phone.util'
import { validatePassword } from '../features/auth/password.util'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { RegisterFaceStep } from '../features/face-auth/components/RegisterFaceStep'

type RegisterStep = 'form' | 'otp' | 'face'

type RegisterFormState = {
  displayName: string
  phone: string
  email: string
  dob: string
  gender: Gender | ''
  password: string
  confirmPassword: string
}

type RegisterErrors = Partial<Record<keyof RegisterFormState | 'otpCode', string>>

const MIN_REGISTER_AGE = 16

function getLocalTodayIsoDate() {
  const now = new Date()
  const offsetMs = now.getTimezoneOffset() * 60000
  return new Date(now.getTime() - offsetMs).toISOString().slice(0, 10)
}

function isAtLeastAge(dobIso: string, minAge: number, referenceDate = new Date()) {
  const [yearRaw, monthRaw, dayRaw] = dobIso.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const day = Number(dayRaw)

  if (!year || !month || !day) return false

  const birthDate = new Date(year, month - 1, day)
  if (Number.isNaN(birthDate.getTime())) return false

  let age = referenceDate.getFullYear() - year
  const currentMonth = referenceDate.getMonth() + 1
  const currentDay = referenceDate.getDate()
  const hadBirthdayThisYear = currentMonth > month || (currentMonth === month && currentDay >= day)

  if (!hadBirthdayThisYear) age -= 1

  return age >= minAge
}

function validateRegisterForm(values: RegisterFormState): RegisterErrors {
  const errors: RegisterErrors = {}
  const normalizedPhone = normalizeVietnamPhone(values.phone)
  const normalizedEmail = values.email.trim().toLowerCase()

  if (!values.displayName.trim()) errors.displayName = 'Vui lòng nhập tên'
  if (!values.phone.trim()) errors.phone = 'Vui lòng nhập SĐT'
  else if (!isNormalizedVietnamPhone(normalizedPhone)) errors.phone = 'SĐT không hợp lệ'

  if (!normalizedEmail) errors.email = 'Vui lòng nhập email'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) errors.email = 'Email không hợp lệ'

  if (!values.dob) errors.dob = 'Nhập ngày sinh'
  else if (!isAtLeastAge(values.dob, MIN_REGISTER_AGE)) errors.dob = `Tối thiểu ${MIN_REGISTER_AGE} tuổi`

  if (!values.gender) errors.gender = 'Chọn giới tính'

  const passwordError = validatePassword(values.password)
  if (passwordError) errors.password = passwordError

  if (values.confirmPassword !== values.password) errors.confirmPassword = 'Mật khẩu chưa khớp'

  return errors
}

export function RegisterPage() {
  const navigate = useNavigate()
  const { setLanguage, language, t } = useLanguage()
  const [step, setStep] = React.useState<RegisterStep>('form')
  const [form, setForm] = React.useState<RegisterFormState>({
    displayName: '',
    phone: '',
    email: '',
    dob: '',
    gender: '',
    password: '',
    confirmPassword: '',
  })
  const [otpCode, setOtpCode] = React.useState('')
  const [normalizedPhone, setNormalizedPhone] = React.useState('')
  const [normalizedEmail, setNormalizedEmail] = React.useState('')
  const [accessToken, setAccessToken] = React.useState<string | null>(null)
  const [errors, setErrors] = React.useState<RegisterErrors>({})
  const [errorMessage, setErrorMessage] = React.useState<string | null>(null)
  const [successMessage, setSuccessMessage] = React.useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = React.useState(false)

  const setField = <T extends keyof RegisterFormState>(field: T, value: RegisterFormState[T]) => {
    setForm((prev) => ({ ...prev, [field]: value }))
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev }; delete next[field]; return next
      })
    }
  }

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    const nextErrors = validateRegisterForm(form)
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length > 0) return

    setErrorMessage(null)
    setIsSubmitting(true)
    const phoneValue = normalizeVietnamPhone(form.phone)
    const emailValue = form.email.trim().toLowerCase()

    try {
      await sendRegisterOtp({ phone: phoneValue, email: emailValue })
      setNormalizedPhone(phoneValue)
      setNormalizedEmail(emailValue)
      setStep('otp')
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Gửi OTP thất bại')
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleFinalRegister = async (e: React.FormEvent) => {
    e.preventDefault()
    if (otpCode.length < 6) {
        setErrors({ otpCode: 'Mã OTP gồm 6 chữ số' })
        return
    }

    setErrorMessage(null)
    setIsSubmitting(true)
    try {
      const token = await registerAccount({
        displayName: form.displayName.trim(),
        phone: normalizedPhone,
        email: normalizedEmail,
        password: form.password,
        otpCode,
        dob: form.dob || undefined,
        gender: form.gender || undefined,
      })

      setAccessToken(token)
      setSuccessMessage('Đăng ký thành công!')
      setStep('face')
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Đăng ký thất bại')
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
            {t('auth.registerHeroTitle')}<br/>
            <span style={{ fontSize: 13, color: '#666' }}>{t('auth.registerHeroCopy').length > 50 ? t('auth.registerHeroCopy').slice(0, 50) + '...' : t('auth.registerHeroCopy')}</span>
          </p>
        </header>

        <div className='auth-card'>
          <div className='auth-content'>
            <div className='auth-copy-block'>
               <h2 style={{ fontSize: 16, fontWeight: 500, textAlign: 'center', marginBottom: 20 }}>
                 {step === 'form' ? t('auth.registerEyebrow') : t('auth.otpVerifyTitle')}
               </h2>
            </div>

            {step === 'face' && accessToken ? (
              <div className='register-face-step-container'>
                <RegisterFaceStep
                  token={accessToken}
                  onComplete={(enrolled) => {
                    if (enrolled) {
                      setSuccessMessage('Đăng ký khuôn mặt thành công!')
                    }
                    setTimeout(() => navigate('/login', { replace: true }), 1200)
                  }}
                />
              </div>
            ) : step === 'form' ? (
              <form className='auth-form' onSubmit={handleSendOtp}>
                <input
                  type='text'
                  placeholder={t('auth.displayNamePlaceholder')}
                  value={form.displayName}
                  onChange={(e) => setField('displayName', e.target.value)}
                />
                {errors.displayName && <span className='auth-field-error'>{errors.displayName}</span>}

                <input
                  type='tel'
                  placeholder={t('profile.phone')}
                  value={form.phone}
                  onChange={(e) => setField('phone', e.target.value)}
                />
                {errors.phone && <span className='auth-field-error'>{errors.phone}</span>}

                <input
                  type='email'
                  placeholder={t('auth.registerEmailLabel')}
                  value={form.email}
                  onChange={(e) => setField('email', e.target.value)}
                />
                {errors.email && <span className='auth-field-error'>{errors.email}</span>}

                <div style={{ display: 'flex', gap: 15 }}>
                  <div style={{ flex: 2 }}>
                    <label htmlFor='reg-dob' style={{ fontSize: 12, color: '#666', marginBottom: 4, display: 'block' }}>{t('profile.dateOfBirth')}</label>
                    <input
                      id='reg-dob'
                      type='date'
                      value={form.dob}
                      max={getLocalTodayIsoDate()}
                      onChange={(e) => setField('dob', e.target.value)}
                      style={{ padding: '8px 0' }}
                    />
                    {errors.dob && <span className='auth-field-error'>{errors.dob}</span>}
                  </div>
                  <div style={{ flex: 1 }}>
                    <label htmlFor='reg-gender' style={{ fontSize: 12, color: '#666', marginBottom: 4, display: 'block' }}>{t('profile.gender')}</label>
                    <select
                        id='reg-gender'
                        value={form.gender}
                        onChange={(e) => setField('gender', e.target.value as Gender)}
                    >
                      <option value=''>--</option>
                      <option value='MALE'>{t('profile.genderLabels.male')}</option>
                      <option value='FEMALE'>{t('profile.genderLabels.female')}</option>
                    </select>
                    {errors.gender && <span className='auth-field-error'>{errors.gender}</span>}
                  </div>
                </div>

                <input
                  type='password'
                  placeholder={t('auth.passwordCreatePlaceholder')}
                  value={form.password}
                  onChange={(e) => setField('password', e.target.value)}
                />
                {errors.password && <span className='auth-field-error'>{errors.password}</span>}

                <input
                  type='password'
                  placeholder={t('auth.confirmPasswordPlaceholder')}
                  value={form.confirmPassword}
                  onChange={(e) => setField('confirmPassword', e.target.value)}
                />
                {errors.confirmPassword && <span className='auth-field-error'>{errors.confirmPassword}</span>}

                {errorMessage && <p className='auth-form-error'>{errorMessage}</p>}

                <button type='submit' disabled={isSubmitting}>
                  {isSubmitting ? t('auth.sendingOtp') : t('auth.receiveOtpButton')}
                </button>

                <p className='auth-switch-copy'>
                  {t('auth.alreadyHaveAccount')} <Link to='/login' style={{ color: '#0068ff', textDecoration: 'none', fontWeight: 500 }}>{t('auth.signInNow')}</Link>
                </p>
              </form>
            ) : (
              <form className='auth-form' onSubmit={handleFinalRegister}>
                <p style={{ textAlign: 'center', fontSize: 14, color: 'var(--auth-text-main)' }}>
                  {t('auth.otpSubtitlePrefix')}<br/>
                  <b style={{ color: '#0068ff' }}>{normalizedEmail}</b>
                </p>
                
                <div style={{ display: 'flex', justifyContent: 'center', margin: '20px 0' }}>
                  <OtpCodeInput value={otpCode} onChange={setOtpCode} disabled={isSubmitting} autoFocus />
                </div>

                {errors.otpCode && <p className='auth-form-error'>{errors.otpCode}</p>}
                {errorMessage && <p className='auth-form-error' role="alert">{errorMessage}</p>}
                {successMessage && <p className='auth-form-success' role="status">{successMessage}</p>}

                <button type='submit' disabled={isSubmitting || otpCode.length < 6}>
                  {isSubmitting ? t('auth.verifying') : t('auth.verifyButton')}
                </button>
                
                <button 
                  type='button' 
                  className='auth-text-action' 
                  style={{ marginTop: 15, color: '#0068ff', background: 'transparent', border: 'none', cursor: 'pointer', width: '100%', fontWeight: 500 }}
                  onClick={() => setStep('form')}
                >
                   {t('auth.editInfoButton')}
                </button>
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
