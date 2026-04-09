import { useLanguage } from '../../shared/i18n/LanguageContext'
import { SettingsModalContent } from './SettingsModalContent'

type SettingsModalProps = {
  isOpen: boolean
  onClose: () => void
  onChangePasswordSuccess?: () => void
}

export function SettingsModal({ isOpen, onClose, onChangePasswordSuccess }: SettingsModalProps) {
  const { t } = useLanguage()

  if (!isOpen) {
    return null
  }

  return (
    <div className='modal-overlay' onClick={onClose}>
      <div className='modal-card modal-card-settings' onClick={(e) => e.stopPropagation()}>
        <div className='modal-header modal-header-settings'>
          <div>
            <h3>{t('pages.settings.title')}</h3>
          </div>
          <button className='modal-close-btn' onClick={onClose} type='button' aria-label={t('settings.securityClose')}>
            ×
          </button>
        </div>
        <div className='modal-body modal-body-settings'>
          <SettingsModalContent onChangePasswordSuccess={onChangePasswordSuccess} />
        </div>
      </div>
    </div>
  )
}
