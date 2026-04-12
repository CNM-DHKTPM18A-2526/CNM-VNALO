import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

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

  Future<User?> getUserByPhone(String phone) async {
    try {
      final normalized = _normalizePhone(phone);
      final encodedPhone = Uri.encodeComponent(normalized);

      final response = await _apiService.get(
        _base,
        '/users/phone/$encodedPhone',
      );

      final dynamic payload = response['data'] ?? response;
      if (payload is Map<String, dynamic>) {
        if (payload.isEmpty || (payload['id'] == null && payload['_id'] == null)) {
          return null;
        }
        return User.fromJson(payload);
      }
      return null;
    } catch (e) {
      debugPrint('[SEARCH] Error searching phone: $e');
      return null;
    }
  }
}
