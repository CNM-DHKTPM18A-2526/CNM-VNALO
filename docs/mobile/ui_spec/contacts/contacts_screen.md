# Contacts Screen UI Specification

## 1. Page Context
- **Feature**: Social (Main Contacts Tab)
- **File**: `lib/features/contacts/screens/contacts_screen.dart`
- **Layer Strategy**: Brand Layer (Social Hub)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: **Search Bar Widget**.
    - Actions: Add friend icon (+).
    - Features: `forceMaterialTransparency: true`
- **Body**: 
    - Top Sections: "Friend Requests", "Groups", "Official Accounts".
    - TabBar: "Contacts", "Recent". 
    - Position: TabBar is in its own white container below the search bar.
- **Background**: White Gradient or `AppColors.sectionBackground`.

## 3. Component Details
- **List Items**: 
    - Avatar: 48px.
    - Padding: 16px horizontal.
    - Divider: Indent 70px.
- **Badge Integration**: 
    - Source: `ContactProvider`.
    - Style: Red circle with white count.

## 4. Theme Adaptation
- **Light Mode**: Blue header, White tabs.
- **Dark Mode**: `DarkColors.appBarBg`, Dark Surface tabs.
