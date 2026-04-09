import 'dart:convert';

import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class QrService {
  final ApiService _apiService;

  QrService(this._apiService);

  String get _coreBase => AppConfig.instance.coreServiceUrl;

  Future<String> generateFriendQrRawPayload() async {
    final response = await _apiService.get(_coreBase, '/qr/generate');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('QR generate response is invalid');
    }

    return jsonEncode(data);
  }
}
