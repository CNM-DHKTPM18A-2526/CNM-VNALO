import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/core/utils/validators.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final emailError = Validators.email(_emailController.text);
    if (emailError != null) {
      _showError(emailError);
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      await context.read<AuthService>().requestPasswordReset(
            email: _emailController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Da gui OTP ve email. Vui long kiem tra hop thu.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } on ApiException catch (e) {
      _showError(_mapApiError(e));
    } catch (_) {
      _showError('Khong the gui OTP, vui long thu lai');
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    final confirmError =
        Validators.confirmPassword(_confirmController.text, _passwordController.text);
    if (emailError != null) {
      _showError(emailError);
      return;
    }
    if (_otpController.text.trim().length != 6) {
      _showError('OTP gom 6 chu so');
      return;
    }
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    if (confirmError != null) {
      _showError(confirmError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<AuthService>().resetPassword(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dat lai mat khau thanh cong'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      _showError(_mapApiError(e));
    } catch (_) {
      _showError('Dat lai mat khau that bai');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _mapApiError(ApiException e) {
    switch (e.code) {
      case 'AUTH_019':
        return 'Email chua duoc dang ky';
      case 'AUTH_009':
        return 'OTP da het han';
      case 'AUTH_010':
        return 'OTP khong dung';
      case 'AUTH_011':
        return 'OTP vuot qua so lan thu';
      case 'AUTH_016':
        return 'Mat khau moi chua dat yeu cau';
      case 'AUTH_020':
        return 'He thong chua cau hinh gui OTP email';
      default:
        return e.message.isNotEmpty ? e.message : 'Yeu cau that bai';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canReset = !_isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quen mat khau'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Nhap email tai khoan',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isSendingOtp ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Gui OTP'),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'OTP',
              hintText: 'Nhap ma OTP 6 so',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mat khau moi',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Xac nhan mat khau moi',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: canReset ? _resetPassword : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Dat lai mat khau'),
          ),
        ],
      ),
    );
  }
}
