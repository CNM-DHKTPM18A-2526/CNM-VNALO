# Group Management Screens UI Specification

## 1. Page Context
- **Feature**: Group Messaging (Creation & Management)
- **Files**: 
    - `lib/features/chat/screens/create_group_screen.dart`
    - `lib/features/chat/screens/add_group_members_screen.dart`
    - `lib/features/chat/screens/group_members_screen.dart`
- **Layer Strategy**: Base Layer (Flow Standard)

## 2. Layout Structure
- **AppBar**:
    - Style: Blue Gradient (`AppColors.appBarGradient`)
    - Title: Localization: `createGroup`, `addMembers`, `members`
- **Body**: 
    - Search: Persistent search bar at the top (Search members).
    - Alphabetical List: Scrollable list of users/friends with checkboxes (Multiple selection).
    - Selected Chips: Horizontal list of selected users (Avatar with close icon).
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **User Row**:
    - Avatar size: 48px.
    - Checkbox: Custom circular checkbox (Blue when checked).
- **Floating Action Button (Create)**:
    - Visible only when 1+ users selected.
    - Position: Bottom Right.
    - Icon: Arrow Forward.

## 4. Theme Adaptation
- **Light Mode**: White list, Blue indicator.
- **Dark Mode**: `DarkColors.scaffold`, `DarkColors.surface` for search bar.
