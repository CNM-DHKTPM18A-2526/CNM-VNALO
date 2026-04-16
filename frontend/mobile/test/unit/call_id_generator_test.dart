import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/call/utils/call_id_generator.dart';

void main() {
  group('generateCallId', () {
    const conversationId = 'conv-123';
    const callerUserId = 'user-456';
    const timestamp = 1625097600000;

    test('should generate voice call ID correctly', () {
      final id = generateCallId(
        conversationId: conversationId,
        callerUserId: callerUserId,
        audioOnly: true,
        timestampMs: timestamp,
      );
      expect(id, equals('voice-conv-123-user-456-1625097600000'));
    });

    test('should generate video call ID correctly', () {
      final id = generateCallId(
        conversationId: conversationId,
        callerUserId: callerUserId,
        audioOnly: false,
        timestampMs: timestamp,
      );
      expect(id, equals('video-conv-123-user-456-1625097600000'));
    });

    test('should use current time if timestampMs is not provided', () {
      final id = generateCallId(
        conversationId: conversationId,
        callerUserId: callerUserId,
        audioOnly: true,
      );
      expect(id, startsWith('voice-conv-123-user-456-'));
      
      // Ensure the timestamp part is a large number (recent timestamp)
      final parts = id.split('-');
      final ts = int.parse(parts.last);
      expect(ts, greaterThan(1700000000000));
    });

    test('should generate different IDs for different callers', () {
      final id1 = generateCallId(
        conversationId: conversationId,
        callerUserId: 'user-1',
        audioOnly: true,
        timestampMs: timestamp,
      );
      final id2 = generateCallId(
        conversationId: conversationId,
        callerUserId: 'user-2',
        audioOnly: true,
        timestampMs: timestamp,
      );
      expect(id1, isNot(equals(id2)));
    });
  });
}
