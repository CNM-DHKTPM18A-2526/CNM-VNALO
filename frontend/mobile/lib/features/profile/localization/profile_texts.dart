import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';

class ProfileTexts {
  final AppLanguage language;

  const ProfileTexts(this.language);

  static ProfileTexts of(BuildContext context, {bool listen = true}) {
    final language = Provider.of<LanguageProvider>(context, listen: listen).language;
    return ProfileTexts(language);
  }

  bool get _isVi => language == AppLanguage.vi;

  // Personal Info Screen
  String get personalInfo => _isVi ? 'Thông tin cá nhân' : 'Personal information';
  String get gender => _isVi ? 'Giới tính' : 'Gender';
  String get birthday => _isVi ? 'Ngày sinh' : 'Date of birth';
  String get phone => _isVi ? 'Điện thoại' : 'Phone number';
  String get phoneVisibilityNote => _isVi 
      ? 'Số điện thoại chỉ hiển thị với người có lưu số bạn trong danh bạ máy'
      : 'Phone number is only visible to those who have you in their contacts';
  String get editInfo => _isVi ? 'Chỉnh sửa' : 'Edit';
  String get editInfoTitle => _isVi ? 'Chỉnh sửa thông tin' : 'Edit information';
  String get selectBirthday => _isVi ? 'Chọn ngày sinh' : 'Select birthday';
  String get saveAction => _isVi ? 'LƯU' : 'SAVE';
  String get updateSuccess => _isVi ? 'Cập nhật thành công!' : 'Update successful!';
  String get updateFailed => _isVi ? 'Cập nhật thất bại' : 'Update failed';

  // Gender Literals
  String get male => _isVi ? 'Nam' : 'Male';
  String get female => _isVi ? 'Nữ' : 'Female';
  String get otherGender => _isVi ? 'Khác' : 'Other';
  String get notUpdated => _isVi ? 'Chưa cập nhật' : 'Not updated';

  // Profile Menu
  String get vnCloud => 'vnCloud';
  String get vnCloudSubtitle => _isVi ? 'Không gian lưu trữ dữ liệu' : 'Cloud storage space';
  String get vnStyle => 'vnStyle';
  String get vnStyleSubtitle => _isVi ? 'Hình nền và nhạc chờ' : 'Wallpapers and ringtones';
  String get myDocuments => _isVi ? 'My Documents' : 'My Documents';
  String get myDocumentsSubtitle => _isVi ? 'Lưu trữ tin nhắn quan trọng' : 'Store important messages';
  String get deviceData => _isVi ? 'Dữ liệu trên máy' : 'Data on device';
  String get deviceDataSubtitle => _isVi ? 'Quản lý dữ liệu ứng dụng' : 'Manage app data';
  String get qrWallet => _isVi ? 'Ví QR' : 'QR Wallet';
  String get qrWalletSubtitle => _isVi ? 'Lưu trữ mã QR quan trọng' : 'Store important QR codes';
  String get vnaloPayTitle => 'Vnalo Pay';
  String get vnaloPaySubtitle => _isVi ? 'Thanh toán trực tuyến' : 'Online payments';
  String get accountAndSecurity => _isVi ? 'Tài khoản và bảo mật' : 'Account and security';
  String get privacy => _isVi ? 'Quyền riêng tư' : 'Privacy';

  // Profile more settings
  String get profileInfo => _isVi ? 'Thông tin cá nhân' : 'Information';
  String get changeProfilePhoto => _isVi ? 'Đổi ảnh đại diện' : 'Change profile photo';
  String get changeCoverPhoto => _isVi ? 'Đổi ảnh bìa' : 'Change cover photo';
  String get updateBio => _isVi ? 'Cập nhật tiểu sử' : 'Update bio';
  String get myWallet => _isVi ? 'Ví của tôi' : 'My wallet';
  String get myQrCode => _isVi ? 'Mã QR của tôi' : 'My QR code';
  String get accountManagement => _isVi ? 'Quản lý tài khoản' : 'Account management';
  String get generalSettings => _isVi ? 'Cài đặt chung' : 'General settings';
  String get comingSoon => _isVi ? 'Tính năng đang được phát triển' : 'Feature under development';
  String get backupRestore => _isVi ? 'Sao lưu và khôi phục' : 'Backup & Restore';
  String get messages => _isVi ? 'Tin nhắn' : 'Messages';
  String get contacts => _isVi ? 'Danh bạ' : 'Contacts';

  // Settings
  String get settings => _isVi ? 'Cài đặt' : 'Settings';
  String get appearance => _isVi ? 'Giao diện và ngôn ngữ' : 'Appearance';
  String get notifications => _isVi ? 'Thông báo' : 'Notifications';
  String get logout => _isVi ? 'Đăng xuất' : 'Log out';
  String get logoutConfirm => _isVi ? 'Bạn có chắc chắn muốn đăng xuất?' : 'Are you sure you want to log out?';
}
