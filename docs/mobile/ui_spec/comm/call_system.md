# Call System UI Specification

## 1. Page Context
- **Feature**: Real-time Communication (Voice & Video)
- **Files**: 
    - `lib/features/call/screens/voice_call_screen.dart`
    - `lib/features/call/screens/video_call_screen.dart`
- **Layer Strategy**: Immersive Layer (Dark Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: `transparent` (Overlay on video/gradient).
    - Actions: Back arrow (Mini-call toggle), Flip Camera (Video).
    - Button Style: Translucent Xanh Đen (`Colors.black.withValues(alpha: 0.5)`), size 44x44, icon 28.
- **Body**: 
    - Video Call: Fullscreen remote stream, draggable local preview (top-right).
    - Voice Call: User avatar center, pulse animation, blurred cover background.
- **Controls Bar**: 
    - Position: **Floating Bottom** (Directly on background).
    - Style: No background panel or blur (Glassmorphism removed for maximum immersion).
    - Buttons: Loa/Camera, Mic, End Call, More (Video only).
- **Background**: Dark Gradient (Voice) / Remote Video Stream (Video).

## 3. Component Details
- **Control Buttons**: 
    - Style: Circular, **Translucent Dark** aesthetic.
    - Colors: **Xanh Đen Mờ** (`Colors.black.withValues(alpha: 0.5)`).
    - Size: 72x72, Icon 36.
- **End Call Button**: 
    - Style: Solid Red (`Color(0xFFFF3B30)`), white icon.

## 4. Positioning & Ergonomics
- **Placement**: Unified `Positioned(bottom: 0)` structure with `SafeArea`.
- **Bottom Clearance**: Standardized **24px** padding from the safe area edge to provide a comfortable, lowered ergonomic feel.

## 5. Theme Adaptation
- **Fixed Mode**: Always **Dark Theme** to ensure focus and reduce glare. Uses `Color(0xFF0F172A)` as deep navy base.
