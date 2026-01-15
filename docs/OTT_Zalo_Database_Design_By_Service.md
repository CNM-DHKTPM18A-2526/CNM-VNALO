# Tài liệu Thiết kế Database theo Service — Hệ thống OTT giả lập Zalo (Spring Boot + React Native)

> ⚠️ **DEPRECATED**: Tài liệu này đã được thay thế bởi [OTT_Zalo_Complete_Database_Schema.md](./OTT_Zalo_Complete_Database_Schema.md) với đầy đủ 16 services và 60 tables.

> **Mục đích**: Tài liệu dữ liệu (data dictionary) theo từng **service** cho hệ thống OTT (nhắn tin thời gian thực) mô phỏng Zalo. Tài liệu này được viết để **AI Agent** hoặc thành viên dự án có thể tra cứu nhanh cấu trúc dữ liệu, ràng buộc, index gợi ý và luồng liên kết giữa các service.
>
> **Lưu ý**: Tài liệu **không chứa script SQL**. Các kiểu dữ liệu là **gợi ý** (logical schema), có thể ánh xạ sang MySQL/PostgreSQL theo lựa chọn dự án.

---

## 1) Tổng quan kiến trúc dữ liệu theo service

### 1.1 Nguyên tắc tách service (microservice-ready)
- **Database-per-service** (mỗi service sở hữu dữ liệu của mình).
- **Không dùng khóa ngoại (FK) xuyên service** để tránh phụ thuộc chặt.
- Khi cần tham chiếu dữ liệu service khác, chỉ lưu **ID tham chiếu** (ví dụ: `userId`, `conversationId`, `mediaId`) và đồng bộ qua **event**.

### 1.2 Chuẩn hóa chung
**ID**
- Khuyến nghị: `UUID` (string) hoặc `BIGINT` (Snowflake/Sequence).
- Với bảng tin nhắn, `BIGINT` tăng dần thường thuận lợi cho phân trang.

**Thời gian & audit**
- Dùng UTC cho timestamp.
- Field chuẩn: `createdAt`, `updatedAt`, (tuỳ chọn) `deletedAt`.

**Trạng thái (status)**
- Dùng enum/string ngắn cho trạng thái: `ACTIVE`, `LOCKED`, `DISABLED`, `DELETED`, ...

### 1.3 Quy ước index (gợi ý)
- Bảng có phân trang theo thời gian: index theo `(ownerId, createdAt)`.
- Lịch sử chat: index theo `(conversationId, messageId)` hoặc `(conversationId, sentAt)`.
- Các bảng mapping nhiều-nhiều: index theo cả 2 chiều (ví dụ: `userId` và `conversationId`).

---

## 2) Bản đồ liên kết ID giữa các service (ID Map)

- **Auth Service**: `accountId`
- **User Profile Service**: `userId` (thường = `accountId` hoặc mapping riêng)
- **Social Graph Service**: dùng `userId`
- **Conversation Service**: `conversationId`, thành viên dùng `userId`
- **Messaging Service**: `messageId`, `conversationId`, `senderId`, (tuỳ) `mediaId`
- **Media Service**: `mediaId`, `ownerUserId`
- **Notification Service**: `notificationId`, `deviceId`, `userId`
- **Moderation Service**: `reportId`, `targetType`, `targetId`

> **Nguyên tắc**: service khác chỉ biết “ID” chứ không join trực tiếp dữ liệu bảng của nhau.

---

## 3) Identity / Auth Service

### Mục tiêu
- Đăng ký/đăng nhập/đăng xuất
- Quản lý mật khẩu, refresh token
- OTP (nếu mô phỏng)
- Theo dõi thiết bị đăng nhập (device)

### 3.1 Bảng: `auth_account`
| Field | Kiểu gợi ý | Mô tả / Ràng buộc |
|---|---|---|
| `accountId` (PK) | UUID/BIGINT | định danh tài khoản |
| `loginType` | ENUM | `PHONE` / `EMAIL` / `USERNAME` |
| `phone` | string | unique, nullable nếu dùng email |
| `email` | string | unique, nullable nếu dùng phone |
| `username` | string | unique, optional |
| `passwordHash` | string | hash mật khẩu (BCrypt/Argon2) |
| `passwordUpdatedAt` | timestamp | phục vụ revoke phiên |
| `status` | ENUM | `ACTIVE` / `LOCKED` / `DISABLED` |
| `lockedUntil` | timestamp | nullable |
| `failedLoginCount` | int | đếm nhập sai |
| `lastLoginAt` | timestamp | nullable |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

