# MODULE SPEC: AI ASSISTANT INTEGRATION

> **Authority:** This document is the **Source of Truth** for AI Assistant behavior in VNALO. All statements using MUST, SHALL, and REQUIRED conform to RFC 2119.

> **Module Owner:** ai-service (Java/Spring Boot) + Flutter AiAssistantProvider + Web ChatClient.
> **Status:** TARGET — 2026-04-29

---

## 1. OVERVIEW

The AI Assistant provides a conversational interface embedded in the VNALO client, supporting voice input (STT), text input, AI response generation, and text-to-speech (TTS) playback. The assistant can also dispatch system actions to navigate the app.

**Key Design Decisions:**
- AI is **opt-in** (disabled by default) to respect user privacy
- Conversation history is stored locally (mobile) and optionally synced to cloud
- Gemini API is the primary provider; Ollama is the fallback for offline/on-prem deployments
- AI Assistant is mobile-first; web equivalent is planned

---

## 2. SCOPE

### In Scope
- AI state machine: idle → listening → thinking → speaking → idle
- Voice input (STT) via device microphone
- Text input via AI conversation board
- AI response generation via ai-service (Gemini / Ollama)
- TTS playback of AI responses in Vietnamese
- System action dispatcher (navigation, open chat, start call)
- Local history persistence (200-entry FIFO)
- Mascot rendering (2D and 3D)

### Out of Scope
- Multi-modal AI input (vision)
- AI-generated stickers or images
- Group AI conversations
- Web AI Assistant (current release)
- Cloud backup (future release)

---

## 3. SECURITY RULES

### SR-1: AI Endpoint Authentication

```
REQUIRED: All requests to ai-service MUST include a valid JWT Bearer token.
The token MUST be validated against the shared HS512 secret.
Anonymous access to ai-service is PROHIBITED.
```

### SR-2: User Isolation

```
REQUIRED: AI conversation history is scoped to the authenticated userId.
ai-service MUST validate that the requesting userId matches the JWT subject.
Cross-user history access is PROHIBITED.
```

### SR-3: AI Response Validation

```
REQUIRED: ai-service MUST sanitize all AI-generated responses before returning.
Content MUST be filtered for:
  - PII (email, phone, national ID patterns)
  - Malicious URLs
  - Inappropriate content (platform policy)
REQUIRED: System action commands MUST be validated against user permissions before dispatch.
```

### SR-4: Rate Limiting

```
REQUIRED: ai-service MUST enforce per-user rate limiting on AI API calls.
Limit: 20 requests per minute per user.
Exceeding the limit: HTTP 429 with Retry-After header.
```

---

## 4. AI STATE MACHINE

```
                    ┌──────────────────────────────────┐
                    │          AiState.idle             │
                    │  (Bubble visible if enabled)      │
                    └──────────────┬───────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
   [User taps]           [User types in]       [User taps mic]
              │                    │                    │
              ▼                    ▼                    ▼
   AiState.listening   AiState.thinking      AiState.listening
   (mic active,        (API call in          (STT active,
    8s timeout)        progress,             8s max,
                         25s timeout)        2s pause)
              │                    │                    │
              │                    │                    │
              │         [Response received]◄───────────┘
              │                    │
              │                    ▼
              │         AiState.speaking
              │         (TTS playback vi-VN 0.5x)
              │                    │
              └────────────────────┘
                                   │
                          [TTS complete / stop]
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │          AiState.idle             │
                    │  (Auto-hide after 12s idle)     │
                    └──────────────────────────────────┘
```

---

## 5. CONFIGURATION

### 5.1 AI Service Configuration

| Parameter | Value | Source |
|---|---|---|
| Primary Provider | Gemini | env `GEMINI_API_KEY` |
| Fallback Provider | Ollama | env `OLLAMA_BASE_URL` |
| Model (Gemini) | `gemini-2.0-flash` | env `GEMINI_MODEL` |
| Model (Ollama) | Configured locally | env `OLLAMA_MODEL` |
| Request Timeout | 25 seconds | Hardcoded |
| Rate Limit | 20 req/min/user | Hardcoded |
| Max History Entries | 200 (FIFO) | Hardcoded |
| Max STT Duration | 8 seconds | Hardcoded |
| STT Silence Pause | 2 seconds | Hardcoded |
| Idle Auto-Hide | 12 seconds | Hardcoded |
| TTS Language | `vi-VN` | Hardcoded |
| TTS Speech Rate | `0.5` | Hardcoded |

### 5.2 Fallback Strategy

```
1. Attempt Gemini API call with configured API key
2. IF Gemini returns 5xx or network error:
     → Retry once with exponential backoff (1s delay)
3. IF retry fails OR Gemini returns 429 (rate limit):
     → Attempt Ollama fallback call (if OLLAMA_BASE_URL configured)
4. IF Ollama fails OR not configured:
     → Return error to client: "AI temporarily unavailable"
5. Frontend: display error in bubble/board, state → idle
```

---

## 6. WEBSOCKET EVENTS

### 6.1 Client → Server (AI-specific namespace)

