# MODULE SPEC WEB APP

> [!IMPORTANT]
> Module owner: frontend/web — React 18 + TypeScript + Vite + TailwindCSS.
> Last audited: 2026-04-22. All rules derived from code-first scan unless marked `[SPEC_ONLY]`.
> This spec covers the web client as a distinct platform from the Flutter mobile app.

---

## Outcomes

- Provide a desktop/browser messaging experience matching core mobile features.
- Share the same Socket.IO `/chat` signaling backend as mobile.
- Enforce `restrictedWebMode` policy: QR-login web sessions see only messages sent after login.
- Support 1:1 and group chat, contacts management, call (audio/video), and profile.

---

## Scope

### In Scope

- React SPA, client-side routing via React Router v6.
- Auth: password login, QR login (scan with mobile), registration, forgot password.
- Chat: inbox list, conversation detail, send/receive messages, group management.
- Contacts: friends list, friend requests, user search.
- Profile: view/edit personal info, update password.
- Documents: shared media browser across conversations.
- Call: WebRTC audio/video call via `WebRtcCallService` (TypeScript port).
- Real-time: Socket.IO `/chat` namespace (same as mobile).
- i18n: `LanguageContext` for UI string translations.

### Out of Scope

- AI Assistant (mobile-only feature, no web equivalent).
- Timeline / Home Wall (mobile-only).
- Discover (mobile-only).
- QR scanner (mobile-only; QR login is different — web displays QR, mobile scans it).
- Push notifications (no FCM on web currently).
- Local SQLite cache (web uses localStorage for soft deletes + pinned state only).

---

## 1. Tech Stack

| Layer | Technology |
|---|---|
| Framework | React 18 |
| Language | TypeScript |
| Build tool | Vite |
| Styling | TailwindCSS |
| Routing | React Router v6 |
| State | useState + useCallback + Context (no Redux/Zustand) |
| Real-time | Socket.IO client (`/chat` namespace) |
| WebRTC | Browser native `RTCPeerConnection` via `WebRtcCallService.ts` |
| Auth storage | localStorage (access token + refresh token) |
| Search | In-memory FlexSearch index (`searchIndex.ts`) |

---

## 2. Route Map

| Path | Page Component | Auth Required | Notes |
|---|---|---|---|
| `/login` | `LoginPage` | ❌ | Redirects to `/chat` if already logged in |
| `/login/qr` | `QrLoginPage` | ❌ | Displays QR code; mobile app scans to auth |
| `/register` | `RegisterPage` | ❌ | Phone + OTP registration |
| `/forgot-password` | `ForgotPasswordPage` | ❌ | Phone + OTP password reset |
| `/chat` | `ChatPage` (inside `MainLayout`) | ✅ | Inbox + empty state |
| `/chat/:conversationId` | `ChatPage` (inside `MainLayout`) | ✅ | Opens specific conversation |
| `/contacts` | `ContactsPage` (inside `MainLayout`) | ✅ | Friends list + search + requests |
| `/documents` | `DocumentsPage` (inside `MainLayout`) | ✅ | Shared media browser |
| `/profile` | `ProfilePage` (inside `MainLayout`) | ✅ | User profile + settings |
| `/*` | Redirect to `/chat` | — | 404 fallback |

---

## 3. Layout Structure

```
MainLayout (ProtectedRoute guard)
  ├── Left sidebar (conversations list, search, create group)
  ├── Center panel (ChatWindow or page content)
  └── Right sidebar (ConversationInfo, SearchMessagesPanel, SearchGlobalPanel)
```

Left sidebar panels (toggled by route):
- `/chat` → `ChatList` component
- `/contacts` → `ContactsPage`
- `/documents` → `DocumentsPage`
- `/profile` → `ProfilePage`

---

## 4. ChatPage Feature Set (Core Feature)

ChatPage (`/pages/ChatPage.tsx`, 4000 lines) is the primary feature page, containing:

### 4.1 Conversation Management

| Feature | Status |
|---|---|
| Inbox loading (`fetchInbox`) | ✅ |
| Direct conversation creation (`getOrCreateDirectConversation`) | ✅ |
| Group conversation creation (`createGroupConversation`) | ✅ |
| Add members to group (`addMembersToConversation`) | ✅ |
| Leave group (`leaveConversation`) | ✅ |
| Remove member from group (`removeMember`) | ✅ |
| Update member role (`updateMemberRole`) | ✅ |
| Rename group (`renameGroupConversation`) | ✅ |
| Update group avatar (`updateGroupAvatar`) | ✅ |
| Set conversation nickname (`setConversationNickname`) | ✅ |
| Pin/unpin conversation (client-side, localStorage) | ✅ |
| Delete local history (client-side timestamp filter) | ✅ |