**Ràng buộc/Quy tắc**
- Unique: `phone`, `email`, `username`.
- Khi `status=LOCKED`, hệ thống từ chối đăng nhập đến khi `lockedUntil` hết hạn.

**Index gợi ý**
- `status`, `lastLoginAt`.

### 3.2 Bảng: `auth_refresh_token`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `tokenId` (PK) | UUID | |
| `accountId` | UUID/BIGINT | tham chiếu logic đến `auth_account` |
| `tokenHash` | string | lưu hash refresh token (không lưu token thô) |
| `deviceId` | string | định danh thiết bị |
| `ip` | string | nullable |
| `userAgent` | string | nullable |
| `expiresAt` | timestamp | |
| `revokedAt` | timestamp | nullable |
| `createdAt` | timestamp | |

**Index gợi ý**
- Unique: `tokenHash`.
- `(accountId, expiresAt)`.

### 3.3 Bảng: `auth_otp` (tuỳ chọn)
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `otpId` (PK) | UUID | |
| `target` | string | phone/email |
| `purpose` | ENUM | `REGISTER` / `RESET_PASSWORD` / `LOGIN` |
| `otpHash` | string | hash OTP |
| `expiresAt` | timestamp | |
| `attempts` | int | số lần nhập sai |
| `verifiedAt` | timestamp | nullable |
| `createdAt` | timestamp | |

---

## 4) User Profile Service

### Mục tiêu
- Quản lý hồ sơ hiển thị (displayName, avatar)
- Cài đặt riêng tư (privacy)

### 4.1 Bảng: `user_profile`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `userId` (PK) | UUID/BIGINT | định danh người dùng |
| `displayName` | string | tên hiển thị |
| `avatarUrl` | string | URL ảnh đại diện |
| `coverUrl` | string | nullable |
| `bio` | string | nullable |
| `gender` | ENUM | `UNKNOWN/MALE/FEMALE/OTHER` |
| `dob` | date | nullable |
| `region` | string | nullable |
| `statusMessage` | string | nullable |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

**Index gợi ý**
- `displayName` (tuỳ DB có thể dùng full-text).

### 4.2 Bảng: `user_privacy_setting`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `userId` (PK) | UUID/BIGINT | |
| `allowSearchByPhone` | boolean | |
| `allowSearchByEmail` | boolean | |
| `allowStrangerMessage` | boolean | cho người lạ nhắn |
| `allowFriendRequest` | boolean | |
| `lastSeenVisibility` | ENUM | `EVERYONE/FRIENDS/NOBODY` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

---

## 5) Social Graph Service (Bạn bè / Lời mời / Chặn)

### Mục tiêu
- Gửi lời mời kết bạn
- Chấp nhận/từ chối
- Danh sách bạn bè
- Chặn/bỏ chặn

### 5.1 Bảng: `friend_request`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `requestId` (PK) | UUID | |
| `fromUserId` | UUID | người gửi |
| `toUserId` | UUID | người nhận |
| `message` | string | lời nhắn kèm, nullable |
| `status` | ENUM | `PENDING/ACCEPTED/DECLINED/CANCELED` |
| `respondedAt` | timestamp | nullable |
| `createdAt` | timestamp | |

**Ràng buộc**
- Tránh spam: unique logic cho cặp `(fromUserId, toUserId)` khi `status=PENDING`.

**Index gợi ý**
- `(toUserId, status, createdAt)` — tải “lời mời đến”.
- `(fromUserId, createdAt)` — tải “lời mời đã gửi”.

### 5.2 Bảng: `friendship`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `friendshipId` (PK) | UUID | |
| `userId1` | UUID | user nhỏ hơn theo quy ước |
| `userId2` | UUID | user lớn hơn theo quy ước |
| `source` | ENUM | `SEARCH/QR/CONTACT_IMPORT` |
| `createdAt` | timestamp | ngày thành bạn |

**Ràng buộc**
- Unique `(userId1, userId2)` theo quy ước min/max.

**Index gợi ý**
- `userId1`, `userId2`.

### 5.3 Bảng: `block_list`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `blockId` (PK) | UUID | |
| `blockerId` | UUID | người chặn |
| `blockedId` | UUID | bị chặn |
| `reason` | string | nullable |
| `createdAt` | timestamp | |

**Ràng buộc**
- Unique `(blockerId, blockedId)`.

