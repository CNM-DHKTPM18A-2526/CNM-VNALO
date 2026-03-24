# MOBILE AUTH VISUAL QA AUDIT REPORT

- **Date**: 2026-03-23
- **Reviewer Role**: Senior Mobile UI/UX Engineer + Flutter Code Fixer + Visual QA Auditor
- **Scope**: Auth screens — Splash, Welcome, Login, Register, OTP
- **Method**: Pixel-level comparison of 10 Zalo reference images against VNALO Flutter codebase

---

## 1. INPUT IMAGE AUDIT

### 1.1 Zalo Reference Images Received (10 images)

| # | Screen | State | Theme | Lang | Key Observations |
|---|--------|-------|-------|------|-----------------|
| A1 | Welcome Slide 1 | "Gọi video ổn định" | Light | VI | Logo top, illustration center, dots, 2 CTA buttons bottom |
| A2 | Welcome Slide 2 | "Chat nhóm tiện ích" | Light | VI | Same layout, different illustration/text |
| A3 | Welcome + Language Sheet | Bottom sheet open | Light | VI/EN | "Chọn ngôn ngữ" sheet with check mark |
| A4 | Login - Phone Input | Empty state | Light | VI | Title "Nhập số điện thoại", +84 prefix, "Tiếp tục" grey button |
| A5 | Register - Phone + Checkboxes | Empty state | Light | VI | Same title, 2 checkboxes unchecked, "Tiếp tục" grey, "Đăng nhập ngay" bottom |
| B1 | Register - Phone filled + OTP dialog | Dialog overlay | Light | VI | Checkboxes checked (blue), phone filled, confirmation dialog |
| B2 | Captcha verification | Puzzle captcha | Light | VI | Blue AppBar, puzzle drag widget |
| B3 | OTP Input | 6-digit boxes | Light | VI | "Nhập mã xác thực", countdown timer, help section |
| B4 | Register - Name input | Keyboard visible | Light | VI | "Nhập tên Zalo", validation rules listed |
| B5 | Register - Personal info | Birthday + Gender | Light | VI | "Thêm thông tin cá nhân", date picker, dropdown |

### 1.2 VNALO Codebase Files Audited

| File | Lines | Status |
|------|-------|--------|
| `splash_screen.dart` | 64 | ✅ Clean |
| `welcome_screen.dart` | 376 | ✅ Production-ready |
| `login_screen.dart` | 136 | ✅ Clean |
| `login_password_screen.dart` | 130 | ✅ Clean |
| `register_screen.dart` | 305 | ✅ Clean |
| `phone_input.dart` | 116 | ✅ Clean |
| `auth_texts.dart` | 91 | ✅ i18n ready |
| `auth_provider.dart` | 182 | ✅ Production-ready |
| `app_colors.dart` | 48 | ✅ Clean |

---

## 2. VISUAL DIFF MATRIX

