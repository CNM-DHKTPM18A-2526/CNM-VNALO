# Database Schema Documentation - OTT Zalo Clone

> **Version**: 5.0  
> **Last Updated**: January 19, 2026  
> **Purpose**: Chi tiết từng table, field và chức năng trong hệ thống

---

## Mục Lục

1. [Auth Service](#1-auth-service)
2. [User Profile Service](#2-user-profile-service)
3. [Social Graph Service](#3-social-graph-service)
4. [Conversation Service](#4-conversation-service)
5. [Message Service](#5-message-service)
6. [Message Metadata Service](#6-message-metadata-service)
7. [Media Service](#7-media-service) ⭐ NEW
8. [Sticker Service](#8-sticker-service) ⭐ UPDATED
9. [Moderation Service](#9-moderation-service) ⭐ UPDATED
10. [Story Service](#10-story-service)
11. [Timeline Service](#11-timeline-service)
12. [Notification Service](#12-notification-service)
13. [Analytics Service](#13-analytics-service)
14. [QR & Link Service](#14-qr--link-service)
15. [Call Service](#15-call-service)
16. [Event Outbox](#16-event-outbox)
17. [Backup Service](#17-backup-service)

---

## 1. Auth Service

**Mục đích**: Quản lý xác thực người dùng, đăng nhập, đăng ký, và quản lý phiên.

### 1.1 `auth_account`

**Chức năng**: Lưu thông tin tài khoản chính của người dùng.

| Field | Type | Mô tả |
|-------|------|-------|
| `account_id` | UUID | Primary key, ID duy nhất của tài khoản |
| `phone` | VARCHAR(20) | Số điện thoại đăng ký (unique) |
| `firebase_uid` | VARCHAR(128) | UID từ Firebase Auth (nếu dùng Firebase) |
| `password_hash` | VARCHAR(255) | Hash của mật khẩu (bcrypt/argon2) |
| `status` | VARCHAR(20) | Trạng thái: ACTIVE, LOCKED, DISABLED, DELETED |
| `locked_until` | TIMESTAMPTZ | Thời điểm hết khóa tài khoản (nếu bị khóa) |
| `failed_login_count` | INT | Số lần đăng nhập thất bại liên tiếp |
| `last_login_at` | TIMESTAMPTZ | Lần đăng nhập cuối |
| `last_login_device_id` | VARCHAR(100) | Device ID của lần đăng nhập cuối |
| `created_at` | TIMESTAMPTZ | Thời điểm tạo tài khoản |
| `updated_at` | TIMESTAMPTZ | Thời điểm cập nhật cuối |

**Business Logic**:
- `failed_login_count >= 5` → Set `status = 'LOCKED'`, `locked_until = NOW() + 30 minutes`
- `status = 'DELETED'` → Soft delete, không xóa vật lý

---

### 1.2 `auth_refresh_token`

**Chức năng**: Quản lý refresh tokens cho JWT authentication.

| Field | Type | Mô tả |
|-------|------|-------|
| `token_id` | UUID | Primary key |
| `account_id` | UUID | FK đến auth_account |
| `token_hash` | VARCHAR(255) | Hash của refresh token (không lưu plaintext) |
| `device_id` | VARCHAR(100) | ID thiết bị (để quản lý multi-device) |
| `device_name` | VARCHAR(100) | Tên thiết bị (vd: "iPhone 15 Pro") |
| `platform` | VARCHAR(20) | ANDROID, IOS, WEB, PC |
| `ip_address` | VARCHAR(45) | IP đăng nhập (IPv4/IPv6) |
| `user_agent` | TEXT | User agent string |
| `expires_at` | TIMESTAMPTZ | Thời điểm hết hạn |
| `revoked_at` | TIMESTAMPTZ | Thời điểm bị thu hồi (logout) |
| `created_at` | TIMESTAMPTZ | Thời điểm tạo |

**Business Logic**:
- Một user có thể đăng nhập trên nhiều devices
- Khi logout, set `revoked_at = NOW()`
- Token hết hạn sau 30 ngày (configurable)

---

### 1.3 `auth_otp`

**Chức năng**: Lưu mã OTP cho xác thực.

| Field | Type | Mô tả |
|-------|------|-------|
| `otp_id` | UUID | Primary key |
| `target` | VARCHAR(50) | Số điện thoại hoặc email nhận OTP |
| `purpose` | VARCHAR(30) | REGISTER, LOGIN, RESET_PASSWORD, VERIFY_DEVICE, CHANGE_PHONE |
| `otp_hash` | VARCHAR(255) | Hash của OTP (không lưu plaintext) |
| `attempts` | INT | Số lần nhập sai |
| `max_attempts` | INT | Số lần tối đa được thử (default: 5) |
| `expires_at` | TIMESTAMPTZ | Thời điểm hết hạn (thường 5 phút) |
| `verified_at` | TIMESTAMPTZ | Thời điểm xác thực thành công |
| `created_at` | TIMESTAMPTZ | Thời điểm tạo OTP |

**Business Logic**:
- OTP hết hạn sau 5 phút
- `attempts >= max_attempts` → OTP bị vô hiệu
- Mỗi `target + purpose` chỉ có 1 OTP active tại một thời điểm

---

## 2. User Profile Service

**Mục đích**: Quản lý thông tin cá nhân, cài đặt riêng tư, preferences.

### 2.1 `user_profile`

**Chức năng**: Thông tin public của người dùng.

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id` | UUID | Primary key (= account_id) |
| `display_name` | VARCHAR(100) | Tên hiển thị |
| `avatar_url` | VARCHAR(500) | URL ảnh đại diện (CDN) |
| `cover_url` | VARCHAR(500) | URL ảnh bìa |
| `bio` | VARCHAR(500) | Giới thiệu bản thân |
| `gender` | VARCHAR(20) | UNKNOWN, MALE, FEMALE, OTHER |
| `date_of_birth` | DATE | Ngày sinh |
| `region` | VARCHAR(100) | Khu vực/thành phố |
| `status_message` | VARCHAR(200) | Trạng thái (mood) |
| `qr_code_url` | VARCHAR(500) | URL QR code cá nhân |
| `is_verified` | BOOLEAN | Tài khoản đã xác thực (tick xanh) |
| `is_official_account` | BOOLEAN | Official Account (doanh nghiệp) |
| `follower_count` | INT | Số người theo dõi (denormalized) |
| `created_at` | TIMESTAMPTZ | Thời điểm tạo |
| `updated_at` | TIMESTAMPTZ | Thời điểm cập nhật |

---

### 2.2 `user_privacy_setting`

**Chức năng**: Cài đặt quyền riêng tư.

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id` | UUID | Primary key (= account_id) |
| `allow_search_by_phone` | BOOLEAN | Cho phép tìm kiếm qua SĐT |
| `allow_search_by_qr` | BOOLEAN | Cho phép quét QR thêm bạn |
| `allow_stranger_message` | BOOLEAN | Cho phép người lạ nhắn tin |
| `allow_friend_request` | BOOLEAN | Cho phép gửi lời mời kết bạn |
| `show_online_status` | BOOLEAN | Hiển thị trạng thái online |
| `last_seen_visibility` | VARCHAR(20) | EVERYONE, FRIENDS, NOBODY |
| `story_visibility` | VARCHAR(20) | EVERYONE, FRIENDS, CUSTOM, CLOSE_FRIENDS |
| `timeline_visibility` | VARCHAR(20) | EVERYONE, FRIENDS, ONLY_ME |
| `allow_add_to_group` | VARCHAR(20) | EVERYONE, FRIENDS, NOBODY |
| `allow_voice_call` | VARCHAR(20) | EVERYONE, FRIENDS, NOBODY |
| `allow_video_call` | VARCHAR(20) | EVERYONE, FRIENDS, NOBODY |

---

### 2.3 `user_setting`

**Chức năng**: Cài đặt ứng dụng.

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id` | UUID | Primary key |
| `language` | VARCHAR(10) | Ngôn ngữ (vi, en, ...) |
| `theme` | VARCHAR(20) | LIGHT, DARK, SYSTEM |
| `font_size` | VARCHAR(20) | SMALL, MEDIUM, LARGE |
| `notification_sound` | BOOLEAN | Bật/tắt âm thanh thông báo |
| `notification_vibrate` | BOOLEAN | Bật/tắt rung |
| `notification_preview` | BOOLEAN | Hiển thị nội dung trong notification |
| `auto_download_image` | BOOLEAN | Tự động tải ảnh |
| `auto_download_video` | BOOLEAN | Tự động tải video |
| `auto_download_file` | BOOLEAN | Tự động tải file |

---

## 3. Social Graph Service

**Mục đích**: Quản lý quan hệ bạn bè, chặn, đồng bộ danh bạ.

### 3.1 `friend_request`

**Chức năng**: Lưu lời mời kết bạn.

| Field | Type | Mô tả |
|-------|------|-------|
| `request_id` | UUID | Primary key |
| `from_user_id` | UUID | Người gửi lời mời |
| `to_user_id` | UUID | Người nhận lời mời |
| `message` | VARCHAR(200) | Lời nhắn kèm theo |
| `source` | VARCHAR(30) | SEARCH, QR, CONTACT_SYNC, SUGGEST, GROUP, NEARBY |
| `status` | VARCHAR(20) | PENDING, ACCEPTED, DECLINED, CANCELED |
| `responded_at` | TIMESTAMPTZ | Thời điểm phản hồi |
| `created_at` | TIMESTAMPTZ | Thời điểm gửi |

**Business Logic**:
- Mỗi cặp user chỉ có 1 pending request tại một thời điểm
- Khi ACCEPTED → Tạo record trong `friendship`

---

### 3.2 `friendship`

**Chức năng**: Quan hệ bạn bè đã được chấp nhận.

| Field | Type | Mô tả |
|-------|------|-------|
| `friendship_id` | UUID | Primary key |
| `user_id_1` | UUID | User có ID nhỏ hơn |
| `user_id_2` | UUID | User có ID lớn hơn |
| `source` | VARCHAR(30) | Nguồn kết bạn |
| `nickname_1_for_2` | VARCHAR(50) | Biệt danh user1 đặt cho user2 |
| `nickname_2_for_1` | VARCHAR(50) | Biệt danh user2 đặt cho user1 |
| `is_favorite_1` | BOOLEAN | User1 đánh dấu yêu thích |
| `is_favorite_2` | BOOLEAN | User2 đánh dấu yêu thích |
| `is_hidden_1` | BOOLEAN | User1 ẩn trong danh sách |
| `is_hidden_2` | BOOLEAN | User2 ẩn trong danh sách |
| `created_at` | TIMESTAMPTZ | Thời điểm kết bạn |

**Design Decision**:
- Constraint `user_id_1 < user_id_2` để tránh duplicate (A-B và B-A)
- Các field `*_1` và `*_2` tương ứng với user_id_1 và user_id_2

---

### 3.3 `block_list`

**Chức năng**: Danh sách người bị chặn.

| Field | Type | Mô tả |
|-------|------|-------|
| `block_id` | UUID | Primary key |
| `blocker_id` | UUID | Người thực hiện chặn |
| `blocked_id` | UUID | Người bị chặn |
| `reason` | VARCHAR(30) | SPAM, HARASSMENT, INAPPROPRIATE, SCAM, OTHER |
| `note` | VARCHAR(200) | Ghi chú cá nhân |
| `created_at` | TIMESTAMPTZ | Thời điểm chặn |

**Business Logic**:
- Người bị chặn không thể: gửi tin nhắn, gọi điện, xem story, xem timeline
- Chặn là đơn hướng (A chặn B ≠ B chặn A)

---

### 3.4 `contact_sync`

**Chức năng**: Đồng bộ danh bạ điện thoại.

| Field | Type | Mô tả |
|-------|------|-------|
| `sync_id` | UUID | Primary key |
| `user_id` | UUID | User thực hiện sync |
| `phone_number` | VARCHAR(20) | SĐT trong danh bạ |
| `contact_name` | VARCHAR(100) | Tên trong danh bạ |
| `matched_user_id` | UUID | User Zalo tương ứng (nếu có) |
| `invited_at` | TIMESTAMPTZ | Thời điểm gửi lời mời (SMS) |
| `synced_at` | TIMESTAMPTZ | Thời điểm đồng bộ |

---

## 4. Conversation Service

**Mục đích**: Quản lý cuộc trò chuyện (1:1 và nhóm).

### 4.1 `conversation`

**Chức năng**: Metadata của cuộc trò chuyện.

| Field | Type | Mô tả |
|-------|------|-------|
| `conversation_id` | UUID | Primary key |
| `type` | VARCHAR(20) | DIRECT (1:1), GROUP |
| `title` | VARCHAR(100) | Tên nhóm (NULL cho DIRECT) |
| `avatar_url` | VARCHAR(500) | Ảnh đại diện nhóm |
| `description` | VARCHAR(500) | Mô tả nhóm |
| `created_by` | UUID | Người tạo |
| `status` | VARCHAR(20) | ACTIVE, ARCHIVED, DISABLED |
| `join_mode` | VARCHAR(20) | OPEN, APPROVAL, INVITE_ONLY |
| `member_limit` | INT | Giới hạn thành viên (default: 1000) |
| `invite_link` | VARCHAR(100) | Link mời vào nhóm (unique) |
| `invite_link_expires_at` | TIMESTAMPTZ | Thời hạn link mời |
| `is_encrypted` | BOOLEAN | E2E encryption |
| `allow_member_invite` | BOOLEAN | Thành viên được mời thêm người |
| `allow_member_pin` | BOOLEAN | Thành viên được ghim tin nhắn |
| `allow_member_edit_info` | BOOLEAN | Thành viên được sửa thông tin nhóm |

---

### 4.2 `conversation_member`

**Chức năng**: Thành viên trong cuộc trò chuyện.

| Field | Type | Mô tả |
|-------|------|-------|
| `conversation_id` | UUID | PK part 1 |
| `user_id` | UUID | PK part 2 |
| `role` | VARCHAR(20) | OWNER, ADMIN, MEMBER |
| `nickname` | VARCHAR(50) | Biệt danh trong nhóm |
| `joined_at` | TIMESTAMPTZ | Thời điểm tham gia |
| `joined_by` | UUID | Người thêm vào |
| `left_at` | TIMESTAMPTZ | Thời điểm rời (NULL = còn trong nhóm) |
| `removed_by` | UUID | Người kick (nếu bị kick) |
| `mute_until` | TIMESTAMPTZ | Tắt thông báo đến thời điểm |
| `is_pinned` | BOOLEAN | Ghim cuộc trò chuyện |
| `pin_order` | INT | Thứ tự ghim |
| `is_hidden` | BOOLEAN | Ẩn cuộc trò chuyện |
| `last_read_seq` | BIGINT | serverSeq đọc cuối (cho unread count) |
| `last_read_at` | TIMESTAMPTZ | Thời điểm đọc cuối |
| `notification_setting` | VARCHAR(20) | ALL, MENTIONS, NONE |

---

### 4.3 `conversation_direct_map`

**Chức năng**: Mapping nhanh để tìm conversation giữa 2 user.

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id_1` | UUID | User ID nhỏ hơn |
| `user_id_2` | UUID | User ID lớn hơn |
| `conversation_id` | UUID | ID cuộc trò chuyện |

**Query Pattern**:
```sql
-- Tìm conversation giữa userA và userB
SELECT conversation_id 
FROM conversation_direct_map 
WHERE user_id_1 = LEAST(userA, userB) 
  AND user_id_2 = GREATEST(userA, userB);
```

---

### 4.4 `conversation_inbox` (CQRS Read Model)

**Chức năng**: View danh sách chat của user (denormalized cho performance).

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id` | UUID | PK part 1 |
| `conversation_id` | UUID | PK part 2 |
| `last_message_seq` | BIGINT | serverSeq của tin nhắn cuối |
| `last_message_at` | TIMESTAMPTZ | Thời điểm tin nhắn cuối |
| `last_message_preview` | VARCHAR(200) | Nội dung preview (truncated) |
| `last_message_sender_id` | UUID | Người gửi tin cuối |
| `last_message_type` | VARCHAR(30) | Loại tin nhắn cuối |
| `unread_count` | INT | Số tin chưa đọc |
| `is_pinned` | BOOLEAN | Đã ghim |
| `is_muted` | BOOLEAN | Đã tắt thông báo |
| `is_hidden` | BOOLEAN | Đã ẩn |

**Update via Kafka**: Mỗi khi Message Service publish event, Conversation Service update table này.

---

## 5. Message Service (Cassandra)

**Mục đích**: Lưu trữ tin nhắn với high throughput.

### 5.1 `messages_by_conversation`

**Chức năng**: Bảng chính lưu tin nhắn, partition theo conversation.

| Field | Type | Mô tả |
|-------|------|-------|
| `conversation_id` | UUID | **Partition Key** |
| `server_seq` | BIGINT | **Clustering Key** (DESC) - Số thứ tự tin nhắn |
| `message_id` | UUID | ID duy nhất của tin nhắn |
| `sender_id` | UUID | Người gửi |
| `client_message_id` | UUID | ID từ client (cho idempotency) |
| `message_type` | TEXT | TEXT, IMAGE, VIDEO, FILE, VOICE, STICKER, ... |
| `content` | TEXT | Nội dung text |
| `media_id` | UUID | Reference đến media_metadata |
| `media_url` | TEXT | URL CDN (denormalized) |
| `media_thumbnail_url` | TEXT | URL thumbnail (denormalized) |
| `sticker_id` | UUID | Reference đến sticker |
| `sticker_url` | TEXT | URL sticker (denormalized) |
| `reply_to_message_id` | UUID | Tin nhắn được reply |
| `reply_to_seq` | BIGINT | serverSeq của tin được reply |
| `reply_to_content` | TEXT | Nội dung tin được reply (denormalized) |
| `forward_from_message_id` | UUID | Tin nhắn gốc (nếu forward) |
| `mentions` | SET<UUID> | Danh sách user được mention |
| `status` | TEXT | SENT, DELETED, REVOKED |
| `is_edited` | BOOLEAN | Đã chỉnh sửa |
| `edited_at` | TIMESTAMP | Thời điểm sửa |
| `server_ts` | TIMESTAMP | Thời điểm server nhận |
| `expires_at` | TIMESTAMP | Thời điểm tự xóa (disappearing) |

**Denormalization Note**: Các field như `media_url`, `reply_to_content` được denormalize để tránh join trong Cassandra.

---

### 5.2 `message_idempotency_by_sender`

**Chức năng**: Kiểm tra duplicate message từ client retry.

| Field | Type | Mô tả |
|-------|------|-------|
| `sender_id` | UUID | **Partition Key** |
| `client_message_id` | UUID | **Clustering Key** - ID từ client |
| `conversation_id` | UUID | Conversation chứa message |
| `server_seq` | BIGINT | serverSeq đã cấp |
| `message_id` | UUID | messageId đã cấp |
| `created_at` | TIMESTAMP | Thời điểm tạo |

**TTL**: 7 ngày - sau 7 ngày client không retry nữa.

---

## 6. Message Metadata Service (PostgreSQL)

**Mục đích**: Lưu metadata cần relational queries (reactions, receipts, polls).

### 6.1 `message_reaction`

| Field | Type | Mô tả |
|-------|------|-------|
| `reaction_id` | UUID | Primary key |
| `conversation_id` | UUID | Để query nhanh |
| `message_id` | UUID | Tin nhắn được react |
| `server_seq` | BIGINT | serverSeq của tin nhắn |
| `user_id` | UUID | Người react |
| `emoji` | VARCHAR(20) | Emoji reaction (👍, ❤️, ...) |

**Constraint**: Mỗi user chỉ react 1 emoji cho mỗi message.

---

### 6.2 `message_receipt`

| Field | Type | Mô tả |
|-------|------|-------|
| `conversation_id` | UUID | PK part 1 |
| `message_id` | UUID | PK part 2 |
| `user_id` | UUID | PK part 3 |
| `delivered_at` | TIMESTAMPTZ | Thời điểm delivered |
| `seen_at` | TIMESTAMPTZ | Thời điểm đọc |

**Design**: User-level receipt (bất kỳ device nào đọc = user đọc).

---

## 7. Media Service (PostgreSQL) ⭐ UPDATED

**Mục đích**: Quản lý file media (upload, processing, serving).

### 7.1 `media_metadata`

**Chức năng**: Metadata của file media trên S3.

| Field | Type | Mô tả |
|-------|------|-------|
| `media_id` | UUID | Primary key |
| `owner_user_id` | UUID | Người upload |
| `media_type` | VARCHAR(20) | IMAGE, VIDEO, DOCUMENT, AUDIO |
| `mime_type` | VARCHAR(100) | MIME type (image/jpeg, video/mp4, ...) |
| `original_filename` | VARCHAR(255) | Tên file gốc |
| `bucket` | VARCHAR(50) | S3 bucket name |
| `object_key` | VARCHAR(500) | S3 object key (path) |
| `region` | VARCHAR(20) | AWS region |
| `cloudfront_url` | VARCHAR(500) | URL CDN để serve |
| `preview_url` | VARCHAR(500) | URL thumbnail/preview |
| `size_bytes` | BIGINT | Kích thước file |
| `checksum_sha256` | VARCHAR(64) | Hash để detect duplicate |
| `width` | INT | Chiều rộng (image/video) |
| `height` | INT | Chiều cao (image/video) |
| `duration_ms` | INT | Thời lượng (video/audio) |
| `needs_processing` | BOOLEAN | Cần xử lý background |
| `status` | VARCHAR(20) | PENDING_UPLOAD, UPLOADED, PROCESSING, READY, FAILED, DELETED |

---

### 7.2 `upload_request` ⭐ NEW

**Chức năng**: Track presigned URL upload flow.

| Field | Type | Mô tả |
|-------|------|-------|
| `upload_request_id` | UUID | Primary key |
| `owner_user_id` | UUID | Người request upload |
| `file_name` | VARCHAR(255) | Tên file sẽ upload |
| `mime_type` | VARCHAR(100) | MIME type dự kiến |
| `expected_size_bytes` | BIGINT | Kích thước dự kiến |
| `presigned_url` | TEXT | URL đã ký để upload |
| `object_key` | VARCHAR(500) | S3 key đã reserve |
| `expires_at` | TIMESTAMPTZ | Thời hạn URL (15 phút) |
| `source_type` | VARCHAR(30) | CHAT, STORY, TIMELINE, AVATAR, STICKER |
| `source_id` | UUID | ID context (conversation_id, story_id, ...) |
| `status` | VARCHAR(20) | ISSUED, CONFIRMED, EXPIRED, CANCELLED |
| `confirmed_media_id` | UUID | media_id sau khi confirm |

**Flow**:
```
1. Client: POST /media/presign → nhận presigned_url
2. Client: PUT presigned_url (upload to S3)
3. Client: POST /media/{uploadRequestId}/confirm
4. Server: Verify S3, create media_metadata, return media_id
```

---

### 7.3 `media_job` ⭐ NEW

**Chức năng**: Queue xử lý background (thumbnail, compress).

| Field | Type | Mô tả |
|-------|------|-------|
| `media_job_id` | UUID | Primary key |
| `media_id` | UUID | Media cần xử lý |
| `job_type` | VARCHAR(20) | THUMBNAIL, COMPRESS, TRANSCODE |
| `status` | VARCHAR(20) | PENDING, RUNNING, DONE, FAILED |
| `kafka_topic` | VARCHAR(100) | Topic để publish event |
| `payload_json` | JSONB | Input parameters |
| `result_json` | JSONB | Output (URLs, sizes, ...) |
| `retry_count` | INT | Số lần retry |
| `next_run_at` | TIMESTAMPTZ | Thời điểm retry tiếp |

**Processing Flow**:
```
1. Upload complete → Create media_job (THUMBNAIL)
2. Worker poll job → Execute → Update status
3. If FAILED and retry_count < 3 → Schedule retry
```

---

### 7.4 `media_variant` ⭐ NEW

**Chức năng**: Các phiên bản khác nhau của media.

| Field | Type | Mô tả |
|-------|------|-------|
| `media_variant_id` | UUID | Primary key |
| `media_id` | UUID | Media gốc |
| `variant_type` | VARCHAR(20) | THUMBNAIL, COMPRESSED, PREVIEW, HD, SD |
| `object_key` | VARCHAR(500) | S3 key của variant |
| `width` | INT | Chiều rộng |
| `height` | INT | Chiều cao |
| `size_bytes` | BIGINT | Kích thước |
| `status` | VARCHAR(20) | PROCESSING, READY, FAILED |

**Example**: Một video 4K có thể có variants: HD (1080p), SD (480p), THUMBNAIL (image).

---

### 7.5 `user_media_library_item` ⭐ NEW

**Chức năng**: Media được user lưu vào thư viện.

| Field | Type | Mô tả |
|-------|------|-------|
| `user_media_lib_id` | UUID | Primary key |
| `user_id` | UUID | User |
| `media_id` | UUID | Media đã lưu |
| `saved_at` | TIMESTAMPTZ | Thời điểm lưu |
| `source_type` | VARCHAR(30) | CHAT, STORY, TIMELINE, UPLOAD |
| `source_id` | UUID | ID nguồn |

---

## 8. Sticker Service (PostgreSQL) ⭐ UPDATED

**Mục đích**: Quản lý sticker packs và stickers.

### 8.1 `sticker_pack`

| Field | Type | Mô tả |
|-------|------|-------|
| `sticker_pack_id` | UUID | Primary key |
| `owner_user_id` | UUID | Người tạo (NULL = official) |
| `name` | VARCHAR(100) | Tên pack |
| `description` | VARCHAR(500) | Mô tả |
| `cover_media_id` | UUID | **→ media_metadata** (thay vì URL) |
| `status` | VARCHAR(20) | DRAFT, PUBLISHED, SUSPENDED |
| `sticker_count` | INT | Số sticker (denormalized) |
| `download_count` | INT | Số lượt tải |

**Change v4→v5**: `thumbnail_url` → `cover_media_id` để integrate với Media Service.

---

### 8.2 `sticker`

| Field | Type | Mô tả |
|-------|------|-------|
| `sticker_id` | UUID | Primary key |
| `pack_id` | UUID | Thuộc pack nào |
| `name` | VARCHAR(50) | Tên sticker |
| `media_id` | UUID | **→ media_metadata** (thay vì URL) |
| `is_animated` | BOOLEAN | Sticker động (GIF/Lottie) |
| `display_order` | INT | Thứ tự hiển thị |
| `status` | VARCHAR(20) | ACTIVE, HIDDEN, BLOCKED |

**Change v4→v5**: `image_url` → `media_id` để integrate với Media Service.

---

### 8.3 `user_sticker_pack`

| Field | Type | Mô tả |
|-------|------|-------|
| `user_id` | UUID | PK part 1 |
| `pack_id` | UUID | PK part 2 |
| `installed_at` | TIMESTAMPTZ | Thời điểm cài (v4: downloaded_at) |
| `pinned_order` | INT | Thứ tự ghim (v4: order_index) |

---

## 9. Moderation Service (PostgreSQL) ⭐ UPDATED

**Mục đích**: Xử lý báo cáo nội dung, quyết định admin, thực thi action.

### 9.1 `content_report`

**Chức năng**: Báo cáo nội dung vi phạm.

| Field | Type | Mô tả |
|-------|------|-------|
| `content_report_id` | UUID | Primary key |
| `reporter_user_id` | UUID | Người báo cáo |
| `target_type` | VARCHAR(20) | MEDIA, STICKER, TIMELINE, MESSAGE |
| `target_id` | UUID | ID nội dung bị báo cáo |
| `reason_code` | VARCHAR(30) | SPAM, HARASSMENT, INAPPROPRIATE, VIOLENCE, SCAM, COPYRIGHT, OTHER |
| `description` | TEXT | Mô tả chi tiết |
| `status` | VARCHAR(20) | NEW, IN_REVIEW, RESOLVED |

---

### 9.2 `moderation_decision` ⭐ NEW

**Chức năng**: Quyết định của admin đối với report.

| Field | Type | Mô tả |
|-------|------|-------|
| `mod_dec_id` | UUID | Primary key |
| `report_id` | UUID | Report được xử lý |
| `decided_by` | UUID | Admin ra quyết định |
| `decision_type` | VARCHAR(20) | NO_ACTION, REMOVE, BLOCK, SUSPEND |
| `notes` | TEXT | Ghi chú của admin |
| `decided_at` | TIMESTAMPTZ | Thời điểm quyết định |

---

### 9.3 `moderation_action` ⭐ NEW

**Chức năng**: Action cần thực thi bởi các service khác.

| Field | Type | Mô tả |
|-------|------|-------|
| `mod_act_id` | UUID | Primary key |
| `decision_id` | UUID | Decision tương ứng |
| `target_service` | VARCHAR(50) | Service thực thi (media-service, sticker-service) |
| `action_type` | VARCHAR(50) | DELETE_MEDIA, HIDE_STICKER, BAN_USER |
| `payload_json` | JSONB | Parameters cho action |
| `status` | VARCHAR(20) | PENDING, SENT, ACKED, FAILED |
| `retry_count` | INT | Số lần retry |

**Flow**:
```
1. Admin tạo moderation_decision (REMOVE)
2. System tạo moderation_action (DELETE_MEDIA, target: media-service)
3. Publish event lên Kafka
4. media-service consume, execute, ACK
5. Update status = ACKED
```

---

### 9.4 `admin_action_log`

**Chức năng**: Audit log cho tất cả hành động admin.

| Field | Type | Mô tả |
|-------|------|-------|
| `log_id` | UUID | Primary key |
| `admin_id` | UUID | Admin thực hiện |
| `action_type` | VARCHAR(50) | Loại hành động |
| `target_type` | VARCHAR(30) | Loại đối tượng |
| `target_id` | UUID | ID đối tượng |
| `reason` | TEXT | Lý do |
| `metadata` | JSONB | Thông tin bổ sung |

---

## Phân Tích Tính Hợp Lý Của Thay Đổi

### 1. Media Service Changes ✅ HỢP LÝ

**Lý do**:
- `upload_request`: Cần thiết cho presigned URL flow (best practice AWS S3)
- `media_job`: Cần thiết để track background processing (thumbnail, transcode)
- `media_variant`: Cần thiết để lưu các phiên bản khác nhau (HD, SD, thumbnail)
- Phù hợp với kiến trúc Zalo và các hệ thống messaging lớn

### 2. Sticker → Media Integration ✅ HỢP LÝ

**Lý do**:
- Thống nhất media management (không có 2 hệ thống riêng)
- Tái sử dụng CDN, processing pipeline
- Dễ dàng thêm tính năng (AI sticker generation)

### 3. Moderation Workflow ✅ HỢP LÝ

**Lý do**:
- `moderation_decision`: Audit trail cho quyết định admin
- `moderation_action`: Async execution via Kafka (scalable)
- Phù hợp với compliance requirements (GDPR, content moderation)

---

## Kết Luận

Các thay đổi trong v5.0 đều **hợp lý và cần thiết** cho một hệ thống production:

| Change | Lý do | Industry Standard |
|--------|-------|-------------------|
| Presigned URL flow | Security, scalability | ✅ AWS best practice |
| Background processing queue | Async, retry-able | ✅ Common pattern |
| Media variants | Performance, bandwidth optimization | ✅ Netflix, YouTube |
| Centralized media management | DRY, single source of truth | ✅ Microservices pattern |
| Moderation workflow | Compliance, audit | ✅ Required by law |
