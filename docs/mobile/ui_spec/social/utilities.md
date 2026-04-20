# Utility & Miscellaneous Screens UI Specification

## 1. Page Context
- **Feature**: Cross-flow Utilities
- **Files**: 
    - `lib/features/auth/screens/qr_scanner_screen.dart`
    - `lib/features/auth/screens/qr_login_approval_screen.dart`
    - `lib/features/auth/screens/splash_screen.dart`
    - `lib/features/ai_assistant/screens/mascot_gallery_screen.dart`
    - `lib/features/ai_assistant/widgets/ai_floating_bubble.dart`
    - `lib/features/ai_assistant/widgets/ai_robot_avatar.dart`
    - `lib/features/ai_assistant/providers/ai_assistant_provider.dart`
    - `lib/features/chat/screens/my_documents_screen.dart`
    - `lib/features/chat/screens/wallpaper_selection_screen.dart`
- **Layer Strategy**: Utility Layer (Minimalist Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`) or Transparent (Splash/Scanner).
- **Body**: 
    - QR Scanner: Pure camera preview, rounded rectangle frame in center, scanning animation.
    - My Documents: List view of files with file type icons (PDF, Word, Image).
    - Mascot Gallery: Carousel cho nhiều mascot, ưu tiên robot 2D làm mặc định.
    - AI Floating Bubble: Layered Gesture Mask để tách thao tác kéo bubble và tương tác mascot.
- **Background**: White or Dark depending on mode.

## 3. Component Details
- **File Row (Documents)**: 
    - Icon leading (Color-coded by type).
    - Title + File Size subtitle.
- **Mascot Card**: 
    - Robot 2D được gắn nhãn "Khuyến nghị mặc định".
    - 3D mascot giữ cho tùy chọn mở rộng/legacy.
    - Nút chọn thể hiện rõ mode 2D/3D.

- **AI Bubble Interaction**:
    - Vùng điều khiển (bubbleControl): kéo thả, hút vào thùng rác, mở gallery.
    - Vùng tương tác mascot (mascotInteract): ưu tiên thao tác mascot 3D.
    - Cơ chế hút thùng rác dùng nội suy mượt (Lerp), không teleport.
    - Có haptic cho hover-trash, đổi mode, và xác nhận xóa.

- **AI Visibility & State**:
    - `PersistentEnabled`: bật vĩnh viễn theo ý định người dùng (lưu prefs).
    - `ProvisionallyVisible`: hiện tạm khi dịch/tóm tắt/phân tích ngữ cảnh.
    - Luồng STT -> AI -> TTS có khóa chống race, tránh chồng lệnh khi tap nhanh.

## 4. Theme Adaptation
- **Standard**: Follows global theme colors for components.
