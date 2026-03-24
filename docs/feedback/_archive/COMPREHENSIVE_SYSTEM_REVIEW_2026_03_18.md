# VNALO Comprehensive System Review & Audit Report

**Ngày đánh giá:** 2026-03-18
**Mục đích:** Rà soát toàn diện hệ thống hiện tại, so sánh chi tiết với thiết kế ban đầu, tài liệu dự án và tiến độ công việc.

> Reconcile update (2026-03-19): Một số rủi ro trong bản gốc đã được vá ở code hiện tại: WS room authorization, members endpoint authorization, pin/unpin policy, recall broadcast integrity, delete-for-me authorization, CORS wildcard. Các mục Race Condition `clientMessageId` và fire-and-forget inbox cũng không còn phản ánh đúng trạng thái mới nhất. Rủi ro còn mở chính là anti-abuse throttling cho realtime events.

> Feedback map (2026-03-20):
> - Security/convention canonical: `SECURITY_CONVENTION_AND_ZALO_GAP_REVIEW_2026-03-17.md`
> - Group settings vs Zalo canonical: `GROUP_SETTINGS_ZALO_COMPARISON.md`
> - User search/privacy canonical: `USER_SEARCH_AND_PRIVACY_AUDIT.md`
> - Test evidence canonical: `DEEP_ENTERPRISE_AUDIT_V2_REPORT.md`
> - Các báo cáo còn lại nên xem là historical/supporting để tránh đọc trùng và mâu thuẫn trạng thái.

> Cleanup update (2026-03-20): Đã gộp/thu gọn thư mục feedback để giảm nhiễu đọc tài liệu.
> - Giữ bộ tài liệu trọng tâm: `COMPREHENSIVE_SYSTEM_REVIEW_2026_03_18.md`, `SECURITY_CONVENTION_AND_ZALO_GAP_REVIEW_2026-03-17.md`, `GROUP_SETTINGS_ZALO_COMPARISON.md`, `USER_SEARCH_AND_PRIVACY_AUDIT.md`, `DEEP_ENTERPRISE_AUDIT_V2_REPORT.md`, `PRODUCTION_READINESS.md`, `VNALO_VS_ZALO_COMPARISON.md`.
> - Nội dung từ các báo cáo trùng vai trò đã được hợp nhất về bộ canonical ở trên.

---

## 1. Tổng Quan Kiến Trúc (Architecture Overview)
Hệ thống VNALO được thiết kế theo mô hình **Polyglot Microservices** nhằm phục vụ ứng dụng nhắn tin thời gian thực.
*   **Thiết kế ban đầu:** Gồm `core-service` (Spring Boot), `message-service` (NestJS), `media-service`, `realtime-gateway`, `content-service`, `notification-service`, `moderation-service`, `analytics-service` và `ai-service`.
*   **Thực tế triển khai hiện tại:** 
    *   Đang chạy cực kỳ ổn định 2 service cốt lõi nhất là **`core-service`** (cổng 8081) và **`message-service`** (cổng 8082/3000). 
    *   Hạ tầng cơ sở dữ liệu (Database): **PostgreSQL 16** (Primary DB) và **Redis 7** (Cache, Pub/Sub, Sequence Generator) đang hoạt động trơn tru qua hệ sinh thái Docker.
*   **Đánh giá sự phù hợp:** Kiến trúc hiện tại bám sát 100% tài liệu thiết kế hệ thống (`architecture.md`). Clean Architecture, Separation of Concerns được áp dụng triệt để. Việc tách Service 1 (Java/Auth/Social) và Service 2 (NodeJS/Messaging/Realtime) phát huy hiệu quả tuyệt vời, thể hiện qua độ trễ siêu thấp ở Node.js khi xử lý Message & WebSocket.

## 2. Tiến Độ & Phân Công Công Việc (Team Assignment vs Reality)

Chiếu theo tài liệu `team-assignment.md` và `status.md`:

