# Chat Options Screen UI Specification

## 1. Page Context
- **Feature**: Messaging Settings (Per-conversation)
- **File**: `lib/features/chat/screens/chat_options_screen.dart` / `group_chat_options_screen.dart`
- **Layer Strategy**: Base Layer (Menu System)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: Localization: `options` / `info`
- **Body**: 
    - Header: Large Avatar + Name + Action Grid (Call, Mute, Search).
    - List: Grouped menu items (Media, Files, Links, Settings).
- **Background**: `AppColors.sectionBackground` (#F4F5F7).

## 3. Component Details
- **Action Grid**:
    - Round icons with labels below.
    - Style: Blue icon, dark text.
- **Menu Items**: 
    - Leading icon, Title, Chevron trailing.
    - Grouped into sections with dividers.

## 4. Theme Adaptation
- **Light Mode**: White sections, Grey dividers, Blue icons.
- **Dark Mode**: `DarkColors.surface` sections, `DarkColors.divider`.
