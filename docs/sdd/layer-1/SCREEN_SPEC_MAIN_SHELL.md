# SCREEN SPEC MAIN SHELL

> [!IMPORTANT]
> Scope: Root tab shell, AI command dispatch, call error surface.

## Outcome

Provide stable global shell with five primary tabs, dynamic badges, and AI-native command execution that maps into safe navigation and communication actions.

## Layout Zones

- Body: IndexedStack of five tab roots.
- BottomNavigationBar: fixed, badge-aware tabs.
- Global listeners:
  - AiAssistantProvider systemActionStream
  - SocketService onCallError stream

## Tab Contract

| Index | Tab | Screen |
| --- | --- | --- |
| 0 | Messages | ChatListScreen |
| 1 | Contacts | ContactsScreen |
| 2 | Discover | DiscoverScreen |
| 3 | Wall | HomeWallScreen |
| 4 | Profile | ProfileScreen |

## AI Command Dispatch Contract

| Command | Result |
| --- | --- |
| NAVIGATE_TO(page) | Switch tab or push QrScannerScreen |
| OPEN_CHAT | Push ChatDetailScreen for resolved conversation |
| SEND_MESSAGE | Push ChatDetailScreen with prefilledText |
| START_CALL | Push VoiceCallScreen or VideoCallScreen |
| NAVIGATE_TO_SETTINGS | Redirect to profile tab |
| NAVIGATE_TO_CHAT | Redirect to chat tab |
| NAVIGATE_TO_SCANNER | Push scanner screen |
| NAVIGATE_TO_TIMELINE | Redirect to wall tab |

### START_CALL Safety Contract

- Command is rejected with red snackbar for non-DIRECT conversation.
- Command is rejected when peerUserId cannot be resolved.
- callId is generated locally from conversationId, callerUserId, and audioOnly.

## Error UX Contract

- Incoming call signaling error from socket stream must surface as floating red snackbar.
- Unsupported AI page parameter surfaces descriptive error snackbar.

## Badge Contract

- Messages tab badge is sum of conversation unreadCount values.
- Contacts tab badge equals pending friend request count from ContactProvider.

## Acceptance Criteria

1. Unknown AI command does not crash shell.
2. START_CALL never opens call UI for group conversation.
3. onCallError stream update always surfaces UX feedback.
4. Tab state switch does not rebuild sibling tabs due to IndexedStack semantics.

## Evidence

- frontend/mobile/lib/navigation/main_shell.dart
- frontend/mobile/lib/features/ai_assistant/providers/ai_assistant_provider.dart
- frontend/mobile/lib/services/socket_service.dart
