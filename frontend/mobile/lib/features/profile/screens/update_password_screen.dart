import 'package:flutter/material.dart';
import 'package:vnalo_mobile/features/auth/localization/auth_texts.dart';
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
    final next = _newController.text;
    final confirm = _confirmController.text;
    if (_currentController.text.isEmpty || next.isEmpty || confirm.isEmpty) return false;
    if (next.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(next)) return false;
    if (!RegExp(r'[a-z]').hasMatch(next)) return false;
    if (!RegExp(r'[0-9]').hasMatch(next)) return false;
    if (next != confirm) return false;
    return true;
  }

  void _validateNewPassword(String value) {
    final t = AuthTexts.of(context, listen: false);
    String? error;
    if (value.isNotEmpty) {
      if (value.length < 8) {
        error = t.passwordAtLeast8;
      } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
        error = t.passwordMustHaveUpper;
      } else if (!RegExp(r'[a-z]').hasMatch(value)) {
        error = t.passwordMustHaveLower;
      } else if (!RegExp(r'[0-9]').hasMatch(value)) {
        error = t.passwordMustHaveNumber;
      }
    }
    setState(() {
      _newPasswordError = error;
      if (_confirmController.text.isNotEmpty &&
          _confirmController.text != value) {
        _confirmPasswordError = t.passwordMismatch;
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    final t = AuthTexts.of(context, listen: false);
    setState(() {
      if (value.isNotEmpty && value != _newController.text) {
        _confirmPasswordError = t.passwordMismatch;
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
    final t = AuthTexts.of(context, listen: false);
    setState(() => _isSubmitting = true);

    try {
      await context.read<AuthService>().changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.updatePasswordSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'AUTH_015':
          message = t.currentPasswordIncorrect;
          break;
        case 'AUTH_016':
          message = t.newPasswordRequirementFail;
          break;
        default:
          message = e.message.isNotEmpty && e.message != 'Unknown error'
              ? e.message
              : '${t.updatePasswordFailed} (${e.statusCode})';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.cancel}: $e'),
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
    final t = AuthTexts.of(context);
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : LightColors.scaffold;
    final surfaceColor = isDarkMode ? DarkColors.surface : LightColors.surface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(t.updatePasswordTitle),
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
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
                Icon(Icons.info_outline, color: isDarkMode ? DarkColors.primary : AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.passwordRequirementShortNote,
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
            label: t.currentPasswordLabel,
            controller: _currentController,
            hint: t.hintCurrentPassword,
            obscure: !_showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: t.newPassword,
            controller: _newController,
            hint: t.hintNewPassword,
            obscure: !_showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            errorText: _newPasswordError,
            onChanged: _validateNewPassword,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: t.confirmNewPassword,
            controller: _confirmController,
            hint: t.hintConfirmPassword,
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
              backgroundColor: _canSubmit ? (isDarkMode ? DarkColors.primary : AppColors.primary) : (isDarkMode ? DarkColors.divider : AppColors.primary.withValues(alpha: 0.3)),
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
                : Text(t.updatePasswordAction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
              borderSide: BorderSide(color: isDarkMode ? DarkColors.primary : AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
