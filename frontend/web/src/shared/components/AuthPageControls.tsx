import { useLanguage } from '../i18n/LanguageContext'
import { useTheme } from '../contexts/ThemeContext'

function ThemeIcon({ theme }: { theme: 'light' | 'dark' }) {
  if (theme === 'dark') {
    return (
      <svg viewBox='0 0 24 24' aria-hidden='true'>
        <path
          d='M21 12.8A8.5 8.5 0 1111.2 3a6.8 6.8 0 109.8 9.8z'
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
      <circle cx='12' cy='12' r='4.5' fill='none' stroke='currentColor' strokeWidth='1.8' />
      <path d='M12 2.8v2.2M12 19v2.2M4.8 4.8l1.6 1.6M17.6 17.6l1.6 1.6M2.8 12H5M19 12h2.2M4.8 19.2l1.6-1.6M17.6 6.4l1.6-1.6' fill='none' stroke='currentColor' strokeWidth='1.8' strokeLinecap='round' />
    </svg>
  )
}

function LanguageIcon() {
  return (
    <svg viewBox='0 0 24 24' aria-hidden='true'>
      <path
        d='M12 20a8 8 0 100-16 8 8 0 000 16zM4 12h16M12 4c2.3 2.1 3.7 4.7 3.7 8s-1.4 5.9-3.7 8m0-16c-2.3 2.1-3.7 4.7-3.7 8S9.7 17.9 12 20'
        fill='none'
        stroke='currentColor'
        strokeWidth='1.8'
        strokeLinecap='round'
        strokeLinejoin='round'
      />
    </svg>
  )
}

export function AuthPageControls() {
  const { theme, toggleTheme } = useTheme()
  const { language, setLanguage, t } = useLanguage()

  const nextLanguage = language === 'vi' ? 'en' : 'vi'
  const nextLanguageLabel = nextLanguage === 'vi' ? t('auth.languageVietnamese') : t('auth.languageEnglish')

  return (
    <div className='auth-page-controls' aria-label='Authentication page controls'>
      <button
        type='button'
        className='auth-page-control-btn'
        onClick={toggleTheme}
        aria-label={theme === 'light' ? t('settings.darkMode') : t('settings.lightMode')}
        title={theme === 'light' ? t('settings.darkMode') : t('settings.lightMode')}
      >
        <ThemeIcon theme={theme} />
        <span>{theme === 'light' ? t('settings.darkMode') : t('settings.lightMode')}</span>
      </button>

      <button
        type='button'
        className='auth-page-control-btn'
        onClick={() => setLanguage(nextLanguage)}
        aria-label={nextLanguageLabel}
        title={nextLanguageLabel}
      >
        <LanguageIcon />
        <span>{nextLanguageLabel}</span>
      </button>
    </div>
  )
}
