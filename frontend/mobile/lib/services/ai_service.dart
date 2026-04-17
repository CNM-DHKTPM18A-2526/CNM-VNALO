import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/config/app_config.dart';

class AiService {
  final ApiService _apiService;

  AiService(this._apiService);

  Future<Map<String, dynamic>> chat(String prompt, {String? contextId, bool analyzeIntent = false}) async {
    try {
      final response = await _apiService.post(
        AppConfig.instance.aiServiceUrl,
        '/ai/chat',
        body: {
          'prompt': prompt,
          'contextId': contextId,
          'analyzeIntent': analyzeIntent,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('AI_SERVICE_UNAVAILABLE');
      }
    } catch (e) {
      rethrow;
    }
  }
}
