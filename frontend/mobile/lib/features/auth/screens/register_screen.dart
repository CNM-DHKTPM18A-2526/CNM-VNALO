import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/avatar_utils.dart';
import 'package:vnalo_mobile/core/utils/validators.dart';
import 'package:vnalo_mobile/core/utils/api_error_mapper.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/login_screen.dart';
import 'package:vnalo_mobile/features/auth/widgets/otp_input.dart';
import 'package:vnalo_mobile/navigation/main_shell.dart';
import 'package:vnalo_mobile/features/auth/widgets/phone_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _agreeTermsA = false;
  bool _agreeTermsB = false;
  bool _isSendingOtp = false;
  bool _isResendingOtp = false;
  bool _isSubmittingRegistration = false;
  bool _isSkipSubmitting = false;
  bool _requiresOtp = true;
  bool _otpStatusResolved = false;
  String _otpCode = '';
  String _countryCode = '+84';
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  bool get _isAnyRequestInFlight =>
      _isSendingOtp || _isResendingOtp || _isSubmittingRegistration;

  int get _totalSteps => _requiresOtp ? 7 : 6;

  String? _phoneValidationError() {
    return Validators.phone(
      _phoneController.text,
      countryCode: _countryCode,
    );
  }

  // Personal info (optional, client-side only for now)
  DateTime? _birthday;
  String? _gender;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _resetRegistrationDraft();
    _loadOtpStatus();
  }

  void _resetRegistrationDraft() {
    _phoneController.clear();
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _otpCode = '';
    _currentStep = 0;
    _agreeTermsA = false;
    _agreeTermsB = false;
    _birthday = null;
    _gender = null;
    _avatarFile = null;
  }

  Future<void> _loadOtpStatus() async {
    const fallbackRequiresOtp = true;
    final previousRequiresOtp = _requiresOtp;

    try {
      final required = await context
          .read<AuthProvider>()
          .fetchOtpRequiredStatus()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => fallbackRequiresOtp,
          );
      if (!mounted) return;
      setState(() {
        _requiresOtp = required;
        _otpStatusResolved = true;
        if (previousRequiresOtp && !required && _currentStep > 0) {
          _currentStep = (_currentStep - 1).clamp(0, _totalSteps - 1);
        }
      });
      if (previousRequiresOtp && !required) {
        _pageController.jumpToPage(_currentStep);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requiresOtp = fallbackRequiresOtp;
        _otpStatusResolved = true;
      });
    }
  }

  String? _genderForApi() {
    switch (_gender) {
      case 'male':
        return 'MALE';
      case 'female':
        return 'FEMALE';
      case 'other':
        return 'UNKNOWN';
      default:
        return null;
    }
  }

  String? _dobForApi() {
    if (_birthday == null) return null;
    return _birthday!.toIso8601String().split('T').first;
  }

  bool _showPasswordInRegister = false;
  bool _showConfirmPasswordInRegister = false;

  String _buildFullPhone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_countryCode == '+84' && digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return '$_countryCode$digits';
  }

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
    _phoneController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    final target = step.clamp(0, _totalSteps - 1);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = target);
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    _goToStep(_currentStep + 1);
  }

  void _backStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    _goToStep(_currentStep - 1);
  }

  void _continueFromNameStep() {
    final error = Validators.displayName(_nameController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    _nextStep();
  }

  void _continueFromPhoneStep() {
    if (_isAnyRequestInFlight) return;
    if (!_agreeTermsA || !_agreeTermsB) return;
    if (_phoneValidationError() != null) return;

    _goToStep(1);
  }

  Future<void> _continueFromEmailStep() async {
    if (_isAnyRequestInFlight) return;

    if (!_otpStatusResolved) {
      await _loadOtpStatus();
      if (!mounted) return;
    }

    final email = _emailController.text.trim();
    final emailError = Validators.email(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!_requiresOtp) {
      _otpCode = '000000';
      _goToStep(2);
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      await context.read<AuthProvider>().sendRegisterOtp(
        phone: _buildFullPhone(),
        email: email,
      );
      if (!mounted) return;
      _startCooldownTimer();
      _nextStep();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorMapper.map(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  void _onOtpChanged(String value) {
    setState(() => _otpCode = value);
  }

  Future<void> _resendOtp() async {
    if (_isAnyRequestInFlight) return;

    setState(() => _isResendingOtp = true);
    try {
      await context.read<AuthProvider>().sendRegisterOtp(
        phone: _buildFullPhone(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _startCooldownTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthTexts.of(context, listen: false).otpResent),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorMapper.map(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResendingOtp = false);
    }
  }

  void _verifyOtpAndContinue() {
    if (!RegExp(r'^\d{6}$').hasMatch(_otpCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthTexts.of(context, listen: false).otpInvalid),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    _nextStep();
  }

  Future<void> _completeRegistration({bool isSkipAction = false}) async {
    if (_isSubmittingRegistration) return;

    setState(() {
      _isSubmittingRegistration = true;
      _isSkipSubmitting = isSkipAction;
    });
    final auth = context.read<AuthProvider>();
    Timer? slowSkipHintTimer;

    try {
      if (isSkipAction) {
        slowSkipHintTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted || !_isSubmittingRegistration) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dang hoan tat dang ky, vui long doi them mot chut...'),
              duration: Duration(seconds: 2),
            ),
          );
        });
      }

      final success = await auth
          .register(
        phone: _buildFullPhone(),
        email: _emailController.text.trim(),
        otp: _otpCode,
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        avatarFile: _avatarFile,
        gender: _genderForApi(),
        dob: _dobForApi(),
      );

      if (!mounted) return;

      if (success) {
        if (_avatarFile == null) {
          await auth.refreshCurrentUser();
          if (!mounted) return;
        }
        // H1: use warning (non-fatal) rather than error for the orange snackbar.
        if (auth.warning != null && auth.warning!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.warning!),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _showContactsPrompt();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? '\u0110\u0103ng k\u00fd th\u1ea5t b\u1ea1i'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // If the auth layer already established a valid session, treat this as
      // a recoverable post-registration issue (typically avatar/network).
      if (auth.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.warning ??
                  'Đăng ký đã hoàn tất, nhưng có lỗi khi cập nhật ảnh đại diện. Bạn có thể cập nhật lại trong Hồ sơ.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _showContactsPrompt();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorMapper.map(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      slowSkipHintTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSubmittingRegistration = false;
          _isSkipSubmitting = false;
        });
      }
    }
  }

  void _showContactsPrompt() {
    final t = AuthTexts.of(context, listen: false);
    final auth = context.read<AuthProvider>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDarkMode ? DarkColors.divider : const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.contacts_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.syncContactsTitle,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.syncContactsMessage,
                style: TextStyle(fontSize: 15, color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF4B5563), height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn luôn có thể thay đổi lựa chọn này trong Cài đặt quyền riêng tư.',
                style: TextStyle(fontSize: 13, color: isDarkMode ? DarkColors.textHint : const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: isDarkMode ? DarkColors.textSecondary : const Color(0xFF4B5563),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (mounted) _navigateToHome(auth);
                      },
                      child: Text(
                        t.laterText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final status = await Permission.contacts.request();
                        if (mounted && status.isPermanentlyDenied) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bạn đã tắt quyền Danh bạ. Có thể bật lại trong Cài đặt hệ thống.'),
                            ),
                          );
                        }
                        if (mounted) _navigateToHome(auth);
                      },
                      child: Text(
                        t.continueText,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet

    // Check permissions
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        _showPermissionDialog('Quyền máy ảnh', 'Vui lòng cấp quyền máy ảnh trong cài đặt để chụp ảnh.');
        return;
      } else if (!status.isGranted) {
        return;
      }
    } else {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isPermanentlyDenied) {
          _showPermissionDialog('Quyền thư viện ảnh', 'Vui lòng cấp quyền truy cập ảnh trong cài đặt để chọn ảnh.');
          return;
        } else if (!storageStatus.isGranted) {
          return;
        }
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (pickedFile != null) {
        setState(() => _avatarFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  void _showPermissionDialog(String title, String message) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? DarkColors.surface : Colors.white,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isDarkMode ? Colors.white : Colors.black)),
        content: Text(message, style: TextStyle(fontSize: 15, color: isDarkMode ? Colors.white70 : const Color(0xFF4B5563))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: isDarkMode ? Colors.white38 : const Color(0xFF6B7280)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Mở Cài đặt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToHome(AuthProvider auth) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            auth.isLoggedIn ? const MainShell() : const LoginScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;
    final appBarBg = isDarkMode ? DarkColors.appBarBg : Colors.white;
    final showAppBarTitle = _currentStep == 0;
    final t = AuthTexts.of(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        elevation: 0,
        leading: BackButton(
          onPressed: _backStep,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        title: showAppBarTitle
            ? Text(
                t.enterPhoneTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF171717),
                ),
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPhoneStep(),
          _buildEmailStep(),
          if (_requiresOtp) _buildOtpStep(),
          _buildNameStep(),
          _buildPersonalInfoStep(),
          _buildPasswordStep(),
          _buildAvatarStep(),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    final t = AuthTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final emailError = Validators.email(_emailController.text.trim());
    final canProceed = emailError == null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              t.enterEmailTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF141414),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Email sẽ được dùng để xác thực OTP đăng ký.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 17, color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: t.emailHint,
                hintStyle: TextStyle(color: isDarkMode ? DarkColors.textHint : LightColors.textHint),
                errorText: _emailController.text.isEmpty ? null : emailError,
                filled: true,
                fillColor: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : LightColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : LightColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor:
                    canProceed ? AppColors.primary : (isDarkMode ? DarkColors.divider : LightColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed:
                  canProceed && !_isAnyRequestInFlight && _otpStatusResolved
                    ? _continueFromEmailStep
                    : null,
                child: _isSendingOtp || !_otpStatusResolved
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      t.continueText,
                      style: TextStyle(
                        color: canProceed
                            ? Colors.white
                            : (isDarkMode ? DarkColors.textHint : LightColors.textHint),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpStep() {
    final t = AuthTexts.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              t.enterOtpTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF141414),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.otpSentToEmail(_emailController.text.trim()),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 28),
            OtpInput(
              onChanged: _onOtpChanged,
              onCompleted: _onOtpChanged,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _isAnyRequestInFlight || _resendCooldown > 0 ? null : _resendOtp,
              child: Text(
                _resendCooldown > 0 ? 'Gửi lại mã (${_resendCooldown}s)' : t.resendOtp,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _resendCooldown > 0 ? Colors.grey : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
                onPressed: _isAnyRequestInFlight ? null : _verifyOtpAndContinue,
                child: _isResendingOtp
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      t.confirmOtp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 0: Phone + Checkboxes ━━━━━━━━━━━━━━━

  Widget _buildPhoneStep() {
    final t = AuthTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPhoneValid = _phoneValidationError() == null;
    final canProceed = _agreeTermsA && _agreeTermsB && isPhoneValid;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneInput(
            controller: _phoneController,
            onChanged: (_) => setState(() {}),
            hintText: t.phoneHint,
            selectedCountryCode: _countryCode,
            onCountryCodeChanged:
                (value) => setState(() => _countryCode = value),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _agreeTermsA,
            onChanged: (value) =>
                setState(() => _agreeTermsA = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            side: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB), width: 1.5),
            title: Text(
              t.agreeTermA,
              style: TextStyle(fontSize: 16, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF252525)),
            ),
          ),
          CheckboxListTile(
            value: _agreeTermsB,
            onChanged: (value) =>
                setState(() => _agreeTermsB = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            side: BorderSide(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB), width: 1.5),
            title: Text(
              t.agreeTermB,
              style: TextStyle(fontSize: 16, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF252525)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor:
                  canProceed ? AppColors.primary : const Color(0xFFE5E7EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: canProceed && !_isAnyRequestInFlight ? _continueFromPhoneStep : null,
            child: _isSendingOtp
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    t.continueText,
                    style: TextStyle(
                      color: canProceed
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: RichText(
                text: TextSpan(
                  text: t.alreadyHasAccount,
                  style: TextStyle(
                    color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF374151),
                    fontSize: 17,
                  ),
                  children: [
                    TextSpan(
                      text: t.loginNow,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 1: Name Input (Zalo-style header) ━━━━━━━━━━━━━━━

  Widget _buildNameStep() {
    final t = AuthTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasValidName = Validators.displayName(_nameController.text) == null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Centered header (NOT in AppBar) — like Zalo
            Text(
              t.enterNameTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF141414),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.enterNameSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 17, color: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary),
              decoration: InputDecoration(
                hintText: t.displayNameHint,
                hintStyle: TextStyle(color: isDarkMode ? DarkColors.textHint : const Color(0xFFB0B0B0)),
                filled: true,
                fillColor: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Rules — bolder text, matching Zalo
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ruleItem('•  ${t.nameHelpLength}'),
                  const SizedBox(height: 8),
                  _ruleItem('•  ${t.nameHelpNoNumbers}'),
                  const SizedBox(height: 8),
                  _ruleItem(
                    '•  ${t.nameHelpRules}',
                    isLink: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor:
                    hasValidName ? AppColors.primary : const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: hasValidName ? _continueFromNameStep : null,
              child: Text(
                t.continueText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: hasValidName ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleItem(String text, {bool isLink = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isLink ? AppColors.primary : (Theme.of(context).brightness == Brightness.dark ? DarkColors.textSecondary : const Color(0xFF4B5563)),
        height: 1.4,
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 2: Personal Info (Zalo-style) ━━━━━━━━━━━━━━━

  Widget _buildPersonalInfoStep() {
    final t = AuthTexts.of(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Centered header
          Text(
            t.personalInfoTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 28),
          // Birthday — tap to open date picker bottom sheet
          GestureDetector(
            onTap: _pickBirthday,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _birthday != null
                          ? '${_birthday!.day.toString().padLeft(2, '0')}/${_birthday!.month.toString().padLeft(2, '0')}/${_birthday!.year}'
                          : t.birthdayHint,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _birthday != null
                            ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                            : (isDarkMode ? Colors.white38 : const Color(0xFFB0B0B0)),
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF9CA3AF), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Gender — tap to open bottom sheet (like language picker)
          GestureDetector(
            onTap: _showGenderPicker,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDarkMode ? DarkColors.divider : const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _gender == 'male'
                          ? t.genderMale
                          : _gender == 'female'
                              ? t.genderFemale
                              : t.genderHint,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _gender != null
                            ? (isDarkMode ? Colors.white : const Color(0xFF1F2937))
                            : (isDarkMode ? Colors.white38 : const Color(0xFFB0B0B0)),
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF9CA3AF), size: 24),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _nextStep,
            child: Text(
              t.continueText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGenderPicker() {
    final t = AuthTexts.of(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 56,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.genderHint,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF141414),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      t.genderMale,
                      style: TextStyle(
                          fontSize: 18, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF1F2937)),
                    ),
                    trailing: _gender == 'male'
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 24)
                        : null,
                    onTap: () {
                      setState(() => _gender = 'male');
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      t.genderFemale,
                      style: TextStyle(
                          fontSize: 18, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF1F2937)),
                    ),
                    trailing: _gender == 'female'
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 24)
                        : null,
                    onTap: () {
                      setState(() => _gender = 'female');
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      t.genderNotShare,
                      style: TextStyle(
                          fontSize: 18, color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF1F2937)),
                    ),
                    trailing: _gender == 'other'
                        ? const Icon(Icons.check,
                            color: AppColors.primary, size: 24)
                        : null,
                    onTap: () {
                      setState(() => _gender = 'other');
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _birthday ?? DateTime(now.year - 18, now.month, now.day);
    final t = AuthTexts.of(context, listen: false);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        DateTime tempDate = initial;
        bool showWarning = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: 380,
              decoration: BoxDecoration(
                color: isDarkMode ? DarkColors.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header with Done button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            t.skip,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: showWarning
                              ? null
                              : () {
                                  setState(() => _birthday = tempDate);
                                  Navigator.pop(sheetContext);
                                },
                          child: Text(
                            t.continueText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: showWarning
                                  ? const Color(0xFFD1D5DB)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Age restriction note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      t.ageRestrictionNote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  // Warning if under 14
                  if (showWarning)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(
                        t.ageRestrictionWarning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // CupertinoDatePicker for smooth scrolling
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      minimumDate: DateTime(1920),
                      maximumDate: now,
                      onDateTimeChanged: (date) {
                        tempDate = date;
                        final age = now.year - date.year;
                        final isUnder14 = age < 14 ||
                            (age == 14 &&
                                (date.month > now.month ||
                                    (date.month == now.month &&
                                        date.day > now.day)));
                        if (isUnder14 != showWarning) {
                          setSheetState(() => showWarning = isUnder14);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━ Step 3: Password ━━━━━━━━━━━━━━━

  Widget _buildPasswordStep() {
    final t = AuthTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Centered header
              Text(
                t.enterPasswordTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? DarkColors.textPrimary : const Color(0xFF141414),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPasswordInRegister,
                validator: Validators.password,
                style: TextStyle(fontSize: 17, color: isDarkMode ? DarkColors.textPrimary : Colors.black),
                decoration: InputDecoration(
                  hintText: t.passwordHint,
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : const Color(0xFFB0B0B0)),
                  filled: true,
                  fillColor: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPasswordInRegister ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                    onPressed: () => setState(() => _showPasswordInRegister = !_showPasswordInRegister),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white54 : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPasswordInRegister,
                validator: (value) => Validators.confirmPassword(
                  value,
                  _passwordController.text,
                ),
                style: TextStyle(fontSize: 17, color: isDarkMode ? DarkColors.textPrimary : Colors.black),
                decoration: InputDecoration(
                  hintText: t.confirmPasswordHint,
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : const Color(0xFFB0B0B0)),
                  filled: true,
                  fillColor: isDarkMode ? DarkColors.surface : const Color(0xFFF9FAFB),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPasswordInRegister ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                    onPressed: () => setState(() => _showConfirmPasswordInRegister = !_showConfirmPasswordInRegister),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Xác nhận mật khẩu phải trùng khớp hoàn toàn với mật khẩu đã nhập.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  if (_profileFormKey.currentState!.validate()) {
                    _nextStep();
                  }
                },
                child: Text(
                  t.continueText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 4: Avatar ━━━━━━━━━━━━━━━

  Widget _buildAvatarStep() {
    final t = AuthTexts.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayName = _nameController.text.trim();
    final initials = AvatarUtils.getInitials(displayName);
    final avatarColor = AvatarUtils.getColor(displayName);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
        children: [
          const SizedBox(height: 16),
          // Centered header
          Text(
            t.avatarTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.avatarSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? DarkColors.textSecondary : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.avatarDevNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 40),
          // Auto-generated initials avatar
          GestureDetector(
            onTap: _showAvatarPicker,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _avatarFile == null ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    avatarColor.withValues(alpha: 0.7),
                    avatarColor,
                  ],
                ) : null,
                image: _avatarFile != null 
                    ? DecorationImage(
                        image: FileImage(_avatarFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _avatarFile == null ? Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ) : null,
            ),
          ),
          const SizedBox(height: 50),
          // Primary Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _isSubmittingRegistration
              ? null
              : (_avatarFile == null
                ? _showAvatarPicker
                : () => _completeRegistration()),
            child: _isSubmittingRegistration && !_isSkipSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _avatarFile == null ? t.update : t.continueText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // Secondary Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFFE5E7EB),
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _isSubmittingRegistration
                ? null
                : (_avatarFile == null
                    ? () => _completeRegistration(isSkipAction: true)
                    : _showAvatarPicker),
            child: _isSubmittingRegistration && _isSkipSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF111827),
                    ),
                  )
                : Text(
              // L1: was a hardcoded Vietnamese literal; now uses AuthTexts for i18n consistency.
              _avatarFile == null ? t.skip : t.changePhoto,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }

  void _showAvatarPicker() {
    final t = AuthTexts.of(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 56,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF374151)),
                    title: Text(t.takePhoto,
                        style: const TextStyle(fontSize: 17)),
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined,
                        color: Color(0xFF374151)),
                    title: Text(t.chooseFromGallery,
                        style: const TextStyle(fontSize: 17)),
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
