# Profile & Settings Screens UI Specification

## 1. Page Context
- **Feature**: User Profile & Management
- **Files**: 
    - `lib/features/profile/screens/profile_screen.dart`
    - `lib/features/profile/screens/profile_detail_screen.dart`
    - `lib/features/profile/screens/settings_screen.dart`
- **Layer Strategy**: Base Layer (Menu Standard)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`) for Main Profile; White/Solid for Settings.
    - Title: **Search Bar Widget** in Profile Tab; Text title in Settings.
- **Body**: 
    - Header Section (Profile): Large Avatar + Display Name + "View Profile" link.
    - Info Section (Detail): Profile Cover Image Hero.
    - Menu List: Grouped sections with spacing (10px).
- **Background**: `AppColors.sectionBackground` (#F4F5F7).

## 3. Component Details
- **Profile Header**: 
    - Avatar size: 60px (Tab) / 80px (Detail).
    - Camera icon overlay for updates.
- **Menu Items**: 
    - Leading: Blue icon (Light) / Primary icon (Dark).
    - Trailing: Chevron icon.
    - Spacing: Indent 70px for dividers.

## 4. Theme Adaptation
- **Light Mode**: White sections, Blue highlights.
- **Dark Mode**: `DarkColors.surface` sections, `DarkColors.appBarBg`, `DarkColors.textPrimary`.