---

## 6) Conversation Service (Hội thoại & thành viên)

### Mục tiêu
- Quản lý hội thoại `DIRECT` và `GROUP`
- Quản lý thành viên nhóm, vai trò, mute/pin
- Tối ưu tìm hội thoại 1-1

### 6.1 Bảng: `conversation`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `conversationId` (PK) | UUID | |
| `type` | ENUM | `DIRECT/GROUP` |
| `title` | string | tên nhóm, nullable nếu DIRECT |
| `avatarUrl` | string | nullable |
| `createdBy` | UUID | user tạo |
| `status` | ENUM | `ACTIVE/DISABLED` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

### 6.2 Bảng: `conversation_member`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `conversationId` (PK*) | UUID | |
| `userId` (PK*) | UUID | |
| `role` | ENUM | `OWNER/ADMIN/MEMBER` |
| `nickname` | string | nullable |
| `joinedAt` | timestamp | |
| `leftAt` | timestamp | nullable |
| `muteUntil` | timestamp | nullable |
| `isPinned` | boolean | ghim hội thoại |
| `pinOrder` | int | nullable |
| `lastReadMessageId` | UUID/BIGINT | cursor đọc gần nhất |
| `lastReadAt` | timestamp | nullable |

> PK* là khoá chính kép `(conversationId, userId)`.

**Index gợi ý**
- `(userId, joinedAt)` — tải danh sách hội thoại của user.
- `(conversationId)` — tải danh sách thành viên.

### 6.3 Bảng: `conversation_direct_map` (tối ưu 1-1)
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `userId1` | UUID | min(userId) |
| `userId2` | UUID | max(userId) |
| `conversationId` | UUID | hội thoại DIRECT tương ứng |
| `createdAt` | timestamp | |

**Ràng buộc**
- Unique `(userId1, userId2)`.

---

## 7) Messaging Service (Tin nhắn & trạng thái)

### Mục tiêu
- Lưu tin nhắn
- Phân trang lịch sử
- Receipt (delivered/seen) hoặc cursor đọc

### 7.1 Bảng: `message`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `messageId` (PK) | UUID/BIGINT | nên tăng dần nếu BIGINT |
| `conversationId` | UUID | |
| `senderId` | UUID | |
| `type` | ENUM | `TEXT/IMAGE/FILE/VOICE/SYSTEM` |
| `contentText` | text | nullable nếu media |
| `mediaId` | UUID | nullable, tham chiếu logic sang Media Service |
| `replyToMessageId` | UUID/BIGINT | nullable |
| `clientMessageId` | string | idempotency key (chống gửi trùng) |
| `status` | ENUM | `SENT/DELETED/REVOKED` |
| `sentAt` | timestamp | |
| `createdAt` | timestamp | |

**Ràng buộc**
- Unique logic: `(conversationId, clientMessageId)` để chống retry tạo bản ghi trùng.

**Index gợi ý (rất quan trọng)**
- `(conversationId, messageId)` hoặc `(conversationId, sentAt)`.
- `(senderId, sentAt)`.

### 7.2 Bảng: `message_receipt` (tuỳ chọn)
> Dùng khi cần hiển thị ai đã nhận/xem (đặc biệt nhóm nhỏ). Nhóm lớn sẽ phình dữ liệu.

| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `messageId` (PK*) | UUID/BIGINT | |
| `userId` (PK*) | UUID | người nhận |
| `deliveredAt` | timestamp | nullable |
| `seenAt` | timestamp | nullable |

> PK* là khoá chính kép `(messageId, userId)`.

**Gợi ý tối ưu thay thế**
- Nếu nhóm đông: ưu tiên lưu `lastReadMessageId` ở `conversation_member` thay vì receipt cho từng message.

### 7.3 Bảng: `message_reaction`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `reactionId` (PK) | UUID | |
| `messageId` | UUID/BIGINT | |
| `userId` | UUID | |
| `emoji` | string | 👍 ❤️ 😆 … |
| `createdAt` | timestamp | |

**Ràng buộc**
- Unique logic: `(messageId, userId)` nếu mỗi người chỉ được 1 reaction, hoặc `(messageId, userId, emoji)` nếu cho phép nhiều.

### 7.4 Bảng: `message_attachment_snapshot` (tuỳ chọn)
> Lưu “ảnh chụp metadata” để hiển thị nhanh mà không cần gọi Media Service.

| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `messageId` (PK) | UUID/BIGINT | |
| `mediaUrl` | string | |
| `mimeType` | string | |
| `sizeBytes` | long | |
| `width` | int | nullable |
| `height` | int | nullable |
| `durationMs` | int | nullable |
| `fileName` | string | nullable |

---

## 8) Media Service (Quản lý file/ảnh trên S3)

### Mục tiêu
- Quản lý metadata media
- Theo dõi trạng thái upload
- Cấp quyền truy cập (nếu cần)

### 8.1 Bảng: `media_object`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `mediaId` (PK) | UUID | |
| `ownerUserId` | UUID | người upload |
| `bucket` | string | |
| `objectKey` | string | key trên S3 |
| `url` | string | URL (public/cdn), nullable nếu dùng signed-url |
| `mimeType` | string | |
| `sizeBytes` | long | |
| `checksum` | string | md5/sha256, nullable |
| `width` | int | nullable |
| `height` | int | nullable |
| `durationMs` | int | nullable |
| `originalFileName` | string | |
| `status` | ENUM | `UPLOADING/READY/FAILED/DELETED` |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

**Index gợi ý**
- `(ownerUserId, createdAt)`.
- `(status)`.

### 8.2 Bảng: `media_access_scope` (tuỳ chọn)
> Nếu cần kiểm soát ai được truy cập media (private link).

| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `mediaId` (PK*) | UUID | |
| `scopeType` (PK*) | ENUM | `CONVERSATION/USER` |
| `scopeId` (PK*) | UUID | conversationId hoặc userId |
| `createdAt` | timestamp | |

> PK* là khoá chính kép `(mediaId, scopeType, scopeId)`.

**Quy ước objectKey (gợi ý)**
- `avatars/{userId}/{fileName}`
- `groups/{groupId}/avatar/{fileName}`
- `chat-media/{conversationId}/{messageId}/{fileName}`
- `voice/{conversationId}/{messageId}.mp3`

---

## 9) Notification Service (Push & In-app)

### Mục tiêu
- Lưu token thiết bị
- Tạo thông báo push khi user offline
- Lưu lịch sử thông báo trong app

### 9.1 Bảng: `device_token`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `deviceId` (PK) | string/UUID | |
| `userId` | UUID | |
| `platform` | ENUM | `ANDROID/IOS/WEB` |
| `pushToken` | string | token FCM/APNs |
| `status` | ENUM | `ACTIVE/REVOKED` |
| `lastSeenAt` | timestamp | |
| `createdAt` | timestamp | |

**Ràng buộc/Index**
- Unique `pushToken`.
- Index `(userId, platform)`.

### 9.2 Bảng: `notification`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `notificationId` (PK) | UUID | |
| `userId` | UUID | người nhận |
| `type` | ENUM | `NEW_MESSAGE/FRIEND_REQUEST/GROUP_INVITE/SYSTEM` |
| `title` | string | |
| `body` | string | |
| `dataJson` | json/text | payload (conversationId, messageId, ...) |
| `isRead` | boolean | |
| `sentAt` | timestamp | |
| `readAt` | timestamp | nullable |
| `createdAt` | timestamp | |

**Index gợi ý**
- `(userId, isRead, createdAt)`.

---

## 10) Presence / Realtime Gateway Service (Online/Offline, socket mapping)

### Mục tiêu
- Quản lý trạng thái online/offline
- Map `userId ↔ connectionId`
- Typing indicator

> **Khuyến nghị**: Dữ liệu presence nên lưu ở **Redis/In-memory** thay vì RDBMS.

### 10.1 Mô hình key-value (mô tả)
- `presence:user:{userId}` → `{ online: true/false, lastActiveAt, deviceId }`
- `socket:user:{userId}` → danh sách `connectionId`
- `typing:conv:{conversationId}` → tập userId (TTL 3–5 giây)

### 10.2 Bảng log (tuỳ chọn nếu cần thống kê)
`presence_log(userId, eventType, at, deviceId, ip)`

---

## 11) Admin / Moderation Service (Quản trị & kiểm duyệt)

### Mục tiêu
- Tiếp nhận report
- Ghi log thao tác admin
- Hỗ trợ khóa/mở tài khoản hoặc xử lý nội dung

