# Media Service — Hướng dẫn sử dụng

> **Port:** `8083` | **Base URL:** `http://localhost:8083/api/v1`

---

## 1. Yêu cầu

| Thành phần | Phiên bản | Ghi chú |
|---|---|---|
| Java | 21+ | |
| Maven | 3.8+ | |
| PostgreSQL | 14+ | Database `vnalo_media` |
| AWS S3 | — | Bucket `vnalo-media`, region `ap-southeast-1` |
| Kafka | 7.5.0 | Tùy chọn — dùng cho thumbnail/compress |

---

## 2. Cấu hình

### 2.1 AWS S3 Setup

1. Vào [S3 Console](https://s3.console.aws.amazon.com/s3/) → **Create bucket**
   - Bucket name: `vnalo-media` | Region: `ap-southeast-1`
   - **Bỏ tick** Block Public Access → tick xác nhận

2. Tab **Permissions** → **Bucket policy** → paste:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::vnalo-media/*"
  }]
}
```

3. Tab **CORS** → paste:
```json
[{
  "AllowedHeaders": ["*"],
  "AllowedMethods": ["GET", "PUT", "POST"],
  "AllowedOrigins": ["*"],
  "ExposeHeaders": ["ETag"],
  "MaxAgeSeconds": 3600
}]
```

4. Vào [IAM Console](https://console.aws.amazon.com/iam/) → tạo user → gán policy **AmazonS3FullAccess** → **Create access key** → lưu lại `Access Key ID` và `Secret Access Key`

---

### 2.2 File cấu hình `application.yml`

Toàn bộ cấu hình nằm trong một file `src/main/resources/application.yml`. Các giá trị nhạy cảm được đọc từ **biến môi trường** (sau dấu `:`là giá trị mặc định dùng cho local dev).

**Các biến cần set khi deploy production (không có giá trị mặc định an toàn):**

| Biến môi trường | Ý nghĩa | Lấy ở đâu |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | IAM → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | IAM → Security credentials (cùng lúc tạo key) |
| `AWS_BUCKET_NAME` | Tên S3 bucket | S3 Console |
| `JWT_SECRET` | Secret key JWT (≥512 bit, base64) | Tạo: `openssl rand -base64 64` |
| `DB_PASS` | Mật khẩu PostgreSQL | |


---


## 3. Khởi động

### Tổng quan các service cần bật

| Service | Port | Bắt buộc | Mô tả |
|---|---|---|---|
| **PostgreSQL** | 5432 | ✅ | Database cho media-service |
| **Redis** | 6379 | ✅ (nếu dùng core-service) | Cache + session |
| **core-service** | 8081 | ✅ (để lấy JWT Token) | Xác thực người dùng |
| **media-service** | 8083 | ✅ | Service chính |
| **message-service** | 3000 | ❌ Tùy chọn | Nhắn tin (nếu test luồng gửi ảnh) |
| **Kafka + Zookeeper** | 9092 | ✅ Tùy chọn | Xử lý thumbnail/compress |

---

### Cách 1: Chạy local (phát triển)

**Bước 1 — Khởi động hạ tầng (PostgreSQL + Redis) bằng Docker:**

```powershell
cd docker
docker compose up -d postgres redis
```

Chờ đến khi cả 2 healthy:
```powershell
docker ps  # Cột STATUS phải là "healthy"
```

**Bước 2 — Khởi động Kafka** nếu cần tính năng thumbnail/compress:

```powershell
cd docker
docker compose --profile kafka up -d zookeeper kafka
```

> ⚠️ Cần có file `docker/.env` chứa ít nhất `JWT_SECRET=...`. Xem mục 2.1.

**Bước 3 — Chạy core-service** (bắt buộc để lấy JWT Token):

```powershell
cd backend/java-services/services/core-service
mvn spring-boot:run
```

Kiểm tra: `GET http://localhost:8081/api/v1/actuator/health` → `{"status":"UP"}`

**Bước 4 — Chạy media-service:**

```powershell
cd backend/java-services/services/media-service
mvn spring-boot:run
```

Kiểm tra: `GET http://localhost:8083/actuator/health` → `{"status":"UP"}`

---

### Cách 2: Chạy toàn bộ bằng Docker Compose

```powershell
cd docker
# Tạo file .env trước (xem mẫu bên dưới)
docker compose up -d
```

Mẫu file `docker/.env`:
```env
JWT_SECRET=ZGV2ZWxvcG1lbnQtb25seS1zZWNyZXQta2V5LWRvLW5vdC11c2UtaW4tcHJvZHVjdGlvbg==
DB_USER=postgres
DB_PASS=postgres
DB_NAME=vnalo_core
AWS_ACCESS_KEY_ID=<key của bạn>
AWS_SECRET_ACCESS_KEY=<secret của bạn>
AWS_BUCKET_NAME=vnalo-media
```

Kiểm tra tất cả service đang chạy:
```powershell
docker ps
# Phải thấy: vnalo-postgres, vnalo-redis, vnalo-core-service, vnalo-message-service, vnalo-media-service
```

---

### Kiểm tra nhanh sau khi khởi động

```powershell
# 1. PostgreSQL
docker exec vnalo-postgres pg_isready -U postgres

# 2. Redis
docker exec vnalo-redis redis-cli ping   # → PONG

# 3. core-service
curl http://localhost:8081/api/v1/actuator/health

# 4. media-service
curl http://localhost:8083/actuator/health
```

---


## 4. Lấy JWT Token

> ⚠️ Cần chạy **core-service** (port 8081) + PostgreSQL + Redis trước.

```bash
# Đăng ký (1 lần)
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"+84901234567","password":"Test@1234","displayName":"Test User"}'

# Đăng nhập → lấy accessToken
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"+84901234567","password":"Test@1234"}'
```

Copy `accessToken` từ response → dùng làm `Bearer <TOKEN>` cho tất cả API bên dưới.

> 📌 **Postman:** Tạo collection variable `TOKEN` → dùng `{{TOKEN}}` trong Authorization header.

---

## 5. Tổng hợp API

### Media API (`/api/v1/media`)

| # | Chức năng | Method | Endpoint |
|---|---|---|---|
| 1 | Upload file | `POST` | `/api/v1/media/upload` |
| 2 | Presigned upload (file lớn) | `POST` | `/api/v1/media/initiate-upload` |
| 3 | Xem media | `GET` | `/api/v1/media/{id}` |
| 4 | List media (filter + paging) | `GET` | `/api/v1/media` |
| 5 | Xóa media | `DELETE` | `/api/v1/media/{id}` |
| 6 | Update metadata | `PATCH` | `/api/v1/media/{id}` |
| 7 | Complete upload | `POST` | `/api/v1/media/{id}/complete` |
| 8 | Presigned download | `GET` | `/api/v1/media/{id}/download` |
| 9 | Lưu về máy (stream) | `GET` | `/api/v1/media/{id}/save` |
| 10 | Thumbnail | `GET` | `/api/v1/media/{id}/thumbnail` |
| 11 | Status | `GET` | `/api/v1/media/{id}/status` |
| 12 | Cấp quyền | `POST` | `/api/v1/media/{id}/access` |
| 13 | Thu hồi quyền | `DELETE` | `/api/v1/media/{id}/access` |
| 14 | Xem quyền | `GET` | `/api/v1/media/{id}/access` |

### Sticker API (`/api/v1/stickers`)

| # | Chức năng | Method | Endpoint |
|---|---|---|---|
| 15 | List sticker pack | `GET` | `/api/v1/stickers/packs` |
| 16 | Chi tiết pack + stickers | `GET` | `/api/v1/stickers/packs/{packId}` |
| 17 | Tạo pack | `POST` | `/api/v1/stickers/packs` |
| 18 | Cập nhật pack | `PATCH` | `/api/v1/stickers/packs/{packId}` |
| 19 | Xóa pack | `DELETE` | `/api/v1/stickers/packs/{packId}` |
| 20 | Upload sticker vào pack | `POST` | `/api/v1/stickers/packs/{packId}/stickers` |
| 21 | Lấy 1 sticker | `GET` | `/api/v1/stickers/{stickerId}` |
| 22 | Xóa sticker | `DELETE` | `/api/v1/stickers/{stickerId}` |
| 23 | Tìm sticker | `GET` | `/api/v1/stickers/search?keyword=` |
| 24 | Tải pack (user) | `POST` | `/api/v1/stickers/packs/{packId}/download` |
| 25 | Bỏ pack (user) | `DELETE` | `/api/v1/stickers/packs/{packId}/download` |
| 26 | Pack đã tải | `GET` | `/api/v1/stickers/my-packs` |
| 27 | Ghi nhận sử dụng | `POST` | `/api/v1/stickers/{stickerId}/use` |
| 28 | Sticker gần đây | `GET` | `/api/v1/stickers/recent` |

> Tất cả 27 API đều cần header `Authorization: Bearer <TOKEN>`.

---

## 6. Chi tiết Media API

### 6.1 Upload file

```bash
curl -X POST http://localhost:8083/api/v1/media/upload \
  -H "Authorization: Bearer <TOKEN>" \
  -F "file=@D:/path/to/photo.jpg" \
  -F "category=CHAT_IMAGE"
```

**Postman:** Method POST → Body → form-data → key `file` (type File) + key `category` (type Text)

**Các category hỗ trợ:**

| Category | Mô tả | Ví dụ file |
|---|---|---|
| `CHAT_IMAGE` | Ảnh chat | jpg, png |
| `CHAT_VIDEO` | Video chat | mp4 |
| `CHAT_FILE` | File đính kèm | pdf, doc, zip |
| `CHAT_VOICE` | Tin nhắn thoại | mp3, m4a |
| `AVATAR` | Ảnh đại diện | jpg, png |
| `COVER` | Ảnh bìa | jpg, png |
| `STORY` | Story (tự hết hạn sau 24h) | jpg, mp4 |
| `TIMELINE` | Ảnh timeline | jpg, png |

**Response (201):**
```json
{
  "success": true,
  "status": 201,
  "data": {
    "mediaId": "uuid-...",
    "url": "https://vnalo-media.s3.amazonaws.com/...",
    "thumbnailUrl": null,
    "mimeType": "image/jpeg",
    "sizeBytes": 245760,
    "status": "READY"
  }
}
```

---

### 6.2 Presigned Upload (file lớn)

Upload file lớn (video) theo 2 bước: lấy presigned URL → upload trực tiếp lên S3.

**Bước 1 — Lấy presigned URL:**
```bash
curl -X POST http://localhost:8083/api/v1/media/initiate-upload \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "video.mp4",
    "contentType": "video/mp4",
    "sizeBytes": 104857600,
    "category": "CHAT_VIDEO"
  }'
```

**Bước 2 — Upload lên S3 (dùng presigned URL):**
```bash
curl -X PUT "<PRESIGNED_URL>" \
  -H "Content-Type: video/mp4" \
  --data-binary @D:/path/to/video.mp4
```

**Bước 3 — Báo hoàn thành:**
```bash
curl -X POST http://localhost:8083/api/v1/media/<MEDIA_ID>/complete \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.3 Xem media

```bash
curl http://localhost:8083/api/v1/media/<MEDIA_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.4 List media

```bash
# Tất cả media của mình
curl "http://localhost:8083/api/v1/media?page=0&size=20" \
  -H "Authorization: Bearer <TOKEN>"

# Filter theo category
curl "http://localhost:8083/api/v1/media?category=CHAT_IMAGE&page=0&size=20" \
  -H "Authorization: Bearer <TOKEN>"
```

| Param | Giá trị mặc định | Mô tả |
|---|---|---|
| `category` | (tất cả) | Filter theo loại media |
| `page` | `0` | Trang |
| `size` | `20` | Số item mỗi trang |

---

### 6.5 Xóa media

```bash
curl -X DELETE http://localhost:8083/api/v1/media/<MEDIA_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.6 Update metadata

```bash
curl -X PATCH http://localhost:8083/api/v1/media/<MEDIA_ID> \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"originalFilename": "ten-moi.jpg"}'
```

---

### 6.7 Presigned Download URL

Tạo link download có thời hạn (mặc định 1 giờ):

```bash
curl http://localhost:8083/api/v1/media/<MEDIA_ID>/download \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.8 Lưu về máy (Stream download)

Lưu file trực tiếp về thiết bị. Trả về stream byte với header `Content-Disposition: attachment`. Tự động kích hoạt dialog lưu file trên trình duyệt/mobile. 

```bash
# Thêm cờ -OJ để curl tự lấy tên file gốc từ header
curl -OJ http://localhost:8083/api/v1/media/<MEDIA_ID>/save \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.9 Thumbnail

```bash
curl http://localhost:8083/api/v1/media/<MEDIA_ID>/thumbnail \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 6.10 Status

```bash
curl http://localhost:8083/api/v1/media/<MEDIA_ID>/status \
  -H "Authorization: Bearer <TOKEN>"
```

**Response:**
```json
{
  "success": true,
  "data": { "status": "READY" }
}
```

---

### 6.11 Cấp quyền truy cập

```bash
curl -X POST http://localhost:8083/api/v1/media/<MEDIA_ID>/access \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"scopeType":"CONVERSATION","scopeId":"<CONVERSATION_UUID>"}'
```

| `scopeType` | Ý nghĩa |
|---|---|
| `CONVERSATION` | Cấp quyền cho cả cuộc trò chuyện |
| `USER` | Cấp quyền cho 1 user |
| `PUBLIC` | Công khai hoàn toàn |

---

### 6.12 Thu hồi quyền

```bash
curl -X DELETE http://localhost:8083/api/v1/media/<MEDIA_ID>/access \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"scopeType":"CONVERSATION","scopeId":"<CONVERSATION_UUID>"}'
```

---

### 6.13 Xem danh sách quyền

```bash
curl http://localhost:8083/api/v1/media/<MEDIA_ID>/access \
  -H "Authorization: Bearer <TOKEN>"
```

---

## 7. Chi tiết Sticker API

> 📌 Base URL: `http://localhost:8083/api/v1/stickers`

### 7.1 List Sticker Pack

```bash
# Tất cả pack
curl "http://localhost:8083/api/v1/stickers/packs?page=0&size=10" \
  -H "Authorization: Bearer <TOKEN>"

# Filter theo category
curl "http://localhost:8083/api/v1/stickers/packs?category=CUTE&page=0&size=10" \
  -H "Authorization: Bearer <TOKEN>"
```

| `category` hợp lệ | `CUTE`, `FUNNY`, `LOVE`, `GREETING`, `TRENDING`, `AI_GENERATED`, `OFFICIAL`, `CUSTOM` |
|---|---|

---

### 7.2 Chi tiết Pack

```bash
curl http://localhost:8083/api/v1/stickers/packs/<PACK_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.3 Tạo Pack

```bash
curl -X POST http://localhost:8083/api/v1/stickers/packs \
  -H "Authorization: Bearer <TOKEN>" \
  -F "thumbnail=@D:/path/to/thumb.png" \
  -F "name=Mèo Cute" \
  -F "description=Bộ sticker mèo dễ thương" \
  -F "author=VnAlo Team" \
  -F "category=CUTE"
```

| Field | Type | Bắt buộc |
|---|---|---|
| `thumbnail` | File | ✅ |
| `name` | Text | ✅ |
| `description` | Text | Không |
| `author` | Text | Không |
| `category` | Text | Không (default: `CUSTOM`) |

> 📌 Lưu lại `packId` → dùng để upload sticker vào pack.

---

### 7.4 Cập nhật Pack

```bash
curl -X PATCH http://localhost:8083/api/v1/stickers/packs/<PACK_ID> \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Mèo Siêu Cute","category":"FUNNY"}'
```

---

### 7.5 Xóa Pack (soft delete)

```bash
curl -X DELETE http://localhost:8083/api/v1/stickers/packs/<PACK_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.6 Upload Sticker vào Pack

```bash
curl -X POST http://localhost:8083/api/v1/stickers/packs/<PACK_ID>/stickers \
  -H "Authorization: Bearer <TOKEN>" \
  -F "file=@D:/path/to/sticker.png" \
  -F "name=Mèo vẫy tay" \
  -F "emojiMatch=😺" \
  -F "keywords=cat" \
  -F "keywords=hello"
```

| Field | Type | Bắt buộc | Ghi chú |
|---|---|---|---|
| `file` | File | ✅ | `.png`→PNG, `.gif`→GIF, `.webp`→WEBP, `.json`→LOTTIE |
| `name` | Text | Không | |
| `emojiMatch` | Text | Không | Emoji liên quan |
| `keywords` | Text (multi) | Không | Thêm nhiều row cùng key `keywords` |
| `orderIndex` | Text | Không | Thứ tự hiển thị |

---

### 7.7 Lấy 1 Sticker

```bash
curl http://localhost:8083/api/v1/stickers/<STICKER_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.8 Xóa Sticker

```bash
curl -X DELETE http://localhost:8083/api/v1/stickers/<STICKER_ID> \
  -H "Authorization: Bearer <TOKEN>"
```

> Tự giảm `stickerCount` của pack.

---

### 7.9 Tìm Sticker

```bash
# Theo keyword
curl "http://localhost:8083/api/v1/stickers/search?keyword=love" \
  -H "Authorization: Bearer <TOKEN>"

# Theo emoji
curl "http://localhost:8083/api/v1/stickers/search?keyword=😺" \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.10 Tải Pack (User download)

```bash
curl -X POST http://localhost:8083/api/v1/stickers/packs/<PACK_ID>/download \
  -H "Authorization: Bearer <TOKEN>"
```

> ⚠️ Tải lại pack đã có → `400 Bad Request`

---

### 7.11 Bỏ Pack

```bash
curl -X DELETE http://localhost:8083/api/v1/stickers/packs/<PACK_ID>/download \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.12 Pack đã tải (My Packs)

```bash
curl http://localhost:8083/api/v1/stickers/my-packs \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.13 Ghi nhận sử dụng Sticker

```bash
curl -X POST http://localhost:8083/api/v1/stickers/<STICKER_ID>/use \
  -H "Authorization: Bearer <TOKEN>"
```

---

### 7.14 Sticker gần đây

```bash
curl "http://localhost:8083/api/v1/stickers/recent?limit=10" \
  -H "Authorization: Bearer <TOKEN>"
```

---

## 8. Test Checklist

### Media API
- [ ] `POST /upload` với ảnh JPG → trả về URL S3
- [ ] `POST /upload` với video MP4 → trả về URL S3
- [ ] `GET /media/{id}` → xem chi tiết media vừa upload
- [ ] `GET /media?category=CHAT_IMAGE` → list media filter đúng
- [ ] `PATCH /media/{id}` → đổi filename → xem lại thấy tên mới
- [ ] `DELETE /media/{id}` → xóa → `GET` lại trả về 404
- [ ] `POST /initiate-upload` → nhận presigned URL
- [ ] `POST /media/{id}/complete` → status chuyển sang READY
- [ ] `GET /media/{id}/download` → nhận URL download có thời hạn
- [ ] `GET /media/{id}/save` → nhận stream dữ liệu file thật (có header Content-Disposition)
- [ ] `GET /media/{id}/status` → trả về status đúng
- [ ] `POST /media/{id}/access` → cấp quyền conversation
- [ ] `GET /media/{id}/access` → xem quyền vừa cấp
- [ ] `DELETE /media/{id}/access` → thu hồi quyền

### Sticker API
- [ ] `POST /packs` → tạo pack → lưu `packId`
- [ ] `POST /packs/{id}/stickers` → upload PNG sticker
- [ ] `GET /packs` → list pack → thấy pack vừa tạo
- [ ] `GET /packs/{id}` → chi tiết pack + danh sách sticker
- [ ] `PATCH /packs/{id}` → đổi tên pack
- [ ] `GET /stickers/search?keyword=cat` → tìm thấy sticker
- [ ] `POST /packs/{id}/download` → tải pack
- [ ] `GET /my-packs` → thấy pack vừa tải
- [ ] `POST /stickers/{id}/use` → ghi nhận sử dụng
- [ ] `GET /stickers/recent` → thấy sticker vừa dùng
- [ ] `DELETE /packs/{id}/download` → bỏ pack
- [ ] `DELETE /stickers/{id}` → xóa sticker
- [ ] `DELETE /packs/{id}` → xóa pack → GET lại = 404
