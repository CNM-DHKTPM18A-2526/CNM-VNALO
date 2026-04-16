String generateCallId({
  required String conversationId,
  required String callerUserId,
  required bool audioOnly,
  int? timestampMs,
}) {
  final mediaType = audioOnly ? 'voice' : 'video';
  final timestamp = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  return '$mediaType-$conversationId-$callerUserId-$timestamp';
}
