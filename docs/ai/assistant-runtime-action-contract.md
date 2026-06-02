# VNALO AI Agent Runtime Action Contract

## Mục tiêu
Tài liệu này chuẩn hóa cách AI Assistant chuyển ý định người dùng thành thao tác an toàn trên VNALO. AI không tự thực thi trực tiếp dữ liệu nhạy cảm; AI chỉ trả về `actionCommand` và `actionParams`, client sẽ validate, resolve target, yêu cầu xác nhận và mới gọi API.

## Pipeline bắt buộc
1. `Normalize`: chuẩn hóa command/params từ phản hồi AI.
2. `Validate`: kiểm tra dữ liệu bắt buộc theo từng action.
3. `Resolve`: map tên người/nhóm sang user/conversation từ danh bạ, chat list hoặc search API.
4. `Confirm`: hiển thị modal/sheet xác nhận với target, nội dung nháp, risk level.
5. `Execute`: gọi API hoặc điều hướng nếu điều kiện hợp lệ.
6. `Report`: ghi feedback vào chat AI, không ghi nhận thành công trước khi API/điều hướng hoàn tất.

## Action và điều kiện nghiệp vụ
| Command | Điều kiện tối thiểu | Risk | Web | Mobile |
|---|---|---:|---|---|
| `OPEN_CHAT` | Có target resolve được thành conversation | Low | Điều hướng | Điều hướng |
| `COMPOSE_MESSAGE` | Có recipient + content, resolve conversation duy nhất | Low | Lưu draft + mở chat | Lưu draft + mở chat |
| `START_CALL` | Target là hội thoại 1-1, không phải nhóm | Medium | Mở chat/flow xác nhận | Mở màn hình call sau xác nhận |
| `CREATE_GROUP` | Có tên nhóm + ít nhất 2 thành viên khác ngoài creator, tất cả là bạn bè | Medium | Confirm + gọi API tạo nhóm | Confirm + gọi API tạo nhóm |
| `SEND_FRIEND_REQUEST` | Target resolve duy nhất qua search user | Medium | Confirm + gửi lời mời | Confirm + gửi lời mời |
| `RECALL_MESSAGE` | Có tin nhắn mới nhất của chính user, đủ điều kiện thu hồi | High | Chưa execute trực tiếp | Confirm + recall |
| `PIN_MESSAGE`/`UNPIN_MESSAGE` | Có message hợp lệ và đủ quyền | Medium | Chưa execute trực tiếp | Confirm + pin/unpin |
| `MUTE_CONVERSATION`/`UNMUTE_CONVERSATION` | Có conversation hợp lệ | Low | Chưa execute trực tiếp | Confirm + execute nếu có provider |
| Group admin actions | Có nhóm, role đủ quyền, target rõ ràng | High | Flow thủ công | Confirm + execute tùy handler |

## Quy tắc chống sai lệch
- Không được hiển thị câu “đã gửi”, “đã gọi”, “đã tạo nhóm” trước khi API hoặc điều hướng thành công.
- Nếu target không tìm thấy hoặc ambiguous, runtime phải dừng action và hỏi rõ hơn.
- Nếu action thiếu precondition, runtime phải feedback điều kiện còn thiếu thay vì mở flow sai.
- Mọi action medium/high risk phải qua xác nhận người dùng.
- Không gửi raw prompt/tin nhắn vào analytics nếu chưa có consent riêng.

## Web runtime hiện tại
- Contract: `frontend/web/src/features/ai-assistant/runtime/aiActionContract.ts`
- Resolver: `frontend/web/src/features/ai-assistant/runtime/aiActionRuntime.ts`
- Entry point: `frontend/web/src/pages/AiChatPage.tsx`

## Backend prompt
- System prompt: `backend/java-services/services/ai-service/src/main/java/iuh/cnm/vnalo/aiservice/knowledge/SystemPrompt.java`
- Prompt bắt buộc nhấn mạnh: tạo nhóm cần ít nhất 2 thành viên khác, thao tác nhạy cảm luôn cần xác nhận, AI không tự khẳng định đã thực thi.

## Parity cần duy trì
- Web và mobile phải dùng cùng tên command, cùng key params chính: `target`, `recipient`, `content`, `groupName`, `memberNames`, `callType`.
- Khi thêm action mới, bắt buộc cập nhật: prompt backend, web contract, mobile action plan/router, test validate thiếu/ambiguous target.

## Hardening cập nhật
- Mobile tạo nhóm phải dùng danh sách thành viên distinct sau normalize tên và sau khi resolve user ID.
- Mobile không được tạo nhóm nếu resolve còn dưới 2 user khác nhau, kể cả khi AI trả về tên trùng lặp.
- Web và mobile đều phải dừng action khi target ambiguous thay vì tự chọn ứng viên đầu tiên.

- AI service phải reject CREATE_GROUP nếu memberNames sau normalize/dedupe còn dưới 2 tên distinct.

- Web không được coi việc mở chat là thực thi thành công cho `MUTE/UNMUTE`, `PIN/UNPIN`, `RECALL` hoặc group-admin actions khi chưa có executor thật.
