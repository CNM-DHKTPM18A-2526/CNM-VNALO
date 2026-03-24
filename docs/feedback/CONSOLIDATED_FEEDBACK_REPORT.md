# VNALO — Consolidated System Feedback Report
**Cập nhật:** 2026-03-24
**Mục đích:** Gộp và chuẩn hóa toàn bộ feedback từ 11 file riêng lẻ thành 1 nguồn duy nhất.

> [!NOTE]
> Tài liệu này thay thế toàn bộ 11 file feedback riêng lẻ trước đó. Các file cũ đã được lưu trữ tại `docs/feedback/_archive/`.

---

## 1. Tổng Quan Hệ Thống

| Metric | Giá trị |
|--------|---------|
| **Kiến trúc** | Polyglot Microservices (Java core-service + NestJS message-service) |
| **Database** | PostgreSQL 16 + Redis 7 (Docker) |
| **Frontend** | Flutter Mobile — Auth flow + 5-tab MainShell hoàn chỉnh |
| **Test coverage** | 110/110 integration tests PASSED (Deep Audit v2) |
| **Core messaging** | 100% Zalo parity (text, reply, forward, edit, recall, reactions, pin, read receipts, typing) |
| **Overall vs Zalo** | ~53% feature completion (media + calls + advanced = 0%) |

---

## 2. Backend — Trạng Thái Bảo Mật

### ✅ Đã Fix (Reconciled 2026-03-19)
| # | Vulnerability | Severity | Status |
|---|--------------|----------|--------|
| 1 | WS room join without membership check | Critical | ✅ Fixed |
| 2 | Member list endpoint leaks participants | High | ✅ Fixed |
| 3 | Pin/unpin authorization mismatch | High | ✅ Fixed |
| 4 | Recall broadcast uses client conversationId | High | ✅ Fixed |
| 5 | Overly permissive CORS (`origin: *`) | Medium | ✅ Fixed (allow-list) |
| 6 | WS auth guard not applied to handlers | Medium | ✅ Fixed |

### ⚠️ Còn Mở (Open Risks)
| # | Risk | Severity | Recommendation |
|---|------|----------|----------------|
| 1 | **Anti-abuse throttling** — no rate limit on WS events | Medium | Add per-user throttle for message.send/typing/read |
| 2 | **Presence broadcast scope** — `server.emit()` toàn cục | Medium | Limit to friend graph / shared conversations |
| 3 | **User search privacy** — `allow_search_by_phone` not mapped in entity | Medium | Map field in `UserPrivacySetting.java`, enforce in search/sync |
| 4 | **Redis password** — `docker-compose.infra.yml` không có `requirepass` | Low | Thống nhất policy |

---

## 3. Backend — Production Readiness

### Blocker (Phải fix trước deploy)
- [x] **SEQ-001**: Redis INCR cho `serverSeq` → ✅ Done
- [ ] **PRES-001**: Giới hạn presence broadcast → Chưa làm
- [ ] **TLS-001**: Reverse proxy + TLS termination → Chưa setup

### High (Nên fix)
- [x] **CORS-001**: Allow-list thay wildcard → ✅ Done
- [x] **INBOX-001**: Transaction wrapping → ✅ Done
- [x] **INBOX-002**: Unread count logic → ✅ Done
- [ ] **AUTH-001**: WS token re-verification → Chưa làm
- [ ] **REDIS-001**: Password policy thống nhất → Chưa làm

### Medium (Cải thiện dần)
- [ ] TypeORM migrations thay `synchronize: true`
- [ ] `.env.example` cho 2 services
- [ ] Structured JSON logging
- [ ] `createDirect()` concurrent race handling

---

## 4. Backend — Group Settings vs Zalo

### ✅ Đã Có
Duyệt thành viên (`joinMode`), quyền sửa info, quyền ghim, quyền invite, phân cấp role (OWNER/ADMIN/MEMBER), ghim/ẩn trò chuyện, tắt thông báo 3 mức.

### ❌ Còn Thiếu
| Feature | Priority | Effort |
|---------|----------|--------|
| Chuyển quyền owner trước khi rời nhóm | **P0** | 4h |
| `allowMemberSendMessages` (nhóm thông báo) | P1 | 2h |
| Auto-delete messages (TTL) | P2 | 4h |
| Polls / Notes / Reminders | P3 | 8h+ |

---

## 5. Frontend Mobile — Auth Flow

### Trạng thái: ✅ Production-Ready (2026-03-24)

