import { Icon } from '../shared/components/Icon'
import { Card } from '../shared/components/ui/Card'
import { SegmentedControl, ToggleSwitch } from '../shared/components/SettingsControls'
import { useTheme } from '../shared/contexts/ThemeContext'
import { useLanguage } from '../shared/i18n/LanguageContext'
import { useNotifications } from '../shared/contexts/NotificationsContext'
import type { Language } from '../shared/i18n/translations'

export function SettingsPage() {
  const { theme, toggleTheme } = useTheme()
  const { language, setLanguage, t } = useLanguage()
  const { notificationsEnabled, toggleNotifications } = useNotifications()

  return (
    <section className='panel-page'>
      <h2>{t('pages.settings.title')}</h2>
      <p className='panel-subtitle'>{t('pages.settings.subtitle')}</p>
      <div className='settings-grid'>
        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='bell' />
                </span>
                {t('settings.notifications')}
              </h3>
              <p>{t('settings.notificationsDesc')}</p>
            </div>
            <ToggleSwitch enabled={notificationsEnabled} onChange={toggleNotifications} />
          </div>
        </Card>

        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='spark' />
                </span>
                {t('settings.theme')}
              </h3>
              <p>{t('settings.themeDesc')}</p>
            </div>
          </div>
          <SegmentedControl
            options={[
              { label: t('settings.lightMode'), value: 'light' },
              { label: t('settings.darkMode'), value: 'dark' },
            ]}
            value={theme}
            onChange={(newTheme: string) => {
              if (newTheme !== theme) {
                toggleTheme()
              }
            }}
          />
        </Card>

        <Card as='article' className='settings-card settings-card-interactive'>
          <div className='settings-card-header'>
            <div>
              <h3>
                <span className='settings-icon'>
                  <Icon name='settings' />
                </span>
                {t('settings.language')}
              </h3>
              <p>{t('settings.languageDesc')}</p>
            </div>
          </div>
          <SegmentedControl
            options={[
              { label: 'Tiếng Việt', value: 'vi' },
              { label: 'English', value: 'en' },
            ]}
            value={language}
            onChange={(lang: string) => setLanguage(lang as Language)}
          />
        </Card>

        <Card as='article' className='settings-card'>
          <h3>
            <span className='settings-icon'>
              <Icon name='settings' />
            </span>
            {t('settings.security')}
          </h3>
          <p>{t('settings.securityDesc')}</p>
        </Card>
      </div>
    </section>
  )
}
