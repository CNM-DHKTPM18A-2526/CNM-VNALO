import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_stt_resilience_policy.dart';

void main() {
  group('AiSttResiliencePolicy.isPermanentError', () {
    test('detects permission and network failures as permanent', () {
      expect(AiSttResiliencePolicy.isPermanentError('permission denied'), isTrue);
      expect(AiSttResiliencePolicy.isPermanentError('network timeout'), isTrue);
      expect(AiSttResiliencePolicy.isPermanentError('initialize failed'), isTrue);
    });

    test('does not treat no-match silence as permanent', () {
      expect(AiSttResiliencePolicy.isPermanentError('error_no_match'), isFalse);
      expect(AiSttResiliencePolicy.isPermanentError('speech_timeout'), isFalse);
    });
  });

  group('AiSttResiliencePolicy.isTransientError', () {
    test('treats silence-like stt errors as transient', () {
      expect(AiSttResiliencePolicy.isTransientError('error_no_match'), isTrue);
      expect(AiSttResiliencePolicy.isTransientError('speech_timeout'), isTrue);
      expect(AiSttResiliencePolicy.isTransientError('error_audio_error'), isTrue);
    });

    test('does not treat permanent failures as transient', () {
      expect(AiSttResiliencePolicy.isTransientError('permission denied'), isFalse);
    });
  });

  group('AiSttResiliencePolicy.shouldHoldListening', () {
    test('keeps listening active for early transient endings', () {
      final shouldHold = AiSttResiliencePolicy.shouldHoldListening(
        isListening: true,
        isPipelineLocked: false,
        hasCapturedFinalTranscript: false,
        elapsed: const Duration(seconds: 2),
        minimumListenFor: const Duration(seconds: 10),
        isPermanentError: false,
      );

      expect(shouldHold, isTrue);
    });

    test('stops holding after minimum window or final transcript', () {
      expect(
        AiSttResiliencePolicy.shouldHoldListening(
          isListening: true,
          isPipelineLocked: false,
          hasCapturedFinalTranscript: true,
          elapsed: const Duration(seconds: 2),
          minimumListenFor: const Duration(seconds: 10),
          isPermanentError: false,
        ),
        isFalse,
      );

      expect(
        AiSttResiliencePolicy.shouldHoldListening(
          isListening: true,
          isPipelineLocked: false,
          hasCapturedFinalTranscript: false,
          elapsed: const Duration(seconds: 12),
          minimumListenFor: const Duration(seconds: 10),
          isPermanentError: false,
        ),
        isFalse,
      );
    });
  });
}
