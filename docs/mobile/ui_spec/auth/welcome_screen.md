# Welcome Screen UI Specification

## 1. Page Context
- **Feature**: Authentication (Initial Entry)
- **File**: `lib/features/auth/screens/welcome_screen.dart`
- **Layer Strategy**: Base Layer (Clean Focus)

## 2. Layout Structure
- **AppBar**: 
    - Style: `transparent` (No background)
    - Title: None
    - Actions: Language selection toggle
- **Body**: 
    - Carousel: Large onboarding images (Assets: `assets/images/welcome/`)
    - Pagination: Smooth dot indicators (Vnalo Blue)
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **Primary Action (Login)**: 
    - Style: Brand Blue (`AppColors.primary`)
    - Type: `ElevatedButton`
    - Elevation: 0
- **Secondary Action (Create Account)**: 
    - Style: **Grey Layer** (`#E5E7EB`)
    - Foreground: `#111827`
    - Type: `ElevatedButton`
    - Elevation: 0
    - Note: No border. Matches the "Skip" pattern.

## 4. Theme Adaptation
- **Light Mode**: White background, Grey secondary button.
- **Dark Mode**: Scaffold background (`DarkColors.scaffold`), Surface secondary button (`DarkColors.surface`).
