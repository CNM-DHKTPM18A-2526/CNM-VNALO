import React from 'react'
/* eslint-disable react-refresh/only-export-components */

type NotificationsContextType = {
  notificationsEnabled: boolean
  toggleNotifications: () => void
}

const NotificationsContext = React.createContext<NotificationsContextType | null>(null)

export function NotificationsProvider({ children }: { children: React.ReactNode }) {
  const [notificationsEnabled, setNotificationsEnabled] = React.useState(() => {
    const saved = localStorage.getItem('vnalo_notifications_enabled')
    return saved !== null ? JSON.parse(saved) : true
  })

  const toggleNotifications = () => {
    setNotificationsEnabled((prev: boolean) => {
      const newState = !prev
      localStorage.setItem('vnalo_notifications_enabled', JSON.stringify(newState))
      return newState
    })
  }

  return (
    <NotificationsContext.Provider value={{ notificationsEnabled, toggleNotifications }}>
      {children}
    </NotificationsContext.Provider>
  )
}

export function useNotifications() {
  const context = React.useContext(NotificationsContext)
  if (!context) {
    throw new Error('useNotifications must be used within NotificationsProvider')
  }
  return context
}
