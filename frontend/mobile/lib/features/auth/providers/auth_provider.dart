import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_events.dart';
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
  /// Non-fatal result message — set when registration succeeds but a
  /// secondary action (e.g. avatar upload) fails. Does not affect [isLoggedIn].
  String? _warning;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  /// Non-fatal warning surfaced after a successful registration.
  String? get warning => _warning;

  AuthProvider(this._authService, this._storageService, this._socketService) {
    AuthEvents.onSessionInvalidated = logout;
  }

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
        await _storageService.saveUserId(_user!.id);
      }

      _socketService.connect(tokens.accessToken);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _isLoading = false;
      _error = _friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendOtp(phone);
    } catch (e) {
      _error = _friendlyAuthError(e);
      throw StateError(_error ?? 'Gửi OTP thất bại');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> fetchOtpRequiredStatus() async {
    try {
      final status = await _authService.getOtpStatus();
      if (status.containsKey('registerPhoneOtpEnabled')) {
        return status['registerPhoneOtpEnabled'] == true;
      }
      return status['enabled'] == true;
    } catch (_) {
      // Fallback is handled by caller.
      rethrow;
    }
  }

  Future<bool> register({
    required String phone,
    required String email,
    required String password,
    required String displayName,
    File? avatarFile,
    String? gender,
    String? dob,
  }) async {
    _isLoading = true;
    _error = null;
    _warning = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        phone: phone,
        email: email,
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

      final hydrated = await _hydrateUserAfterRegister(
        data,
        displayName: displayName,
      );
      _user = hydrated.user;
      await _storageService.saveUserId(_user!.id);
      if (hydrated.warning != null) {
        _warning = hydrated.warning;
      }

      if (avatarFile != null) {
        try {
          final avatarUrl = await _uploadAvatarWithRetry(avatarFile);
          await _authService.updateProfileAvatar(avatarUrl);
          // Refresh profile to pick up the persisted avatar URL.
          try {
            _user = await _authService.getMe();
          } catch (_) {
            // Upload+patch succeeded — apply optimistic local update.
            if (_user != null) {
              _user = _user!.copyWith(avatarUrl: avatarUrl);
            }
          }
          // No need to re-save userId — it cannot change after registration.
        } catch (e) {
          // Avatar upload is non-fatal: registration already succeeded.
          final av = _avatarUploadWarning(e);
          _warning = _warning != null && _warning!.isNotEmpty
              ? '$_warning — $av'
              : av;
        }
      } else {
        // No avatar file — do a final consistency refresh.
        try {
          _user = await _getMeWithRetry(attempts: 2);
        } catch (_) {
          // Non-fatal: keep best-effort hydrated profile.
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'AUTH_001':
          return 'Sai số điện thoại hoặc mật khẩu';
        case 'AUTH_002':
          return 'Tài khoản đã bị vô hiệu hóa';
        case 'AUTH_003':
          return 'Tài khoản tạm thời bị khóa';
        case 'AUTH_008':
          return 'Số điện thoại đã được đăng ký';
        case 'AUTH_009':
          return 'Mã OTP đã hết hạn';
        case 'AUTH_010':
          return 'Mã OTP không đúng';
        case 'AUTH_011':
          return 'Bạn đã nhập sai OTP quá số lần cho phép';
        case 'AUTH_012':
        case 'AUTH_013':
          return 'Bạn thao tác quá nhanh, vui lòng thử lại sau';
        case 'ERR_400':
          return 'Dữ liệu không hợp lệ, vui lòng kiểm tra lại';
      }

      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    if (error is UnauthorizedException) {
      return 'Phiên đăng nhập không hợp lệ';
    }

    return error.toString();
  }

  /// Builds [User] after `/auth/register` — tolerant to flaky LAN right after signup.
  Future<({User user, String? warning})> _hydrateUserAfterRegister(
    Map<String, dynamic> data, {
    required String displayName,
  }) async {
    final raw = data['user'];
    Map<String, dynamic>? rawMap;
    if (raw is Map<String, dynamic>) {
      rawMap = raw;
    }

    if (rawMap != null) {
      try {
        return (user: User.fromJson(rawMap), warning: null);
      } catch (_) {
        // Fall through — e.g. unexpected field shapes on some gateways.
      }
    }

    try {
      final me = await _getMeWithRetry();
      return (user: me, warning: null);
    } catch (e) {
      final fallback = _userFromRegisterPayload(rawMap, displayName: displayName);
      if (fallback != null) {
        return (
          user: fallback,
          warning: _profileHydrationFallbackWarning(e),
        );
      }
      rethrow;
    }
  }

  Future<User> _getMeWithRetry({int attempts = 4}) async {
    Object? last;
    for (var i = 0; i < attempts; i++) {
      try {
        return await _authService.getMe();
      } catch (e) {
        last = e;
        if (i < attempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 350 * (i + 1)));
        }
      }
    }
    throw last!;
  }

  User? _userFromRegisterPayload(
    Map<String, dynamic>? raw, {
    required String displayName,
  }) {
    if (raw == null) return null;
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return User(
      id: id,
      phone: raw['phone']?.toString(),
      email: raw['email']?.toString(),
      displayName:
          raw['displayName']?.toString() ??
          raw['display_name']?.toString() ??
          displayName,
      avatarUrl: raw['avatarUrl']?.toString() ?? raw['avatar_url']?.toString(),
    );
  }

  String _profileHydrationFallbackWarning(Object error) {
    if (error is ApiException && error.statusCode == 0) {
      final m = error.message.toLowerCase();
      if (m.contains('timed out')) {
        return 'Đăng ký thành công nhưng tải hồ sơ bị chậm. Mở lại ứng dụng hoặc vào Hồ sơ để đồng bộ.';
      }
      if (m.contains('no internet')) {
        return 'Đăng ký thành công nhưng chưa tải được hồ sơ đầy đủ do mạng. Vào Hồ sơ sau khi có mạng.';
      }
    }
    return 'Đăng ký thành công; hồ sơ sẽ đồng bộ đầy đủ khi mạng ổn định. Bạn có thể mở Hồ sơ.';
  }

  Future<String> _uploadAvatarWithRetry(File avatarFile, {int attempts = 3}) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await _authService.uploadAvatar(avatarFile);
      } catch (e) {
        lastError = e;
        final shouldRetry = _isTransientAvatarFailure(e);
        if (!shouldRetry || i == attempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 700 * (i + 1)));
      }
    }
    throw lastError ?? StateError('Avatar upload failed');
  }

  bool _isTransientAvatarFailure(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 0) return true;
      if (error.statusCode >= 500) return true;
      if (error.statusCode == 429) return true;
    }
    return false;
  }
  String _avatarUploadWarning(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 0) {
        final raw = error.message.toLowerCase();
        if (raw.contains('timed out')) {
          return 'Đăng ký thành công nhưng tải ảnh đại diện bị timeout. Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
        }
        if (raw.contains('no internet')) {
          return 'Đăng ký thành công nhưng chưa có mạng để tải ảnh đại diện. Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
        }
        return 'Đăng ký thành công nhưng chưa tải được ảnh đại diện do lỗi mạng. Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
      }
      return 'Đăng ký thành công nhưng cập nhật ảnh đại diện thất bại (${error.statusCode}). Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
    }

    if (error is StateError) {
      return 'Đăng ký thành công nhưng phản hồi tải ảnh chưa hợp lệ. Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
    }

    return 'Đăng ký thành công nhưng cập nhật ảnh đại diện thất bại. Bạn có thể cập nhật lại ảnh trong Hồ sơ.';
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

  Future<void> refreshCurrentUser() async {
    try {
      final me = await _authService.getMe();
      _user = me;
      notifyListeners();
    } catch (_) {
      // Keep current user if refresh fails transiently.
    }
  }

  Future<bool> updateAvatar(File avatarFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final avatarUrl = await _uploadAvatarWithRetry(avatarFile);
      await _authService.updateProfileAvatar(avatarUrl);

      try {
        _user = await _authService.getMe();
      } catch (_) {
        // Avatar is already persisted on server; fallback to local optimistic update.
        if (_user != null) {
          _user = _user!.copyWith(avatarUrl: avatarUrl);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _avatarUploadWarning(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

class _TokenPair {
  final String accessToken;
  final String refreshToken;

  const _TokenPair({required this.accessToken, required this.refreshToken});
}
