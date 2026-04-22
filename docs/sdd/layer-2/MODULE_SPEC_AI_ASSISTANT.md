# MODULE SPEC AI ASSISTANT

> [!IMPORTANT]
> Module owner: Flutter mobile `features/ai_assistant` + `navigation/main_shell.dart`.
> Last audited: 2026-04-22. All rules derived from code-first scan of `ai_assistant_provider.dart` and `main_shell.dart`.
> **AI Assistant is mobile-only.** No web equivalent exists in the current release.

---

## Outcomes

- Provide a floating AI mascot bubble on all main shell screens.
- Accept voice (STT) and text input to generate AI responses (Gemini API via `AiService`).
- Execute system commands (navigation, open chat, start call, send message) on user intent.
- Persist conversation history locally (SharedPreferences) with optional cloud backup.
- Support mascot customization from a predefined gallery.

---

## Scope

### In Scope

- `AiAssistantProvider` state machine (idle, listening, thinking, speaking).
- Floating bubble UI (`AiFloatingBubble`) with drag, trash bin, and mascot rendering.
- AI conversation board (`AiChatBoard`) — full chat history panel.
- System action dispatcher in `MainShell._handleAiSystemAction`.
- STT (Speech-to-Text) via `SpeechToText` package, locale `vi_VN`.
- TTS (Text-to-Speech) via `FlutterTts`, language `vi-VN`, rate `0.5x`.
- Mascot gallery screen (`MascotGalleryScreen`).
- AI conversation screen (`AiConversationScreen`).
- Local history persistence: SharedPreferences (JSON, max 200 entries).
- Cloud backup toggle (opt-in, debounced).

### Out of Scope

- Web AI Assistant (not implemented).
- Group AI conversations.
- AI-generated stickers / images.
- Multi-modal (vision) AI input.

---

## 1. AI State Machine

```
AiState.idle
  │
  ├─ [User taps bubble / starts listening] ──→ AiState.listening
  │                                            (STT active, 8s max, 2s pause)
  │                                                  │
  │                               [STT result received]
  │                                             │
  │                              AiState.thinking
  │                              (AI API call, 25s timeout)
  │                                             │
  │                         [AI response received]
  │                                             │
  │                              AiState.speaking
  │                              (TTS playback vi-VN 0.5x)
  │                                             │
  │                         [TTS complete / stop]
  │                                             │
  │                                         AiState.idle
  │
  └─ [User types in board] ──→ AiState.thinking ──→ AiState.speaking ──→ AiState.idle
```

### State Field Details

| Field | Type | Description |
|---|---|---|
| `state` | `AiState` | Current pipeline state |
| `persistentEnabled` | bool | AI bubble shown persistently across sessions |
| `provisionallyVisible` | bool | Temporarily shown during a session even if persistent=false |
| `isSessionActive` | bool | Active STT or TTS session in progress |
| `isBusy` | bool | `state != idle || isPipelineLocked` |
| `isMascotVisible` | bool | `persistentEnabled || provisionallyVisible || isSessionActive` |
| `isPipelineLocked` | bool | Prevents concurrent AI pipeline calls |
| `operationToken` | int | Incremented to invalidate stale async operations |

---

## 2. Visibility & Persistence Rules

### 2.1 Enabled by Default

AI Assistant is **disabled by default** (`persistentEnabled = false`).

- `persistentEnabled` is stored in SharedPreferences key `vnalo_ai_is_visible`.
- User must explicitly enable it.

### 2.2 Visibility Lifecycle

```
isMascotVisible = persistentEnabled || provisionallyVisible || isSessionActive

Idle auto-hide: after 12s of AiState.idle with no interaction:
  → provisionallyVisible = false
  → if !persistentEnabled: bubble hides
```

### 2.3 Session Visibility

```
User initiates voice or typed query:
  → provisionallyVisible = true
  → isSessionActive = true (during pipeline)
  → On completion: isSessionActive = false
  → idleAutoHideTimer starts (12s)
  → if no new interaction: provisionallyVisible = false
```

---

## 3. STT (Speech-to-Text)

