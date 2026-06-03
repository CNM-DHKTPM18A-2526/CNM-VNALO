import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_policy.dart';

void main() {
  group('AiActionPolicy.requiresConfirmation', () {
    test('returns true for high impact commands', () {
      expect(AiActionPolicy.requiresConfirmation('compose_message'), isTrue);
      expect(AiActionPolicy.requiresConfirmation('START_CALL'), isTrue);
      expect(AiActionPolicy.requiresConfirmation('DISBAND_GROUP'), isTrue);
    });

    test('returns false for passive navigation commands', () {
      expect(AiActionPolicy.requiresConfirmation('OPEN_CHAT'), isFalse);
      expect(AiActionPolicy.requiresConfirmation('OPEN_PROFILE'), isFalse);
      expect(AiActionPolicy.requiresConfirmation('OPEN_GROUP_SETTINGS'), isFalse);
    });
  });

  group('AiActionPolicy.isDestructive', () {
    test('returns true for destructive actions', () {
      expect(AiActionPolicy.isDestructive('RECALL_MESSAGE'), isTrue);
      expect(AiActionPolicy.isDestructive('block_user'), isTrue);
      expect(AiActionPolicy.isDestructive('DISBAND_GROUP'), isTrue);
    });

    test('returns false for non destructive actions', () {
      expect(AiActionPolicy.isDestructive('COMPOSE_MESSAGE'), isFalse);
      expect(AiActionPolicy.isDestructive('START_CALL'), isFalse);
    });
  });
}
