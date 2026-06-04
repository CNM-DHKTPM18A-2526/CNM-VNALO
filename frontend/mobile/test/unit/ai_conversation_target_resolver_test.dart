import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_context_store.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_conversation_target_resolver.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/conversation_member_model.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

Conversation _directConversation({
  required String id,
  required String currentUserId,
  required String peerUserId,
}) {
  return Conversation(
    id: id,
    type: ConversationType.DIRECT,
    members: [
      ConversationMember(
        conversationId: id,
        userId: currentUserId,
        joinedAt: DateTime(2026),
      ),
      ConversationMember(
        conversationId: id,
        userId: peerUserId,
        joinedAt: DateTime(2026),
      ),
    ],
  );
}

Conversation _groupConversation(String id) {
  return Conversation(
    id: id,
    type: ConversationType.GROUP,
    title: 'Nhom $id',
  );
}

void main() {
  group('AiConversationTargetResolver.directPeerUserId', () {
    test('returns the other member in direct conversation', () {
      final conversation = _directConversation(
        id: 'c1',
        currentUserId: 'me',
        peerUserId: 'u1',
      );

      expect(
        AiConversationTargetResolver.directPeerUserId(conversation, 'me'),
        'u1',
      );
    });

    test('returns null for group conversation', () {
      expect(
        AiConversationTargetResolver.directPeerUserId(
          _groupConversation('g1'),
          'me',
        ),
        isNull,
      );
    });
  });

  group('AiConversationTargetResolver.preferConversationFromContext', () {
    test('prefers conversation id over peer context', () {
      final first = _directConversation(
        id: 'c1',
        currentUserId: 'me',
        peerUserId: 'u1',
      );
      final second = _directConversation(
        id: 'c2',
        currentUserId: 'me',
        peerUserId: 'u2',
      );
      final context = AiTargetContext(
        targetName: 'Uyen',
        conversationId: 'c2',
        peerUserId: 'u1',
        updatedAt: DateTime(2026),
      );

      expect(
        AiConversationTargetResolver.preferConversationFromContext(
          [first, second],
          context: context,
          currentUserId: 'me',
        ),
        same(second),
      );
    });

    test('falls back to direct peer context', () {
      final first = _directConversation(
        id: 'c1',
        currentUserId: 'me',
        peerUserId: 'u1',
      );
      final second = _directConversation(
        id: 'c2',
        currentUserId: 'me',
        peerUserId: 'u2',
      );
      final context = AiTargetContext(
        targetName: 'Uyen',
        peerUserId: 'u2',
        updatedAt: DateTime(2026),
      );

      expect(
        AiConversationTargetResolver.preferConversationFromContext(
          [first, second],
          context: context,
          currentUserId: 'me',
        ),
        same(second),
      );
    });
  });

  group('AiConversationTargetResolver.directConversationForUser', () {
    test('finds existing direct conversation for user', () {
      final direct = _directConversation(
        id: 'c1',
        currentUserId: 'me',
        peerUserId: 'u1',
      );

      expect(
        AiConversationTargetResolver.directConversationForUser(
          [_groupConversation('g1'), direct],
          currentUserId: 'me',
          userId: 'u1',
        ),
        same(direct),
      );
    });
  });
}


