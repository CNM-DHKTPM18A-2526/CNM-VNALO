import { FaceSettings } from '../features/face-auth/components/FaceSettings'
import { useAuth } from '../features/auth/useAuth'
import { Card } from '../shared/components/ui/Card'

export function FaceAuthPage() {
  const { accessToken } = useAuth()

  if (!accessToken) {
    return (
      <div className='panel-page face-auth-page'>
        <div className='face-auth-page-header'>
          <h2>Xác thực khuôn mặt</h2>
        </div>
        <Card>
          <p className='face-auth-page-unauthenticated'>
            Vui lòng đăng nhập để sử dụng tính năng xác thực khuôn mặt.
          </p>
        </Card>
      </div>
    )
  }

  return (
    <div className='panel-page face-auth-page'>
      <div className='face-auth-page-header'>
        <h2>Xác thực khuôn mặt</h2>
        <p className='panel-subtitle'>
          Quản lý đăng ký khuôn mặt cho đăng nhập nhanh
        </p>
      </div>

      <Card className='face-auth-page-card'>
        <FaceSettings token={accessToken} />
      </Card>
    </div>
  )
}