| Thành viên | Trách nhiệm | Mức độ phức tạp | Hoàn thành thực tế | Đánh giá / Phân tích |
|:---|:---|:---|:---|:---|
| **Dev 1 (Leader)** | core-service, message-service | 🔴 **Rất Cao** (Critical Path) | **100% (60/60 features)** | **Xuất sắc.** Đã gánh vác vòng đời toàn bộ nền tảng cốt lõi (Auth, User, Friends, Messaging 1-1 & Group, WebSocket Gateway nội bộ, CQRS Inbox). Vượt tiến độ đề ra rất xa. Toàn bộ 60 tính năng xương sống đều Passed trong khâu Testing. |
| **Dev 2** | realtime-gateway, media-service | 🔴 **Cao** | **0% (Chưa bắt đầu)** | **Trễ tiến độ.** Đáng lý cần khởi động Media Upload (Cloudinary) ở Tuần 2 nhưng hiện trạng là `Not started`. Việc chưa tách biệt được API WebSocket Gateway cũng khiến toàn bộ tải Realtime bị dồn vào `message-service`. |
| **Dev 3** | content-service (Story/Timeline), notification-service | 🟡 **Trung bình** | **0% (Chưa bắt đầu)** | Mọi chức năng liên quan đến bài đăng, nhật ký và Push Notifications qua Firebase đều chưa được khởi tạo (Dù core-service đã setup sẵn FCM provider). |
| **Dev 4** | moderation-service, analytics, ai-service | 🟡 **Trung bình** | **0% (Chưa bắt đầu)** | Công cụ quản trị Admin và Hệ thống AI Chatbot đều vẫn nằm trên bảng vẽ. |

**Kết luận tiến độ:** Backend đã có một nền móng (Core + Chat) thuộc hàng cực phẩm và sẵn sàng lên Production để cung cấp API. Tuy nhiên, rủi ro lớn nhất của dự án là **Sự mất cân bằng nguồn lực (Bottleneck) khủng khiếp**. Toàn bộ hệ thống hiện tại được sống nhờ nỗ lực 100% của Dev 1, trong khi các mảnh ghép của 3 Dev còn lại đều "trắng tay". Dù có Core tốt nhưng không có UI (Frontend) hay File/Media thì app không thể demo được. 

## 3. Khớp Nối Thiết Kế & Thực Tế (Schema Alignment)

*   **Database Migrations:** Khớp hoàn toàn với tài liệu `database-schema.md`. Đã chạy thành công 11 bước nâng cấp (V1 đến V11) bằng Flyway. Cấu trúc bảng (Entities, ERD) ràng buộc chặt chẽ, foreign keys nguyên vẹn và đã tích hợp idempontency + uniqueness constraints.
*   **Chuẩn Bảo Mật (Authentication):** Triển khai chính xác JWT (HS512) có Shared Secret giữa mọi services. Hash Password an toàn bằng Bcrypt. Đã tích hợp chống vét cạn, rate limit (ví dụ: OTP check), bảo vệ enumerate (không cho lộ lý do lỗi email hay pass sai).
*   **Messaging Patterns Đỉnh Cao (Enterprise Level):** 
    *   Thiết kế sử dụng **Redis INCR** sinh số thứ tự `serverSeq` (monotonically increasing) cho tin nhắn, khắc phục triệt để lỗi Clock Skew (chênh lệch đồng hồ từng server máy con), rập khuôn hệt như thiết kế của WhatsApp/Zalo thật.
    *   Tối ưu hóa Database bằng mô hình CQRS (Command Query Responsibility Segregation) cho Inbox (Tạo riêng bảng phụ `conversation_inbox` dạng denormalized để load danh sách chat siêu tốc `O(1)` thay vì query Join nặng nề).
    *   Sử dụng Idempotent Map: Không cho phép lặp lại việc tạo nhóm chat hoặc lặp Request gửi tin.

## 4. Chất Lượng Kỹ Thuật (Enterprise Tech Audit)

Hệ thống đã trải qua đợt "Deep Enterprise Audit v2" với 125 bài Test Component & 110 bài Test Tích Hợp (End-to-End) có độ khó cao (Setup 5 user song song, DM chéo, Group, Tranh chấp đồng thời 25 tin nhắn/s, Cấu hình chịu tải/Performance limits) và **Passed Toàn Bộ 100%**. Không ghi nhận bất kỳ Fail case nào.

*   **REST API Latency:** Độ trễ trung bình siêu tốt. `P50` chỉ mất khoảng ~13.2ms đến ~23.0ms để phản hồi một HTTP Web Request (Ngang ngửa Golang/Rust).
*   **WebSocket Realtime Latency:** Phân phối tin nhắn Delivery thời gian thực trung bình 9.9ms - 11.2ms (Đỉnh cao của Node Socket.io).
*   **Max Throughput (Sức chịu tải cục bộ):** Gửi 100 tin nhắn qua WS mất vỏn vẹn ~914ms (Tốc độ trên 109 msg/giây). Phản hồi REST chịu tải hỗn hợp khoảng ~65.7 requests/giây. Với một cấu hình Docker Dev Local, đây là thông số thuộc mức "Enterprise".

