import type { PropsWithChildren } from 'react'
import { Navigate, useLocation } from 'react-router-dom'

import { canAccessAdminMonitoring } from './adminAccess'
import { useAuth } from './useAuth'

export function AdminRoute({ children }: PropsWithChildren) {
  const { accessToken, isBootstrapping, isAuthenticated, user } = useAuth()
  const location = useLocation()

  if (isBootstrapping) {
    return <div className='route-loading'>Đang xác thực phiên đăng nhập...</div>
  }

  if (!isAuthenticated) {
    return <Navigate replace to='/login' state={{ from: location.pathname }} />
  }

  if (!canAccessAdminMonitoring(user, accessToken)) {
    return <Navigate replace to='/chat' />
  }

  return children
}
