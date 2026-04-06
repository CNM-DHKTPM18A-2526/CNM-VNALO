import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'dart:io';

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;
  String get _mediaBase => AppConfig.instance.mediaServiceUrl;

  String _normalizePhone(String phone) {
    // Already fully-qualified — skip re-normalisation to avoid double-prefixing
    // (e.g. when _buildFullPhone in the screen already prepended the country code).
    if (phone.startsWith('+')) return phone.trim();

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length >= 10) {
      return '+84${digits.substring(1)}';
    }
    if (digits.startsWith('84')) {
      return '+$digits';
    }
    if (digits.startsWith('9') && digits.length == 9) {
      return '+84$digits';
    }
    return phone.trim();
  }

  // Send OTP to the given phone number
  Future<void> sendOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    await _apiService.post(
      _base,
      '/auth/register/send-otp',
      body: {'phone': normalized},
    );
  }

  // Check OTP configuration status from backend.
  // Supports both wrapped ({ "data": { "enabled": true } }) and flat ({ "enabled": true }) responses.
  Future<Map<String, dynamic>> getOtpStatus() async {
    final response = await _apiService.get(_base, '/auth/otp/status');
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    // Flat response — treat the whole body as the data payload.
    return response;
  }

  // Register a new user with phone, OTP, password, display name, gender, and dob
  Future<Map<String, dynamic>> register({
    required String phone,
    required String email,
    required String password,
    required String displayName,
    String? gender,
    String? dob, // ISO 8601 string
  }) async {
    final normalized = _normalizePhone(phone);
    final body = <String, dynamic>{
      'phone': normalized,
      'email': email.trim().toLowerCase(),
      'password': password,
      'displayName': displayName,
      'display_name': displayName,
    };
    if (gender != null) {
      body['gender'] = gender.toUpperCase();
    }
    if (dob != null) {
      body['dob'] = dob;
    }
    return await _apiService.post(
      _base,
      '/auth/register',
      body: body,
    );
  }

  // Login with phone and password
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final normalized = _normalizePhone(phone);
    return await _apiService.post(
      _base,
      '/auth/login',
      body: {
        'identifier': normalized,
        'password': password,
      },
    );
  }

  // Refresh access token using refresh token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return await _apiService.post(
      _base,
      '/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
  }

  // Logout
  Future<void> logout(String refreshToken) async {
    await _apiService.post(
      _base,
      '/auth/logout',
      body: {'refreshToken': refreshToken},
    );
  }

  Future<User> getMe() async {
    final response = await _apiService.get(_base, '/users/me');
    return User.fromJson(response['data']);
  }

  /// Extracts a public media URL from core-style `{ data: { ... } }` upload responses.
  static String? parseUploadedMediaUrl(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final url = data['url'] ??
        data['fileUrl'] ??
        data['mediaUrl'] ??
        data['downloadUrl'];
    if (url is String && url.isNotEmpty) return url;
    return null;
  }

  Future<String> uploadAvatar(File avatarFile) async {
    final response = await _apiService.postMultipart(
      _mediaBase,
      '/media/upload',
      file: avatarFile,
      fields: const {'category': 'AVATAR'},
    );

    final url = parseUploadedMediaUrl(response);
    if (url == null) {
      throw StateError('Invalid media upload response or missing URL');
    }
    return url;
  }

  Future<void> updateProfileAvatar(String avatarUrl) async {
    await _apiService.patch(
      _base,
      '/users/me',
      body: {'avatarUrl': avatarUrl},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiService.post(
      _base,
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> requestPasswordReset({
    required String email,
  }) async {
    await _apiService.post(
      _base,
      '/auth/forgot-password',
      body: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _apiService.post(
      _base,
      '/auth/reset-password',
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }
}
