# SCREEN SPEC VIDEO CALL

> [!IMPORTANT]
> Scope: VideoCallScreen rendering, media stream attachment, draggable preview, and control overlay behavior.

## Outcome

Deliver stable two-stream video call experience with fallback UI before connection and non-disruptive control interactions.

## Rendering Contract

- Before connected:
  - Show local preview as background if available.
  - Else show remote placeholder with target identity.
- After connected:
  - Show remote stream full-screen.
  - Show draggable local preview overlay.

## Control Overlay Contract

- Tap toggles overlay visibility.
- Auto-hide after 5 seconds when connected.
- Top actions: back and camera flip.
- Bottom actions include decline or accept for callee pre-accept state, and in-call controls after acceptance.

## Stream Lifecycle

- Initialize local and remote RTCVideoRenderer before binding streams.
- Update renderer srcObject on service state updates.
- Dispose both renderers on screen dispose.

## Side Effects

- Ringtone behavior mirrors voice call path.
- Wakelock enabled during call and released on dispose.
- Caller emits call log message with mediaType video after end.

## Failure and End Contract

- On timeout end reason, return faster to previous screen.
- On remote end or failure, ensure controls and timers are canceled.

## Acceptance Criteria

1. Renderers are initialized before stream bind.
2. Remote stream transition does not crash when local stream still active.
3. Draggable preview remains constrained to safe viewport bounds.
4. Call log is emitted exactly once for caller side.

## Evidence

- frontend/mobile/lib/features/call/screens/video_call_screen.dart
- frontend/mobile/lib/features/call/services/webrtc_call_service.dart
