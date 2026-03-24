# Báo cáo Phân tích Cài đặt Nhóm (VNALO vs Zalo)
**Ngày lập báo cáo:** 20/03/2026

Dựa trên các hình ảnh cung cấp về giao diện cài đặt nhóm của Zalo, dưới đây là kết quả kiểm toán (audit) và đối chiếu chi tiết với Schema Database & Backend (message-service) hiện hành của VNALO.

> Reconcile note (2026-03-20): `joinMode`, `allowMemberInvite`, `allowMemberPin`, `allowMemberEditInfo` đã được hỗ trợ qua `PATCH /conversations/{id}` (không có endpoint riêng `/settings`). Tuy nhiên, luồng owner tự rời nhóm vẫn chưa ép chuyển quyền trước khi leave.

---

## 1. Các tính năng VNALO ĐÃ CÓ (Khớp với Zalo)

Hệ thống VNALO đã thiết kế một Entity `Conversation` và `ConversationMember` khá chuẩn mực, cover được các tính năng cơ bản sau từ UI của Zalo:

| Tính năng trên Zalo | Tương ứng trong VNALO (Database Field) | Đánh giá |
| :--- | :--- | :--- |
| **Duyệt thành viên** | `Conversation.joinMode = APPROVAL` | Đã hỗ trợ hoàn chỉnh qua bảng `ConversationJoinRequest`. |
| **Quyền sửa thông tin nhóm** | `Conversation.allowMemberEditInfo` | Đã hỗ trợ phân quyền cho Member. |
| **Quyền ghim tin nhắn** | `Conversation.allowMemberPin` | Đã hỗ trợ chặn/cho phép Member ghim. |
| **Thêm thành viên** | `Conversation.allowMemberInvite` | Đã hỗ trợ chặn Member tự mời người khác. |
| **Xem/Quản lý thành viên** | `ConversationMember.role` (OWNER, ADMIN, MEMBER) | Phân cấp quyền đầy đủ như Trưởng/Phó nhóm. |
| **Ghim trò chuyện** | `ConversationMember.isPinned` | Cài đặt cá nhân, đã có trên Entity. |
| **Ẩn trò chuyện** | `ConversationMember.isHidden` | Cài đặt cá nhân, đã có trên Entity. |
| **Tắt thông báo** | `ConversationMember.notificationSetting` | Hỗ trợ 3 mức: ALL, MENTIONS, NONE. |

---

## 2. Các tính năng VNALO CÒN THIẾU (Gap Analysis)

Để nhóm trên VNALO đạt tới độ chuyên sâu về quản trị và tiện ích như Zalo, hệ thống đang thiếu hụt các tính năng/cấu hình sau (chưa có trường tương ứng trong DB):

### 🚫 A. Tính năng Tin nhắn & Lịch sử
1. **Tin nhắn tự xoá (Auto-delete messages)**
   - **VNALO:** Chưa có. Không có cờ `autoDeleteTimer` trên `Conversation`.
   - **Đề xuất:** Thêm trường cấu hình thời gian tự xoá (ví dụ: 1 ngày, 7 ngày, 30 ngày) cho từng cuộc hội thoại.
2. **Làm nổi tin nhắn từ trưởng và phó nhóm**
   - **VNALO:** Chưa có tính năng đặc quyền UI này cho message.
3. **Thành viên mới xem được tin gửi gần đây**
   - **VNALO:** Nhìn chung VNALO thiết kế theo hướng "Join lúc nào thì xem tin lúc đó" (dựa vào sequence id). Tuy nhiên chưa có nút toggle bật/tắt rõ ràng để cấp quyền xem toàn bộ lịch sử cũ cho thành viên mới vào.

### 🚫 B. Quyền của Thành viên (Member Permissions)
1. **Quyền gửi tin nhắn (Chỉ Trưởng/Phó nhóm mới được chat)**
   - **VNALO:** Chưa có. Bất kỳ ai là `MEMBER` đều có thể chat. Thiếu một cờ như `allowMemberSendMessages`. Tính năng này Zalo dùng rất nhiều cho các nhóm thông báo một chiều.
2. **Quyền tạo ghi chú, nhắc hẹn**
   - **VNALO:** Chưa phát triển Module Notes/Reminders nên không có quyền này.
3. **Quyền tạo bình chọn (Polls)**
   - **VNALO:** Chưa phát triển Module Polls.

### 🚫 C. Logic Quản trị Rời Nhóm / Giải Tán (Trưởng nhóm)
1. **Rời nhóm của Trưởng nhóm**
   - **Thực tế Zalo:** Nếu Trưởng nhóm muốn Rời nhóm (Leave group), hệ thống **bắt buộc** họ phải thực hiện thao tác **Chuyển quyền Trưởng nhóm** cho một thành viên khác trước khi rời rạc. (Ngoại lệ: Nếu nhóm chỉ còn đúng 1 người là Trưởng nhóm thì hành động Rời nhóm sẽ biến thành Xác nhận xóa/giải tán nhóm).
   - **VNALO:** Logic hiện tại cho phép owner gọi `removeMember` lên chính mình (`isSelf`) mà không ép buộc chuyển quyền. Điều này có thể tạo nhóm "vô chủ" (owner-less group) nếu owner rời trước.

### 🚫 D. Tính năng Mở rộng Khác
- **Ảnh, file, link (Media Gallery):** VNALO cần có API để truy xuất nhóm Media theo Conversation (hiện chưa rõ đã hoàn thiện ở tầng Storage chưa).
- **Lịch nhóm:** Chưa có tính năng chia sẻ sự kiện.

---

## 3. Tổng kết & Kiến nghị Ảnh hưởng (Impact Summary)

Nếu dự án quyết định nâng cấp VNALO để **bắt kịp hoàn toàn giao diện Cài đặt nhóm này của Zalo**, cần thực hiện:

- **Mức độ ảnh hưởng Backend (Trung bình):** Cần bổ sung thêm một số cột/field vào bảng `conversation` (như `allow_member_send_messages`, `auto_delete_timer`) và thêm API chuyển quyền owner. Việc này chủ yếu là 1 migration + cập nhật entity/DTO/service.
- **Mức độ ảnh hưởng Tính năng (Lớn):** Các tính năng như **Bình chọn (Polls)** và **Nhắc hẹn (Notes/Reminders)** đòi hỏi đắp thêm 2 module/table hoàn toàn mới vào hệ thống Message Service, tốn nhiều Effort code logic và WebSocket event.
- **Ưu tiên thực hiện (High Priority):** 
  1. Thêm tính năng chặn hội viên chat (Chế độ nhóm thông báo). Rất dễ làm ở Backend (chặn trước khi insert message).
  2. Bổ sung tính năng Tin nhắn tự xoá (Chạy Cronjob ở DB hoặc quy định TTL).
