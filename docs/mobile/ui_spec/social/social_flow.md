# Search & Social Screens UI Specification

## 1. Page Context
- **Feature**: Discovery & Global Navigation
- **Files**: 
    - `lib/features/search/screens/unified_search_screen.dart`
    - `lib/features/discover/screens/discover_screen.dart`
    - `lib/features/timeline/screens/home_wall_screen.dart`
- **Layer Strategy**: Brand Layer (Social High-Impact)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Search: **Dynamic Search Bar** in `UnifiedSearchScreen` (autofocus).
- **Body**: 
    - Search Results: Categorized sections (Messages, Contacts, Groups).
    - Discover: Grid/List of third-party apps, mini-apps, and AI Assistant entry.
    - Timeline (Wall): Post feed with media support.
- **Background**: `AppColors.sectionBackground` (#F4F5F7).

## 3. Component Details
- **Search Result Row**:
    - Highlight: Matching text should be highlighted in Vnalo Blue.
- **Discover Mini-App**:
    - Round icon + Name.
    - Style: Grid of 4 columns.
- **Feed Post Card**:
    - Top: User avatar + name + timestamp.
    - Content: Text + Images (Grid).
    - Footer: Like, Comment (Inline buttons).

## 4. Theme Adaptation
- **Light Mode**: White cards, Grey background.
- **Dark Mode**: `DarkColors.surface` cards, `DarkColors.scaffold` background.