| Parameter | Value |
|---|---|
| Package | `speech_to_text` |
| Locale | `vi_VN` (resolved at runtime, falls back to device locale) |
| Listen duration | 8 seconds max |
| Pause for silence | 2 seconds |
| Deduplication | `lastFinalResultAt` + `lastFinalResultText` to prevent duplicate results within 300ms |
| Guard timer | 10s listen guard — if STT doesn't produce result, state reset to idle |

### STT Flow

```
User taps bubble / presses mic
  → SpeechToText.listen(onResult, listenFor: 8s, pauseFor: 2s)
  → On result (final): _lastWords = result → _submitToAi()
  → On error: state = idle, errorMessage shown
  → Listen guard timer: if no final result in 10s → stop + reset
```

---

## 4. TTS (Text-to-Speech)

| Parameter | Value |
|---|---|
| Package | `flutter_tts` |
| Language | `vi-VN` |
| Pitch | `1.0` |
| Speech Rate | `0.5` (slower for Vietnamese clarity) |
| Await completion | `true` |

TTS is triggered after each AI response. During TTS playback, `state = AiState.speaking`.  
Stop TTS: user taps bubble during speaking → `tts.stop()` → `state = AiState.idle`.

---

## 5. AI API Integration

- Service: `AiService` (HTTP calls to Gemini or configured AI endpoint).
- Timeout: **25 seconds** per request.
- Session history sent as `_sessionHistory` for context (role-based: user/assistant).
- Max conversation entries stored locally: **200** (FIFO eviction).
- On error: `errorMessage` set → displayed in bubble/board → `state = idle`.

### Conversation History Storage

```
Key: 'vnalo_ai_history_v1' in SharedPreferences
Format: JSON array of AiConversationEntry { role, text, source, createdAt }
Roles: user | assistant | system
Max: 200 entries
```

Cloud backup: opt-in boolean (`vnalo_ai_cloud_backup_enabled`). Debounced write.

---

## 6. System Actions (AI → App Navigation)

The AI can dispatch system actions to navigate the app or perform actions on the user's behalf.  
Actions are emitted via `systemActionStream` and handled in `MainShell._handleAiSystemAction`.

### 6.1 Supported Commands

| Command | Params | Behaviour |
|---|---|---|
| `NAVIGATE_TO` | `page: string` | Switch to named tab |
| `NAVIGATE_TO_SETTINGS` | none | Navigate to settings tab |
| `NAVIGATE_TO_CHAT` | none | Switch to chat tab |
| `NAVIGATE_TO_SCANNER` | none | Push QR scanner screen |
| `NAVIGATE_TO_TIMELINE` | none | Switch to timeline/wall tab |
| `OPEN_CHAT` | `target: string` | Find conversation by name → push ChatDetailScreen |
| `SEND_MESSAGE` | `target: string, content: string` | Open chat → prefill text in composer |
| `START_CALL` | `target: string, callType: 'audio'|'video'` | Find conversation → push VoiceCall/VideoCallScreen |

### 6.2 Command Guards

| Guard | Condition | Behaviour |
|---|---|---|
| Conversation not found | `findConversationByName(target)` returns null | Snackbar error, abort |
| Already in target chat | `activeConversationId == conversation.id` | Switch to chat tab, skip navigation |
| Call screen already active | `_isCallScreenActive == true` | Abort, no duplicate call screens |
| Group call attempt | `!isDirect || peerUserId.isEmpty` | Snackbar error: "chỉ hỗ trợ hội thoại 1-1" |

### 6.3 START_CALL Multi-Device Safety

`_isCallScreenActive` flag is set to `true` on call start and reset on pop. This prevents concurrent call screens from being pushed via AI command.

---

## 7. Mascot System

### 7.1 Mascot Metadata

```dart
MascotMetadata {
  id: string,
  name: string,
  renderMode: MascotRenderMode (static2D | animated3D),
  previewAsset: string,
  description: string,
}
```

Default mascots list: `MascotMetadata.defaultMascots`.  
Selected mascot persisted in SharedPreferences key `vnalo_ai_mascot_id`.

### 7.2 Render Modes

| Mode | Renderer | Notes |
|---|---|---|
| `static2D` | Flutter `Image.asset` | No gesture hijacking issues |
| `animated3D` | `model_viewer` WebView | Known gesture hijacking issue — IgnorePointer applied during drag |

