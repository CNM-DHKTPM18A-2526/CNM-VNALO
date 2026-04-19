# Add Friend Screen UI Specification

## 1. Page Context
- **Feature**: Contacts (Social Discovery)
- **File**: `lib/features/contacts/screens/add_friend_screen.dart`
- **Layer Strategy**: Base Layer (Discovery Hub)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: Localization: `addFriendHeader`
    - Title Style: `fontSize: 18`, `fontWeight: FontWeight.w600`, `color: Colors.white`
- **Body**: 
    - Top Section: Your Name + QR Code in a Styled Card.
    - Input Section: Country Code + Phone Input field.
    - Bottom List: "Scan QR", "People Nearby".
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **QR Card**:
    - Background: `Color(0xFF3F5F85)` (Light) or `DarkColors.surface` (Dark).
    - Shadow: Subtle (e.g., `0.05` opacity).
- **Secondary Action (Reload QR)**:
    - Style: **Grey Layer** (`#E5E7EB`).
    - Foreground: `#111827`.

## 4. Theme Adaptation
- **Light Mode**: White Scaffold, Blue Header, Grey secondary button.
- **Dark Mode**: `DarkColors.scaffold`, `DarkColors.appBarBg`, `DarkColors.surface` card.
