# Login Screen UI Specification

## 1. Page Context
- **Feature**: Authentication (Phone Entry)
- **File**: `lib/features/auth/screens/login_screen.dart`
- **Layer Strategy**: Base Layer (Form Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: `transparent` (Matches page background)
    - Title: Localization: `login` (e.g., "ÄÄƒng nháº­p")
    - Title Style: `fontSize: 18`, `fontWeight: FontWeight.w600`, `color: #171717`
    - Leading: Standard Back button (Icon color: `#171717`)
- **Body**: 
    - Padding: 16px horizontal
    - Header: Instructional text in Grey (`#6B7280`)
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **Phone Input**: 
    - Country code picker + text field
    - Border: Standard underline or subtle outline (Project preference: Underline with focusing)
- **Primary Button (Continue)**:
    - High-emphasis Brand Blue (`AppColors.primary`)
    - Width: Full width
- **Link Buttons**: 
    - "Can't login?": Blue text, no background.

## 4. Theme Adaptation
- **Light Mode**: White background, Dark text.
- **Dark Mode**: `DarkColors.scaffold`, white text, `DarkColors.primary` button.