### 4.2 Messaging Features

| Feature | Status |
|---|---|
| Send TEXT message (WS + REST fallback) | ✅ |
| Send IMAGE/FILE/AUDIO/STICKER | ✅ |
| Reply to message | ✅ |
| Forward message (`MessageShareModal`) | ✅ |
| Recall message | ✅ |
| Delete message for me | ✅ (localStorage-persisted) |
| Multi-select messages | ✅ |
| Pin / unpin message | ✅ |
| View pinned messages | ✅ |
| Message search within conversation | ✅ (`SearchMessagesPanel`) |
| Global search (conversations + users + messages) | ✅ (`SearchGlobalPanel`, FlexSearch) |
| Jump to searched message | ✅ |
| Read receipts (mark read on open) | ✅ |
| Typing indicator | ✅ |
| Message reaction (emoji) | ✅ |
| Reaction details modal | ✅ (`MessageReaction`) |
| Image viewer | ✅ (`ImageViewer`) |
| Call log bubble in chat | ✅ (`CallLogBubble`) |

### 4.3 restrictedWebMode (QR Login Policy)

Web sessions initiated via QR login carry `restrictedWebMode=true` in the JWT.

| Behaviour | restrictedWebMode=false | restrictedWebMode=true |
|---|---|---|
| Display messages from before login | ✅ | ❌ Replaced with `'Nội dung được ẩn trên web do chính sách đồng bộ.'` |
| Inbox preview of pre-login messages | ✅ | ❌ Replaced with restricted text |
| Sending new messages | ✅ | ❌ Blocked at backend service level |

> **Client-side**: `isRestrictedWebToken(accessToken)` parses JWT and sets `isRestrictedMode` flag.
> **Backend enforcement**: Additional guard in `message.service` checks `access.restrictedWebMode`.

### 4.4 Delete for Me (Backend + localStorage)

Web now calls backend hide endpoint and keeps a local fallback cache:
- API: `DELETE /messages/{id}/for-me` to persist `hiddenByUsers` on server.
- localStorage key `vnalo:chat:deleted-for-me:{userId}` still exists for optimistic/offline UI behavior.
- Primary source of truth is backend history filtering; localStorage is no longer the only mechanism.

### 4.5 Message Deduplication

Web ChatPage deduplicates `message.received` events (dual delivery from room + per-user):
- By `clientMessageId` (client UUID) if present.
- By `message.id` (server UUID) otherwise.
- `dedupeMessages()` + `upsertMessage()` merge fields from both copies.

---

## 5. Call Feature (Web)

Web implements WebRTC calls via `WebRtcCallService.ts` (TypeScript port of Flutter `WebRtcCallService.dart`).

| Feature | Status |
|---|---|
| Outgoing voice/video call | ✅ |
| Incoming call detection | ✅ (`useChatSocket` → `callState`) |
| Call modal UI (`CallModal.tsx`) | ✅ |
| ICE candidate exchange | ✅ |
| Toggle mic / camera | ✅ |
| End call | ✅ |
| Ring timeout | ✅ |
| Group call | ❌ Blocked |

> Web call uses browser `RTCPeerConnection` directly; no `flutter_webrtc` SDK. ICE servers from same `VITE_ICE_SERVERS` env config.

---

## 6. Auth Flows

### 6.1 Password Login

```
LoginPage → POST /auth/login {phone, password}
  → {accessToken, refreshToken}
  → Store in localStorage
  → Navigate to /chat
```

### 6.2 QR Login

```
QrLoginPage → POST /auth/qr/sessions → {token, expiresAt, status}
           → Display QR code embedding token
           → Poll /auth/qr/sessions/{token} until status=APPROVED
           → On APPROVED: receive {accessToken, refreshToken}
           → Parse JWT: if restrictedWebMode=true → setIsRestrictedMode(true)
           → Navigate to /chat (restricted mode active)
```

### 6.3 Registration

```
RegisterPage → POST /auth/register/send-otp {phone, email}
            → POST /auth/register/verify-otp {email, otp}
            → POST /auth/register {phone, email, password, displayName, otp?}
            → Auto-login → Navigate to /chat
```

