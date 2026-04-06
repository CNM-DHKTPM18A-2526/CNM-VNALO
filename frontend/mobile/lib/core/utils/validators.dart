class Validators {
  Validators._();

  static String? phone(String? value, {String countryCode = '+84'}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Vui lòng nhập số điện thoại';

    final normalized = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (countryCode == '+84') {
      final vnMobile = RegExp(r'^(?:0)?(?:3|5|7|8|9)\d{8}$');
      if (!vnMobile.hasMatch(normalized)) {
        return 'Số điện thoại Việt Nam không hợp lệ';
      }
      return null;
    }

    if (normalized.length < 7 || normalized.length > 15) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Vui lòng nhập tên hiển thị';
    if (name.length > 100) return 'Tên hiển thị tối đa 100 ký tự';
    final normalized = name.replaceAll(RegExp(r'\s+'), ' ');
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) {
      return 'Tên hiển thị phải gồm ít nhất 2 từ';
    }

    final validChars = RegExp(r"^[A-Za-zÀ-ỹà-ỹĐđ\s'\-]+$");
    if (!validChars.hasMatch(normalized)) {
      return 'Tên hiển thị chỉ được chứa chữ cái';
    }

    if (RegExp(r'\d').hasMatch(name)) {
      return 'Tên hiển thị không được chứa số';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    if (!hasUpper || !hasLower || !hasDigit) {
      return 'Mật khẩu cần có chữ hoa, chữ thường và số';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Vui lòng xác nhận mật khẩu';
    if (value != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }
}
