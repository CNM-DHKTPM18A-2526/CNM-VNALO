import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';

class AuthTexts {
  final AppLanguage language;

  const AuthTexts(this.language);

  static AuthTexts of(BuildContext context, {bool listen = true}) {
    final language = Provider.of<LanguageProvider>(context, listen: listen).language;
    return AuthTexts(language);
  }

  bool get _isVi => language == AppLanguage.vi;

  String get appName => 'VNALO';

  String get login => _isVi ? 'Đăng nhập' : 'Log in';
  String get createAccount =>
      _isVi ? 'Tạo tài khoản mới' : 'Create new account';
  String get createAccountShort => _isVi ? 'Tạo tài khoản' : 'Create account';
  String get continueText => _isVi ? 'Tiếp tục' : 'Continue';
  String get enterPhoneTitle =>
      _isVi ? 'Nhập số điện thoại' : 'Enter phone number';
  String get enterOtpTitle => _isVi ? 'Nhập mã OTP' : 'Enter OTP code';
  String get enterPasswordTitle => _isVi ? 'Nhập mật khẩu' : 'Enter password';
  String get completeRegister =>
      _isVi ? 'Hoàn tất đăng ký' : 'Complete registration';
  String get phoneHint => _isVi ? 'Số điện thoại' : 'Phone number';
  String get displayNameHint => _isVi ? 'Tên hiển thị' : 'Display name';
  String get passwordHint => _isVi ? 'Mật khẩu' : 'Password';
  String get confirmPasswordHint =>
      _isVi ? 'Xác nhận mật khẩu' : 'Confirm password';
  String get otpSent =>
      _isVi ? 'Nhập mã OTP đã gửi đến' : 'Enter the OTP sent to';
  String otpSentTo(String phone) =>
      _isVi ? 'Nhập mã OTP đã gửi đến $phone' : 'Enter the OTP sent to $phone';
  String get confirmOtp => _isVi ? 'Xác nhận' : 'Confirm';
  String get resendOtp => _isVi ? 'Gửi lại mã OTP' : 'Resend OTP';
  String get otpResent => _isVi ? 'Đã gửi lại OTP' : 'OTP resent';
  String get otpInvalid => _isVi ? 'Mã OTP phải gồm 6 chữ số' : 'OTP must be 6 digits';

  String get alreadyHasAccount =>
      _isVi ? 'Bạn đã có tài khoản? ' : 'Already have an account? ';
  String get noAccount =>
      _isVi ? 'Bạn chưa có tài khoản? ' : 'No account yet? ';
  String get loginNow => _isVi ? 'Đăng nhập ngay' : 'Log in now';

  String get agreeTermA =>
      _isVi
          ? 'Tôi đồng ý với các điều khoản sử dụng VNALO'
          : 'I agree to VNALO Terms of Use';
  String get agreeTermB =>
      _isVi
          ? 'Tôi đồng ý với điều khoản Mạng xã hội của VNALO'
          : 'I agree to VNALO Social Network Terms';

  String get loginFailed => _isVi ? 'Đăng nhập thất bại' : 'Login failed';
  String get registerFailed => _isVi ? 'Đăng ký thất bại' : 'Register failed';
  String otpFailed(Object error) =>
      _isVi ? 'Gửi OTP thất bại: $error' : 'Failed to send OTP: $error';
  String accountLabel(String phone) =>
      _isVi ? 'Tài khoản: $phone' : 'Account: $phone';

  String get languageTitle => _isVi ? 'Chọn ngôn ngữ' : 'Choose language';
  String get vietnamese => 'Tiếng Việt';
  String get english => 'English';

  // ─── Register wizard: Name step ───

  String get enterNameTitle =>
      _isVi ? 'Nhập tên VNALO' : 'Enter your VNALO name';
  String get enterNameSubtitle =>
      _isVi
          ? 'Hãy dùng tên thật để mọi người dễ nhận ra bạn'
          : 'Use your real name so people can recognize you';
  String get nameHelpLength =>
      _isVi ? 'Dài từ 2 đến 100 ký tự' : '2 to 100 characters';
  String get nameHelpNoNumbers =>
      _isVi ? 'Không chứa số' : 'Must not contain numbers';
  String get nameHelpRules =>
      _isVi
          ? 'Cần tuân thủ quy định đặt tên VNALO'
          : 'Must follow VNALO naming rules';

