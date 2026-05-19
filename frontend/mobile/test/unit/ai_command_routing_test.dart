import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';

void main() {
  group('AiCommandRouting.normalizeSystemAction', () {
    test('maps localized navigation aliases', () {
      expect(
        AiCommandRouting.normalizeSystemAction('Mở settings'),
        'NAVIGATE_TO_SETTINGS',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('MỞ DANH BẠ'),
        'NAVIGATE_TO_CONTACTS',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('mở chat'),
        'NAVIGATE_TO_CHAT',
      );
    });

    test('maps legacy message aliases', () {
      expect(
        AiCommandRouting.normalizeSystemAction('SEND_MESSAGE'),
        'COMPOSE_MESSAGE',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('RECALL_LAST_MESSAGE'),
        'RECALL_MESSAGE',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('UNDO_LAST_MESSAGE'),
        'RECALL_MESSAGE',
      );
    });
  });

  group('AiCommandRouting.normalizeParams', () {
    test('keeps typed maps intact', () {
      final params = {'recipient': 'An', 'content': 'Xin chào'};
      expect(AiCommandRouting.normalizeParams(params), same(params));
    });

    test('converts dynamic maps to string-keyed maps', () {
      final params = {1: 'one', 'two': 2};
      expect(AiCommandRouting.normalizeParams(params), {'1': 'one', 'two': 2});
    });

    test('returns null for unsupported param types', () {
      expect(AiCommandRouting.normalizeParams('bad'), isNull);
    });
  });

  group('AiCommandRouting extraction helpers', () {
    test('extractTargetName checks common target keys in order', () {
      expect(
        AiCommandRouting.extractTargetName({
          'recipient': '  Bình  ',
          'target': 'An',
        }),
        'An',
      );
      expect(
        AiCommandRouting.extractTargetName({'contactName': 'Cường'}),
        'Cường',
      );
      expect(AiCommandRouting.extractTargetName(null), isEmpty);
    });

    test('extractPrefilledText only returns compose content', () {
      expect(
        AiCommandRouting.extractPrefilledText('COMPOSE_MESSAGE', {
          'content': '  gặp nhau lúc 7h  ',
        }),
        'gặp nhau lúc 7h',
      );
      expect(
        AiCommandRouting.extractPrefilledText('SEND_MESSAGE', {
          'messageText': 'xin chào',
        }),
        'xin chào',
      );
      expect(
        AiCommandRouting.extractPrefilledText('OPEN_CHAT', {
          'content': 'xin chào',
        }),
        isNull,
      );
      expect(
        AiCommandRouting.extractPrefilledText('COMPOSE_MESSAGE', {
          'content': '   ',
        }),
        isNull,
      );
    });
  });

  group('AiCommandRouting navigation guards', () {
    test('blocks open chat if already active or pending', () {
      expect(
        AiCommandRouting.shouldBlockOpenChat(
          isAlreadyActiveConversation: true,
          hasPendingAiNavigation: false,
        ),
        isTrue,
      );
      expect(
        AiCommandRouting.shouldBlockOpenChat(
          isAlreadyActiveConversation: false,
          hasPendingAiNavigation: true,
        ),
        isTrue,
      );
      expect(
        AiCommandRouting.shouldBlockOpenChat(
          isAlreadyActiveConversation: false,
          hasPendingAiNavigation: false,
        ),
        isFalse,
      );
    });

    test('only blocks compose when a pending AI navigation exists', () {
      expect(
        AiCommandRouting.shouldBlockCompose(hasPendingAiNavigation: true),
        isTrue,
      );
      expect(
        AiCommandRouting.shouldBlockCompose(hasPendingAiNavigation: false),
        isFalse,
      );
    });
  });
}
