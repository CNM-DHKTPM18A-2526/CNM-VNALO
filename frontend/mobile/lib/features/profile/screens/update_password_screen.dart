import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

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
  bool _isSubmitting = false;

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
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật mật khẩu (mô phỏng UI).')),
    );
    Navigator.pop(context);
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
          const Text(
            'Mật khẩu phải gồm chữ hoa, chữ thường và số; không nên dùng thông tin dễ đoán như năm sinh hoặc tên.',
            style: TextStyle(fontSize: 16, color: Color(0xFF374151), height: 1.4),
          ),
          const SizedBox(height: 22),
          const Text('Mật khẩu hiện tại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
          const Text('Mật khẩu mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _newController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Nhập mật khẩu mới',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Nhập lại mật khẩu mới',
              border: UnderlineInputBorder(),
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
