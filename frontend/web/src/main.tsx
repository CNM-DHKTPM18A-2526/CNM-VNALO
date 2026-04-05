import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { AuthProvider } from './features/auth/auth.context'
import { ThemeProvider } from './shared/contexts/ThemeContext'
import { LanguageProvider } from './shared/i18n/LanguageContext'
import { NotificationsProvider } from './shared/contexts/NotificationsContext'

import './index.css'
import './styles/settings.css'
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ThemeProvider>
      <LanguageProvider>
        <NotificationsProvider>
          <AuthProvider>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </AuthProvider>
        </NotificationsProvider>
      </LanguageProvider>
    </ThemeProvider>
  </StrictMode>,
)
