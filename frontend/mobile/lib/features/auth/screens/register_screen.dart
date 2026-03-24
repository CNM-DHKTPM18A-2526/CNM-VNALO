import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/avatar_utils.dart';
import 'package:vnalo_mobile/core/utils/validators.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/screens/login_screen.dart';
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
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _agreeTermsA = false;
  bool _agreeTermsB = false;
  bool _isLoading = false;
  String _otpCode = '';
  String _countryCode = '+84';

  // Personal info (optional, client-side only for now)
  DateTime? _birthday;
  String? _gender;

  String _buildFullPhone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return '$_countryCode$digits';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  void _nextStep() {
    FocusScope.of(context).unfocus();
    _goToStep(_currentStep + 1);
  }

  Future<void> _sendOtp() async {
    if (!_agreeTermsA || !_agreeTermsB) return;
    if (Validators.phone(_phoneController.text) != null) return;

    setState(() => _isLoading = true);
    try {
      // DEV mode: bypass OTP verification step.
      // PROD: uncomment the following and add OTP screen step.
      // await context.read<AuthProvider>().sendOtp(_buildFullPhone());
      _otpCode = '000000';
      if (!mounted) return;
      _nextStep();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi OTP thất bại: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      final success = await auth.register(
        phone: _buildFullPhone(),
        otp: _otpCode,
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        _showContactsPrompt();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Đăng ký thất bại'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showContactsPrompt() {
    final t = AuthTexts.of(context, listen: false);
    final auth = context.read<AuthProvider>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          t.syncContactsTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          t.syncContactsMessage,
          style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToHome(auth);
            },
            child: Text(
              t.laterText,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // TODO: Implement actual contacts permission request 
              Navigator.pop(ctx);
              _navigateToHome(auth);
            },
            child: Text(
              t.continueText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
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
    // Only show AppBar title for Phone step; other steps use in-body header
    final showAppBarTitle = _currentStep == 0;
    final t = AuthTexts.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: showAppBarTitle
            ? Text(
                t.enterPhoneTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF171717),
                ),
              )
            : null,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPhoneStep(),
          _buildNameStep(),
          _buildPersonalInfoStep(),
          _buildPasswordStep(),
          _buildAvatarStep(),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 0: Phone + Checkboxes ━━━━━━━━━━━━━━━

  Widget _buildPhoneStep() {
    final t = AuthTexts.of(context);
    final canProceed = _agreeTermsA && _agreeTermsB;

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
            contentPadding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
            title: Text(
              t.agreeTermA,
              style: const TextStyle(fontSize: 16, color: Color(0xFF252525)),
            ),
          ),
          CheckboxListTile(
            value: _agreeTermsB,
            onChanged: (value) =>
                setState(() => _agreeTermsB = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
            title: Text(
              t.agreeTermB,
              style: const TextStyle(fontSize: 16, color: Color(0xFF252525)),
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
            onPressed: canProceed && !_isLoading ? _sendOtp : null,
            child: _isLoading
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
                  style: const TextStyle(
                    color: Color(0xFF374151),
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
    final name = _nameController.text.trim();
    final hasName = name.length >= 2;

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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF141414),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.enterNameSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: t.displayNameHint,
                hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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
                    hasName ? AppColors.primary : const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: hasName ? _nextStep : null,
              child: Text(
                t.continueText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: hasName ? Colors.white : const Color(0xFF9CA3AF),
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
        color: isLink ? AppColors.primary : const Color(0xFF4B5563),
        height: 1.4,
      ),
    );
  }

  // ━━━━━━━━━━━━━━━ Step 2: Personal Info (Zalo-style) ━━━━━━━━━━━━━━━

  Widget _buildPersonalInfoStep() {
    final t = AuthTexts.of(context);

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
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141414),
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
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
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
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFB0B0B0),
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
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
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
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFB0B0B0),
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
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF141414),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      t.genderMale,
                      style: const TextStyle(
                          fontSize: 18, color: Color(0xFF1F2937)),
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
                      style: const TextStyle(
                          fontSize: 18, color: Color(0xFF1F2937)),
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
                      style: const TextStyle(
                          fontSize: 18, color: Color(0xFF1F2937)),
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
            return Container(
              height: 380,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF141414),
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                validator: Validators.password,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  hintText: t.passwordHint,
                  hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                validator: (value) => Validators.confirmPassword(
                  value,
                  _passwordController.text,
                ),
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  hintText: t.confirmPasswordHint,
                  hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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
    final displayName = _nameController.text.trim();
    final initials = AvatarUtils.getInitials(displayName);
    final avatarColor = AvatarUtils.getColor(displayName);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Centered header
          Text(
            t.avatarTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.avatarSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF4B5563),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    avatarColor.withValues(alpha: 0.7),
                    avatarColor,
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
          // "Cập nhật" blue button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _isLoading ? null : _showAvatarPicker,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    t.update,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // "Bỏ qua" skip grey button
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
            onPressed: _isLoading ? null : _confirmSkipAvatar,
            child: Text(
              t.skip,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmSkipAvatar() {
    final t = AuthTexts.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          t.skipAvatarTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          t.skipAvatarMessage,
          style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t.cancel,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _completeRegistration();
            },
            child: Text(
              t.accept,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
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
                    onTap: () {
                      Navigator.pop(sheetContext);
                      // TODO: Implement camera capture
                      _completeRegistration();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined,
                        color: Color(0xFF374151)),
                    title: Text(t.chooseFromGallery,
                        style: const TextStyle(fontSize: 17)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      // TODO: Implement gallery picker
                      _completeRegistration();
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
}