| Screen | Status | Notes |
|--------|--------|-------|
| Splash | ✅ | Blue bg (#006AF5), 2s timer, mounted guard |
| Welcome/Onboarding | ✅ | Carousel externalized, language picker, 2 CTA buttons |
| Login (Phone → Password) | ✅ | Wizard 2-step, phone validation, password toggle |
| Register (Phone + Checkboxes) | ✅ | 2 legal checkboxes gate "Tiếp tục" |
| Register (Name) | ✅ | Centered header, validation rules |
| Register (Personal Info) | ✅ | Birthday picker with 14yo warning, Gender 3 options |
| Register (Password) | ✅ | Password strength validation |
| Register (Avatar) | ✅ | Initials avatar, skip confirmation modal |
| Contacts Sync Prompt | ✅ | "Bật danh bạ" / "Để sau" |
| OTP | ⚠️ | Architecture ready, bypassed in DEV mode |

### Auth Checklist: 10/10 PASS
All controllers disposed, mounted guards on async, try/finally patterns, Form key validation, keyboard-safe layout.

---

## 6. Frontend Mobile — Post-Login Screens

### Trạng thái: ✅ Updated (2026-03-24)

| Screen | Status | Notes |
|--------|--------|-------|
| Bottom Nav | ✅ | 5 tabs, correct icons, blue active color |
| Chat List | ✅ | Blue AppBar, search bar, QR + Add icons |
| Contacts | ✅ | Blue AppBar, search bar, friend list |
| Discover | ✅ | Blue AppBar, 4 menu items |
| Timeline | ✅ | Blue AppBar, post composer |
| Profile Tab | ✅ | Avatar + name header, quick menu, ⚙️ → Settings |
| Settings | ✅ | 13 items matching Zalo, grouped sections |
| Appearance | ✅ | 3 visual theme cards, font options, language picker |
| Dark Mode | ✅ | Full 3-mode support (Light/Dark/System) |

### Diacritics: 7/7 files PASS ✅

---

## 7. Feature Comparison Score (VNALO vs Zalo)

| Module | VNALO | Hoàn thiện |
|--------|-------|------------|
| Authentication | 7/10 | **70%** |
| User Profile | 9/10 | **90%** |
| Friends & Social | 8/11 | **73%** |
| **Text Messaging** | **16/16** | **100%** ⭐ |
| Media Messaging | 0/7 | **0%** |
| Group Features | 9/13 | **69%** |
| Voice/Video Call | 0/4 | **0%** |
| Other Features | 3/8 | **38%** ↑ (was 25%, dark mode + language + multi-tab now working) |
| **Overall** | **52/79** | **~55%** ↑ (was ~53%) |

---

## 8. Performance Benchmarks (Deep Audit v2)

| Metric | Value | Rating |
|--------|-------|--------|
| REST P50 | 23.0ms | 🟢 |
| REST P95 | 284.3ms | 🟡 |
| WS 1:1 delivery | 9.9ms avg | 🟢 |
| WS Group (1→4) | 11.2ms avg | 🟢 |
| WS throughput | 109.4 msg/sec | 🟢 |
| REST concurrency | 65.7 rps | 🟢 |
| Message ordering | Monotonic ✅ | 🟢 |

---

## 9. Đánh Giá Tổng Quan (Objective Assessment)

| Area | Score | Verdict |
|------|-------|---------|
| **Backend Architecture** | ⭐⭐⭐⭐⭐ | Enterprise-grade, clean, well-tested |
| **Backend Security** | ⭐⭐⭐⭐ | Critical fixes done, 4 medium risks open |
| **Core Messaging** | ⭐⭐⭐⭐⭐ | 100% Zalo parity, 110/110 tests |
| **Mobile Auth Flow** | ⭐⭐⭐⭐⭐ | Pixel-perfect, all edge cases handled |
| **Mobile Post-Login** | ⭐⭐⭐⭐ | All screens built, needs real data binding |
| **Media/Calls** | ⭐ | 0% — critical gap for demo |
| **DevOps/Infra** | ⭐⭐⭐ | Docker ready, needs TLS + monitoring |
| **Documentation** | ⭐⭐⭐⭐ | Extensive, now consolidated |

### Critical Path to Demo-Ready:
1. **Media upload** (Cloudinary/S3) — Chat không ý nghĩa nếu không gửi được ảnh
2. **API integration** — Chat List cần kết nối `ChatProvider` thực sự
3. **TLS + deploy** — Cần reverse proxy cho production

### Bottom Line:
> Backend messaging = Enterprise. Frontend auth = Production-ready. Nhưng **app chưa thể demo end-to-end** vì Chat List chưa gọi API thật và không gửi được media. Cần tập trung vào API integration + media upload.
