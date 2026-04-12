import 'package:flutter/foundation.dart';
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

  // Send registration OTP to the given email (phone used for duplicate check).
  Future<void> sendRegisterOtp({
    required String phone,
    required String email,
  }) async {
    final normalized = _normalizePhone(phone);
    await _apiService.post(
      _base,
      '/auth/register/send-otp',
      body: {
        'phone': normalized,
        'email': email.trim().toLowerCase(),
      },
    );
  }

  // Backward-compatible wrapper kept for existing unit tests and older callers.
  Future<void> sendOtp(String phone, {String email = 'placeholder@vnalo.local'}) {
    return sendRegisterOtp(phone: phone, email: email);
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
    required String otp,
    required String password,
    required String displayName,
    String? gender,
    String? dob, // ISO 8601 string
  }) async {
    final normalized = _normalizePhone(phone);
    final body = <String, dynamic>{
      'phone': normalized,
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
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
        'platform': 'ANDROID',
        'deviceName': 'VNALO Mobile',
      },
    );
  }

  Future<Map<String, dynamic>> getQrLoginSessionPreview(String token) async {
    final response = await _apiService.get(_base, '/auth/qr/sessions/$token/preview');
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return response;
  }

  Future<void> approveQrLoginSession({
    required String token,
    String? deviceId,
    String? deviceName,
    String? platform,
    String? location,
  }) async {
    await _apiService.post(
      _base,
      '/auth/qr/sessions/$token/approve',
      body: {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform ?? 'ANDROID',
        'location': location,
        'confirmReplaceActiveUntrusted': true,
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

  /// Extracts the mediaId from a media-service upload response.
  static String? _parseMediaId(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final id = data['mediaId'] ?? data['media_id'];
    if (id != null) return id.toString();
    return null;
  }

  // Backward-compatible helper used by unit tests and older upload callers.
  static String? parseUploadedMediaUrl(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final url = data['url'] ?? data['fileUrl'] ?? data['mediaUrl'];
    if (url is String && url.isNotEmpty) {
      return url;
    }
    return null;
  }

  Future<String> uploadAvatar(File avatarFile) async {
    final response = await _apiService.postMultipart(
      _mediaBase,
      '/media/upload',
      file: avatarFile,
      fields: const {'category': 'AVATAR'},
    );

    debugPrint('[AVATAR] Upload response data: ${response['data']}');

    // Use the media-service save endpoint URL (existing, deployed, auth-protected).
    // AvatarWidget passes auth headers so this works without needing public endpoint.
    final mediaId = _parseMediaId(response);
    if (mediaId != null) {
      final avatarUrl = '$_mediaBase/media/$mediaId/save';
      debugPrint('[AVATAR] Constructed save URL: $avatarUrl');
      return avatarUrl;
    }

    // Fallback: try raw URL from response
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final url = data['url'] ?? data['fileUrl'] ?? data['mediaUrl'];
      debugPrint('[AVATAR] Fallback URL: $url');
      if (url is String && url.isNotEmpty) return url;
    }

    throw StateError('Invalid media upload response or missing mediaId/URL');
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

  Future<String> uploadCover(File coverFile) async {
    final response = await _apiService.postMultipart(
      _mediaBase,
      '/media/upload',
      file: coverFile,
      fields: const {'category': 'COVER'},
    );

    debugPrint('[COVER] Upload response data: ${response['data']}');

    final mediaId = _parseMediaId(response);
    if (mediaId != null) {
      final coverUrl = '$_mediaBase/media/$mediaId/save';
      debugPrint('[COVER] Constructed save URL: $coverUrl');
      return coverUrl;
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final url = data['url'] ?? data['fileUrl'] ?? data['mediaUrl'];
      if (url is String && url.isNotEmpty) return url;
    }

    throw StateError('Invalid media upload response or missing mediaId/URL');
  }

  Future<void> updateProfileCover(String coverUrl) async {
    await _apiService.patch(
      _base,
      '/users/me',
      body: {'coverUrl': coverUrl},
    );
  }
}
