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
    final list = response['data'] as List;
    return list.map((e) => User.fromJson(e)).toList();
  }
}
