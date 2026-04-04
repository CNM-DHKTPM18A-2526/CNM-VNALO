import { Icon } from '../shared/components/Icon'
import { Card } from '../shared/components/ui/Card'

export function SettingsPage() {
  return (
    <section className='panel-page'>
      <h2>Cài đặt</h2>
      <p className='panel-subtitle'>Tùy chỉnh trải nghiệm thông báo, giao diện và bảo mật tài khoản.</p>
      <div className='settings-grid'>
        <Card as='article' className='settings-card'>
          <h3>
            <span className='settings-icon'>
              <Icon name='bell' />
            </span>
            Thông báo
          </h3>
          <p>Bật/tắt thông báo.</p>
        </Card>
        <Card as='article' className='settings-card'>
          <h3>
            <span className='settings-icon'>
              <Icon name='spark' />
            </span>
            Giao diện
          </h3>
          <p>Tùy chọn mật độ hiển thị và bộ màu theo nhóm.</p>
        </Card>
        <Card as='article' className='settings-card'>
          <h3>
            <span className='settings-icon'>
              <Icon name='settings' />
            </span>
            Bảo mật
          </h3>
          <p>Đổi mật khẩu và quản lý phiên đăng nhập.</p>
        </Card>
      </div>
    </section>
  )
}
