# Feedback & Review Report (System Design)

**Scope**: Rà soát và đánh giá lại 2 tài liệu đã cập nhật:
- `OTT_AI_Agent_Project_Docs.md`
- `OTT_Zalo_Complete_Database_Schema.md`

**Mục tiêu**: Đưa ra nhận xét theo góc nhìn *System Design / Backend Architect*, tập trung vào tính nhất quán (single source of truth), correctness của realtime/eventing, data model theo query patterns, khả năng scale/reliability, security/ops, và mức độ implementable.

> Ngày review: **2026-01-15 (GMT+7)**

---

## 1) Executive Summary

Tài liệu đã đạt mức **rất tốt** cho một blueprint OTT Zalo-like: có các quyết định cốt lõi như `serverSeq` per conversation, idempotency theo `clientMessageId`, cursor pagination tách theo use-case, và mô tả realtime gateway + Kafka event contracts đủ để triển khai.

Tuy nhiên vẫn còn một số **P0 issues** có thể làm đội triển khai đi sai hướng hoặc tạo inconsistency về sau, đặc biệt là **ownership của conversation metadata (last message/unread)** và **mâu thuẫn scope (Out-of-scope vs schema)**.

---

## 2) Những cải thiện đáng ghi nhận (So với bản trước)

### 2.1 Đồng bộ hoá “16 services” và bổ sung Backup/Moderation
- Docs kiến trúc đã liệt kê rõ 16 services và mô tả trách nhiệm Backup/Moderation.
- Schema DB có bảng đầy đủ cho Backup (`backup_job`, `restore_job`) và Moderation (`report`, `admin_action_log`, `user_warning`).

**Tác động**: giảm rủi ro “docs nói có nhưng schema thiếu” hoặc ngược lại; tốt cho AI agent khi implement.

### 2.2 Read vs Receipt Strategy rõ ràng hơn
Docs đã viết rule về receipts:
- 1:1 cần tick xanh -> có thể dùng per-message receipt.
- Group lớn -> chỉ dùng cursor-based `last_read_seq` để tránh write amplification.

**Tác động**: hợp lý cho scale, tránh nổ data khi group 1000 thành viên.

---

## 3) P0 Issues (Must Fix trước khi code mạnh)

### P0.1 Mâu thuẫn ownership: D11 (Message Service owns metadata) vs Schema Conversation
**Hiện trạng**
- Docs (D11) khẳng định **Message Service owns**: `last_message`, `last_message_seq`, `unread_count`.
- Nhưng schema `conversation` (Conversation Service) vẫn có các cột: `last_message_seq`, `last_message_at`, `last_message_preview`, `last_message_sender_id`.

**Rủi ro**
- 2 nguồn dữ liệu cho cùng một khái niệm => **double-write**, **race condition**, **event lag** gây inbox lệch.
- Pagination cursor của conversation list dựa vào `last_message_seq` sẽ sai nếu source-of-truth không rõ.

**Khuyến nghị chốt 1 phương án (chỉ 1 source-of-truth)**
1) **CQRS / Inbox read model (khuyến nghị nhất)**
   - Message Service là source-of-truth về message & seq.
   - Emit event `conversation_metadata_updated`.
   - Conversation Service hoặc Inbox Service maintain bảng read-model `conversation_inbox` (1 row per user+conversation) cho list conversation.
2) **Conversation Service owns metadata**
   - Message Service chỉ persist message; event-driven update metadata về Conversation Service.
3) **Tách Inbox Service**
   - Khi hệ thống lớn và read-heavy, tách riêng service phục vụ list inbox.

> **Action**: chọn 1 option và sửa cả docs + schema theo option đó.

---

### P0.2 Mâu thuẫn “Out of Scope” vs schema (OA/Payments/Channel)
**Hiện trạng**
- Docs ghi out-of-scope: Payments, Mini apps, Official Account.
- Nhưng schema chứa:
  - `conversation.type` có `CHANNEL`, `OFFICIAL_ACCOUNT`
  - `qr_code.type` có `PAYMENT`, `OFFICIAL_ACCOUNT`

**Rủi ro**
- Team/AI agent hiểu nhầm là feature đã hỗ trợ, dẫn đến code nửa vời.

**Khuyến nghị**
- Nếu thật sự out-of-scope: remove các enum/values khỏi schema.
- Nếu “reserved for future”: cập nhật docs thành "Reserved (not implemented in Phase X)" và gắn feature flag.

---

### P0.3 PostgreSQL partial index dùng `NOW()` (Story)
Schema có:

```sql
CREATE INDEX idx_story_active ON story(expires_at) WHERE expires_at > NOW();
```

**Vấn đề**
- Predicate phụ thuộc thời gian có thể không hoạt động như mong đợi (planner/index usage), và trong nhiều hệ thống CI/DB policy coi là anti-pattern.

**Khuyến nghị**
- Thay bằng index thường:

```sql
CREATE INDEX idx_story_expires_at ON story(expires_at);
```

