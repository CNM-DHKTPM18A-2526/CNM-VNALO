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

  String get login => _isVi ? '─É─âng nhß║¡p' : 'Log in';
  String get createAccount =>
      _isVi ? 'Tß║ío t├ái khoß║ún mß╗¢i' : 'Create new account';
  String get createAccountShort => _isVi ? 'Tß║ío t├ái khoß║ún' : 'Create account';
  String get continueText => _isVi ? 'Tiß║┐p tß╗Ñc' : 'Continue';
  String get enterPhoneTitle =>
      _isVi ? 'Nhß║¡p sß╗æ ─æiß╗çn thoß║íi' : 'Enter phone number';
  String get enterOtpTitle => _isVi ? 'Nhß║¡p m├ú OTP' : 'Enter OTP code';
  String get enterPasswordTitle => _isVi ? 'Nhß║¡p mß║¡t khß║⌐u' : 'Enter password';
  String get completeRegister =>
      _isVi ? 'Ho├án tß║Ñt ─æ─âng k├╜' : 'Complete registration';
  String get phoneHint => _isVi ? 'Sß╗æ ─æiß╗çn thoß║íi' : 'Phone number';
  String get displayNameHint => _isVi ? 'T├¬n hiß╗ân thß╗ï' : 'Display name';
  String get passwordHint => _isVi ? 'Mß║¡t khß║⌐u' : 'Password';
  String get confirmPasswordHint =>
      _isVi ? 'X├íc nhß║¡n mß║¡t khß║⌐u' : 'Confirm password';
  String get otpSent =>
      _isVi ? 'Nhß║¡p m├ú OTP ─æ├ú gß╗¡i ─æß║┐n' : 'Enter the OTP sent to';
  String otpSentTo(String phone) =>
      _isVi ? 'Nhß║¡p m├ú OTP ─æ├ú gß╗¡i ─æß║┐n $phone' : 'Enter the OTP sent to $phone';
  String get confirmOtp => _isVi ? 'X├íc nhß║¡n' : 'Confirm';
  String get resendOtp => _isVi ? 'Gß╗¡i lß║íi m├ú OTP' : 'Resend OTP';
  String get otpResent => _isVi ? '─É├ú gß╗¡i lß║íi OTP' : 'OTP resent';
  String get otpInvalid => _isVi ? 'M├ú OTP phß║úi gß╗ôm 6 chß╗» sß╗æ' : 'OTP must be 6 digits';

  String get alreadyHasAccount =>
      _isVi ? 'Bß║ín ─æ├ú c├│ t├ái khoß║ún? ' : 'Already have an account? ';
  String get noAccount =>
      _isVi ? 'Bß║ín ch╞░a c├│ t├ái khoß║ún? ' : 'No account yet? ';
  String get loginNow => _isVi ? '─É─âng nhß║¡p ngay' : 'Log in now';

  String get agreeTermA =>
      _isVi
          ? 'T├┤i ─æß╗ông ├╜ vß╗¢i c├íc ─æiß╗üu khoß║ún sß╗¡ dß╗Ñng VNALO'
          : 'I agree to VNALO Terms of Use';
  String get agreeTermB =>
      _isVi
          ? 'T├┤i ─æß╗ông ├╜ vß╗¢i ─æiß╗üu khoß║ún Mß║íng x├ú hß╗Öi cß╗ºa VNALO'
          : 'I agree to VNALO Social Network Terms';

  String get loginFailed => _isVi ? '─É─âng nhß║¡p thß║Ñt bß║íi' : 'Login failed';
  String get registerFailed => _isVi ? '─É─âng k├╜ thß║Ñt bß║íi' : 'Register failed';
  String otpFailed(Object error) =>
      _isVi ? 'Gß╗¡i OTP thß║Ñt bß║íi: $error' : 'Failed to send OTP: $error';
  String accountLabel(String phone) =>
      _isVi ? 'T├ái khoß║ún: $phone' : 'Account: $phone';

  String get languageTitle => _isVi ? 'Chß╗ìn ng├┤n ngß╗»' : 'Choose language';
  String get vietnamese => 'Tiß║┐ng Viß╗çt';
  String get english => 'English';

  // ΓöÇΓöÇΓöÇ Register wizard: Name step ΓöÇΓöÇΓöÇ

  String get enterNameTitle =>
      _isVi ? 'Nhß║¡p t├¬n VNALO' : 'Enter your VNALO name';
  String get enterNameSubtitle =>
      _isVi
          ? 'H├úy d├╣ng t├¬n thß║¡t ─æß╗â mß╗ìi ng╞░ß╗¥i dß╗à nhß║¡n ra bß║ín'
          : 'Use your real name so people can recognize you';
  String get nameHelpLength =>
      _isVi ? 'D├ái tß╗½ 2 ─æß║┐n 40 k├╜ tß╗▒' : '2 to 40 characters';
  String get nameHelpNoNumbers =>
      _isVi ? 'Kh├┤ng chß╗⌐a sß╗æ' : 'Must not contain numbers';
  String get nameHelpRules =>
      _isVi
          ? 'Cß║ºn tu├ón thß╗º quy ─æß╗ïnh ─æß║╖t t├¬n VNALO'
          : 'Must follow VNALO naming rules';

  // ΓöÇΓöÇΓöÇ Register wizard: Personal Info step ΓöÇΓöÇΓöÇ

  String get personalInfoTitle =>
      _isVi ? 'Th├¬m th├┤ng tin c├í nh├ón' : 'Add personal info';
  String get birthdayHint => _isVi ? 'Sinh nhß║¡t' : 'Birthday';
  String get genderHint => _isVi ? 'Giß╗¢i t├¡nh' : 'Gender';
  String get genderMale => _isVi ? 'Nam' : 'Male';
  String get genderFemale => _isVi ? 'Nß╗»' : 'Female';
  String get genderNotShare => _isVi ? 'Kh├┤ng chia sß║╗' : 'Prefer not to say';
  String get ageRestrictionNote =>
      _isVi
          ? 'Ng╞░ß╗¥i d├╣ng phß║úi ─æß╗º 14 tuß╗òi ─æß╗â sß╗¡ dß╗Ñng VNALO'
          : 'Users must be at least 14 years old to use VNALO';
  String get ageRestrictionWarning =>
      _isVi
          ? 'Bß║ín ch╞░a ─æß╗º 14 tuß╗òi ─æß╗â sß╗¡ dß╗Ñng VNALO. Vui l├▓ng kiß╗âm tra lß║íi ng├áy sinh.'
          : 'You must be at least 14 years old to use VNALO. Please check your birthday.';
  String get laterText => _isVi ? '─Éß╗â sau' : 'Later';

  // ΓöÇΓöÇΓöÇ Register wizard: Avatar step ΓöÇΓöÇΓöÇ

  String get avatarTitle =>
      _isVi ? 'Cß║¡p nhß║¡t ß║únh ─æß║íi diß╗çn' : 'Update profile photo';
  String get avatarSubtitle =>
      _isVi
          ? '─Éß║╖t ß║únh ─æß║íi diß╗çn ─æß╗â mß╗ìi ng╞░ß╗¥i dß╗à nhß║¡n ra bß║ín'
          : 'Set a profile photo so people can recognize you';
  String get avatarDevNotice => _isVi
      ? 'Giai ─æoß║ín hiß╗çn tß║íi chß╗ë xem tr╞░ß╗¢c ß║únh, t├¡nh n─âng ─æß╗ông bß╗Ö ß║únh sß║╜ bß║¡t ß╗ƒ bß║ún cß║¡p nhß║¡t tiß║┐p theo.'
      : 'This phase supports local preview only; avatar sync will be enabled in a later update.';
  String get update => _isVi ? 'Cß║¡p nhß║¡t' : 'Update';
  String get skip => _isVi ? 'Bß╗Å qua' : 'Skip';
  String get takePhoto => _isVi ? 'Chß╗Ñp ß║únh mß╗¢i' : 'Take a photo';
  String get chooseFromGallery =>
      _isVi ? 'Chß╗ìn ß║únh tr├¬n m├íy' : 'Choose from gallery';
  String get skipAvatarTitle =>
      _isVi ? 'Bß╗Å qua ß║únh ─æß║íi diß╗çn?' : 'Skip profile photo?';
  String get skipAvatarMessage => _isVi
      ? 'Bß╗Å qua cß║¡p nhß║¡t ß║únh ─æß║íi diß╗çn sß║╜ l├ám hß║ín chß║┐ mß╗Öt sß╗æ chß╗⌐c n─âng trong ß╗⌐ng dß╗Ñng.'
      : 'Skipping profile photo might limit some features in the app.';
  String get cancel => _isVi ? 'Hß╗ºy' : 'Cancel';
  String get accept => _isVi ? 'Chß║Ñp nhß║¡n' : 'Accept';

  // ΓöÇΓöÇΓöÇ Contacts Sync Prompt ΓöÇΓöÇΓöÇ
  String get syncContactsTitle =>
      _isVi ? '─Éß╗ông bß╗Ö danh bß║í' : 'Sync Contacts';
  String get syncContactsMessage => _isVi
      ? 'Cho ph├⌐p VNALO truy cß║¡p danh bß║í ─æß╗â t├¼m danh s├ích user VNALO tß╗½ m├íy cß╗ºa bß║ín.'
      : 'Allow VNALO to access contacts to find VNALO users from your device.';

  // ΓöÇΓöÇΓöÇ Welcome carousel ΓöÇΓöÇΓöÇ
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
        'Gß╗ìi video ß╗òn ─æß╗ïnh',
        'Nhß║»n tin nhanh ch├│ng',
        'Bß║úo mß║¡t v├á ─æß╗ông bß╗Ö',
      ];
    }
    return const ['Stable video calls', 'Fast messaging', 'Secure and synced'];
  }

  List<String> get welcomeSubtitles {
    if (_isVi) {
      return const [
        'Tr├▓ chuyß╗çn thß║¡t ─æ├ú vß╗¢i chß║Ñt l╞░ß╗úng video ß╗òn ─æß╗ïnh mß╗ìi l├║c, mß╗ìi n╞íi',
        'Giß╗» kß║┐t nß╗æi vß╗¢i bß║ín b├¿ v├á c├┤ng viß╗çc theo thß╗¥i gian thß╗▒c',
        'Dß╗» liß╗çu an to├án tr├¬n mß╗ìi thiß║┐t bß╗ï bß║ín ─æ─âng nhß║¡p',
      ];
    }
    return const [
      'Enjoy stable video quality anytime, anywhere',
      'Stay connected with friends and work in real-time',
      'Your data stays secure across all signed-in devices',
    ];
  }
}
