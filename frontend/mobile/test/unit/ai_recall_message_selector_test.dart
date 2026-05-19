import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_recall_message_selector.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/models/message_model.dart';

Message _msg({
  required String id,
  required String senderId,
  int? seq,
  DateTime? createdAt,
  MessageType type = MessageType.TEXT,
  MessageStatus status = MessageStatus.SENT,
}) {
  return Message(
    id: id,
    conversationId: 'c1',
    senderId: senderId,
    serverSeq: seq,
    messageType: type,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    content: id,
  );
}

void main() {
  group('AiRecallMessageSelector.selectLatestRecallableMessage', () {
    test('returns null if current user is empty', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [_msg(id: 'm1', senderId: 'u1')],
        currentUserId: '  ',
      );
      expect(result, isNull);
    });

    test('ignores messages from other users', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [
          _msg(id: 'm1', senderId: 'u2', seq: 1),
          _msg(id: 'm2', senderId: 'u3', seq: 2),
        ],
        currentUserId: 'u1',
      );
      expect(result, isNull);
    });

    test('ignores recalled and system messages', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [
          _msg(
            id: 'm1',
            senderId: 'u1',
            seq: 1,
            status: MessageStatus.RECALLED,
          ),
          _msg(id: 'm2', senderId: 'u1', seq: 2, type: MessageType.SYSTEM),
          _msg(id: 'm3', senderId: 'u1', seq: 3),
        ],
        currentUserId: 'u1',
      );
      expect(result?.id, 'm3');
    });

    test('prefers higher server sequence when available', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [
          _msg(id: 'm1', senderId: 'u1', seq: 10),
          _msg(id: 'm2', senderId: 'u1', seq: 12),
          _msg(id: 'm3', senderId: 'u1', seq: 11),
        ],
        currentUserId: 'u1',
      );
      expect(result?.id, 'm2');
    });

    test('uses createdAt fallback when sequence is missing on both', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [
          _msg(id: 'm1', senderId: 'u1', createdAt: DateTime(2026, 1, 1, 10)),
          _msg(id: 'm2', senderId: 'u1', createdAt: DateTime(2026, 1, 1, 11)),
        ],
        currentUserId: 'u1',
      );
      expect(result?.id, 'm2');
    });

    test('prioritizes seq-present message over seq-missing message', () {
      final result = AiRecallMessageSelector.selectLatestRecallableMessage(
        messages: [
          _msg(id: 'm1', senderId: 'u1', createdAt: DateTime(2026, 1, 1, 15)),
          _msg(
            id: 'm2',
            senderId: 'u1',
            seq: 4,
            createdAt: DateTime(2026, 1, 1, 8),
          ),
        ],
        currentUserId: 'u1',
      );
      expect(result?.id, 'm2');
    });
  });
}
