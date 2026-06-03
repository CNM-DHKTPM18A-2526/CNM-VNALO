import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_mobile_capability_catalog.dart';

void main() {
  group('AiMobileCapabilityCatalog', () {
    test('knows supported mobile assistant commands', () {
      expect(AiMobileCapabilityCatalog.isSupported('OPEN_CHAT'), isTrue);
      expect(AiMobileCapabilityCatalog.isSupported('compose_message'), isTrue);
      expect(AiMobileCapabilityCatalog.isSupported('DISBAND_GROUP'), isTrue);
    });

    test('returns clear feedback for unsupported video commands', () {
      final feedback = AiMobileCapabilityCatalog.buildUnsupportedFeedback(
        'START_VIDEO_CALL',
      );

      expect(feedback, contains('gọi video'));
      expect(feedback, contains('thủ công'));
    });

    test('returns safe feedback for risky unsupported commands', () {
      final feedback = AiMobileCapabilityCatalog.buildUnsupportedFeedback(
        'DELETE_ACCOUNT',
      );

      expect(feedback, contains('đảm bảo an toàn'));
    });
  });
}
