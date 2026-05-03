import React, { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { useAuth } from '../../features/auth/useAuth'
import { fetchInbox } from '../../features/chat/chat.api'
import { getFriendStats } from '../../features/friends/friends.api'
import { useChatSocket } from '../../features/chat/useChatSocket'

const FRIEND_REQUEST_REFRESH_INTERVAL_MS = 5000

export const refreshNotificationBadges = () => {
  window.dispatchEvent(new CustomEvent('vnalo:refresh-notifications'))
}

type NotificationContextType = {
  unreadMessageCount: number
  pendingFriendRequestCount: number
  refreshCounts: () => Promise<void>
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined)

export const NotificationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { accessToken, user } = useAuth()
  const [unreadMessageCount, setUnreadMessageCount] = useState(0)
  const [pendingFriendRequestCount, setPendingFriendRequestCount] = useState(0)
  const refreshInFlightRef = React.useRef<Promise<void> | null>(null)

  const refreshCounts = useCallback(async () => {
    if (!accessToken) return

    if (refreshInFlightRef.current) {
      return refreshInFlightRef.current
    }

    const refreshPromise = (async () => {
      try {
        const [conversations, stats] = await Promise.all([
          fetchInbox(accessToken, user?.id),
          getFriendStats(accessToken).catch(() => ({ friendCount: 0, pendingRequestCount: 0 }))
        ])

        const totalUnread = conversations.reduce((sum, conv) => sum + (conv.unreadCount || 0), 0)
        setUnreadMessageCount(totalUnread)
        setPendingFriendRequestCount(stats.pendingRequestCount)
      } catch (error) {
        console.error('[NotificationProvider] Failed to refresh counts:', error)
      } finally {
        refreshInFlightRef.current = null
      }
    })()

    refreshInFlightRef.current = refreshPromise
    return refreshPromise
  }, [accessToken, user?.id])

  // Initial fetch and polling fallback for friend requests if socket doesn't support it
  useEffect(() => {
    if (accessToken) {
      refreshCounts()
      
      // Poll friend stats more frequently and refresh immediately on focus/visibility changes.
      const interval = window.setInterval(() => {
        void refreshCounts()
      }, FRIEND_REQUEST_REFRESH_INTERVAL_MS)

      const handleWindowFocus = () => {
        void refreshCounts()
      }

      const handleVisibilityChange = () => {
        if (!document.hidden) {
          void refreshCounts()
        }
      }

      window.addEventListener('focus', handleWindowFocus)
      document.addEventListener('visibilitychange', handleVisibilityChange)

      return () => {
        clearInterval(interval)
        window.removeEventListener('focus', handleWindowFocus)
        document.removeEventListener('visibilitychange', handleVisibilityChange)
      }
    }
  }, [accessToken, refreshCounts])

  // Listen for real-time message updates
  useChatSocket({
    token: accessToken,
    onMessageReceived: () => {
      // When a new message arrives, refresh inbox counts
      void refreshCounts()
    },
    onMessageRead: () => {
      // When a message is marked as read, refresh counts
      void refreshCounts()
    }
  })

  useEffect(() => {
    const handleRefresh = () => {
      void refreshCounts()
    }
    window.addEventListener('vnalo:refresh-notifications', handleRefresh)
    return () => window.removeEventListener('vnalo:refresh-notifications', handleRefresh)
  }, [refreshCounts])

  return (
    <NotificationContext.Provider value={{ unreadMessageCount, pendingFriendRequestCount, refreshCounts }}>
      {children}
    </NotificationContext.Provider>
  )
}

export const useNotifications = () => {
  const context = useContext(NotificationContext)
  if (!context) {
    throw new Error('useNotifications must be used within a NotificationProvider')
  }
  return context
}
