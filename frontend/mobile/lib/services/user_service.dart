import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    if (trimmed.startsWith('0') && trimmed.length >= 10) {
      return '+84${trimmed.substring(1)}';
    }
    if (trimmed.startsWith('84')) return '+$trimmed';
    return trimmed;
  }

  Future<User?> getUserByPhone(String phone) async {
    try {
      final normalized = _normalizePhone(phone);
      final response = await _apiService.get(
        _base,
        '/users/search-by-phone',
        queryParams: {'phone': normalized},
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return User.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
