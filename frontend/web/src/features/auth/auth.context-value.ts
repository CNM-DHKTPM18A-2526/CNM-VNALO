import React from 'react'

import type { AuthUser, LoginPayload } from './auth.types'

export type AuthContextValue = {
  user: AuthUser | null
  accessToken: string | null
  isBootstrapping: boolean
  isAuthenticated: boolean
  login: (payload: LoginPayload) => Promise<void>
  loginWithAccessToken: (token: string) => Promise<void>
  updateUser: (patch: Partial<AuthUser>) => void
  logout: () => void
}

export const AuthContext = React.createContext<AuthContextValue | null>(null)
