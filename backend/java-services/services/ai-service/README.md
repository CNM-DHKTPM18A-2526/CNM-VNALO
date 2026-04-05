# AI Service (Spring Boot)

AI Service cung cấp tính năng trợ lý ảo (Chatbot) thông minh trả lời các câu hỏi liên quan đến nền tảng VNALO.
Dịch vụ được xây dựng bằng **Spring Boot 3.4.2** (Java 21), sử dụng **Google Gemini** làm Engine chính, tự động fallback sang **Ollama** khi cạn kiệt token/quota, và dùng **Redis** để lưu trữ lịch sử hội thoại cũng như giới hạn request (Rate Limit).

---

## 🏗 Kiến Trúc

- **Ngôn ngữ / Framework**: Java 21, Spring Boot 3.4.2
- **Cơ sở dữ liệu**: Redis (Sử dụng cho Rate Limiting & Lưu cache History, không dùng DB RDBMS)
- **Primary AI**: Google Gemini API (`gemini-2.5-flash`) thông qua `google-genai` SDK
- **Fallback AI**: Ollama Local API (`llama3.1:8b`)
- **Bảo mật**: JWT (Chia sẻ chung `JWT_SECRET` với `core-service`)

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy (Docker)

AI service đã được tích hợp sẵn vào file `docker-compose.yml` gốc của project. Đây là cách dễ nhất để chạy toàn bộ hệ thống.

### 1. Cấu hình Biến môi trường (`.env`)

Mở file `docker/.env` và thêm/sửa các key sau:

```env
# Mật khẩu giải mã Token phải giống bên core-service
JWT_SECRET=ZGV2ZWxvcG1lbnQtb25seS1zZWNyZXQta2V5LWRvLW5vdC11c2UtaW4tcHJvZHVjdGlvbi10aGlzLWlzLWF0LWxlYXN0LTUxMi1iaXRzLWxvbmc=

# AI Service Config
GEMINI_API_KEY=AIzaSyxxxxxxxxxxxxxxxxx         # Lấy Miễn phí tại: https://aistudio.google.com/apikey
GEMINI_MODEL=gemini-2.5-flash
OLLAMA_URL=http://ollama:11434                 # URL tới container của Ollama 
OLLAMA_MODEL=llama3.1:8b
AI_RATE_LIMIT=5                                # Tối đa lượt hỏi / 1 phút (Cho từng user)
AI_RATE_LIMIT_GLOBAL=10                        # Tối đa lượt hỏi / 1 phút (Tổng Service - Vượt mức -> Fallback)
```

### 2. Khởi động AI Service

Tại thư mục `docker`, chạy các lệnh sau:

Chỉ chạy AI Service (và Redis cần thiết):
```bash
docker compose up -d redis ai-service
```

> **Lưu ý Fallback Ollama:** Mặc định Ollama không tự khởi động để tiết kiệm RAM. Nếu bạn muốn chạy kèm Ollama để test Fallback:
> ```bash
> docker compose --profile ai-local up -d ollama
> ```
> *Trong lần đầu chạy Ollama, hệ thống cần pull model (4.7GB):* `docker exec vnalo-ollama ollama pull llama3.1:8b`

---

## 🏃 Thao Tác Chạy Local (Không dùng Docker)

Dành cho môi trường Dev:

1. Yêu cầu: Java 21, Redis đang chạy ở port 6379 (Localhost).
2. Tại `backend/java-services/services/ai-service`, chạy lệnh:
```bash
./mvnw clean spring-boot:run
```
Service sẽ chạy ở port **8094**.

---

## 🧪 Hướng Dẫn Test Toàn Bộ Service (API)

Khi AI Service đã chạy, có thể test thông qua Swagger UI hoặc cURL. 
Mọi API chat đều **yêu cầu JWT Token** lấy được từ quá trình Đăng nhập của `core-service`.

*(Giả sử Token Đăng nhập lưu trong biến `$TOKEN`)*

### 1. Test Trạng thái hệ thống (Health Check)
Không yêu cầu Token, dùng để xem Application & Redis báo UP chưa:
```bash
curl http://localhost:8094/actuator/health
```

### 2. UI Trực Quan Swagger (Dev)
Truy cập qua trình duyệt: **[http://localhost:8094/swagger-ui.html](http://localhost:8094/swagger-ui.html)**
*Nhập Bearer Token góc phải trên cùng (Nút Authorize) để test từ giao diện.*

### 3. API Đặt Câu Hỏi (Gửi Chat)
```bash
curl -X POST http://localhost:8094/api/v1/chat/ask \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "message": "Ứng dụng VNALO có tính năng tạo nhóm không?"
      }'
```

**Dự kiến Trả về:**
```json
{
  "success": true,
  "status": 200,
  "data": {
    "answer": "Có, VNALO cung cấp tính năng...",
    "conversationId": "50c82f25-...",
    "provider": "gemini",
    "timestamp": "2026-04-03T10:00:00Z"
  }
}
```
*(Bạn có thể gài thêm thuộc tính `"conversationId"` truyền từ response trước vào JSON Request để AI nhớ Context)*

### 4. API Lấy Lịch Sử Tất Cả Session Của User
```bash
curl -X GET http://localhost:8094/api/v1/chat/history \
  -H "Authorization: Bearer $TOKEN"
```

### 5. API Lấy Lịch Sử Chi Tiết Một Chat
```bash
curl -X GET "http://localhost:8094/api/v1/chat/history?conversationId=50c82f25-..." \
  -H "Authorization: Bearer $TOKEN"
```

### 6. API Xóa Lịch Sử Chat
```bash
# Xóa cụ thể 1 phiên chat
curl -X DELETE "http://localhost:8094/api/v1/chat/history?conversationId=50c82f25-..." \
  -H "Authorization: Bearer $TOKEN"

# Xóa TẤT CẢ các cuộc trò chuyện của User truyền Token
curl -X DELETE "http://localhost:8094/api/v1/chat/history" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🛠 Xử Lý Lỗi Phổ Biến

- **Lỗi 401 Unauthorized**: JWT Token không hợp lệ hoặc sai biến môi trường `JWT_SECRET`. Đảm bảo secret khớp y hệt trong `.env`.
- **Lỗi 429 Too Many Requests**: Trigger thuật toán Rate Limit (Bảo vệ spam/quota). Chờ 1 phút để reset.
- **Lỗi "Gemini not configured" hoặc Error 503**: Thiếu `GEMINI_API_KEY` và Ollama không online. Cập nhật mã Key trong tệp `.env` hoặc bật Profile `ai-local`.
- **Test Knowledge Limit**: Thử hỏi về "Chính trị" hoặc "Bitcoin", Chatbot sẽ phản hồi: *"Xin lỗi, tôi chỉ hỗ trợ các câu hỏi liên quan đến hệ thống VNALO..."*.
