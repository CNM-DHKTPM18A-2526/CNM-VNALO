/* eslint-disable react-refresh/only-export-components */
import React from 'react'
import type { FaceStatusResponse, FaceEnrollmentState } from './face-auth.types'

export type FaceAuthContextValue = {
  status: FaceStatusResponse | null
  statusLoading: boolean
  statusError: string | null
  enrollmentState: FaceEnrollmentState
  enrollmentError: string | null
  refreshStatus: () => Promise<void>
}

const FaceAuthContext = React.createContext<FaceAuthContextValue | null>(null)

export function FaceAuthProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = React.useState<FaceStatusResponse | null>(null)
  const [statusLoading, setStatusLoading] = React.useState(false)
  const [statusError, setStatusError] = React.useState<string | null>(null)
  const [enrollmentState] = React.useState<FaceEnrollmentState>('idle')
  const [enrollmentError] = React.useState<string | null>(null)

  const refreshStatus = React.useCallback(async () => {
    setStatusLoading(true)
    setStatusError(null)

    const token = localStorage.getItem('vnalo_access_token')
    if (!token) {
      setStatusLoading(false)
      setStatusError('Vui lòng đăng nhập để quản lý face auth.')
      return
    }

    try {
      const { getFaceStatus } = await import('./face-auth.api')
      const result = await getFaceStatus(token)
      setStatus(result)
    } catch (err) {
      setStatusError(err instanceof Error ? err.message : 'Không thể tải trạng thái face auth.')
    } finally {
      setStatusLoading(false)
    }
  }, [])

  const value = React.useMemo<FaceAuthContextValue>(
    () => ({
      status,
      statusLoading,
      statusError,
      enrollmentState,
      enrollmentError,
      refreshStatus,
    }),
    [status, statusLoading, statusError, enrollmentState, enrollmentError, refreshStatus],
  )

  return <FaceAuthContext.Provider value={value}>{children}</FaceAuthContext.Provider>
}

export function useFaceAuthContext(): FaceAuthContextValue {
  const ctx = React.useContext(FaceAuthContext)
  if (!ctx) {
    throw new Error('useFaceAuthContext must be used within FaceAuthProvider')
  }
  return ctx
}
