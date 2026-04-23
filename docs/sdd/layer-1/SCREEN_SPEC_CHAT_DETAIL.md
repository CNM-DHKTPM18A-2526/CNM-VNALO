# SCREEN SPEC CHAT DETAIL

> [!IMPORTANT]
> Scope: Direct and group conversation detail UI, message rendering, read-only enforcement, and call launch entry points.

## Outcome

Render real-time conversation state with stable pagination, reactions, pinning, and safe transitions to voice/video calling for direct chats.

## Header Contract

- Title: resolved display name from conversation members or friend snapshot.
- Action icons:
  - call_outlined -> VoiceCallScreen for direct chat only.
  - videocam_outlined -> VideoCallScreen for direct chat only.
  - menu -> ChatOptionsScreen or GroupChatOptionsScreen based on conversation type.

## Message Timeline Contract

- Reverse ListView ordering (newest first).
- Infinite scroll fetches older messages when nearing max scroll extent.
- Adjacent image messages by same sender in close window are grouped.
- Milestone date text appears when gaps exceed threshold.
- Read state indicators shown for sender latest eligible message.

## Input Contract

- If group is read-only for members and current role is not ADMIN or DEPUTY, hide ChatInputBar and show read-only banner.
- Otherwise show ChatInputBar with send callback.
- Supports prefilledText for AI SEND_MESSAGE flow.

## Feature Rails

- PinnedMessageBar at top with jump-to-message behavior.
- Reaction toggle and reaction detail sheet integration.
- Profile cards shown as timeline anchor when conversation starts.

## Error and Guard Behavior

| Guard | Behavior |
| --- | --- |
| group call button tap | snackbar placeholder, do not open call screen |
| unresolved direct peer id | snackbar cannot open chat or call |
| message retry | enabled only for FAILED status |

## Acceptance Criteria

1. Opening conversation joins socket room via provider pipeline.
2. Leaving screen closes conversation and room subscription.
3. Group read-only policy blocks input for non-admin members.
4. Call icons only navigate for direct conversation.

## Evidence

- frontend/mobile/lib/features/chat/screens/chat_detail_screen.dart
- frontend/mobile/lib/features/chat/providers/chat_provider.dart
- frontend/mobile/lib/features/chat/widgets/chat_input_bar.dart
- frontend/mobile/lib/features/chat/widgets/pinned_message_bar.dart
