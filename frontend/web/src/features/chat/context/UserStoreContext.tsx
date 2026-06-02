import React from 'react'
import { getUserById } from '../../friends/friends.api'

type CachedUserProfile = {
  displayName: string
  avatarUrl: string | null
  bio?: string | null
}

const AI_ASSISTANT_USER_ID = '__vnalo_ai__'
const AI_ASSISTANT_PROFILE: CachedUserProfile = {
  displayName: 'VNALO AI Assistant',
  avatarUrl: null,
}
const UNKNOWN_USER_PROFILE: CachedUserProfile = {
  displayName: 'Người dùng',
  avatarUrl: null,
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
      if (
        prev[userId]?.displayName === profile.displayName &&
        prev[userId]?.avatarUrl === profile.avatarUrl &&
        prev[userId]?.bio === profile.bio
      ) {
        return prev
      }

      return { ...prev, [userId]: profile }
    })
  }, [])

  const getDisplayName = React.useCallback((userId: string) => {
    if (userId === AI_ASSISTANT_USER_ID) return AI_ASSISTANT_PROFILE.displayName
    return userMap[userId]?.displayName || UNKNOWN_USER_PROFILE.displayName
  }, [userMap])

  const ensureUser = React.useCallback(async (token: string, userId: string): Promise<CachedUserProfile> => {
    if (userId === AI_ASSISTANT_USER_ID) {
      upsertUser(userId, AI_ASSISTANT_PROFILE)
      return AI_ASSISTANT_PROFILE
    }

    if (userMap[userId] && userMap[userId].displayName !== UNKNOWN_USER_PROFILE.displayName) return userMap[userId]

    const pending = pendingRequests.current.get(userId)
    if (pending) return pending

    const fetchPromise = (async () => {
      try {
        const profile = await getUserById(token, userId)
        const resolved: CachedUserProfile = {
          displayName: profile?.displayName?.trim() || profile?.phone || profile?.email || UNKNOWN_USER_PROFILE.displayName,
          avatarUrl: profile?.avatarUrl ?? null,
        }
        upsertUser(userId, resolved)
        return resolved
      } catch {
        return UNKNOWN_USER_PROFILE
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
