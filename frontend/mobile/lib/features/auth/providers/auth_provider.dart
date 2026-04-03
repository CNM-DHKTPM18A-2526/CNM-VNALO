import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/services/socket_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final StorageService _storageService;
  final SocketService _socketService;

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  AuthProvider(this._authService, this._storageService, this._socketService);

  // Initialize the provider by checking if there's a valid token and fetching user info
  Future<void> initialize() async {
    final token = await _storageService.getAccessToken();
    if (token != null) {
      try {
        _user = await _authService.getMe();
        _socketService.connect(token);
      } catch (_) {
        await _storageService.clearAll();
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  // Login with phone and password
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Attempt to login and handle success or error cases
    try {
      final response = await _authService.login(
        phone: phone,
        password: password,
      );
      final data = (response['data'] ?? response) as Map<String, dynamic>;
      final tokens = _extractTokens(data);

      // Save tokens and user info, connect to socket, and update state
      await _storageService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      if (data['user'] != null) {
        await _storageService.saveUserId(data['user']['id']);
        _user = User.fromJson(data['user']);
      } else {
        _user = await _authService.getMe();
      }

      _socketService.connect(tokens.accessToken);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool _requiresOtp = true;
  bool get requiresOtp => _requiresOtp;

  Future<void> checkOtpStatus() async {
    try {
      final statusMap = await _authService.getOtpStatus();
      _requiresOtp = statusMap['enabled'] == true;
      notifyListeners();
    } catch (_) {
      _requiresOtp = true; // Default fallback to safe side
      notifyListeners();
    }
  }

  Future<void> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendOtp(phone);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String phone,
    required String otp,
    required String password,
    required String displayName,
    String? gender,
    String? dob,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        phone: phone,
        otp: otp,
        password: password,
        displayName: displayName,
        gender: gender,
        dob: dob,
      );

      final data = (response['data'] ?? response) as Map<String, dynamic>;
      final hasTokens =
          data.containsKey('accessToken') && data.containsKey('refreshToken');

      if (!hasTokens) {
        throw StateError('Token data is missing from registration response');
      }

      final tokens = _extractTokens(data);
      await _storageService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _socketService.connect(tokens.accessToken);

      if (data['user'] != null) {
        await _storageService.saveUserId(data['user']['id']);
        _user = User.fromJson(data['user']);
      } else {
        _user = await _authService.getMe();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  _TokenPair _extractTokens(Map<String, dynamic> data) {
    final access = data['accessToken'] ?? data['access_token'];
    final refresh = data['refreshToken'] ?? data['refresh_token'];

    if (access is! String || refresh is! String) {
      throw StateError('Token data is missing from auth response');
    }

    return _TokenPair(accessToken: access, refreshToken: refresh);
  }

  // Logout the user by clearing tokens, disconnecting socket, and resetting state
  Future<void> logout() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        await _authService.logout(refreshToken);
      }
    } catch (_) {
      // Ignore network errors during logout; local cleanup still applies.
    }

    _socketService.disconnect();
    await _storageService.clearAll();
    _user = null;
    notifyListeners();
  }
}

class _TokenPair {
  final String accessToken;
  final String refreshToken;

  const _TokenPair({required this.accessToken, required this.refreshToken});
}
