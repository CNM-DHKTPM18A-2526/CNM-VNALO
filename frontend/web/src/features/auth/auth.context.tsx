import { useEffect, useMemo, useState } from 'react'

import { getMe, login as loginApi } from './auth.api'
import { AuthContext } from './auth.context-value'
import type { AuthContextValue } from './auth.context-value'
import type { AuthUser, LoginPayload } from './auth.types'

const ACCESS_TOKEN_KEY = 'vnalo_access_token'

type AuthProviderProps = {
  children: React.ReactNode
}

export function AuthProvider({ children }: AuthProviderProps) {
  const initialToken = localStorage.getItem(ACCESS_TOKEN_KEY)

  const [user, setUser] = useState<AuthUser | null>(null)
  const [accessToken, setAccessToken] = useState<string | null>(initialToken)
  const [isBootstrapping, setIsBootstrapping] = useState(Boolean(initialToken))

  useEffect(() => {
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

  const login = async (payload: LoginPayload) => {
    const token = await loginApi(payload)
    const profile = await getMe(token)

    localStorage.setItem(ACCESS_TOKEN_KEY, token)
    setAccessToken(token)
    setUser(profile)
  }

  const loginWithAccessToken = async (token: string) => {
    const profile = await getMe(token)
    localStorage.setItem(ACCESS_TOKEN_KEY, token)
    setAccessToken(token)
    setUser(profile)
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
  }

  const value = useMemo<AuthContextValue>(
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