> [!WARNING]
> **Known issue (3D mode)**: WebView-based 3D mascot intercepts touch events during bubble drag. `IgnorePointer` wrapper is applied to the mascot widget during drag. Full migration to 2D is recommended (see implementation_plan.md).

---

## 8. Floating Bubble UI

Reference: `ai_floating_bubble.dart`

| Feature | Details |
|---|---|
| Position | Draggable, persisted per-session (defaults to bottom-right) |
| Drag | `GestureDetector.onPanUpdate` — moves bubble freely on screen |
| Trash bin | Appears during drag at bottom center. Proximity check → if within radius → dismiss bubble |
| Tap | Short tap → toggles listening / stops TTS |
| Long press | Opens full AI conversation board |
| Emotion display | Mascot expression updates per `currentEmotion`: `neutral | happy | thinking | speaking | error` |
| Sound level visualizer | Ring animation scale driven by `soundLevel` during listening |

---

## 9. AI Conversation Board

Reference: `ai_chat_board.dart`

| Feature | Details |
|---|---|
| Mode | Full-screen overlay panel (swipe up / drag to expand) |
| History | Displays `conversationHistory` (200 entries max) |
| Input | Text field + mic button |
| Glassmorphism | `BackdropFilter` + semi-transparent background |
| System message | Displays `[Source: system]` entries with different styling |

---

## 10. AI Conversation Screen

Reference: `ai_conversation_screen.dart`

Standalone full-screen conversation view for the AI assistant conversation.  
Accessed from MainShell or bubble long-press.

---

## 11. Mascot Gallery Screen

Reference: `mascot_gallery_screen.dart`

- Displays all available mascots with preview + description.
- User selects mascot → `setMascot(mascot)` → persisted.
- Accessed from AI conversation board settings or profile settings.

---

## 12. Known Issues & Active Technical Debt

| Issue | Severity | Status |
|---|---|---|
| 3D WebView gesture hijacking during drag | High | Mitigated (IgnorePointer), full 2D migration planned |
| `translateMessage` helper forces AI visibility | Medium | Open — violates "Disabled by Default" |
| `_isCallScreenActive` flag not reset on app cold start | Low | Open |
| Cloud backup debounce timer may not fire on app kill | Low | Open |

---

## 13. Decisions

1. AI Assistant is disabled by default (opt-in). Prevents unexpected visibility after app upgrade.
2. STT uses `vi_VN` locale resolved at runtime; falls back to system locale if unavailable.
3. Max 200 conversation history entries (FIFO) to bound SharedPreferences storage.
4. Mascot 3D rendering uses `IgnorePointer` during drag as a tactical fix; final solution is 2D migration.
5. System actions gated by `_isCallScreenActive` flag to prevent duplicate call screens.
6. AI is mobile-only; web equivalent is not planned for current release.

---

## 14. Task Breakdown

| Task | Status | Priority |
|---|---|---|
| Migrate 3D mascot to 2D to eliminate WebView gesture hijacking | Open | P0 |
| Fix: `translateMessage` helper must not force AI visibility | Open | P1 |
| Add `NAVIGATE_TO_CONTACTS` system action | Open | P2 |
| Add `SEARCH_GLOBAL` system action | Open | P2 |
| Cloud backup implementation (server-side) | Open | P3 |
| Implement `MascotRenderMode.animated2D` (Lottie/Rive) | Open | P2 |

---

## 15. Evidence

- frontend/mobile/lib/features/ai_assistant/providers/ai_assistant_provider.dart
- frontend/mobile/lib/features/ai_assistant/widgets/ai_floating_bubble.dart
- frontend/mobile/lib/features/ai_assistant/widgets/ai_chat_board.dart
- frontend/mobile/lib/features/ai_assistant/screens/ai_conversation_screen.dart
- frontend/mobile/lib/features/ai_assistant/screens/mascot_gallery_screen.dart
- frontend/mobile/lib/features/ai_assistant/models/mascot_metadata.dart
- frontend/mobile/lib/navigation/main_shell.dart (_handleAiSystemAction)
- frontend/mobile/lib/services/ai_service.dart
