import React from 'react'

import { getMe, login as loginApi } from './auth.api'
import { AuthContext } from './auth.context-value'
import type { AuthContextValue } from './auth.context-value'
import type { AuthUser, LoginPayload } from './auth.types'

const ACCESS_TOKEN_KEY = 'vnalo_access_token'
const AUTH_LOGOUT_EVENT = 'vnalo:auth-logout'

type AuthProviderProps = {
  children: React.ReactNode
}

export function AuthProvider({ children }: AuthProviderProps) {
  const initialToken = localStorage.getItem(ACCESS_TOKEN_KEY)

  const [user, setUser] = React.useState<AuthUser | null>(null)
  const [accessToken, setAccessToken] = React.useState<string | null>(initialToken)
  const [isBootstrapping, setIsBootstrapping] = React.useState(Boolean(initialToken))

  React.useEffect(() => {
    if (!accessToken) {
      return
    }

    void getMe(accessToken)
      .then((profile) => {
        setUser(profile)
      })
      .catch(() => {
        localStorage.removeItem(ACCESS_TOKEN_KEY)
        setAccessToken(null)
        setUser(null)
      })
      .finally(() => {
        setIsBootstrapping(false)
      })
  }, [accessToken])

  React.useEffect(() => {
    const handleRevoked = () => {
      console.log('[AuthContext] Auth revoked (401/403), logging out...');
      logout();
    };

    window.addEventListener('vnalo:auth:revoked', handleRevoked);
    return () => {
      window.removeEventListener('vnalo:auth:revoked', handleRevoked);
    };
  }, []);

  React.useEffect(() => {
    const handleStorage = (event: StorageEvent) => {
      if (event.key !== ACCESS_TOKEN_KEY) {
        return
      }

      const nextToken = event.newValue
      if (nextToken === accessToken) {
        return
      }

      setAccessToken(nextToken)
      setUser(null)
      setIsBootstrapping(Boolean(nextToken))
    }

    window.addEventListener('storage', handleStorage)
    return () => {
      window.removeEventListener('storage', handleStorage)
    }
  }, [accessToken])

  const login = async (payload: LoginPayload) => {
    const token = await loginApi(payload)
    const profile = await getMe(token)

    localStorage.setItem(ACCESS_TOKEN_KEY, token)
    setAccessToken(token)
    setUser(profile)
    setIsBootstrapping(false)
  }

  const loginWithAccessToken = async (token: string) => {
    const profile = await getMe(token)
    localStorage.setItem(ACCESS_TOKEN_KEY, token)
    setAccessToken(token)
    setUser(profile)
    setIsBootstrapping(false)
  }

  const updateUser = (patch: Partial<AuthUser>) => {
    setUser((prev) => {
      if (!prev) {
        return prev
      }

      return {
        ...prev,
        ...patch,
      }
    })
  }

  const logout = () => {
    localStorage.removeItem(ACCESS_TOKEN_KEY)
    setAccessToken(null)
    setUser(null)
    setIsBootstrapping(false)
    window.dispatchEvent(new CustomEvent(AUTH_LOGOUT_EVENT))
  }

  const value = React.useMemo<AuthContextValue>(
    () => ({
      user,
      accessToken,
      isBootstrapping,
      isAuthenticated: Boolean(accessToken),
      login,
      loginWithAccessToken,
      updateUser,
      logout,
    }),
    [accessToken, isBootstrapping, user],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
