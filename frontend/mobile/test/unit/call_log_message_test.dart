import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/call/models/call_log_message.dart';

void main() {
  group('CallLogMessage', () {
    test('encodes and parses payload successfully', () {
      final now = DateTime(2026, 4, 14, 10, 30, 12);
      final original = CallLogMessage(
        callId: 'call-123',
        conversationId: 'conv-1',
        callerId: 'u-a',
        calleeId: 'u-b',
        mediaType: CallMediaType.video,
        outcome: CallOutcome.answered,
        durationSeconds: 52,
        createdAt: now,
      );

      final content = original.toMessageContent();
      final parsed = CallLogMessage.tryParse(content);

      expect(parsed, isNotNull);
      expect(parsed!.callId, 'call-123');
      expect(parsed.conversationId, 'conv-1');
      expect(parsed.callerId, 'u-a');
      expect(parsed.calleeId, 'u-b');
      expect(parsed.mediaType, CallMediaType.video);
      expect(parsed.outcome, CallOutcome.answered);
      expect(parsed.durationSeconds, 52);
      expect(parsed.createdAt.toIso8601String(), now.toIso8601String());
    });

    test('returns null when content is not call-log format', () {
      expect(CallLogMessage.tryParse('hello'), isNull);
      expect(CallLogMessage.tryParse(null), isNull);
    });
  });
}
