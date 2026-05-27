import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';

void main() {
  group('AiCommandRouting.normalizeSystemAction', () {
    test('maps localized navigation aliases', () {
      expect(
        AiCommandRouting.normalizeSystemAction('M\u1EDF settings'),
        'NAVIGATE_TO_SETTINGS',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('M\u1EDF DANH B\u1EA0'),
        'NAVIGATE_TO_CONTACTS',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('m\u1EDF chat'),
        'NAVIGATE_TO_CHAT',
      );
    });

    test('maps legacy message aliases', () {
      expect(
        AiCommandRouting.normalizeSystemAction('SEND_MESSAGE'),
        'COMPOSE_MESSAGE',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('message_contact'),
        'COMPOSE_MESSAGE',
      );
      expect(AiCommandRouting.normalizeSystemAction('open_chat'), 'OPEN_CHAT');
      expect(
        AiCommandRouting.normalizeSystemAction('open_conversation'),
        'OPEN_CHAT',
      );
      expect(AiCommandRouting.normalizeSystemAction('go_to_chat'), 'OPEN_CHAT');
      expect(
        AiCommandRouting.normalizeSystemAction('start_video_call'),
        'START_CALL',
      );
      expect(AiCommandRouting.normalizeSystemAction('make_call'), 'START_CALL');
      expect(
        AiCommandRouting.normalizeSystemAction('send_text'),
        'COMPOSE_MESSAGE',
      );
      expect(
        AiCommandRouting.normalizeSystemAction('call_contact'),
        'START_CALL',
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
      final params = {'recipient': 'An', 'content': 'Xin chÃƒÂ o'};
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
          'recipient': '  BÃƒÂ¬nh  ',
          'target': 'An',
        }),
        'An',
      );
      expect(
        AiCommandRouting.extractTargetName({'contactName': 'CÃ†Â°Ã¡Â»Âng'}),
        'CÃ†Â°Ã¡Â»Âng',
      );
      expect(AiCommandRouting.extractTargetName(null), isEmpty);
    });

    test('extractPrefilledText only returns compose content', () {
      expect(
        AiCommandRouting.extractPrefilledText('COMPOSE_MESSAGE', {
          'content': '  gÃ¡ÂºÂ·p nhau lÃƒÂºc 7h  ',
        }),
        'gÃ¡ÂºÂ·p nhau lÃƒÂºc 7h',
      );
      expect(
        AiCommandRouting.extractPrefilledText('SEND_MESSAGE', {
          'messageText': 'xin chÃƒÂ o',
        }),
        'xin chÃƒÂ o',
      );
      expect(
        AiCommandRouting.extractPrefilledText('OPEN_CHAT', {
          'content': 'xin chÃƒÂ o',
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
        'groupTitle': 'NhÃƒÂ³m Ã„â€˜i chÃ†Â¡i',
        'members': ['An', 'BÃƒÂ¬nh'],
      };
      expect(
        AiCommandRouting.extractGroupName(params),
        'NhÃƒÂ³m Ã„â€˜i chÃ†Â¡i',
      );
      expect(AiCommandRouting.extractMemberNames(params), ['An', 'BÃƒÂ¬nh']);
    });

    test('extracts fallback member name and conversation name', () {
      final params = {
        'memberName': 'UyÃƒÂªn',
        'conversationName': 'LÃ¡Â»â€ºp 18DHTPM',
      };
      expect(AiCommandRouting.extractMemberNames(params), ['UyÃƒÂªn']);
      expect(
        AiCommandRouting.extractConversationName(params),
        'LÃ¡Â»â€ºp 18DHTPM',
      );
    });

    test('extracts new group title and friend request message', () {
      final params = {
        'newName': 'NhÃƒÂ³m mÃ¡Â»â€ºi',
        'note': 'KÃ¡ÂºÂ¿t bÃ¡ÂºÂ¡n nhÃƒÂ©',
      };
      expect(AiCommandRouting.extractNewTitle(params), 'NhÃƒÂ³m mÃ¡Â»â€ºi');
      expect(
        AiCommandRouting.extractFriendRequestMessage(params),
        'KÃ¡ÂºÂ¿t bÃ¡ÂºÂ¡n nhÃƒÂ©',
      );
    });
  });

  group('AiCommandRouting flexible name matching', () {
    test('normalizes Vietnamese accents and spacing', () {
      expect(
        AiCommandRouting.normalizeSearchText('  L\u00FD   Tinh V\u00E2n  '),
        'ly tinh van',
      );
      expect(
        AiCommandRouting.normalizeSearchText(
          '\u0110\u1EB7ng Th\u1ECB Uy\u00EAn',
        ),
        'dang thi uyen',
      );
    });

    test('matches skipped middle names for contact resolution', () {
      expect(
        AiCommandRouting.isFlexibleNameMatch(
          'L\u00FD Tinh V\u00E2n',
          'l\u00FD v\u00E2n',
        ),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch('L\u00FD Tinh V\u00E2n', 'ly van'),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch(
          'Nguy\u1EC5n Th\u1ECB Uy\u00EAn',
          'uyen',
        ),
        isTrue,
      );
      expect(
        AiCommandRouting.isFlexibleNameMatch(
          'L\u00FD Tinh V\u00E2n',
          'l\u00FD b\u00ECnh',
        ),
        isFalse,
      );
    });

    test('ranks exact and suffix matches above loose flexible matches', () {
      final exact = AiCommandRouting.computeNameMatchScore(
        'L\u00FD V\u00E2n',
        'l\u00FD v\u00E2n',
      );
      final suffix = AiCommandRouting.computeNameMatchScore(
        'L\u00FD Tinh V\u00E2n',
        'l\u00FD v\u00E2n',
      );
      final loose = AiCommandRouting.computeNameMatchScore(
        'Nguy\u1EC5n L\u00FD Tinh V\u00E2n',
        'l\u00FD v\u00E2n',
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
        targetName: 'UyÃƒÂªn',
        candidates: const [
          'UyÃƒÂªn LÃƒÂ½',
          'UyÃƒÂªn NguyÃ¡Â»â€¦n',
          'UyÃƒÂªn TrÃ¡ÂºÂ§n',
          'UyÃƒÂªn HoÃƒÂ ng',
          'UyÃƒÂªn Ã„ÂÃ¡ÂºÂ·ng',
        ],
      );

      expect(message, contains('UyÃƒÂªn LÃƒÂ½'));
      expect(message, contains('UyÃƒÂªn NguyÃ¡Â»â€¦n'));
      expect(message, isNot(contains('UyÃƒÂªn Ã„ÂÃ¡ÂºÂ·ng')));
    });

    test('builds missing target feedback with specific type', () {
      final message = AiCommandRouting.buildMissingTargetFeedback(
        targetName: 'LÃƒÂ½ VÃƒÂ¢n',
        targetType: 'liÃƒÂªn hÃ¡Â»â€¡ trong danh bÃ¡ÂºÂ¡',
      );

      expect(message, contains('liÃƒÂªn hÃ¡Â»â€¡ trong danh bÃ¡ÂºÂ¡'));
      expect(message, contains('LÃƒÂ½ VÃƒÂ¢n'));
    });

    test('round-trips ambiguity candidate metadata in source', () {
      final source = AiCommandRouting.buildAmbiguityFeedbackSource(
        scope: 'contact',
        candidates: const [
          'UyÃƒÂªn LÃƒÂ½',
          'UyÃƒÂªn NguyÃ¡Â»â€¦n',
          'UyÃƒÂªn LÃƒÂ½',
        ],
      );

      expect(source, startsWith('ai_action_ambiguity.contact::'));
      expect(
        AiCommandRouting.parseAmbiguityCandidatesFromSource(source),
        const ['UyÃƒÂªn LÃƒÂ½', 'UyÃƒÂªn NguyÃ¡Â»â€¦n'],
      );
    });
  });
}
