import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/api_service.dart';

class BlockService {
  final ApiService _apiService;

  BlockService(this._apiService);

  String get _base => AppConfig.instance.coreServiceUrl;

  Future<Map<String, dynamic>> checkBlockStatus(String userId) {
    return _apiService.get(_base, '/blocks/$userId/status');
  }

  Future<Map<String, dynamic>> getBlockedUsers({int page = 0, int size = 20}) {
    return _apiService.get(
      _base,
      '/blocks',
      queryParams: {
        'page': page.toString(),
        'size': size.toString(),
      },
    );
  }

  Future<Map<String, dynamic>> blockUser(
    String userId, {
    required bool blockMessages,
    required bool blockCalls,
  }) {
    return _apiService.post(
      _base,
      '/blocks/$userId',
      queryParams: {
        'blockMessages': blockMessages.toString(),
        'blockCalls': blockCalls.toString(),
      },
    );
  }

  Future<Map<String, dynamic>> updateBlock(
    String userId, {
    bool? blockMessages,
    bool? blockCalls,
  }) {
    return _apiService.patch(
      _base,
      '/blocks/$userId',
      body: {
        if (blockMessages != null) 'blockMessages': blockMessages,
        if (blockCalls != null) 'blockCalls': blockCalls,
      },
    );
  }

  Future<Map<String, dynamic>> unblockUser(String userId) {
    return _apiService.delete(_base, '/blocks/$userId');
  }
}
