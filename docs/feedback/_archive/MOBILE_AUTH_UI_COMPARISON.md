# Báo cáo Phân tích Mobile UI: Màn hình Đăng Nhập & Đăng Ký (VNALO vs Zalo)
**Ngày lập báo cáo:** 22/03/2026

> Trang thái tài liệu: Baseline tham chiếu lịch sử (Round 1 Gap Analysis).
> Không dùng tài liệu này làm kết luận cuối cho release.
> Kết luận chính thức hiện tại nằm tại: `docs/feedback/MOBILE_AUTH_QC_REVIEW_REPORT_2026-03-22.md`.

Dựa trên việc đối chiếu 5 ảnh màn hình thực tế của Zalo và tài liệu thiết kế ứng dụng `docs/mobile/MOBILE_IMPLEMENTATION_GUIDE_P3.md`, dưới đây là những đánh giá chi tiết về sự chênh lệch UI/UX.

---

## 1. Phân tích Hiện trạng (Gap Analysis)

### 🚫 A. Thiếu Màn hình Welcome & Onboarding (Trang bìa)
- **Thực tế Zalo (Ảnh 1 & 2 & 3):** Zalo có hẳn một **Welcome Screen** rất chỉn chu.
  + Có **Language Selector** (chọn Tiếng Việt / English) ở góc phải trên.
  + Có **Carousel Header** (các slide vuốt ngang giới thiệu tính năng "Gọi video ổn định", "Chat nhóm tiện ích").
  + Chỉ có 2 nút to dưới cùng: Đăng nhập (Xanh) & Tạo tài khoản mới (Xám).
- **VNALO Mobile Guide (`main.dart` & `splash_screen.dart`):** Bỏ qua hoàn toàn màn hình giao tiếp đầu tiên này. Cấu trúc hiện tại là `SplashScreen` load xong sẽ ném người dùng văng thẳng vào `LoginScreen`. Điều này làm giảm trải nghiệm Premium của người dùng mới (First-time User Experience).

### 🚫 B. Luồng Đăng nhập (Login Flow) bị Mắc kẹt ở thiết kế cũ
- **Thực tế Zalo (Ảnh 4):** Áp dụng thiết kế **Wizard-based (Từng bước một)**. Màn hình đầu tiên cực kỳ tối giản, chỉ yêu cầu "Nhập số điện thoại" và bấm "Tiếp tục". (Sau đó Zalo mới chuyển sang màn hình nhập Mật khẩu ở step 2).
- **VNALO Mobile Guide (`login_screen.dart`):** Áp dụng thiết kế **Form-based (Mào đầu tất cả)**. VNALO đang dồn cả 1 cụm khổng lồ gồm: Logo + Input SDT + Input Password + Nút Quên mật khẩu + Nút Đăng ký vào *Cùng Một Màn Hình*. Thiết kế này khá chật chội và không hiện đại bằng Zalo.

### 🚫 C. Thiếu Xác minh Pháp lý (Terms of Service) ở Luồng Đăng ký
- **Thực tế Zalo (Ảnh 5):** Khi người dùng muốn Đăng ký, ngay dưới ô nhập Số điện thoại có 2 **Checkbox Bắt Buộc**: "Tôi đồng ý với các điều khoản sử dụng Zalo" và "điều khoản Mạng xã hội". Nút "Tiếp tục" chỉ sáng lên khi user đã tick đồng ý.
- **VNALO Mobile Guide (`register_screen.dart` -> `_buildPhoneStep`):** Hoàn toàn **KHÔNG CÓ** checkbox Điều khoản sử dụng. Đây là một rủi ro cực lớn về Legal Compliance (Tuân thủ Pháp luật) nếu ứng dụng VNALO đước Release lên Apple App Store / Google Play.

### 🚫 D. Cấu trúc Điều hướng Phụ (Bottom Context Menu)
- **Thực tế Zalo:** Luôn có dòng text phụ ngay sát cạnh tren của bàn phím ảo (Nằm dưới nút Tiếp tục): "Bạn chưa có tài khoản? Tạo tài khoản" hoặc "Bạn đã có tài khoản? Đăng nhập ngay". Giúp user chuyển đổi qua lại mượt mà.
- **VNALO:** Đang dùng 1 nút OutlinedButton siêu to `[ĐĂNG KÝ TÀI KHOẢN MỚI]` đặt dưới cùng dòng Login, chiếm nhiều không gian. Nó không bám sát Bottom Edge như Zalo.

---

## 2. Kế hoạch Cải tiến Hệ thống (Implementation Recommendations)

### Giai đoạn 1: Bổ sung lớp Welcome Screen
- Tạo mới file `lib/features/auth/screens/welcome_screen.dart`.
- Màn hình này sẽ hiển thị Zalo/VNALO Carousel, Nút Language (Drop down switch Locale), sau đó đẩy sang `LoginScreen` hoặc `RegisterScreen`. Sửa logic ở `splash_screen.dart` để trỏ vào `WelcomeScreen` thay vì `LoginScreen`.

### Giai đoạn 2: Tách đôi màn hình Login (Wizard Flow)
- Sửa lại `LoginScreen`: Chỉnh UI chỉ có 1 trường là `PhoneInput` -> Bấm Next -> Sang màn hình `LoginPasswordScreen` (chứa avatar + trường nhập pass). Thiết kế giống hệt tài liệu Zalo mô phỏng.

### Giai đoạn 3: Update Legal Requirements cho Resgiter
- Mở `register_screen.dart`, tại `_buildPhoneStep`:
  + Bổ sung 2 widget `CheckboxListTile` cho Privacy Policy và Terms of Service.
  + Nối validation của Nút "Tiếp tục" với trạng thái check của 2 ô này (Chỉ bật khi cả 2 ô là True).

> **Lời kết:** Backend hiện tại không cần thay đổi gì cho các việc này, đây 100% là công việc Refactor UI của tầng Flutter App.
