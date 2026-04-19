# Chat List Screen UI Specification

## 1. Page Context
- **Feature**: Core Communication (List of conversations)
- **File**: `lib/features/chat/screens/chat_list_screen.dart`
- **Layer Strategy**: Brand Layer (Social Hub)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: **Persistent Search Interaction Widget** (Hero tagged).
    - Actions: 
        - QR Scanner Icon (outlined)
        - Add/Quick Actions Icon (+)
    - Transparency: `forceMaterialTransparency: !isDarkMode`
- **Body**: 
    - Divider: Custom divider with `indent: 80` (aligns with text start after 52px avatar).
- **Background**: `AppColors.sectionBackground` (#F4F5F7).

## 3. Component Details
- **Chat List Item**:
    - Avatar: 52px.
    - Title: w600, Size 16.
    - Subtitle: w400, Size 14, Grey.
    - Unread Badge: Round red circle with white text.
- **"My Documents" Entry**:
    - Special blue/cloud icon leading.
    - Distinct pinned position at index 0.

## 4. Theme Adaptation
- **Light Mode**: Blue Header, White Items.
- **Dark Mode**: `DarkColors.appBarBg`, `DarkColors.surface` for items, `DarkColors.scaffold` for page background.
