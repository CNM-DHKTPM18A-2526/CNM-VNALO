import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
import 'package:vnalo_mobile/core/utils/validators.dart';
import 'package:vnalo_mobile/features/auth/widgets/otp_input.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/core/utils/api_error_mapper.dart';

/// Forgot-password flow with 3 steps:
///   1. Enter email -> check exists & send OTP
///   2. Enter OTP -> verify
///   3. Enter new password -> reset
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _pageController = PageController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _currentStep = 0; // 0=email, 1=otp, 2=new password
  String _otpCode = '';
  bool _isSending = false;
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  // ─── Step 1: Send OTP ───
  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final emailError = Validators.email(email);
    if (emailError != null) {
      _showError(emailError);
      return;
    }

    setState(() => _isSending = true);
    final t = AuthTexts.of(context, listen: false);
    try {
      await context.read<AuthService>().requestPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.otpSentToEmailSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      _startCooldownTimer();
      _goToStep(1);
    } on ApiException catch (e) {
      _showError(ApiErrorMapper.map(e));
    } catch (_) {
      _showError(t.cannotSendOtp);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Step 2: Verify OTP ───
  void _verifyOtp() {
    FocusScope.of(context).unfocus();
    final t = AuthTexts.of(context, listen: false);
    if (!RegExp(r'^\d{6}$').hasMatch(_otpCode)) {
      _showError(t.otpMustBeDigits);
      return;
    }
    _goToStep(2);
  }

  // ─── Step 2: Resend OTP ───
  Future<void> _resendOtp() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    final t = AuthTexts.of(context, listen: false);
    try {
      await context.read<AuthService>().requestPasswordReset(
            email: _emailController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.otpResentSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      _startCooldownTimer();
    } on ApiException catch (e) {
      _showError(ApiErrorMapper.map(e));
    } catch (_) {
      _showError(t.resendOtpFailed);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Step 3: Reset Password ───
  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final t = AuthTexts.of(context, listen: false);
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      _showError(t.passwordAtLeast8);
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showError(t.passwordMustHaveUpper);
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      _showError(t.passwordMustHaveLower);
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showError(t.passwordMustHaveNumber);
      return;
    }
    if (password != confirm) {
      _showError(t.passwordMismatch);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<AuthService>().resetPassword(
            email: _emailController.text.trim(),
            otp: _otpCode,
            newPassword: password,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.resetPasswordSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context); // Back to login
    } on ApiException catch (e) {
      if (e.code == 'AUTH_009' || e.code == 'AUTH_010' || e.code == 'AUTH_011') {
        // OTP error -> go back to OTP step
        _showError(ApiErrorMapper.map(e));
        _goToStep(1);
      } else {
        _showError(ApiErrorMapper.map(e));
      }
    } catch (e) {
      _showError('${t.resetPasswordFailed}: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _onBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      _goToStep(_currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = AuthTexts.of(context);
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;
    final appBarFg = isDarkMode ? Colors.white : const Color(0xFF171717);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appBarFg),
          onPressed: _onBack,
        ),
        title: Text(
          t.forgotPasswordTitle,
          style: TextStyle(
            color: appBarFg,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildEmailStep(),
          _buildOtpStep(),
          _buildNewPasswordStep(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: Email Input
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEmailStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = AuthTexts.of(context);
    final email = _emailController.text.trim();
    final isValid = Validators.email(email) == null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.divider : const Color(0xFFEBF5FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.email_outlined,
                size: 48,
                color: isDarkMode ? DarkColors.primary : AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.enterEmailToRegister,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF141414),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.otpSentNotice,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'example@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: isDarkMode ? DarkColors.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.primary : AppColors.primary, width: 1.5),
                ),
                errorText: email.isNotEmpty && !isValid
                    ? Validators.email(email)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isValid && !_isSending ? _sendOtp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? const Color(0xFF0068FF) : const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        t.resendOtp,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isValid ? Colors.white : const Color(0xFF9CA3AF),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: OTP Verification
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOtpStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = AuthTexts.of(context);
    final email = _emailController.text.trim();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.divider : const Color(0xFFEBF5FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: isDarkMode ? DarkColors.primary : const Color(0xFF0068FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.enterOtpTitleShort,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : const Color(0xFF141414),
                letterSpacing: 1.0,
                shadows: isDarkMode ? [
                  Shadow(
                    color: DarkColors.primary.withValues(alpha: 0.5),
                    blurRadius: 10,
                  )
                ] : null,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF6B7280), height: 1.4),
                children: [
                  TextSpan(text: '${t.otpSentToLabel}\n'),
                  TextSpan(
                    text: email,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? DarkColors.primary : const Color(0xFF0068FF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            OtpInput(
              onChanged: (val) => setState(() => _otpCode = val),
              onCompleted: (val) => setState(() => _otpCode = val),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSending || _resendCooldown > 0 ? null : _resendOtp,
              child: Text(
                _isSending
                    ? t.sending
                    : (_resendCooldown > 0
                        ? '${t.resendIn} (${_resendCooldown}s)'
                        : t.resendOtp),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _resendCooldown > 0 ? Colors.grey : (isDarkMode ? DarkColors.primary : const Color(0xFF0068FF)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _otpCode.length == 6 ? _verifyOtp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _otpCode.length == 6
                      ? (isDarkMode ? DarkColors.primary : const Color(0xFF0068FF))
                      : (isDarkMode ? DarkColors.divider : const Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  t.confirm,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  color: _otpCode.length == 6 ? Colors.white : (isDarkMode ? DarkColors.textHint : const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: New Password
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildNewPasswordStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final t = AuthTexts.of(context);
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final isPasswordValid = password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
    final isMatch = password == confirm && confirm.isNotEmpty;
    final canSubmit = isPasswordValid && isMatch && !_isSubmitting;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Text(
                t.setNewPassword,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF141414),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                t.resetPasswordNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              t.newPassword,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: t.hintNewPassword,
                filled: true,
                fillColor: isDarkMode ? DarkColors.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
                border: const UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            if (password.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPasswordCheck(t.passwordAtLeast8, password.length >= 8),
              _buildPasswordCheck(t.passwordMustHaveUpper, RegExp(r'[A-Z]').hasMatch(password)),
              _buildPasswordCheck(t.passwordMustHaveLower, RegExp(r'[a-z]').hasMatch(password)),
              _buildPasswordCheck(t.passwordMustHaveNumber, RegExp(r'[0-9]').hasMatch(password)),
            ],
            const SizedBox(height: 20),
            Text(
              t.confirmNewPassword,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              obscureText: !_showConfirm,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: t.hintConfirmPassword,
                filled: true,
                fillColor: isDarkMode ? DarkColors.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                errorText: confirm.isNotEmpty && !isMatch
                    ? t.passwordMismatch
                    : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
                border: const UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit ? _resetPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit
                      ? (isDarkMode ? DarkColors.primary : AppColors.primary)
                      : (isDarkMode ? DarkColors.divider : const Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        t.confirmAction,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCheck(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: passed ? AppColors.success : (Theme.of(context).brightness == Brightness.dark ? DarkColors.textHint : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: passed ? AppColors.success : (Theme.of(context).brightness == Brightness.dark ? DarkColors.textHint : const Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}
