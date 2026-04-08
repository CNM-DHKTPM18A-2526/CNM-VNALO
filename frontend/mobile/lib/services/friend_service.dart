import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class FriendService {
  final ApiService _apiService;
  FriendService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  Future<List<User>> getFriends() async {
    final response = await _apiService.get(_base, '/friends');
    final list = response['data'] as List;
    return list.map((e) => User.fromJson(e)).toList();
  }

  Future<void> sendFriendRequest(String userId, {String? message}) async {
    await _apiService.post(
      _base,
      '/friends/requests',
      body: {'toUserId': userId, if (message != null) 'message': message},
    );
  }

  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final response = await _apiService.get(_base, '/friends/requests/incoming');
    return List<Map<String, dynamic>>.from(response['data']);
  }

  Future<List<Map<String, dynamic>>> getIncommingRequests() {
    return getIncomingRequests();
  }

  Future<void> acceptRequest(String requestId) async {
    await _apiService.post(_base, '/friends/requests/$requestId/accept');
  }

  Future<void> rejectRequest(String requestId) async {
    await _apiService.post(_base, '/friends/requests/$requestId/decline');
  }

  Future<List<User>> searchUsers(String keyword) async {
    final response = await _apiService.get(
      _base,
      '/users/search',
      queryParams: {'keyword': keyword},
    );
    final data = response['data'];
    final list = data is Map<String, dynamic>
        ? (data['content'] as List? ?? <dynamic>[])
        : (data as List? ?? <dynamic>[]);
    return list.map((e) => User.fromJson(e)).toList();
  }

  Future<User> searchUserByPhone(String phoneNumber) async {
    final normalized = _normalizePhone(phoneNumber);
    final response = await _apiService.get(_base, '/users/phone/$normalized');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid phone search response');
    }
    return User.fromJson(data);
  }

  Future<Map<String, dynamic>> scanFriendQr({
    required String userId,
    required String token,
    required String nonce,
    bool addFriend = true,
  }) async {
    final endpoint = addFriend ? '/qr/scan/add-friend' : '/qr/scan';
    final response = await _apiService.post(
      _base,
      endpoint,
      body: {'userId': userId, 'token': token, 'nonce': nonce},
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{};
  }

  String _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^+\d]'), '');
    if (cleaned.startsWith('0')) {
      return '+84${cleaned.substring(1)}';
    }
    return cleaned;
  }
}