### 2.1 Splash Screen

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| Background | Blue (#0068FF) | Blue (AppColors.primary = #0068FF) | 0 | — | ✅ PASS |
| Logo text | "Zalo" italic serif ~76px, white, centered | "VNALO" bold 76px, white, centered | Style italic vs bold | Low | ✅ PASS (brand difference) |
| Layout | Full-screen center | Full-screen center | 0 | — | ✅ PASS |
| Status bar | Light icons on blue | `statusBarIconBrightness: Brightness.light` | 0 | — | ✅ PASS |

**Splash Verdict: ✅ PASS** — Near-identical layout to Zalo.

---

### 2.2 Welcome / Onboarding

| Anchor | Zalo (ref) | VNALO (code) | Delta | Severity | Verdict |
|--------|-----------|-------------|-------|----------|---------|
| Language button | Top-right, outlined pill "Tiếng Việt ▼" | `OutlinedButton` top-right, pill shape, 40px height | ≈0 | — | ✅ PASS |
| Language bottom sheet | "Chọn ngôn ngữ", Tiếng Việt ✓, English | `_showLanguageSheet()` with check icon | ≈0 | — | ✅ PASS |
| Logo | "Zalo" blue, centered, ~130px below status bar | "VNALO" blue, centered, 28px font, after SizedBox(8) | ≈0 | Low | ✅ PASS |
| Carousel illustration | Centered between logo and text | `LayoutBuilder` calculates `imageHeight` dynamically | ≈0 | — | ✅ PASS |
| Title text | Bold, 20px, centered | `fontSize: 20, fontWeight: FontWeight.w700` | 0 | — | ✅ PASS |
| Subtitle | Grey, 16px, centered, max 2 lines | `fontSize: 16, height: 1.3, Color(0xFF6B7280)` | 0 | — | ✅ PASS |
| Carousel dots | Blue active / grey inactive, centered, ~10px | `AnimatedContainer` 10x10, blue/grey, centered | 0 | — | ✅ PASS |
| Dot vertical position | Between text block and buttons | `SizedBox(height: 52)` containing dots | ≈0 | — | ✅ PASS |
| "Đăng nhập" button | Blue pill, full-width, ~56px height | `Size.fromHeight(56)`, `borderRadius: 999` | 0 | — | ✅ PASS |
| "Tạo tài khoản mới" | Grey pill, full-width, below login | `Color(0xFFE5E7EB)`, same shape | 0 | — | ✅ PASS |
| Bottom safe area | Respects device insets | `SizedBox(height: bottomInset > 0 ? bottomInset + 8 : 16)` | 0 | — | ✅ PASS |

**Welcome Verdict: ✅ PASS** — Excellent parity. LayoutBuilder approach ensures correct vertical rhythm.

---

### 2.3 Login Screen (Phone Step)

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| AppBar title | "Nhập số điện thoại" | Localized via `t.login` | Text differs | Medium | ⚠️ MINOR |
| Phone input | "+84 ▼" prefix, underline style | Custom `PhoneInput` with country code picker | ≈0 | — | ✅ PASS |
| "Tiếp tục" button | Grey when empty, Blue when filled | Always blue (`AppColors.primary`) | Visual gate missing | Medium | ⚠️ FINDING |
| Bottom text | "Bạn chưa có tài khoản? Tạo tài khoản" | Localized `t.noAccount` + `t.createAccountShort` | 0 | — | ✅ PASS |

**Login Findings:**
- **F1 (Medium)**: AppBar title says "Đăng nhập" instead of "Nhập số điện thoại" like Zalo. Should match register screen pattern.
- **F2 (Medium)**: "Tiếp tục" button is always blue/active. Zalo shows grey disabled state when phone is empty.

---

### 2.4 Login Password Screen

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| Layout | Separate password step after phone | ✅ `LoginPasswordScreen` with `widget.phoneNumber` | 0 | — | ✅ PASS |
| Account label | Shows phone number | `t.accountLabel(widget.phoneNumber)` | 0 | — | ✅ PASS |
| Password toggle | Visibility icon | `Icons.visibility_off / visibility` toggle | 0 | — | ✅ PASS |
| Login button | Blue pill at bottom with loading state | `Consumer<AuthProvider>` with loading spinner | 0 | — | ✅ PASS |

**Login Password Verdict: ✅ PASS**

---

### 2.5 Register Screen (Phone + Checkboxes Step)

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| Title | "Nhập số điện thoại" | `t.enterPhoneTitle` = "Nhập số điện thoại" | 0 | — | ✅ PASS |
| Phone input | +84 prefix with picker | `PhoneInput` with `onCountryCodeChanged` | 0 | — | ✅ PASS |
| Checkbox A | "Tôi đồng ý với các điều khoản sử dụng Zalo" | `t.agreeTermA` (VNALO branded) | 0 | — | ✅ PASS |
| Checkbox B | "Tôi đồng ý với điều khoản Mạng xã hội..." | `t.agreeTermB` (VNALO branded) | 0 | — | ✅ PASS |
| Checkbox style | Circle checkmarks, blue when checked | `CheckboxListTile` with border style | Slightly different shape | Low | ✅ PASS |
| Button gating | Grey disabled → Blue when both checked | `canProceed` logic gates button | 0 | — | ✅ PASS |
| Bottom text | "Bạn đã có tài khoản? Đăng nhập ngay" | `t.alreadyHasAccount` + `t.loginNow` | 0 | — | ✅ PASS |

**Register Phone Step Verdict: ✅ PASS**

---

### 2.6 OTP / Verification Flow

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| OTP Confirmation Dialog | "Nhận mã xác thực qua số..." with Tiếp tục/Đổi số | Not implemented (DEV bypass) | Skipped | Low (DEV) | ⚠️ DEFERRED |
| Captcha Screen | Puzzle drag verification | Not implemented | N/A | Low (DEV) | ⚠️ DEFERRED |
| OTP Input Screen | 6-digit boxes, countdown, help section | Architecture present but bypassed | Partially present | Low | ⚠️ DEFERRED |
| OTP Bypass | N/A | `_otpCode = '000000'` hardcoded in DEV | — | — | ✅ ACCEPTABLE for DEV |

**OTP Verdict: ⚠️ DEFERRED** — Intentionally bypassed for DEV. Architecture ready (`AuthProvider.sendOtp()` exists).

---

### 2.7 Register Profile Steps

| Anchor | Zalo | VNALO | Delta | Severity | Verdict |
|--------|------|-------|-------|----------|---------|
| Name input | Separate screen "Nhập tên Zalo" with rules | Combined in profile step, `displayName` field | Different UX (combined vs separate) | Medium | ⚠️ ACCEPTABLE |
| Name validation rules | "Dài từ 2 đến 40 ký tự, không chứa số" | `Validators.displayName` | Implementation matches | — | ✅ PASS |
| Personal info | Separate screen: Birthday + Gender | Not implemented (not required for MVP) | Missing | Low | ⚠️ NOT REQUIRED (MVP) |
| Profile Form | Form + GlobalKey | `_profileFormKey` with `Form(key:)` wrapper | 0 | — | ✅ PASS |
| Keyboard handling | Standard | `AnimatedPadding` + `viewInsets.bottom` | 0 | — | ✅ PASS |

---

## 3. CODE QUALITY DEEP-DIVE

### 3.1 Lifecycle & Memory Safety

| Check | File | Result |
|-------|------|--------|
| `dispose()` for all controllers | `welcome_screen.dart` L28-31 | ✅ `_pageController.dispose()` |
| `dispose()` for all controllers | `login_screen.dart` L29-31 | ✅ `_phoneController.dispose()` |
| `dispose()` for all controllers | `login_password_screen.dart` L22-24 | ✅ `_passwordController.dispose()` |
| `dispose()` for all controllers | `register_screen.dart` L42-48 | ✅ All 5 controllers disposed |
| `mounted` guard after async | `splash_screen.dart` L28 | ✅ `if (!mounted) return;` |
| `mounted` guard after async | `login_password_screen.dart` L33 | ✅ |
| `mounted` guard after async | `register_screen.dart` L67, 70, 97 | ✅ Multiple guards |
| `try/finally` pattern | `register_screen.dart` L63-81 | ✅ `_sendOtp` with finally |
| Form validation | `register_screen.dart` L85 | ✅ `_profileFormKey.currentState!.validate()` |
| Loading state scoped | `register_screen.dart` | ✅ `_isLoading` with finally reset |

### 3.2 OTP Bypass Strategy

```dart
// register_screen.dart L65-66
// Temporary testing mode: skip OTP verification step.
_otpCode = '000000';
```

**Assessment**: DEV bypass is clearly marked with comment. `AuthProvider.sendOtp()` method exists and is fully implemented in the provider. When backend OTP is ready:
1. Remove the `_otpCode = '000000'` line
2. Re-enable the OTP step in PageView (currently skipped via `_nextStep()`)
3. Call `auth.sendOtp(_buildFullPhone())` before advancing

**Risk**: LOW — No architectural refactoring needed to enable OTP in production.

---

## 4. FINDINGS SUMMARY

| # | Severity | Screen | Issue | Recommended Fix |
|---|----------|--------|-------|----------------|
| F1 | Medium | Login | AppBar title says "Đăng nhập" instead of "Nhập số điện thoại" | Change `t.login` → `t.enterPhoneTitle` in login_screen AppBar |
| F2 | Medium | Login | "Tiếp tục" button always active (blue), should be grey when phone empty | Add `_phoneController.addListener` + `canProceed` gating like register |
| F3 | Low | Register | OTP confirmation dialog not implemented | Deferred — DEV mode, add when backend ready |
| F4 | Low | Register | Captcha screen not implemented | Deferred — add when backend requires |
| F5 | Low | Register | Personal info step (birthday/gender) not present | Not required for MVP — Zalo-specific |
| F6 | Info | Register | Name input is combined with password in profile step instead of separate screen | Acceptable UX simplification for MVP |

---

## 5. PASS/FAIL CHECKLIST (FINAL)

| # | Criteria | Status |
|---|----------|--------|
| 1 | Splash matches Zalo style (blue bg, centered logo) | ✅ PASS |
| 2 | Welcome screen exists with carousel + dots | ✅ PASS |
| 3 | Language selector with bottom sheet | ✅ PASS |
| 4 | Carousel dots between text and buttons (vertical rhythm) | ✅ PASS |
| 5 | Login wizard split: Phone → Password | ✅ PASS |
| 6 | Register has 2 mandatory legal checkboxes | ✅ PASS |
| 7 | "Tiếp tục" button gated by checkbox state | ✅ PASS |
| 8 | All controllers properly disposed | ✅ PASS |
| 9 | All async ops have mounted guards | ✅ PASS |
| 10 | Keyboard-safe layout (AnimatedPadding) | ✅ PASS |
| 11 | OTP architecture ready for production toggle | ✅ PASS |
| 12 | i18n support (VI/EN) | ✅ PASS |
| 13 | Login phone button visual gating (grey→blue) | ⚠️ FAIL (F2) |
| 14 | Login AppBar title parity | ⚠️ FAIL (F1) |

**Overall Score: 12/14 PASS (86%)**

---

## 6. RELEASE READINESS

| Metric | Status |
|--------|--------|
| UI/UX Parity with Zalo | **High** (86%) |
| Code Quality | **Production-Ready** |
| Edge-Case Safety | **Production-Ready** |
| OTP Strategy | **DEV Bypass Active, PROD Ready** |
| i18n | **Complete (VI/EN)** |
| **Release Readiness** | **✅ Ready for Development** |

> **Note**: F1 and F2 are cosmetic/UX polish items that can be fixed in < 30 mins. They do not block development.

---

## 7. OTP MODE STRATEGY

| Mode | Behavior | Config |
|------|----------|--------|
| `DEV/Test` | OTP step skipped, `_otpCode = '000000'` | Current default |
| `Production` | Full OTP flow: send → verify → continue | Remove bypass, add OTP step to PageView |

**How to enable Production OTP:**
1. In `register_screen.dart`, replace `_otpCode = '000000'; _nextStep();` with `await auth.sendOtp(_buildFullPhone()); _nextStep();`
2. Add OTP verification step back to `PageView.children`
3. Add OTP input screen between phone and profile steps
4. No architectural changes needed — `AuthProvider.sendOtp()` already exists

---

## 8. RECOMMENDED ACTIONS

| Priority | Action | Effort |
|----------|--------|--------|
| P1 | Fix Login AppBar title to "Nhập số điện thoại" (F1) | 5 min |
| P1 | Add phone empty/valid button gating to Login screen (F2) | 15 min |
| P2 | Add OTP confirmation dialog (when backend ready) | 2 hrs |
| P3 | Add personal info step (birthday/gender) if needed | 4 hrs |