- Hoặc thêm cột `is_active` được update bởi job, rồi partial index `WHERE is_active = true`.

---

## 4) P1 Issues (Should Fix sớm để tránh nợ kỹ thuật)

### P1.1 Chuẩn hoá time type: `TIMESTAMPTZ`
Schema hiện dùng `TIMESTAMP` ở nhiều nơi.

**Rủi ro**
- Multi-region / daylight saving / timezone conversion tạo bug khó debug với expiry (story/link) và audit.

**Khuyến nghị**
- Dùng `TIMESTAMPTZ` cho các trường thời gian mang ý nghĩa absolute: `created_at`, `updated_at`, `expires_at`, `seen_at`, `delivered_at`.

### P1.2 Rõ ràng hoá boundary Conversation vs Group
Docs liệt kê Conversation/Group service như 1, nhưng API lại có `/conversations` và `/groups` như 2 service.

**Khuyến nghị**
- Nếu 1 service: gộp endpoint dưới conversation (`/conversations/{id}/members`).
- Nếu 2 service: update danh sách service và ownership rõ ràng.

### P1.3 Safety net cho `serverSeq` (consumer guard)
Docs có cảnh báo rollback risk khi Redis failover nhưng chưa có “hard guard”.

**Khuyến nghị**
- Message Service consumer kiểm tra monotonic: `serverSeq` phải > `last_persisted_seq`.
- Nếu vi phạm: DLQ + alert + quarantine conversation.

---

## 5) P2 (Nice-to-have / Production hardening)

### P2.1 Cassandra hotspot mitigation
Partition theo `conversation_id` có thể hotspot nếu group cực hot.

**Gợi ý**
- Cân nhắc bucketing/time-window (tháng) hoặc adaptive bucketing cho conversation cực nóng.

### P2.2 Event schema evolution & compatibility
Docs có `version` trong envelope nhưng chưa có policy evolve.

**Khuyến nghị**
- Quy tắc backward compatible: chỉ add optional fields, không đổi semantics field cũ.
- Có schema registry (Avro/Protobuf) hoặc JSON schema versioning.

### P2.3 Privacy cho contact sync
Schema lưu `phone_number` dạng plaintext.

**Khuyến nghị**
- Lưu `phone_e164_hash` + `last4`/label, hạn chế plaintext; mã hoá nếu phải giữ.

---

## 6) Đề xuất bản chỉnh sửa tiếp theo (Concrete Next Steps)

### 6.1 Chốt CQRS Inbox Read Model (đề xuất)
Nếu chọn option CQRS, thêm bảng (ở Conversation Service hoặc Inbox Service):

```sql
CREATE TABLE conversation_inbox (
  user_id UUID NOT NULL,
  conversation_id UUID NOT NULL,
  last_message_seq BIGINT NOT NULL DEFAULT 0,
  last_message_at TIMESTAMPTZ,
  last_message_preview VARCHAR(200),
  last_message_sender_id UUID,
  unread_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, conversation_id)
);

CREATE INDEX idx_inbox_user_sort
  ON conversation_inbox(user_id, last_message_seq DESC, conversation_id DESC);
```

**Luồng update**
- Message Service persist message -> update own metadata -> publish `conversation_metadata_updated`.
- Read model consumer upsert vào `conversation_inbox`.

### 6.2 Fix scope mismatch
- Xoá hoặc đánh dấu “reserved” các type `OFFICIAL_ACCOUNT`, `CHANNEL`, `PAYMENT` theo quyết định scope.

### 6.3 Fix story index
- Bỏ partial index `WHERE expires_at > NOW()`.

---

## 7) Kết luận

Tài liệu hiện tại đã đủ mạnh để đội triển khai bắt đầu, nhưng cần xử lý **3 P0 issues** để tránh:
- inconsistency ở inbox/unread,
- scope confusion (OA/Payments),
- bug/anti-pattern trong schema.

Sau khi chốt ownership và sửa schema tương ứng, hệ thống sẽ “đúng kiến trúc” hơn, dễ scale và dễ vận hành.

---

## 8) Checklist hành động (ngắn gọn)

- [x] Chọn ownership metadata (CQRS read model / Conversation owns / Inbox service) → **Chọn CQRS read model**
- [x] Sửa schema conversation: remove/relocate `last_message_*` theo quyết định → **Đã thêm `conversation_inbox` table**
- [x] Đồng bộ docs "Out of Scope" với schema enums → **Đã xóa CHANNEL, OFFICIAL_ACCOUNT, PAYMENT**
- [x] Sửa index story active → **Đã đổi thành `idx_story_expires` không dùng NOW()**
- [x] Chuẩn hoá TIMESTAMPTZ → **Đã áp dụng cho các trường thời gian quan trọng**
- [ ] Thêm consumer guard cho monotonic `serverSeq` → **P1 - triển khai trong code**

> **Updated**: 2026-01-16 - All P0 issues resolved
