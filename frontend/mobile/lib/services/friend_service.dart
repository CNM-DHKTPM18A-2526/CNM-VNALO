import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class FriendService {
  final ApiService _apiService;
  FriendService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  Future<List<User>> getFriends() async {
    final response = await _apiService.get(_base, '/friends');
    final data = response['data'];

    // Handle paginated response (Page<FriendResponse> has 'content' key)
    List items;
    if (data is Map<String, dynamic> && data.containsKey('content')) {
      items = data['content'] as List;
    } else if (data is List) {
      items = data;
    } else {
      items = [];
    }

    return items.map((e) {
      final map = Map<String, dynamic>.from(e);
      // Backend FriendResponse uses 'friendId' instead of 'id'
      if (!map.containsKey('id') && map.containsKey('friendId')) {
        map['id'] = map['friendId'];
      }
      return User.fromJson(map);
    }).toList();
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
    final data = response['data'];
    if (data is Map<String, dynamic> && data.containsKey('content')) {
      return List<Map<String, dynamic>>.from(data['content']);
    }
    return List<Map<String, dynamic>>.from(data as List? ?? []);
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

  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final response = await _apiService.get(_base, '/friends/requests/sent');
    final data = response['data'];
    if (data is Map<String, dynamic> && data.containsKey('content')) {
      return List<Map<String, dynamic>>.from(data['content']);
    }
    return List<Map<String, dynamic>>.from(data as List? ?? []);
  }

  Future<void> cancelRequest(String requestId) async {
    await _apiService.delete(_base, '/friends/requests/$requestId');
  }

  Future<void> cancelRequestByUserId(String userId) async {
    final sent = await getSentRequests();
    // find request where toUserId == userId
    final req = sent.firstWhere(
      (r) => r['toUserId'] == userId || (r['toUser'] != null && r['toUser']['id'] == userId),
      orElse: () => throw ApiException(message: 'Không tìm thấy lời mời để hủy.', statusCode: 404),
    );
    final id = req['id'];
    if (id == null) throw ApiException(message: 'Dữ liệu lời mời không hợp lệ.', statusCode: 500);
    await cancelRequest(id.toString());
  }

  Future<void> unfriend(String friendId) async {
    await _apiService.delete(_base, '/friends/$friendId');
  }

  Future<String?> getFriendshipStatus(String userId) async {
    try {
      final response = await _apiService.get(_base, '/friends/$userId/status');
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final status = data['status'] ?? data['friendshipStatus'] ?? data['friendship_status'];
        return status?.toString();
      }
      if (data is String) {
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkSentRequest(String userId) async {
    try {
      final sent = await getSentRequests();
      return sent.any((r) => 
        r['toUserId'] == userId || 
        (r['toUser'] != null && r['toUser']['id'] == userId)
      );
    } catch (_) {
      return false;
    }
  }

  Future<int> getPendingRequestCount() async {
    final response = await _apiService.get(_base, '/friends/stats');
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return (data['pendingRequestCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
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
    final encodedPhone = Uri.encodeComponent(normalized);
    final response = await _apiService.get(
      _base,
      '/users/phone/$encodedPhone',
    );

    final dynamic data = response['data'] ?? response;
    if (data is! Map<String, dynamic> || 
        data.isEmpty || 
        (data['id'] == null && data['_id'] == null)) {
       throw ApiException(
         message: 'Không tìm thấy người dùng với số điện thoại này.',
         statusCode: 404,
         code: 'USER_001',
       );
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
}
