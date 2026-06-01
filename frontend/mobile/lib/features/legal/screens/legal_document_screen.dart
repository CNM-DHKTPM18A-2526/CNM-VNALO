
import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final doc = type.content;
    final textColor = isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary;
    final mutedColor = isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;
    final cardColor = isDarkMode ? const Color(0xFF111827) : Colors.white;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(doc.title),
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              doc.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              doc.subtitle,
              style: TextStyle(fontSize: 15, height: 1.55, color: mutedColor),
            ),
            const SizedBox(height: 10),
            Text(
              doc.updatedLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
            ),
            const SizedBox(height: 18),
            for (final section in doc.sections) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode ? DarkColors.divider : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final paragraph in section.body) ...[
                      Text(
                        paragraph,
                        style: TextStyle(fontSize: 14.5, height: 1.6, color: mutedColor),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum LegalDocumentType { terms, privacy }

extension on LegalDocumentType {
  _LegalDocumentContent get content {
    switch (this) {
      case LegalDocumentType.terms:
        return const _LegalDocumentContent(
          title: 'Điều khoản sử dụng VNALO',
          subtitle: 'Các nguyên tắc dùng tài khoản, nhắn tin, cuộc gọi, AI và đăng nhập khuôn mặt trong VNALO.',
          updatedLabel: 'Cập nhật: 01/06/2026',
          sections: [
            _LegalSection(
              title: '1. Tài khoản và trách nhiệm',
              body: [
                'Bạn cần cung cấp thông tin đăng ký chính xác, giữ an toàn cho mật khẩu và chịu trách nhiệm với hoạt động phát sinh từ tài khoản của mình.',
                'VNALO có thể yêu cầu xác minh bổ sung hoặc tạm giới hạn tính năng khi phát hiện bất thường bảo mật.',
              ],
            ),
            _LegalSection(
              title: '2. Hành vi sử dụng',
              body: [
                'Không dùng VNALO để spam, lừa đảo, phát tán mã độc, quấy rối hoặc chia sẻ nội dung vi phạm pháp luật.',
                'Các tính năng nhóm, mạng xã hội, chia sẻ tệp và cuộc gọi phải được dùng cho mục đích giao tiếp hợp pháp.',
              ],
            ),
            _LegalSection(
              title: '3. AI và trợ lý ảo',
              body: [
                'Trợ lý AI chỉ hỗ trợ gợi ý, soạn thảo và thao tác trong ứng dụng. Bạn cần tự kiểm tra lại nội dung quan trọng trước khi sử dụng.',
                'Không nhập mật khẩu, OTP, token truy cập hoặc dữ liệu bí mật không cần thiết vào AI.',
              ],
            ),
            _LegalSection(
              title: '4. Đăng nhập khuôn mặt',
              body: [
                'Face-auth là tính năng tùy chọn và chỉ nên bật trên thiết bị đáng tin cậy.',
                'Bạn không được dùng dữ liệu khuôn mặt của người khác nếu chưa có sự đồng ý hợp lệ.',
              ],
            ),
          ],
        );
      case LegalDocumentType.privacy:
        return const _LegalDocumentContent(
          title: 'Chính sách quyền riêng tư VNALO',
          subtitle: 'Tóm tắt các nhóm dữ liệu được xử lý, mục đích sử dụng và giới hạn hiển thị dữ liệu nhạy cảm.',
          updatedLabel: 'Cập nhật: 01/06/2026',
          sections: [
            _LegalSection(
              title: '1. Dữ liệu tài khoản',
              body: [
                'VNALO xử lý số điện thoại, email, tên hiển thị, ngày sinh, giới tính, ảnh đại diện và thiết bị để đăng ký, xác thực và đồng bộ trải nghiệm.',
              ],
            ),
            _LegalSection(
              title: '2. Danh bạ, tin nhắn, media và cuộc gọi',
              body: [
                'Danh bạ chỉ nên được dùng khi bạn cấp quyền để gợi ý kết nối.',
                'Tin nhắn, media, phản ứng, nhóm và nhật ký cuộc gọi được xử lý để cung cấp tính năng chat/gọi theo thời gian thực.',
              ],
            ),
            _LegalSection(
              title: '3. Dữ liệu AI và dữ liệu khuôn mặt',
              body: [
                'Prompt, phản hồi AI, lịch sử hội thoại AI và lệnh hành động có thể được xử lý để trả lời và giữ ngữ cảnh.',
                'Khi bật face-auth, ảnh khuôn mặt hoặc embedding sinh trắc học có thể được xử lý cho đăng ký/xác thực và cần được mã hóa, giới hạn truy cập.',
              ],
            ),
            _LegalSection(
              title: '4. Lưu trữ dữ liệu và quyền của bạn',
              body: [
                'VNALO chỉ nên giữ dữ liệu trong thời gian cần thiết cho vận hành, bảo mật và nghĩa vụ pháp lý, sau đó cần xóa hoặc ẩn danh theo chính sách nội bộ.',
                'Bạn có thể yêu cầu hỗ trợ cập nhật hồ sơ, đổi quyền thiết bị hoặc vô hiệu hóa face-auth nếu sản phẩm hỗ trợ.',
              ],
            ),
            _LegalSection(
              title: '5. Giám sát vận hành và quyền kiểm soát',
              body: [
                'VNALO có thể ghi nhận sự kiện đăng nhập, đăng xuất, QR approval, lỗi dịch vụ và trạng thái push token để vận hành hệ thống.',
                'Dashboard admin không nên hiển thị mật khẩu, OTP, token hoặc dữ liệu sinh trắc học thô.',
              ],
            ),
          ],
        );
    }
  }
}

class _LegalDocumentContent {
  final String title;
  final String subtitle;
  final String updatedLabel;
  final List<_LegalSection> sections;

  const _LegalDocumentContent({
    required this.title,
    required this.subtitle,
    required this.updatedLabel,
    required this.sections,
  });
}

class _LegalSection {
  final String title;
  final List<String> body;

  const _LegalSection({required this.title, required this.body});
}
