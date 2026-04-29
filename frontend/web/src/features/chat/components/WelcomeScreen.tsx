import { useLanguage } from '../../../shared/i18n/LanguageContext'
import { Icon } from '../../../shared/components/Icon'

export function WelcomeScreen() {
  const { t } = useLanguage()

  return (
    <div className='welcome-screen'>
      <div className='welcome-screen-content'>
        <div className='welcome-screen-header'>
          <h1>Chào mừng đến với <strong>VNALO PC</strong>!</h1>
          <p>
            Khám phá những tiện ích hỗ trợ làm việc và trò chuyện cùng người thân, 
            bạn bè được tối ưu hóa cho máy tính của bạn.
          </p>
        </div>

        <div className='welcome-screen-illustration'>
          <div className='illustration-main'>
            <div className='illustration-person'>
               {/* This would ideally be a beautiful SVG or Image */}
               <div className='mock-illustration'>
                  <div className='laptop'>
                    <div className='screen'>
                      <div className='chat-lines'>
                        <div className='line short'></div>
                        <div className='line long'></div>
                        <div className='line med'></div>
                      </div>
                    </div>
                    <div className='keyboard'></div>
                  </div>
                  <div className='floating-icons'>
                    <div className='float-icon chat-bubble'><Icon name='chat' size={24} /></div>
                    <div className='float-icon cloud-icon'><Icon name='cloud' size={24} /></div>
                    <div className='float-icon heart-icon'>❤️</div>
                  </div>
               </div>
            </div>
          </div>
        </div>

        <div className='welcome-screen-carousel'>
          <div className='carousel-item'>
            <h3>Nhắn tin nhiều hơn, soạn thảo ít hơn</h3>
            <p>Sử dụng <strong>Tin Nhắn Nhanh</strong> để lưu sẵn các tin nhắn thường dùng và gửi nhanh trong hội thoại bất kỳ.</p>
          </div>
          <div className='carousel-indicators'>
            <span className='indicator active'></span>
            <span className='indicator'></span>
            <span className='indicator'></span>
            <span className='indicator'></span>
            <span className='indicator'></span>
          </div>
        </div>
      </div>
    </div>
  )
}
