import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  String? _newPasswordError;
  String? _confirmPasswordError;

  bool get _canSubmit {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) return false;
    if (next.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(next)) return false;
    if (!RegExp(r'[a-z]').hasMatch(next)) return false;
    if (!RegExp(r'[0-9]').hasMatch(next)) return false;
    if (next != confirm) return false;
    return true;
  }

  void _validateNewPassword(String value) {
    String? error;
    if (value.isNotEmpty) {
      if (value.length < 8) {
        error = 'Mật khẩu phải có ít nhất 8 ký tự';
      } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
        error = 'Mật khẩu phải có ít nhất 1 chữ hoa';
      } else if (!RegExp(r'[a-z]').hasMatch(value)) {
        error = 'Mật khẩu phải có ít nhất 1 chữ thường';
      } else if (!RegExp(r'[0-9]').hasMatch(value)) {
        error = 'Mật khẩu phải có ít nhất 1 chữ số';
      }
    }
    setState(() {
      _newPasswordError = error;
      // Re-validate confirm if already filled
      if (_confirmController.text.isNotEmpty &&
          _confirmController.text != value) {
        _confirmPasswordError = 'Mật khẩu xác nhận không khớp';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value.isNotEmpty && value != _newController.text) {
        _confirmPasswordError = 'Mật khẩu xác nhận không khớp';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    try {
      await context.read<AuthService>().changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật mật khẩu thành công'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'AUTH_015':
          message = 'Mật khẩu hiện tại không đúng';
          break;
        case 'AUTH_016':
          message = 'Mật khẩu mới không đáp ứng yêu cầu';
          break;
        default:
          message = e.message.isNotEmpty && e.message != 'Unknown error'
              ? e.message
              : 'Cập nhật mật khẩu thất bại (${e.statusCode})';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Cập nhật mật khẩu'),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? DarkColors.divider : AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mật khẩu phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? DarkColors.textSecondary : LightColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildInputField(
            label: 'Mật khẩu hiện tại',
            controller: _currentController,
            hint: 'Nhập mật khẩu hiện tại',
            obscure: !_showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Mật khẩu mới',
            controller: _newController,
            hint: 'Nhập mật khẩu mới',
            obscure: !_showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            errorText: _newPasswordError,
            onChanged: _validateNewPassword,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Nhập lại mật khẩu mới',
            controller: _confirmController,
            hint: 'Nhập lại mật khẩu mới',
            obscure: !_showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
            errorText: _confirmPasswordError,
            onChanged: _validateConfirmPassword,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isSubmitting || !_canSubmit ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: _canSubmit ? AppColors.primary : (isDarkMode ? DarkColors.divider : AppColors.primary.withValues(alpha: 0.3)),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('CẬP NHẬT MẬT KHẨU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDarkMode,
    required Color surfaceColor,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 15),
            filled: true,
            fillColor: surfaceColor,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDarkMode ? Colors.white54 : Colors.grey,
                size: 22,
              ),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDarkMode ? DarkColors.divider : LightColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
