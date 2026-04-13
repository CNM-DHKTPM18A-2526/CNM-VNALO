import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
import 'package:vnalo_mobile/features/auth/screens/login_password_screen.dart';
import 'package:vnalo_mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:vnalo_mobile/features/auth/screens/register_screen.dart';
import 'package:vnalo_mobile/features/auth/widgets/phone_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _countryCode = '+84';
  bool _hasPhone = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final hasPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
    if (hasPhone != _hasPhone) {
      setState(() => _hasPhone = hasPhone);
    }
  }

  String _buildFullPhone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return '$_countryCode$digits';
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPasswordScreen(phoneNumber: _buildFullPhone()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AuthTexts.of(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          t.enterPhoneTitle,
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF171717),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                PhoneInput(
                  controller: _phoneController,
                  hintText: t.phoneHint,
                  selectedCountryCode: _countryCode,
                  onCountryCodeChanged:
                      (value) => setState(() => _countryCode = value),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: _hasPhone ? (isDarkMode ? DarkColors.primary : AppColors.primary) : (isDarkMode ? DarkColors.surface : const Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _hasPhone ? _handleNext : null,
                  child: Text(
                    t.continueText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _hasPhone ? Colors.white : (isDarkMode ? Colors.white38 : const Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      t.forgotPassword,
                      style: TextStyle(
                        color: isDarkMode ? DarkColors.primary : AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: t.noAccount,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : LightColors.textPrimary,
                          fontSize: 18,
                        ),
                        children: [
                          TextSpan(
                            text: t.createAccountShort,
                            style: TextStyle(
                              color: isDarkMode ? DarkColors.primary : AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