### 11.1 Bảng: `report`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `reportId` (PK) | UUID | |
| `reporterId` | UUID | người báo cáo |
| `targetType` | ENUM | `USER/MESSAGE/CONVERSATION` |
| `targetId` | UUID/BIGINT | id mục tiêu |
| `reasonCode` | ENUM | `SPAM/HARASSMENT/SCAM/OTHER` |
| `reasonText` | string | nullable |
| `status` | ENUM | `OPEN/REVIEWING/RESOLVED/REJECTED` |
| `assignedTo` | UUID | adminId, nullable |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | |

**Index gợi ý**
- `(status, createdAt)`.
- `(targetType, targetId)`.

### 11.2 Bảng: `admin_action_log`
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `logId` (PK) | UUID | |
| `adminId` | UUID | |
| `actionType` | ENUM | `LOCK_USER/UNLOCK_USER/DELETE_MESSAGE/BAN_DEVICE` |
| `targetType` | ENUM | `USER/MESSAGE/CONVERSATION` |
| `targetId` | UUID/BIGINT | |
| `note` | string | nullable |
| `createdAt` | timestamp | |

---

## 12) Event / Outbox (Khuyến nghị để đồng bộ liên service)

### Mục tiêu
- Đảm bảo phát event “đúng và đủ” khi có thay đổi dữ liệu (đặc biệt với message, friendship, conversation)

### 12.1 Bảng: `outbox_event` (mỗi service có thể có một bảng)
| Field | Kiểu gợi ý | Mô tả |
|---|---|---|
| `eventId` (PK) | UUID | |
| `aggregateType` | string | `USER/MESSAGE/CONVERSATION/...` |
| `aggregateId` | UUID/BIGINT | |
| `eventType` | string | ví dụ `MESSAGE_SENT` |
| `payloadJson` | json/text | nội dung event |
| `status` | ENUM | `NEW/PUBLISHED/FAILED` |
| `createdAt` | timestamp | |

---

## 13) Luồng truy vấn điển hình (để thiết kế index đúng)

### 13.1 Load danh sách hội thoại của user
- Input: `userId`
- Nguồn: `conversation_member` (lọc `leftAt IS NULL`)
- Sort: theo `pinOrder` (nếu pinned) rồi theo `lastMessageAt` (nếu có lưu) hoặc dựa trên message mới nhất.

> Gợi ý nâng cấp: Lưu `lastMessageId/lastMessageAt/lastMessagePreview` trong Conversation Service để tránh query nặng sang Messaging.

### 13.2 Load lịch sử tin nhắn
- Input: `conversationId`, `cursor` (messageId hoặc sentAt)
- Nguồn: `message`
- Index: `(conversationId, messageId)` hoặc `(conversationId, sentAt)`

### 13.3 Cập nhật đã xem
- Nếu dùng cursor đọc: cập nhật `conversation_member.lastReadMessageId` và `lastReadAt`
- Nếu dùng receipt: ghi `message_receipt` cho messageId tương ứng

### 13.4 Gửi media
- Media upload → tạo `media_object` (status UPLOADING → READY)
- Gửi message với `mediaId`
- Tuỳ chọn: snapshot metadata vào `message_attachment_snapshot`

---

## 14) Checklist nhất quán dữ liệu (data consistency)

- **Idempotency**: dùng `clientMessageId` để tránh duplicate khi client retry.
- **Soft delete**: message revoke/delete cần status rõ (`DELETED/REVOKED`) để giữ lịch sử hợp lệ.
- **Group scale**: cân nhắc receipt cho nhóm lớn (ưu tiên cursor đọc).
- **Privacy/Block**: trước khi tạo hội thoại/gửi message phải kiểm tra `block_list` và `privacy_setting`.

---

## 15) Phạm vi tối thiểu (MVP) khuyến nghị cho đồ án

Nếu cần làm gọn:
- Auth: `auth_account`, `auth_refresh_token`
- Profile: `user_profile`
- Social: `friend_request`, `friendship`, `block_list`
- Conversation: `conversation`, `conversation_member`, `conversation_direct_map`
- Messaging: `message` + **cursor đọc** trong `conversation_member` (tạm thời không làm `message_receipt`)
- Media: `media_object`
- Notification: `device_token` (nếu có push)

---

### Kết thúc tài liệu
Tài liệu này mô tả cấu trúc dữ liệu theo từng service cho hệ thống OTT giả lập Zalo. Khi bạn xác định rõ phạm vi tính năng (có receipt đầy đủ hay chỉ cursor đọc; có voice/call hay không), các bảng và field có thể được tinh chỉnh để tối ưu hiệu năng và dễ triển khai.