  // ─── Register wizard: Personal Info step ───

  String get personalInfoTitle =>
      _isVi ? 'Thêm thông tin cá nhân' : 'Add personal info';
  String get birthdayHint => _isVi ? 'Sinh nhật' : 'Birthday';
  String get genderHint => _isVi ? 'Giới tính' : 'Gender';
  String get genderMale => _isVi ? 'Nam' : 'Male';
  String get genderFemale => _isVi ? 'Nữ' : 'Female';
  String get genderNotShare => _isVi ? 'Không chia sẻ' : 'Prefer not to say';
  String get ageRestrictionNote =>
      _isVi
          ? 'Người dùng phải đủ 14 tuổi để sử dụng VNALO'
          : 'Users must be at least 14 years old to use VNALO';
  String get ageRestrictionWarning =>
      _isVi
          ? 'Bạn chưa đủ 14 tuổi để sử dụng VNALO. Vui lòng kiểm tra lại ngày sinh.'
          : 'You must be at least 14 years old to use VNALO. Please check your birthday.';
  String get laterText => _isVi ? 'Để sau' : 'Later';

  // ─── Register wizard: Avatar step ───

  String get avatarTitle =>
      _isVi ? 'Cập nhật ảnh đại diện' : 'Update profile photo';
  String get avatarSubtitle =>
      _isVi
          ? 'Đặt ảnh đại diện để mọi người dễ nhận ra bạn'
          : 'Set a profile photo so people can recognize you';
  String get avatarDevNotice => _isVi
      ? 'Giai đoạn hiện tại chỉ xem trước ảnh, tính năng đồng bộ ảnh sẽ bật ở bản cập nhật tiếp theo.'
      : 'This phase supports local preview only; avatar sync will be enabled in a later update.';
  String get update => _isVi ? 'Cập nhật' : 'Update';
  String get skip => _isVi ? 'Bỏ qua' : 'Skip';
  String get takePhoto => _isVi ? 'Chụp ảnh mới' : 'Take a photo';
  String get chooseFromGallery =>
      _isVi ? 'Chọn ảnh trên máy' : 'Choose from gallery';
  String get changePhoto =>
      _isVi ? 'Chọn ảnh khác' : 'Change photo';
  String get skipAvatarTitle =>
      _isVi ? 'Bỏ qua ảnh đại diện?' : 'Skip profile photo?';
  String get skipAvatarMessage => _isVi
      ? 'Bỏ qua cập nhật ảnh đại diện sẽ làm hạn chế một số chức năng trong ứng dụng.'
      : 'Skipping profile photo might limit some features in the app.';
  String get cancel => _isVi ? 'Hủy' : 'Cancel';
  String get accept => _isVi ? 'Chấp nhận' : 'Accept';

  // ─── Contacts Sync Prompt ───
  String get syncContactsTitle =>
      _isVi ? 'Đồng bộ danh bạ' : 'Sync Contacts';
  String get syncContactsMessage => _isVi
      ? 'Cho phép VNALO truy cập danh bạ để tìm danh sách user VNALO từ máy của bạn.'
      : 'Allow VNALO to access contacts to find VNALO users from your device.';

  // ─── Welcome carousel ───
  // Data-driven: easily add/remove/reorder slides by editing these lists.
  // Image paths correspond to assets/images/welcome/ folder.

  static const List<String> carouselImages = [
    'assets/images/welcome/welcome_1.png',
    'assets/images/welcome/welcome_2.png',
    'assets/images/welcome/welcome_3.png',
  ];

  List<String> get welcomeTitles {
    if (_isVi) {
      return const [
        'Gọi video ổn định',
        'Nhắn tin nhanh chóng',
        'Bảo mật và đồng bộ',
      ];
    }
    return const ['Stable video calls', 'Fast messaging', 'Secure and synced'];
  }

  List<String> get welcomeSubtitles {
    if (_isVi) {
      return const [
        'Trò chuyện thật đã với chất lượng video ổn định mọi lúc, mọi nơi',
        'Giữ kết nối với bạn bè và công việc theo thời gian thực',
        'Dữ liệu an toàn trên mọi thiết bị bạn đăng nhập',
      ];
    }
    return const [
      'Enjoy stable video quality anytime, anywhere',
      'Stay connected with friends and work in real-time',
      'Your data stays secure across all signed-in devices',
    ];
  }
}
