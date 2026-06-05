import { Link } from 'react-router-dom'

import { useLanguage } from '../shared/i18n/LanguageContext'
import '../styles/legal.css'

type LegalPageKind = 'terms' | 'privacy'

type LegalSection = {
  title: string
  body: string[]
}

type LegalContent = {
  title: string
  subtitle: string
  summary: string[]
  sections: LegalSection[]
}

const updatedAt = '01/06/2026'

const content: Record<'vi' | 'en', Record<LegalPageKind, LegalContent>> = {
  vi: {
    terms: {
      title: 'Điều khoản sử dụng VNALO',
      subtitle: 'Quy định sử dụng tài khoản, nhắn tin, gọi điện, AI assistant, face-auth và các tính năng cộng đồng trong VNALO.',
      summary: ['Tối thiểu 16 tuổi', 'Không spam/lừa đảo', 'AI chỉ hỗ trợ, người dùng cần kiểm tra lại', 'Face-auth là tùy chọn'],
      sections: [
        {
          title: '1. Tài khoản và điều kiện sử dụng',
          body: [
            'Bạn cần cung cấp thông tin đăng ký chính xác, bảo mật mật khẩu/OTP và chịu trách nhiệm với hoạt động phát sinh từ tài khoản của mình.',
            'VNALO áp dụng yêu cầu độ tuổi tối thiểu 16 tuổi. Nếu phát hiện thông tin không hợp lệ hoặc có rủi ro an toàn, hệ thống có thể yêu cầu xác minh bổ sung.',
          ],
        },
        {
          title: '2. Hành vi được phép và bị cấm',
          body: [
            'Bạn không được sử dụng VNALO để spam, lừa đảo, phát tán mã độc, quấy rối, xâm phạm quyền riêng tư hoặc chia sẻ nội dung vi phạm pháp luật.',
            'Tin nhắn, nhóm, mạng xã hội, cuộc gọi và chia sẻ tệp phải phục vụ mục đích giao tiếp hợp pháp, tôn trọng người dùng khác và không gây quá tải hệ thống.',
          ],
        },
        {
          title: '3. AI assistant và action command',
          body: [
            'AI assistant có thể hỗ trợ soạn thảo, tóm tắt, tìm kiếm, phân tích ảnh hoặc gợi ý thao tác trong ứng dụng. Kết quả AI có thể sai và cần được bạn kiểm tra trước khi sử dụng.',
            'Không nhập mật khẩu, OTP, token, khóa bí mật, dữ liệu sinh trắc học thô hoặc nội dung bạn không có quyền xử lý vào AI assistant.',
            'Các thao tác có rủi ro như tạo nhóm, gửi lời mời, thay đổi dữ liệu hoặc gọi tính năng hệ thống cần được xác nhận rõ ràng trong ứng dụng.',
          ],
        },
        {
          title: '4. Đăng nhập khuôn mặt',
          body: [
            'Face-auth là tính năng tùy chọn, chỉ nên bật trên thiết bị đáng tin cậy. Bạn không được đăng ký hoặc xác thực bằng khuôn mặt của người khác nếu không có sự đồng ý hợp lệ.',
            'VNALO có thể tạm ngừng face-auth khi model chưa sẵn sàng, phát hiện rủi ro bảo mật hoặc dịch vụ xác thực không khả dụng.',
          ],
        },
        {
          title: '5. Xử lý vi phạm và an toàn hệ thống',
          body: [
            'VNALO có thể giới hạn tính năng, khóa phiên, yêu cầu xác minh bổ sung hoặc thu hồi quyền truy cập khi phát hiện gian lận, lạm dụng, rủi ro bảo mật hoặc vi phạm điều khoản.',
          ],
        },
      ],
    },
    privacy: {
      title: 'Chính sách quyền riêng tư VNALO',
      subtitle: 'Mô tả các nhóm dữ liệu VNALO xử lý, mục đích sử dụng, dữ liệu hành vi phục vụ monitoring và các giới hạn bảo vệ dữ liệu nhạy cảm.',
      summary: ['Không hiển thị dữ liệu nhạy cảm trong admin', 'Analytics cần consent phù hợp', 'Face data phải mã hóa', 'Không dùng dữ liệu sinh trắc cho quảng cáo'],
      sections: [
        {
          title: '1. Dữ liệu tài khoản và xác thực',
          body: [
            'VNALO xử lý số điện thoại, email, tên hiển thị, ngày sinh, giới tính, ảnh đại diện, trạng thái tài khoản, phiên đăng nhập, token thiết bị và sự kiện bảo mật để tạo tài khoản, xác thực và bảo vệ người dùng.',
            'Các sự kiện như đăng nhập thành công/thất bại, logout, QR login, OTP, đổi mật khẩu và khóa phiên được ghi nhận để phát hiện rủi ro và hỗ trợ vận hành.',
          ],
        },
        {
          title: '2. Dữ liệu giao tiếp và nội dung',
          body: [
            'Tin nhắn, nhóm, phản ứng, tệp đính kèm, ảnh, video, nhật ký cuộc gọi và trạng thái kết nối được xử lý để cung cấp tính năng chat/gọi theo thời gian thực.',
            'Nội dung tin nhắn hoặc prompt không nên được gửi vào analytics dạng raw nếu không có consent riêng và mục đích xử lý rõ ràng.',
          ],
        },
        {
          title: '3. Dữ liệu hành vi và analytics sản phẩm',
          body: [
            'VNALO có thể ghi nhận phiên sử dụng, thời điểm mở app, thời lượng phiên, màn hình đã xem, tính năng đã dùng, số lượng tin nhắn, lỗi client/API, trạng thái online và mức độ sử dụng theo giờ/ngày/tuần/tháng.',
            'Các chỉ số như người dùng đang hoạt động, DAU/WAU/MAU, session duration p50/p95, screen views, top features, AI success rate, face-auth success rate và error rate nên được tổng hợp để monitoring sản phẩm.',
            'Dữ liệu hành vi dùng cho cải thiện sản phẩm cần được tối thiểu hóa, giới hạn kích thước payload, loại bỏ trường nhạy cảm và tuân thủ lựa chọn consent của người dùng.',
          ],
        },
        {
          title: '4. AI assistant',
          body: [
            'Prompt, phản hồi AI, lịch sử hội thoại AI, action command và lỗi provider có thể được xử lý để trả lời yêu cầu, duy trì ngữ cảnh, kiểm tra độ an toàn và debug lỗi.',
            'VNALO cần lọc bỏ mật khẩu, OTP, token, khóa bí mật và dữ liệu nhạy cảm không cần thiết trước khi lưu log hoặc hiển thị trong dashboard quản trị.',
          ],
        },
        {
          title: '5. Face-auth và dữ liệu sinh trắc',
          body: [
            'Khi bật face-auth, ảnh khuôn mặt hoặc embedding sinh trắc có thể được xử lý để đăng ký và xác minh. Dữ liệu này phải được mã hóa, giới hạn quyền truy cập và không dùng cho quảng cáo.',
            'Admin dashboard chỉ nên hiển thị metadata như modelReady, số lần enroll/verify, tỉ lệ thành công/thất bại và lỗi dịch vụ; không hiển thị ảnh khuôn mặt hoặc embedding thô.',
          ],
        },
        {
          title: '6. Lưu giữ, quyền kiểm soát và minh bạch',
          body: [
            'VNALO nên lưu dữ liệu trong thời hạn cần thiết cho vận hành, bảo mật, nghĩa vụ pháp lý và xử lý tranh chấp, sau đó xóa hoặc ẩn danh theo chính sách retention.',
            'Người dùng nên có khả năng xem/rút consent analytics, cập nhật hồ sơ, thay đổi quyền thiết bị, tắt face-auth và yêu cầu hỗ trợ về dữ liệu cá nhân.',
          ],
        },
      ],
    },
  },
  en: {
    terms: {
      title: 'VNALO Terms of Use',
      subtitle: 'Rules for accounts, messaging, calling, AI assistant, face-auth, and community features in VNALO.',
      summary: ['Minimum age 16', 'No spam or fraud', 'AI assists; users must review', 'Face-auth is optional'],
      sections: [
        { title: '1. Accounts and eligibility', body: ['Provide accurate registration information, protect passwords/OTPs, and remain responsible for activity under your account.', 'VNALO applies a minimum age requirement of 16 years and may request additional verification when risk is detected.'] },
        { title: '2. Acceptable use', body: ['Do not use VNALO for spam, fraud, malware, harassment, privacy violations, or unlawful content.', 'Messages, groups, social posts, calls, and file sharing must be used for lawful communication and must not overload the system.'] },
        { title: '3. AI assistant and action commands', body: ['The AI assistant can draft, summarize, search, analyze images, or suggest in-app actions. AI output can be wrong and should be reviewed before use.', 'Do not enter passwords, OTPs, tokens, secret keys, raw biometric data, or content you are not authorized to process.', 'Risky actions such as creating groups, sending invitations, changing data, or invoking system features require explicit in-app confirmation.'] },
        { title: '4. Face sign-in', body: ['Face-auth is optional and should only be enabled on trusted devices. Do not enroll or verify with another person’s face without valid consent.', 'VNALO may pause face-auth when models are not ready, security risk is detected, or verification services are unavailable.'] },
        { title: '5. Enforcement and safety', body: ['VNALO may limit features, revoke sessions, require additional verification, or remove access when fraud, abuse, security risk, or terms violations are detected.'] },
      ],
    },
    privacy: {
      title: 'VNALO Privacy Policy',
      subtitle: 'Data categories VNALO processes, why they are used, product analytics monitoring, and guardrails for sensitive data.',
      summary: ['No sensitive data in admin dashboards', 'Analytics requires appropriate consent', 'Face data must be encrypted', 'Biometrics are not used for ads'],
      sections: [
        { title: '1. Account and authentication data', body: ['VNALO processes phone number, email, display name, date of birth, gender, avatar, account state, sign-in sessions, device tokens, and security events to create accounts, authenticate users, and protect the service.', 'Login success/failure, logout, QR login, OTP, password change, and session revocation events may be recorded for security monitoring.'] },
        { title: '2. Communication and content data', body: ['Messages, groups, reactions, attachments, images, videos, call logs, and connection state are processed to provide real-time chat and calling.', 'Message content or prompts should not be sent to analytics as raw data without separate consent and a clear processing purpose.'] },
        { title: '3. Behavioral and product analytics', body: ['VNALO may record app sessions, open times, session duration, screens viewed, features used, message counts, client/API errors, online state, and usage intensity by hour/day/week/month.', 'Metrics such as active users, DAU/WAU/MAU, session duration p50/p95, screen views, top features, AI success rate, face-auth success rate, and error rate should be aggregated for product monitoring.', 'Behavioral data for product improvement should be minimized, size-limited, sanitized, and governed by user consent choices.'] },
        { title: '4. AI assistant', body: ['Prompts, AI responses, AI history, action commands, and provider errors may be processed to answer requests, preserve context, enforce safety, and debug failures.', 'VNALO should remove passwords, OTPs, tokens, secret keys, and unnecessary sensitive data before storing logs or showing data in admin dashboards.'] },
        { title: '5. Face-auth and biometric data', body: ['When face-auth is enabled, face images or biometric embeddings may be processed for enrollment and verification. This data must be encrypted, access-limited, and not used for advertising.', 'Admin dashboards should show only metadata such as model readiness, enrollment/verification counts, success/failure rates, and service errors; raw face images or embeddings must not be exposed.'] },
        { title: '6. Retention, controls, and transparency', body: ['VNALO should retain data only as long as needed for operations, security, legal obligations, and dispute handling, then delete or anonymize it according to retention policy.', 'Users should be able to view/withdraw analytics consent, update profile data, change device permissions, disable face-auth, and request support about personal data.'] },
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
        <div className='legal-topbar'>
          <Link className='legal-back-link' to='/register'>← {language === 'vi' ? 'Quay lại đăng ký' : 'Back to register'}</Link>
          <span className='legal-updated'>VNALO · {language === 'vi' ? 'Cập nhật' : 'Updated'} {updatedAt}</span>
        </div>
        <div className='legal-hero'>
          <p className='legal-eyebrow'>{kind === 'terms' ? 'Terms' : 'Privacy'}</p>
          <h1>{page.title}</h1>
          <p className='legal-subtitle'>{page.subtitle}</p>
        </div>
        <div className='legal-summary-grid'>
          {page.summary.map((item) => <span key={item}>{item}</span>)}
        </div>
        <div className='legal-section-list'>
          {page.sections.map((section) => (
            <section className='legal-section' key={section.title}>
              <h2>{section.title}</h2>
              {section.body.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
            </section>
          ))}
        </div>
      </section>
    </main>
  )
}
