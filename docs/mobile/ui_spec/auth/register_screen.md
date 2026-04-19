# Register Screen UI Specification

## 1. Page Context
- **Feature**: Authentication (Account Creation)
- **File**: `lib/features/auth/screens/register_screen.dart`
- **Layer Strategy**: Base Layer (Multi-step Form)

## 2. Layout Structure
- **AppBar**:
    - Style: `transparent`
    - Title: Localization: `register`
    - Title Style: `fontSize: 18`, `fontWeight: FontWeight.w600`, `color: #171717`
- **Body**: 
    - Progress Indicator: Subtle bar or step counter at the top.
    - Padding: 16px horizontal.
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **Input Fields**: 
    - Full Name, Phone, Gender (Radio/Select), Birthday (DatePicker).
    - Style: Clean underline with focusing state transition.
- **Primary Action (Next)**:
    - High-emphasis Brand Blue (`AppColors.primary`).
- **Secondary Action (Back)**:
    - Standard AppBar navigation or "Back to Login" text link.

## 4. Theme Adaptation
- **Light Mode**: White scaffold, Dark inputs.
- **Dark Mode**: `DarkColors.scaffold`, white text.
