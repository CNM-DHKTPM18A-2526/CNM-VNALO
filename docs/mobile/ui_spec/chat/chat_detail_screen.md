# Chat Detail Screen UI Specification

## 1. Page Context
- **Feature**: Messaging (Real-time Conversation)
- **File**: `lib/features/chat/screens/chat_detail_screen.dart`
- **Layer Strategy**: Base Layer (Content Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`) in Light mode; Solid `DarkColors.appBarBg` in Dark mode.
    - Title: **Avatar + Display Name + Status/Member count**.
    - Actions: 
        - Voice Call icon
        - Video Call icon
        - Options/Menu icon (≡)
- **Body**: 
    - Pinned Message Bar: Sticky header below AppBar (optional).
    - Message List: ListView.builder (reverse: true).
    - Chat Input Bar: Stick to the bottom, adaptive to keyboard height.
- **Background**: Standard background or custom wallpaper (`AppColors.chatBackground`).

## 3. Component Details
- **Message Bubble**:
    - Outgoing (Mine): Blue background, right-aligned.
    - Incoming (Theirs): White/Grey background, left-aligned, shows avatar (Groups).
    - Status: Double checkmark (Read), Single (Sent).
- **Chat Input Bar**:
    - Icons: Emoji, Media (+), Mic.
    - Style: Rounded rectangle, grey border.

## 4. Theme Adaptation
- **Light Mode**: Blue Header, Light message area, Colorful bubbles.
- **Dark Mode**: `DarkColors.appBarBg`, `DarkColors.scaffold` (Black) for list area, `DarkColors.surface` for incoming bubbles.
