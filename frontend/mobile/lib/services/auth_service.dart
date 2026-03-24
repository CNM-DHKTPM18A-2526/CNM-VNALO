import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  String _normalizePhone(String phone) {
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

  // Register a new user with phone, OTP, password and display name
  Future<Map<String, dynamic>> register({
    required String phone,
    required String otp,
    required String password,
    required String displayName,
  }) async {
    final normalized = _normalizePhone(phone);
    return await _apiService.post(
      _base,
      '/auth/register',
      body: {
        'phone': normalized,
        'otp': otp,
        'password': password,
        'displayName': displayName,
        'display_name': displayName,
      },
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
        'phone': normalized,
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
}