### 6.4 Forgot Password

```
ForgotPasswordPage → POST /auth/forgot-password {email}
                  → POST /auth/reset-password {email, otp, newPassword}
                  → Navigate to /login
```

---

## 7. Socket Integration (Web)

Web connects to the same `/chat` Socket.IO namespace as mobile.

Hook: `useChatSocket()` — manages:
- Connection lifecycle (connect/disconnect on auth change).
- Event subscriptions: `message.received`, `message.recalled`, `message.typing`, `message.read`, `message.pinned`, `message.unpinned`, `call.offer`, `call.answer`, `call.ice-candidate`, `call.end`.
- Room joining per conversation.
- Auto reconnect.

Socket module: `features/chat/chat.socket.ts`.

---

## 8. Search Architecture

Web implements a client-side search index using FlexSearch:

```
searchIndex.ts:
  initializeSearchIndex() → creates FlexSearch Document instance
  updateSearchIndexConversations(conversations) → indexes conversation names
  updateSearchIndexUsers(users) → indexes user displayName, phone, email, bio
  addMessagesToSearchIndex(messages) → indexes message content
```

- Search index rebuilt on conversation/message/user data changes.
- Used by `SearchGlobalPanel` for real-time local search.

---

## 9. Contacts & Friends (Web)

`ContactsPage` provides:
- Friends list with online status.
- User search by phone/name.
- Friend request send/accept/decline.
- Block/unblock (if implemented in web).

API module: `features/friends/friends.api.ts`.

---

## 10. Platform Differences vs Mobile

| Feature | Mobile (Flutter) | Web (React) |
|---|---|---|
| Local message cache | SQLite (persistent, cross-session) | localStorage (soft-delete + pinned only) |
| Delete for me sync | Backend `hiddenByUsers` | localStorage-only |
| AI Assistant | ✅ Floating bubble + conversation | ❌ Not available |
| Timeline / Wall | ✅ `HomeWallScreen` | ❌ Not available |
| Discover | ✅ `DiscoverScreen` | ❌ Not available |
| QR scanner | ✅ Scan QR codes | ❌ QR login only (display QR, not scan) |
| Push notifications | FCM (wired, partial) | ❌ Not wired |
| Group call | ❌ Blocked | ❌ Blocked |
| Offline message catch-up | SQLite pull on reconnect | REST pull on reconnect |
| restrictedWebMode enforcement | N/A (mobile not restricted) | ✅ Client + backend enforcement |
| i18n | `AppLocalizations` | `LanguageContext` |

---

## 11. Decisions

1. Web uses React + Vite + TailwindCSS (not Next.js) for fast SPA delivery.
2. No Redux/Zustand: useState + Context for simplicity at current scale.
3. FlexSearch for client-side instant search (no search API round-trip).
4. Delete-for-me is localStorage-only on web; server sync is a future milestone.
5. QR login triggers `restrictedWebMode=true` in JWT; client enforces message masking.
6. AI Assistant is mobile-only; no web equivalent planned in current release.

---

## 12. Task Breakdown

| Task | Status | Priority |
|---|---|---|
| Align "delete for me" between web (localStorage) and mobile (DB `hiddenByUsers`) | Open | P2 |
| Wire FCM push notifications for web (service worker) | Open | P2 |
| Handle `group.disbanded` event in web `useChatSocket` | Open | P0 |
| Handle group membership events in web | Open | P1 |
| Add `onlyAdminCanPost` enforcement in `MessageInput.tsx` | Open | P1 |
| Add documentation for web QR login session polling | Done | — |

---

## 13. Evidence

- frontend/web/src/App.tsx
- frontend/web/src/pages/ChatPage.tsx
- frontend/web/src/pages/ContactsPage.tsx
- frontend/web/src/pages/ProfilePage.tsx
- frontend/web/src/pages/QrLoginPage.tsx
- frontend/web/src/pages/RegisterPage.tsx
- frontend/web/src/pages/ForgotPasswordPage.tsx
- frontend/web/src/pages/DocumentsPage.tsx
- frontend/web/src/features/chat/chat.socket.ts
- frontend/web/src/features/chat/useChatSocket.ts
- frontend/web/src/features/chat/webrtcCallService.ts
- frontend/web/src/features/chat/searchIndex.ts
- frontend/web/src/features/chat/components/
- frontend/web/src/features/auth/useAuth.ts
- frontend/web/src/features/friends/friends.api.ts
