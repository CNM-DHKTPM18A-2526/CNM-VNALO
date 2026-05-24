class AiSttResiliencePolicy {
  const AiSttResiliencePolicy._();

  static bool isPermanentError(String rawError) {
    final normalized = rawError.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('permission') ||
        normalized.contains('denied') ||
        normalized.contains('initialize') ||
        normalized.contains('notavailable') ||
        normalized.contains('not available') ||
        normalized.contains('network');
  }

  static bool isTransientError(String rawError) {
    final normalized = rawError.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    if (isPermanentError(normalized)) {
      return false;
    }

    return normalized.contains('no_match') ||
        normalized.contains('no match') ||
        normalized.contains('speech_timeout') ||
        normalized.contains('speech timeout') ||
        normalized.contains('error_client') ||
        normalized.contains('client') ||
        normalized.contains('busy') ||
        normalized.contains('retry') ||
        normalized.contains('timeout') ||
        normalized.contains('error_audio') ||
        normalized.contains('audio');
  }

  static bool shouldHoldListening({
    required bool isListening,
    required bool isPipelineLocked,
    required bool hasCapturedFinalTranscript,
    required Duration elapsed,
    required Duration minimumListenFor,
    required bool isPermanentError,
  }) {
    return isListening &&
        !isPipelineLocked &&
        !isPermanentError &&
        !hasCapturedFinalTranscript &&
        elapsed < minimumListenFor;
  }
}
