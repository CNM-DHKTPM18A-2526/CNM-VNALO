class Validators {
  Validators._();

  static String? phone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Vui lòng nhập số điện thoại';

    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length < 9 || normalized.length > 11) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Vui lòng nhập tên hiển thị';
    if (name.length < 2) return 'Tên hiển thị tối thiểu 2 ký tự';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Vui lòng xác nhận mật khẩu';
    if (value != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }
}
