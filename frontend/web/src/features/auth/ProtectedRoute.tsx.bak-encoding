import type { PropsWithChildren } from 'react'
import { Navigate, useLocation } from 'react-router-dom'

import { useAuth } from './useAuth'

export function ProtectedRoute({ children }: PropsWithChildren) {
  const { isAuthenticated, isBootstrapping } = useAuth()
  const location = useLocation()

  if (isBootstrapping) {
    return <div className='route-loading'>Đang xác thực phiên đăng nhập...</div>
  }

  if (!isAuthenticated) {
    return <Navigate replace to='/login' state={{ from: location.pathname }} />
  }

  return children
}
