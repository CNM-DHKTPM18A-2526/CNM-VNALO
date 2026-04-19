# Utility & Miscellaneous Screens UI Specification

## 1. Page Context
- **Feature**: Cross-flow Utilities
- **Files**: 
    - `lib/features/auth/screens/qr_scanner_screen.dart`
    - `lib/features/auth/screens/qr_login_approval_screen.dart`
    - `lib/features/auth/screens/splash_screen.dart`
    - `lib/features/ai_assistant/screens/mascot_gallery_screen.dart`
    - `lib/features/chat/screens/my_documents_screen.dart`
    - `lib/features/chat/screens/wallpaper_selection_screen.dart`
- **Layer Strategy**: Utility Layer (Minimalist Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`) or Transparent (Splash/Scanner).
- **Body**: 
    - QR Scanner: Pure camera preview, rounded rectangle frame in center, scanning animation.
    - My Documents: List view of files with file type icons (PDF, Word, Image).
    - Mascot Gallery: Grid view of mascot avatars.
- **Background**: White or Dark depending on mode.

## 3. Component Details
- **File Row (Documents)**: 
    - Icon leading (Color-coded by type).
    - Title + File Size subtitle.
- **Mascot Card**: 
    - High-quality image, rounded corners, "Select" button below.

## 4. Theme Adaptation
- **Standard**: Follows global theme colors for components.
