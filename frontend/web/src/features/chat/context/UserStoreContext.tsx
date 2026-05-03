import React from 'react'
import { getUserById } from '../../friends/friends.api'

type CachedUserProfile = {
  displayName: string
  avatarUrl: string | null
}

type UserStoreContextType = {
  userMap: Record<string, CachedUserProfile>
  getDisplayName: (userId: string) => string
  upsertUser: (userId: string, profile: CachedUserProfile) => void
  ensureUser: (token: string, userId: string) => Promise<CachedUserProfile>
}

const UserStoreContext = React.createContext<UserStoreContextType | undefined>(undefined)

export const UserStoreProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [userMap, setUserMap] = React.useState<Record<string, CachedUserProfile>>({})
  const pendingRequests = React.useRef(new Map<string, Promise<CachedUserProfile>>())

  const upsertUser = React.useCallback((userId: string, profile: CachedUserProfile) => {
    setUserMap((prev) => {
      // Avoid unnecessary updates if data is identical
      if (prev[userId]?.displayName === profile.displayName && prev[userId]?.avatarUrl === profile.avatarUrl) {
        return prev
      }
      console.log(`[UserStore] Seeding/Updating user ${userId}:`, profile.displayName)
      return { ...prev, [userId]: profile }
    })
  }, [])

  const getDisplayName = React.useCallback((userId: string) => {
    return userMap[userId]?.displayName || 'Người dùng'
  }, [userMap])

  const ensureUser = React.useCallback(async (token: string, userId: string): Promise<CachedUserProfile> => {
    if (userMap[userId] && userMap[userId].displayName !== 'Người dùng') return userMap[userId]

    const pending = pendingRequests.current.get(userId)
    if (pending) return pending

    const fetchPromise = (async () => {
      try {
        const profile = await getUserById(token, userId)
        const resolved: CachedUserProfile = {
          displayName: profile?.displayName?.trim() || profile?.phone || profile?.email || 'Người dùng',
          avatarUrl: profile?.avatarUrl ?? null,
        }
        upsertUser(userId, resolved)
        return resolved
      } catch (error) {
        return { displayName: 'Người dùng', avatarUrl: null }
      } finally {
        pendingRequests.current.delete(userId)
      }
    })()

    pendingRequests.current.set(userId, fetchPromise)
    return fetchPromise
  }, [userMap, upsertUser])

  const value = React.useMemo(() => ({
    userMap,
    getDisplayName,
    upsertUser,
    ensureUser,
  }), [userMap, getDisplayName, upsertUser, ensureUser])

  return (
    <UserStoreContext.Provider value={value}>
      {children}
    </UserStoreContext.Provider>
  )
}

export const useUserStore = () => {
  const context = React.useContext(UserStoreContext)
  if (!context) throw new Error('useUserStore must be used within a UserStoreProvider')
  return context
}
