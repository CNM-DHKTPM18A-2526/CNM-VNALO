# Call System Module Specification (L2)

## 🎯 1. Outcomes
Enable high-quality, real-time Voice and Video communication between two users (P2P) with a professional "Premium Glass" UI that remains responsive across background/foreground transitions.

## 🚧 2. Scope Boundaries
- **In-Scope**: One-to-one P2P calls, WebRTC signaling via Socket.io, CallKit integration (iOS/Android), Floating premium buttons layout.
- **Out-of-Scope**: Group calls (>2 participants), PSTN integration, Screen sharing, Call recording.

## 🛑 3. Constraints & Assumptions
- **Constraint**: Must use HSL colors and alpha 0.5 overlays for all control buttons.
- **Constraint**: Bottom controls must be exactly 24px above bottom safe area.
- **Assumption**: STUN/TURN servers are available for P2P connection fallback.
- **Assumption**: The Node.js gateway is the reliable broker for `call.offer` and `call.answer` signals.

## 💡 4. Prior Decisions
- **Standardized Ergonomics**: Use `Positioned(bottom: 0)` to ensure consistent control strip placement regardless of aspect ratio.
- **Background Sync**: Use `IncomingCallCoordinator` as a global persistent widget to listen for socket signals while the app is alive.

## 📝 5. Task Breakdown (Feature Delta)
- [x] Refactor UI to remove separate glass panels and use unified floating buttons.
- [x] Standardize color tokens to `Colors.black.withValues(alpha: 0.5)`.
- [ ] Implement robust `senderId` mapping in `IncomingCallCoordinator` (P0 fix identified in audit).
- [ ] Implement timeout handling if target doesn't answer after 30 seconds.

## ✅ 6. Verification Criteria
- **Functional**: The recipient must receive the call waiting screen when an `offer` is received.
- **UI**: Bottom buttons must align exactly at the 24px coordinate.
- **Signaling**: Sdp/Ice-candidates must successfully traverse the Node.js gateway.
- **Gherkin**:
    ```gherkin
    Given User A calls User B
    When User B is in foreground
    Then User B sees the IncomingCall screen with Answer/Decline buttons
    And Background is blurred or darkened with alpha 0.5
    ```