## 5. So Sánh Tính Năng Với Zalo Product (Competitor GAP Analysis)

Theo cấu trúc review của file `VNALO_VS_ZALO_COMPARISON.md`:

*   **Core Messaging (Nhắn tin cốt lõi):** VNALO đã đạt **Mức độ hoàn thiện 100%** so với Zalo (Hỗ trợ Text thuần, Forward tin, Reply tin, Chỉnh sửa, Thu hồi RECALLED, Bắn Emoji/Reaction siêu tốc, Pin tin nhắn, Phân quyền Đọc Checkmark read receipts, Typing broadcast). Thực sự đáng nể cho một dự án đại học/cá nhân.
*   **Tổng thể toàn App:** VNALO đạt điểm số **~53%** chức năng so với Zalo thật (Sản phẩm hơn 12 năm tuổi của VNG).
*   **Những lỗ hổng tính năng trí mạng (Dealbreakers):**
    1.  **Media Upload (0%):** Không gửi được bất kỳ hình ảnh, file đính kèm, hay đoạn ghi âm nào vì Media Service không tồn tại.
    2.  **WebRTC (0%):** Chưa có hệ thống Voice Call / Video Call.
    3.  **UI/UX Status:** Frontend Flutter (Mobile) hiện đang như một bộ xương (Mới chỉ setup cấu trúc thư mục, Theme UI Sáng Tối, Model hứng Data). Chưa gọi 1 dòng API nào lên Backend, chưa có Màn hình Chat nào hoạt động. 

## 6. Hồ Sơ Rủi Ro Nợ Kỹ Thuật (Technical Debts & Open Risks)

Dù vượt qua bộ Test Enterprise, các rủi ro còn mở nên theo trạng thái reconcile hiện tại:

1.  **🟡 Anti-abuse throttling cho realtime events (Open):** Chưa có throttle/rate-limit hiệu lực cho các event WS như `message.send`, `message.typing`, `message.read`, nên còn cửa flood.
2.  **🟡 Presence broadcast scope (Open):** `presence.changed` vẫn broadcast toàn cục (`server.emit`) thay vì giới hạn theo friend graph hoặc shared conversations.
3.  **🟡 User search/privacy mismatch (Open):** DB đã có `allow_search_by_phone` nhưng entity privacy chưa map field này; contact sync vẫn có nguy cơ bypass kỳ vọng privacy theo số điện thoại.
4.  **🟢 Redis password policy chưa đồng nhất theo profile chạy (Open):** `docker-compose.yml` hỗ trợ `requirepass` dạng optional, còn `docker-compose.infra.yml` vẫn để Redis không password; cần thống nhất policy vận hành.

---
## 7. Tổng Kết & Khuyến Nghị (Actionable Recommendations)

Dự án VNALO sở hữu một lớp Backend Messaging thực sự tinh xảo, chất lượng kiến trúc tiệm cận mức Enterprise, sạch sẽ, testable 100% nhờ nỗ lực phi thường của **Dev 1**. Nhưng toàn bộ bức tranh dự án đang **chết đứng** ở khâu tích hợp và phân mảnh. Đề xuất:

1.  **Tối Cấp Cứu (Urgent) - Frontend Integration:** Tạm gác viển vông về Story/Timeline. Đẩy toàn lực nhân sự ghép API Đăng Nhập / Chat 1-1 / Chat Group vào App Flutter. Nếu không trải nghiệm được bằng mắt, Backend có Test 100% cũng vô nghĩa.
2.  **Tập trung giải cứu Dev 2:** Media Upload (Cloudinary) là xương sống thứ 2 của ứng dụng. Dev 2 phải làm ngay lập tức, nếu quá tải, cần san sẻ cho Dev 3, 4. Không có File/Hình ảnh, không thể gọi là App Chat.
3.  **Vá Lỗ Hổng Kỹ Thuật (Cho Dev 1):** Code thêm 3 dòng Config UNIQUE CONSTRAINT, Async/Await Transaction chặt chẽ cho Inbox Update, và cấm CORS vô tội vạ.
4.  **Tạm hoãn các Service hào nhoáng:** Hạ độ ưu tiên của Timeline (`content-service`), Moderation Tool, tính năng Chatbot AI (Của Dev 4). Hãy đảm bảo Chat Text và Chat Ảnh chạy nuột trên Mobile Phone trước. 
