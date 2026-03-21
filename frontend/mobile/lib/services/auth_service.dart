import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  // Send OTP to the given phone number
  Future<void> sendOtp(String phone) async {
    await _apiService.post(_base, '/auth/register/send-otp', body: {'phone': phone});
  }

  // Register a new user with phone, OTP, password and display name
  Future<Map<String, dynamic>> register({
    required String phone,
    required String otp,
    required String password,
    required String displayName,
  }) async {
    return await _apiService.post(
      _base,
      '/auth/register',
      body: {
        'phone': phone,
        'otp': otp,
        'password': password,
        'displayName': displayName,
      },
    );
  }

  // Login with phone and password
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    return await _apiService.post(
      _base,
      '/auth/login',
      body: {'identifier': phone, 'password': password},
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
