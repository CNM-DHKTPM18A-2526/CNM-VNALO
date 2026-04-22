import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/config/app_config.dart';

class AiService {
  final ApiService _apiService;

  AiService(this._apiService);

  Future<Map<String, dynamic>> chat(
    String prompt, {
    String? contextId,
    bool analyzeIntent = false,
    bool enableDeepSummary = false,
  }) async {
    try {
      final response = await _apiService.post(
        AppConfig.instance.aiServiceUrl,
        '/ai/chat',
        body: {
          'prompt': prompt,
          'contextId': contextId,
          'analyzeIntent': analyzeIntent,
          'enableDeepSummary': enableDeepSummary,
        },
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception('AI_SERVICE_UNAVAILABLE - INVALID DATA FORMAT');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> backupConversationHistory({
    required String conversationId,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) {
      return;
    }

    await _apiService.post(
      AppConfig.instance.aiServiceUrl,
      '/ai/history/backup',
      body: {'conversationId': conversationId, 'entries': entries},
    );
  }
}
