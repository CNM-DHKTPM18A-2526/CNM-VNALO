import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_context_store.dart';

void main() {
  group('AiActionContextStore target context', () {
    test('returns active target before ttl and clears expired target', () {
      final now = DateTime(2026, 5, 23, 10);
      final store = AiActionContextStore(
        targetContextTtl: const Duration(minutes: 12),
      );

      store.rememberTarget(
        targetName: '  Lý Vân  ',
        conversationId: ' c1 ',
        peerUserId: ' u1 ',
        now: now,
      );

      final active = store.activeTarget(now: now.add(const Duration(minutes: 5)));
      expect(active?.targetName, 'Lý Vân');
      expect(active?.conversationId, 'c1');
      expect(active?.peerUserId, 'u1');

      expect(
        store.activeTarget(now: now.add(const Duration(minutes: 13))),
        isNull,
      );
      expect(store.activeTarget(now: now.add(const Duration(minutes: 14))), isNull);
    });

    test('ignores blank target names', () {
      final store = AiActionContextStore();
      store.rememberTarget(targetName: '   ');
      expect(store.activeTarget(), isNull);
    });
  });

  group('AiActionContextStore pending action', () {
    test('returns active pending action before ttl and clears expired action', () {
      final now = DateTime(2026, 5, 23, 10);
      final store = AiActionContextStore(
        pendingActionTtl: const Duration(minutes: 5),
      );

      store.rememberPendingAction(
        command: 'COMPOSE_MESSAGE',
        scope: 'conversation',
        params: {'draft': 'Xin chào'},
        now: now,
      );

      final active = store.activePendingAction(
        now: now.add(const Duration(minutes: 3)),
      );
      expect(active?.command, 'COMPOSE_MESSAGE');
      expect(active?.scope, 'conversation');
      expect(active?.params, {'draft': 'Xin chào'});

      expect(
        store.activePendingAction(now: now.add(const Duration(minutes: 6))),
        isNull,
      );
    });

    test('injects selected conversation name into pending conversation action', () {
      final store = AiActionContextStore();
      final pending = AiPendingAction(
        command: 'COMPOSE_MESSAGE',
        params: {'messageText': 'Ði h?p nhé'},
        scope: 'conversation',
        updatedAt: DateTime(2026),
      );

      final next = store.injectSelectedNameIntoPendingParams(pending, 'Uyên Lý');

      expect(next['conversation'], 'Uyên Lý');
      expect(next['conversationName'], 'Uyên Lý');
      expect(next['target'], 'Uyên Lý');
      expect(next['recipient'], 'Uyên Lý');
      expect(next['messageText'], 'Ði h?p nhé');
    });

    test('injects selected user name into pending contact action', () {
      final store = AiActionContextStore();
      final pending = AiPendingAction(
        command: 'SEND_FRIEND_REQUEST',
        params: null,
        scope: 'contact',
        updatedAt: DateTime(2026),
      );

      final next = store.injectSelectedNameIntoPendingParams(pending, 'Minh Anh');

      expect(next['target'], 'Minh Anh');
      expect(next['recipient'], 'Minh Anh');
      expect(next['contactName'], 'Minh Anh');
      expect(next['name'], 'Minh Anh');
    });
  });
}