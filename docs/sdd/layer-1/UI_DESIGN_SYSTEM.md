# UI DESIGN SYSTEM

> [!IMPORTANT]
> This file formalizes the implemented Flutter design tokens and component behavior.

## Token Source Files

- frontend/mobile/lib/core/theme/app_colors.dart
- frontend/mobile/lib/core/theme/app_typography.dart
- frontend/mobile/lib/core/theme/app_theme.dart

## Color Tokens

### Brand and Semantic

| Token | Value |
| --- | --- |
| primary | #007BFF |
| primaryLight | #00A2ED |
| primaryDark | #0050CC |
| success | #22C55E |
| error | #EF4444 |
| warning | #F59E0B |
| unreadBadge | #EF4444 |
| appBarGradient | linear gradient #007BFF -> #00A2ED |

### Light Theme Surface

| Token | Value |
| --- | --- |
| scaffold | #F0F2F5 |
| surface | #FFFFFF |
| surfaceLight | #F6F7F8 |
| textPrimary | #1A1A1A |
| textSecondary | #666666 |
| textHint | #999999 |
| divider | #E0E0E0 |
| appBarBg | #0068FF |

### Dark Theme Surface

| Token | Value |
| --- | --- |
| scaffold | #000000 |
| surface | #131313 |
| surfaceLight | #1A1A1A |
| textPrimary | #FFFFFF |
| textSecondary | #B0B0B0 |
| textHint | #808080 |
| divider | #333333 |
| appBarBg | #222222 |
| primary | #4A90E2 |
| primaryLight | #6AB0FF |

## Typography Tokens

Font family source: GoogleFonts.inter

| Token | Size | Weight |
| --- | --- | --- |
| displayLarge | 28 | bold |
| displayMedium | 24 | bold |
| titleLarge | 20 | w600 |
| titleMedium | 16 | w600 |
| bodyLarge | 16 | normal |
| bodyMedium | 14 | normal |
| bodySmall | 12 | normal |
| labelLarge | 14 | w500 |
| labelSmall | 11 | w500 |

## Theming Contract

### Global Theme

- Material3 enabled in both light and dark theme.
- AppBar height is 52.
- Input fields use rounded radius 12.
- Primary action button min height is 48 and full width.
- Bottom navigation uses fixed layout.

### Interaction States

| State | Light Mode | Dark Mode |
| --- | --- | --- |
| splash | itemPressBackground alpha 0.7 | itemPressBackground alpha 0.22 |
| highlight | itemPressBackground | itemPressBackground alpha 0.16 |
| hover | itemPressBackground alpha 0.6 | itemPressBackground alpha 0.1 |

## Component-Level Contracts

### Bottom Navigation Bar

- Selected color: primary token.
- Unselected color: textHint token.
- Badge for unread and pending friend requests uses unreadBadge token.

### Snack Bars

- Error notification uses redAccent in MainShell for call signaling errors.
- Warning uses orange in registration partial success paths.

### Call Screens

- Voice call primary background uses #0068FF in light mode and #0F172A in dark mode.
- Video call background is black with overlay controls.

## Accessibility and Localization

- Language toggle supports vi-VN and en-US.
- Text style contrast depends on dark and light palette token mapping.
- Large labels and compact badges are used to preserve readability in navigation and call controls.

## Visual Hierarchy Rules

- High emphasis actions use filled primary buttons.
- Secondary actions use outlined or text buttons.
- Destructive actions use error red in call controls and snackbar.
- Status and metadata text use textSecondary and textHint tokens.
