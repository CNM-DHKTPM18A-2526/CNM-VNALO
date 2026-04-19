# CLAUDE.md - VNALO Mobile Specialist

## Project Vision
To build a high-performance, high-aesthetic messaging and calling ecosystem ("Zalo Premium" style) with seamless AI integration.

## Guiding Principles
- **Spec-Driven Development (SDD)**: Spec first, then code. Reconcile if they diverge.
- **Premium Glass Aesthetic**: Use HSL colors, alpha-blended dark backgrounds (e.g., `Colors.black.withValues(alpha: 0.5)`), and smooth micro-animations.
- **Microservice Harmony**: Align mobile logic with the 7 key Java services (Core, Message, Media, AI, Analytics, Moderation, Notification).

## Technical Standards
- **Framework**: Flutter 3.x
- **State Management**: Provider / ChangeNotifierProxyProvider
- **Signaling**: WebRTC + Socket.io (Node.js Gateway)
- **Design Tokens**: Standard black-alpha overlays, Inter font, 24px thumb-zone padding.

## Reference Patterns
- **Call Screens**: `lib/features/call/screens/voice_call_screen.dart` (Standardized floating layout).
- **Socket Handling**: `lib/services/socket_service.dart` (Unified event emitter).
- **AI Integration**: `lib/features/ai_assistant/providers/ai_assistant_provider.dart` (Action mapping pattern).

## Development Workflow Commands
- **Analyze**: `flutter analyze lib`
- **Clean**: `flutter clean && flutter pub get`
- **Run Dev**: `flutter run`
- **Build**: `flutter build apk/ios`
- **Lint Fix**: `dart fix --apply`

## PR Review Criteria
- [ ] 0 Errors and 0 Dangerous Warnings in `flutter analyze`.
- [ ] Documentation (Spec) updated to match code changes.
- [ ] UI follows the 24px ergonomic layout for floating controls.
- [ ] Logic handles background signaling (Push + CallKit) properly.
