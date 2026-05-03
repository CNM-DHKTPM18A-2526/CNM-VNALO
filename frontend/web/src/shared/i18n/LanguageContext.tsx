import React from 'react'
/* eslint-disable react-refresh/only-export-components */

import { type Language, translations } from './translations'

type LanguageContextType = {
  language: Language
  setLanguage: (language: Language) => void
  t: (key: string) => string
}

const LanguageContext = React.createContext<LanguageContextType | null>(null)

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = React.useState<Language>(() => {
    const saved = localStorage.getItem('vnalo_language')
    return (saved as Language) || 'vi'
  })

  const setLanguage = (lang: Language) => {
    setLanguageState(lang)
    localStorage.setItem('vnalo_language', lang)
  }

  const t = (key: string): string => {
    const keys = key.split('.')
    let value: unknown = translations[language]

    for (const k of keys) {
      value = (value as Record<string, unknown>)?.[k]
    }

    return (value as string) || key
  }

  return (
    <LanguageContext.Provider value={{ language, setLanguage, t }}>
      {children}
    </LanguageContext.Provider>
  )
}

export function useLanguage() {
  const context = React.useContext(LanguageContext)
  if (!context) {
    throw new Error('useLanguage must be used within LanguageProvider')
  }
  return context
}
