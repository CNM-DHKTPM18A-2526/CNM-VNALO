import { Link } from 'react-router-dom'

import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/legal.css'

type LegalPageKind = 'terms' | 'privacy'

type LegalSection = {
  title: string
  body: string[]
}

const updatedAt = '01/06/2026'

const content: Record<'vi' | 'en', Record<LegalPageKind, { title: string; subtitle: string; sections: LegalSection[] }>> = {
  vi: {
    terms: {
      title: 'Điều khoản sử dụng VNALO',
      subtitle: 'Các nguyên tắc sử dụng tài khoản, nhắn tin, gọi điện, AI và đăng nhập khuôn mặt trên VNALO.',
      sections: [
        {
          title: '1. Tài khoản và độ tuổi',
          body: [
            'Bạn cần cung cấp thông tin đăng ký chính xác, bảo mật mật khẩu và chịu trách nhiệm cho hoạt động phát sinh từ tài khoản của mình.',
            'VNALO chỉ cho phép đăng ký khi người dùng đáp ứng yêu cầu độ tuổi tối thiểu đang được áp dụng trong sản phẩm.',
          ],
        },
        {
          title: '2. Hành vi được phép',
          body: [
            'Bạn không được dùng VNALO để spam, lừa đảo, phát tán mã độc, xâm phạm quyền riêng tư, quấy rối hoặc chia sẻ nội dung vi phạm pháp luật.',
            'Các tính năng nhóm, mạng xã hội, cuộc gọi và chia sẻ tệp phải được sử dụng theo đúng mục đích giao tiếp hợp pháp.',
          ],
        },
        {
          title: '3. AI và trợ lý ảo',
          body: [
            'Trợ lý AI có thể hỗ trợ soạn thảo, tóm tắt, tìm kiếm hoặc đề xuất thao tác trong ứng dụng. Bạn cần kiểm tra lại nội dung quan trọng trước khi sử dụng.',
            'Không nhập mật khẩu, mã OTP, khóa bí mật, dữ liệu nhạy cảm hoặc nội dung bạn không có quyền xử lý vào trợ lý AI.',
          ],
        },
        {
          title: '4. Đăng nhập khuôn mặt',
          body: [
            'Đăng nhập khuôn mặt là tính năng tùy chọn. Bạn chỉ nên bật trên thiết bị tin cậy và có quyền tắt/xóa đăng ký khuôn mặt khi sản phẩm cung cấp tùy chọn này.',
            'Bạn không được đăng ký hoặc xác thực bằng khuôn mặt của người khác nếu không có sự đồng ý hợp lệ.',
          ],
        },
        {
          title: '5. Tạm khóa và xử lý vi phạm',
          body: [
            'VNALO có thể giới hạn tính năng, tạm khóa phiên hoặc yêu cầu xác minh bổ sung khi phát hiện rủi ro bảo mật, gian lận hoặc vi phạm điều khoản.',
          ],
        },
      ],
    },
    privacy: {
      title: 'Chính sách quyền riêng tư VNALO',
      subtitle: 'Tóm tắt dữ liệu VNALO xử lý, mục đích sử dụng và các kiểm soát quyền riêng tư quan trọng.',
      sections: [
        {
          title: '1. Dữ liệu tài khoản',
          body: [
            'VNALO xử lý số điện thoại, email, tên hiển thị, ngày sinh, giới tính, ảnh đại diện, trạng thái phiên đăng nhập và thiết bị để tạo tài khoản, xác thực và đồng bộ trải nghiệm.',
          ],
        },
        {
          title: '2. Tin nhắn, media, cuộc gọi và danh bạ',
          body: [
            'Tin nhắn, nhóm, phản ứng, tệp đính kèm, ảnh, video, nhật ký cuộc gọi và trạng thái kết nối được xử lý để cung cấp tính năng chat/gọi theo thời gian thực.',
            'Danh bạ chỉ nên được dùng để gợi ý kết nối khi bạn cấp quyền. Bạn có thể thu hồi quyền danh bạ trong cài đặt hệ thống của thiết bị.',
          ],
        },
        {
          title: '3. AI và lịch sử trợ lý',
          body: [
            'Prompt, phản hồi AI, lịch sử hội thoại AI và các lệnh hành động có thể được xử lý để trả lời, duy trì ngữ cảnh, cải thiện độ ổn định và kiểm tra lỗi.',
            'VNALO không nên ghi log mật khẩu, OTP, token truy cập hoặc nội dung nhạy cảm không cần thiết cho mục đích vận hành.',
          ],
        },
        {
          title: '4. Dữ liệu khuôn mặt',
          body: [
            'Khi bật face-auth, ảnh khuôn mặt/đặc trưng sinh trắc học có thể được xử lý để đăng ký và xác minh. Dữ liệu này cần được bảo vệ bằng mã hóa, giới hạn truy cập và không dùng cho mục đích quảng cáo.',
            'Trạng thái model, lỗi xác thực và số lần thất bại có thể được ghi nhận để bảo mật và chống lạm dụng, nhưng không nên hiển thị dữ liệu sinh trắc học thô trong dashboard admin.',
          ],
        },
        {
          title: '5. Lưu trữ dữ liệu và quyền của bạn',
          body: [
            'VNALO chỉ nên lưu dữ liệu trong thời gian cần thiết cho vận hành, bảo mật, nghĩa vụ pháp lý và xử lý tranh chấp; sau đó cần xóa hoặc ẩn danh theo chính sách nội bộ.',
            'Bạn có quyền yêu cầu hỗ trợ cập nhật hồ sơ, thay đổi quyền thiết bị, vô hiệu hóa face-auth và nhận giải thích về các nhóm dữ liệu đang được xử lý.',
          ],
        },
        {
          title: '6. Giám sát vận hành và quyền của bạn',
          body: [
            'VNALO có thể ghi nhận sự kiện đăng nhập, đăng xuất, QR approval, lỗi dịch vụ, trạng thái push token và sự kiện bảo mật để vận hành hệ thống.',
            'Bạn có thể cập nhật hồ sơ, thay đổi quyền thiết bị và yêu cầu hỗ trợ về dữ liệu cá nhân qua kênh hỗ trợ của dự án.',
          ],
        },
      ],
    },
  },
  en: {
    terms: {
      title: 'VNALO Terms of Use',
      subtitle: 'Rules for using accounts, messaging, calls, AI assistant, and face sign-in on VNALO.',
      sections: [
        {
          title: '1. Account and age',
          body: [
            'You must provide accurate registration information, protect your password, and remain responsible for activity under your account.',
            'VNALO allows registration only when the active product age requirement is satisfied.',
          ],
        },
        {
          title: '2. Acceptable use',
          body: [
            'Do not use VNALO for spam, fraud, malware, privacy violations, harassment, or unlawful content.',
            'Groups, social posts, calls, and file sharing must be used for lawful communication purposes.',
          ],
        },
        {
          title: '3. AI assistant',
          body: [
            'The AI assistant may help draft, summarize, search, or suggest in-app actions. Review important outputs before using them.',
            'Do not enter passwords, OTPs, secret keys, sensitive data, or content you are not authorized to process.',
          ],
        },
        {
          title: '4. Face sign-in',
          body: [
            'Face sign-in is optional. Enable it only on trusted devices and disable/delete enrollment when the product provides that control.',
            'Do not enroll or verify with another person’s face without valid consent.',
          ],
        },
        {
          title: '5. Enforcement',
          body: [
            'VNALO may limit features, revoke sessions, or require additional verification when security, fraud, or terms violations are detected.',
          ],
        },
      ],
    },
    privacy: {
      title: 'VNALO Privacy Policy',
      subtitle: 'A summary of data VNALO processes, why it is used, and important privacy controls.',
      sections: [
        {
          title: '1. Account data',
          body: [
            'VNALO processes phone number, email, display name, date of birth, gender, avatar, session state, and device information to create accounts, authenticate users, and sync the experience.',
          ],
        },
        {
          title: '2. Messages, media, calls, and contacts',
          body: [
            'Messages, groups, reactions, attachments, images, videos, call logs, and connection state are processed to provide real-time chat and calling.',
            'Contacts should only be used for friend suggestions after permission is granted. You can revoke contacts permission in system settings.',
          ],
        },
        {
          title: '3. AI assistant history',
          body: [
            'Prompts, AI responses, AI conversation history, and action commands may be processed to answer requests, preserve context, improve reliability, and debug failures.',
            'VNALO should not log passwords, OTPs, access tokens, or sensitive content that is unnecessary for operations.',
          ],
        },
        {
          title: '4. Face data',
          body: [
            'When face-auth is enabled, face images or biometric embeddings may be processed for enrollment and verification. This data must be encrypted, access-limited, and not used for advertising.',
            'Model readiness, authentication errors, and failed attempts may be recorded for security and abuse prevention, but raw biometric data should not be exposed in admin dashboards.',
          ],
        },
        {
          title: '5. Retention and your rights',
          body: [
            'VNALO should retain data only for the period needed for operations, security, legal obligations, and dispute handling, then delete or anonymize it according to internal policy.',
            'You can request support to update profile data, change device permissions, disable face-auth, and understand which categories of data are being processed.',
          ],
        },
        {
          title: '6. Operations monitoring and your controls',
          body: [
            'VNALO may record login, logout, QR approval, service errors, push token state, and security events to operate the system.',
            'You can update your profile, change device permissions, and request support about personal data through the project support channel.',
          ],
        },
      ],
    },
  },
}

export function LegalPage({ kind }: { kind: LegalPageKind }) {
  const { language } = useLanguage()
  const page = content[language][kind]

  return (
    <main className='legal-page'>
      <section className='legal-card'>
        <Link className='legal-back-link' to='/register'>← {language === 'vi' ? 'Quay lại đăng ký' : 'Back to register'}</Link>
        <p className='legal-eyebrow'>VNALO · {language === 'vi' ? 'Cập nhật' : 'Updated'} {updatedAt}</p>
        <h1>{page.title}</h1>
        <p className='legal-subtitle'>{page.subtitle}</p>
        <div className='legal-section-list'>
          {page.sections.map((section) => (
            <section className='legal-section' key={section.title}>
              <h2>{section.title}</h2>
              {section.body.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </section>
          ))}
        </div>
      </section>
    </main>
  )
}
