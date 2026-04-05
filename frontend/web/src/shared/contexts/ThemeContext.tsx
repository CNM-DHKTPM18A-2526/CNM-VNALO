import { createContext, useContext, useEffect, useState } from 'react'
/* eslint-disable react-refresh/only-export-components */

type Theme = 'light' | 'dark'

type ThemeContextType = {
  theme: Theme
  toggleTheme: () => void
}

const ThemeContext = createContext<ThemeContextType | null>(null)

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>(() => {
    const saved = localStorage.getItem('vnalo_theme')
    return (saved as Theme) || 'light'
  })

  useEffect(() => {
    localStorage.setItem('vnalo_theme', theme)
    document.documentElement.setAttribute('data-theme', theme)
    document.body.className = `theme-${theme}`
  }, [theme])

  const toggleTheme = () => {
    setTheme((prev) => (prev === 'light' ? 'dark' : 'light'))
  }

  return <ThemeContext.Provider value={{ theme, toggleTheme }}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider')
  }
  return context
}