| Event | Payload | Description |
|---|---|---|
| `ai.chat` | `{ conversationHistory, userMessage, clientMessageId }` | Send message to AI |
| `ai.abort` | `{ clientMessageId }` | Abort ongoing AI generation |

### 6.2 Server → Client

| Event | Payload | Description |
|---|---|---|
| `ai.response` | `{ clientMessageId, text, done, error? }` | AI response stream (can be chunked) |
| `ai.error` | `{ code, message, clientMessageId }` | Error response |

---

## 7. DATA FLOW

### 7.1 Chat Message Format

```json
{
  "role": "user" | "assistant" | "system",
  "text": "string",
  "source": "voice" | "text" | "system",
  "createdAt": "ISO8601",
  "id": "uuid"
}
```

### 7.2 System Prompt

```json
{
  "role": "system",
  "text": "Bạn là trợ lý AI của VNALO. Hãy trả lời bằng tiếng Việt, ngắn gọn, hữu ích. Không tiết lộ thông tin cá nhân. Chỉ trả lời các câu hỏi phù hợp.",
  "source": "system"
}
```

---

## 8. SYSTEM ACTION DISPATCHER

The AI can produce structured commands in its response. The client MUST parse and validate these before execution.

### 8.1 Supported Commands

| Command | Parameter | Validation | Action |
|---|---|---|---|
| `NAVIGATE_TO` | `page: string` | Page name must be in allowed list | Navigate to named tab |
| `NAVIGATE_TO_SETTINGS` | none | Always valid | Navigate to settings |
| `NAVIGATE_TO_CHAT` | none | Always valid | Switch to chat tab |
| `NAVIGATE_TO_CONTACTS` | none | Always valid | Switch to contacts tab |
| `OPEN_CHAT` | `target: string` | Conversation must exist | Push ChatDetailScreen |
| `SEND_MESSAGE` | `target: string, content: string` | Conversation must exist, content sanitized | Open chat, prefilled text |
| `START_CALL` | `target: string, callType: 'audio'|'video'` | Must be 1:1 conversation, user is participant | Push call screen |
| `SEARCH_GLOBAL` | `keyword: string` | Keyword sanitized, non-empty | Trigger global search |

### 8.2 Command Parsing

```
AI response MAY contain structured JSON commands embedded in the text.
Format: ```json { "action": "COMMAND_NAME", "params": {...} } ```
Client MUST:
  1. Extract JSON block from response text
  2. Validate action against allowed command list
  3. Validate params against parameter schema
  4. Execute only if all validations pass
  5. Strip command JSON from displayed text
```

### 8.3 Command Guards

| Guard | Condition | Action |
|---|---|---|
| Conversation not found | `findConversationByName(target)` returns null | Snackbar error |
| Already in target chat | `activeConversationId == conversation.id` | Skip navigation |
| Call screen active | `_isCallScreenActive == true` | Abort, no duplicate |
| Group conversation for call | `!isDirect` | Snackbar: "chỉ hỗ trợ cuộc gọi 1-1" |

---

## 9. OBSERVABILITY

### 9.1 Logging

```
ai-service MUST log:
  - Request: userId, timestamp, input token count
  - Response: userId, timestamp, output token count, latency
  - Error: userId, error code, error message, provider
  - Token usage: per-user, per-day aggregation
```

### 9.2 Metrics

| Metric | Description |
|---|---|
| `ai_request_total` | Total AI API requests |
| `ai_request_duration_seconds` | Request latency histogram |
| `ai_provider_switch_total` | Count of Gemini → Ollama fallbacks |
| `ai_rate_limit_exceeded_total` | Rate limit hit count |
| `ai_error_total` | Error count by error type |

---

## 10. EVIDENCE

| Component | File |
|---|---|
| AI service controller | `backend/java-services/services/ai-service/src/.../controller/` |
| AI service implementation | `backend/java-services/services/ai-service/src/.../service/` |
| Flutter AI provider | `frontend/mobile/lib/features/ai_assistant/providers/ai_assistant_provider.dart` |
| Flutter AI floating bubble | `frontend/mobile/lib/features/ai_assistant/widgets/ai_floating_bubble.dart` |
| Flutter system action dispatcher | `frontend/mobile/lib/navigation/main_shell.dart` |

---

## 11. REMEDIATION CHECKLIST

| Item | Priority | Status |
|---|---|---|
| Enforce JWT validation on ai-service endpoints | CRITICAL | `[SPEC_ONLY]` |
| Implement per-user rate limiting (20 req/min) | CRITICAL | `[SPEC_ONLY]` |
| Implement Ollama fallback on Gemini 5xx | HIGH | `[SPEC_ONLY]` |
| Implement AI response content sanitization (PII, malicious URLs) | CRITICAL | `[SPEC_ONLY]` |
| Validate AI system commands against user permissions | CRITICAL | `[SPEC_ONLY]` |
| Implement `NAVIGATE_TO_CONTACTS` and `SEARCH_GLOBAL` actions | MEDIUM | `[SPEC_ONLY]` |
| Web AI Assistant equivalent | LOW | Planned |
| Cloud backup for AI history | LOW | Planned |
