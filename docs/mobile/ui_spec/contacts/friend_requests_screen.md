# Friend Requests Screen UI Specification

## 1. Page Context
- **Feature**: Contacts Flow (Sub-page)
- **File**: `lib/features/contacts/screens/friend_requests_screen.dart`
- **Layer Strategy**: Social Layer (Standardized)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: Localization: `friendRequests`
    - Title Style: `fontSize: 18`, `fontWeight: FontWeight.w600`, `color: Colors.white`
    - Transparency: `forceMaterialTransparency: !isDarkMode`
- **Body**: 
    - **Header TabBar**: Placed in a White Container (`#FFFFFF`) at the TOP of the body column.
    - Tab Selection: Blue underline indicator.
    - Divider: 1px Grey below TabBar.
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **List Items**: 
    - Avatar size: 48px.
    - Background: `Colors.white`.
- **Primary Action (Accept)**: 
    - Style: Primary Blue, elevation 0.
- **Secondary Action (Reject)**: 
    - Style: **Grey Layer** (`backgroundColor: #E5E7EB`, `foregroundColor: #111827`, `elevation: 0`).

## 4. Theme Adaptation
- **Light Mode**: Blue Header, White Body, Grey secondary button.
- **Dark Mode**: `DarkColors.appBarBg`, `DarkColors.scaffold`, `DarkColors.surface` buttons.
