# Login Password Screen UI Specification

## 1. Page Context
- **Feature**: Authentication (Password Entry)
- **File**: `lib/features/auth/screens/login_password_screen.dart`
- **Layer Strategy**: Base Layer (Security Focus)

## 2. Layout Structure
- **AppBar**:
    - Style: `transparent`
    - Title: Localization: `login`
    - Title Style: `fontSize: 18`, `fontWeight: FontWeight.w600`, `color: #171717`
- **Body**: 
    - Padding: 16px horizontal
- **Background**: Pure White (`#FFFFFF`)

## 3. Component Details
- **Password Input**: 
    - Obscured text with visibility toggle.
    - Underline border.
- **Primary Action (Log in)**:
    - Standard high-emphasis button style.
- **Secondary Actions**:
    - "Forgot Password" link (Blue text).
    - "Switch Account" link.

## 4. Theme Adaptation
- **Standard**: Follows pure white strategy for Light mode to ensure optimal readability for security-critical inputs.
