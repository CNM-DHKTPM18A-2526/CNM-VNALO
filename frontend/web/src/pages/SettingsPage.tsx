import { useNavigate } from 'react-router-dom'

import { SettingsModalContent } from '../features/settings/SettingsModalContent'
import { useLanguage } from '../shared/i18n/LanguageContext'

export function SettingsPage() {
  const navigate = useNavigate()
  const { t } = useLanguage()

  const handleChangePasswordSuccess = () => {
    navigate('/login', { replace: true })
  }

  return (
    <section className='panel-page'>
      <h2>{t('pages.settings.title')}</h2>
      <p className='panel-subtitle'>{t('pages.settings.subtitle')}</p>
      <SettingsModalContent onChangePasswordSuccess={handleChangePasswordSuccess} />
    </section>
  )
}
