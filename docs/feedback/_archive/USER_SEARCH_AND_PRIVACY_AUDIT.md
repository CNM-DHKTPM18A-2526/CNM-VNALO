# Báo cáo Phân tích & Đánh giá Hệ thống Tìm kiếm Người dùng (VNALO vs Zalo)
**Ngày lập báo cáo:** 19/03/2026

> Document role (2026-03-20): Đây là tài liệu canonical cho mảng user-search/privacy trong thư mục feedback.

## 1. Tóm tắt Kiểm toán (Audit Summary)

Dựa trên việc đối chiếu với cơ chế thực tế của Zalo, hệ thống Tìm kiếm Người dùng của VNALO hiện tại đang thiêng về hướng "Mạng xã hội mở" (Open Social Network) hơn là nền tảng nhắn tin bảo mật, riêng tư. Cụ thể:

1. **Tìm bằng Số điện thoại (Chính xác nhất trên Zalo):** **Thiếu sót.** VNALO hiện không có API công khai (`/api/users/search-by-phone`) để hỗ trợ tìm một cá nhân cụ thể thông qua số điện thoại. Sự liên kết qua số điện thoại hiện chỉ xảy ra ngầm trong lúc Đồng bộ danh bạ.
2. **Tìm bằng Zalo ID / Username:** **Không tồn tại.** Hệ thống không lưu trữ Username; hoàn toàn sử dụng định danh `UUID`.
3. **Tìm bằng Tên (Bị giới hạn trên Zalo):** **Mở hoàn toàn.** API `GET /users/search?keyword=` đang quét toàn bộ cơ sở dữ liệu (Wildcard Name Search), cho phép bất kỳ ai tìm thấy bất kỳ ai. Trái ngược hoàn toàn với tiêu chí ưu tiên bạn bè/người quen của Zalo.
4. **Gợi ý từ Danh bạ:** **Khá tốt.** Tính năng `ContactSyncService` đã hỗ trợ đồng bộ và tìm kiếm bạn bè thông qua `AuthAccountRepository.findByPhone`.
5. **Cấu hình Quyền riêng tư (Privacy Settings):** **Không đồng bộ.** Database (Flyway `V7__schema_improvements.sql`) đã định nghĩa cột `allow_search_by_phone BOOLEAN DEFAULT TRUE`. Tuy nhiên, mã nguồn Java của Entity `UserPrivacySetting.java` lại **bỏ quên** (không map) trường này. Do VNALO chưa có API tìm bằng số điện thoại, nên trường này thực chất đang ở trạng thái "orphaned" (chết). Nó cũng chưa được áp dụng để chặn việc rò rỉ danh tính khi một người thực hiện "Đồng bộ danh bạ".

---

## 2. Kế hoạch Thay đổi Hệ thống (System Change Requirements)

Nếu định hướng của VNALO là **tuân thủ chặt chẽ triết lý bảo mật & riêng tư của Zalo**, hệ thống bắt buộc phải thay đổi các luồng chức năng cốt lõi sau:

### Thay đổi 1: Bổ sung API "Tìm kiếm bằng số điện thoại"
- Xây dựng API mới: `GET /users/phone/{phoneNumber}` trong `core-service/UserController`.
- API này chỉ thực hiện truy vấn **Exact Match** (khớp chính xác) xuống bảng `AuthAccount`.
- API không được phép trả về tài khoản nếu người dùng đó đã tắt "Cho phép tìm kiếm qua số điện thoại".

### Thay đổi 2: Hạn chế/Quy hoạch lại API "Tìm kiếm bằng Tên"
- Dỡ bỏ cấu trúc Wildcard Public Search hiện tại của `GET /users/search`.
- Đổi logic để API này **chỉ ưu tiên trả về** những người: (A) Đang là bạn bè, (B) Đã từng có hội thoại, hoặc (C) Đã nằm trong danh sách đồng bộ danh bạ.

### Thay đổi 3: Khôi phục cấu hình Privacy `allow_search_by_phone`
- Cập nhật Data Entity `UserPrivacySetting.java` để map với cột `allow_search_by_phone`.
- Bổ sung logic kiểm tra cờ này vào 2 vị trí trọng yếu:
  + API "Tìm theo số điện thoại" (Thất bại / Not Found nếu cờ = false).
  + Luồng `ContactSyncService` (Không tự động match nếu người kia đặt cờ = false).

---

## 3. Mức độ Ảnh hưởng (Impact Readiness)

Việc dịch chuyển từ "Mạng xã hội mở" sang "Nền tảng nhắn tin kín" đòi hỏi thiết kế lại luồng Frontend và điều chỉnh Core Backend. 

| Hệ thống / Component | Mức độ | Chi tiết Ảnh hưởng & Rủi ro Cần xử lý |
| -------------------- | ------ | ------------------------------------- |
| **Java Core Service**| Cao    | Cần sửa đổi `UserController`, `UserService`, `ContactSyncService`, `UserPrivacySetting.java`. Rủi ro thấp vì Schema DB (`V7__schema_improvements.sql`) đã có sẵn cột. Chỉ là bổ sung code. |
| **Frontend (Web/App)**| Cao    | **Break Thay Đổi Lớn:** Khung tìm kiếm ở header của Frontend hiện tại (nếu đang dùng API search name) sẽ phải làm lại UI. Cần bổ sung UI "Nhập số điện thoại để kết bạn" thay vì nhập một cái tên chung chung. Cần bổ sung nút toggle (bật/tắt tìm kiếm SĐT) trong phần Cài đặt Quyền riêng tư. |
| **User Experience (UX)**| Trung bình | Người dùng sẽ cảm nhận ngay sự "đóng" của hệ thống (giống Zalo), không thể tìm thấy vô số đối tượng qua tên nữa, mà bị bắt buộc phải có thông tin liên lạc rõ ràng (SĐT). |
| **Bảo mật (Security)**| Rất Tốt| Khắc phục triệt để lỗ hổng cho phép "quét tên người đăng ký" hàng loạt. Gắn bảo mật chặt vào ý thức đăng ký của người dùng cuối. |

### Lời Khuyên Hành Động Cuối Cùng (Next Steps)
Cần lên kế hoạch Sprint để (1) Cập nhật Java Entity `UserPrivacySetting`, (2) Triển khai API Exact Phone Search, và (3) Sửa lại UI Global Search trên Client của VNALO để bắt kịp thực tế này.
