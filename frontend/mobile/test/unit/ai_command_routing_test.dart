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
      expect(
        AiCommandRouting.normalizeSystemAction('create_group_draft'),
        'CREATE_GROUP',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('add_group_member'),
        'ADD_GROUP_MEMBER',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('transfer_owner'),
        'TRANSFER_GROUP_OWNER',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('block_contact'),
        'BLOCK_USER',
      );
    });

    test('keeps call and scanner commands canonical', () {
      expect(
        AiCommandRouting.normalizeSystemAction(' start_call '),
        'START_CALL',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('navigate_to_scanner'),
        'NAVIGATE_TO_SCANNER',
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

    test('preserves call params for downstream confirmation flow', () {
      final params = AiCommandRouting.normalizeParams({
        'target': 'Minh Anh',
        'callType': 'video',
      });

      expect(AiCommandRouting.extractTargetName(params), 'Minh Anh');
      expect(params?['callType'], 'video');
      expect(
        AiCommandRouting.extractPrefilledText('START_CALL', params),
        isNull,
      );
    });

    test('extracts group metadata and member names', () {
      final params = {
        'groupTitle': 'Nhóm đi chơi',
        'members': ['An', 'Bình'],
      };
      expect(AiCommandRouting.extractGroupName(params), 'Nhóm đi chơi');
      expect(AiCommandRouting.extractMemberNames(params), ['An', 'Bình']);
    });

    test('extracts fallback member name and conversation name', () {
      final params = {'memberName': 'Uyên', 'conversationName': 'Lớp 18DHTPM'};
      expect(AiCommandRouting.extractMemberNames(params), ['Uyên']);
      expect(AiCommandRouting.extractConversationName(params), 'Lớp 18DHTPM');
    });

    test('extracts new group title and friend request message', () {
      final params = {'newName': 'Nhóm mới', 'note': 'Kết bạn nhé'};
      expect(AiCommandRouting.extractNewTitle(params), 'Nhóm mới');
      expect(
        AiCommandRouting.extractFriendRequestMessage(params),
        'Kết bạn nhé',
      );
    });
  });

  group('AiCommandRouting flexible name matching', () {
    test('normalizes Vietnamese accents and spacing', () {
      expect(
        AiCommandRouting.normalizeSearchText('  Lý   Tinh Vân  '),
        'ly tinh van',
      );
      expect(
        AiCommandRouting.normalizeSearchText('Đặng Thị Uyên'),
        'dang thi uyen',
      );
    });

    test('matches skipped middle names for contact resolution', () {
      expect(
        AiCommandRouting.isFlexibleNameMatch('Lý Tinh Vân', 'lý vân'),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch('Lý Tinh Vân', 'ly van'),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch('Nguyễn Thị Uyên', 'uyen'),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch('Lý Tinh Vân', 'lý bình'),
        isFalse,
      );
    });

    test('ranks exact and suffix matches above loose flexible matches', () {
      final exact = AiCommandRouting.computeNameMatchScore('Lý Vân', 'lý vân');
      final suffix = AiCommandRouting.computeNameMatchScore(
        'Lý Tinh Vân',
        'lý vân',
      );
      final loose = AiCommandRouting.computeNameMatchScore(
        'Nguyễn Lý Tinh Vân',
        'lý vân',
      );

      expect(exact, greaterThan(suffix));
      expect(suffix, greaterThan(loose));
      expect(loose, greaterThanOrEqualTo(0));
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

  group('AiCommandRouting action feedback copy', () {
    test('builds ambiguity feedback with candidate names', () {
      final message = AiCommandRouting.buildAmbiguousTargetFeedback(
        targetName: 'Uyên',
        candidates: const [
          'Uyên Lý',
          'Uyên Nguyễn',
          'Uyên Trần',
          'Uyên Hoàng',
          'Uyên Đặng',
        ],
      );

      expect(message, contains('Uyên Lý'));
      expect(message, contains('Uyên Nguyễn'));
      expect(message, isNot(contains('Uyên Đặng')));
    });

    test('builds missing target feedback with specific type', () {
      final message = AiCommandRouting.buildMissingTargetFeedback(
        targetName: 'Lý Vân',
        targetType: 'liên hệ trong danh bạ',
      );

      expect(message, contains('liên hệ trong danh bạ'));
      expect(message, contains('Lý Vân'));
    });
  });
}
