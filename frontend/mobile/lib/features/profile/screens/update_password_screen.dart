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
    if (!RegExp(r'\d').hasMatch(next)) return false;
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
      } else if (!RegExp(r'\d').hasMatch(value)) {
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
          backgroundColor: Color(0xFF22C55E),
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
          message = e.message.isNotEmpty
              ? e.message
              : 'Cập nhật mật khẩu thất bại (${e.statusCode})';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xảy ra lỗi, vui lòng thử lại'),
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
    final appBarBg = isDarkMode ? DarkColors.appBarBg : LightColors.appBarBg;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Cập nhật mật khẩu'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0068FF), Color(0xFF00A2ED)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            'Mật khẩu phải gồm chữ hoa, chữ thường và số; không nên dùng thông tin dễ đoán như năm sinh hoặc tên.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Mật khẩu hiện tại',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _currentController,
            obscureText: !_showCurrent,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Nhập mật khẩu hiện tại',
              suffix: GestureDetector(
                onTap: () => setState(() => _showCurrent = !_showCurrent),
                child: Text(
                  _showCurrent ? 'ẨN' : 'HIỆN',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              border: const UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Mật khẩu mới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newController,
            obscureText: !_showNew,
            onChanged: (v) {
              _validateNewPassword(v);
            },
            decoration: InputDecoration(
              hintText: 'Nhập mật khẩu mới',
              errorText: _newPasswordError,
              suffix: GestureDetector(
                onTap: () => setState(() => _showNew = !_showNew),
                child: Text(
                  _showNew ? 'ẨN' : 'HIỆN',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              border: const UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: !_showConfirm,
            onChanged: (v) {
              _validateConfirmPassword(v);
            },
            decoration: InputDecoration(
              hintText: 'Nhập lại mật khẩu mới',
              errorText: _confirmPasswordError,
              suffix: GestureDetector(
                onTap: () => setState(() => _showConfirm = !_showConfirm),
                child: Text(
                  _showConfirm ? 'ẨN' : 'HIỆN',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              border: const UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting || !_canSubmit ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: _canSubmit ? AppColors.primary : const Color(0xFFBFDBFE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('CẬP NHẬT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
