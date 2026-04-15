String generateCallId({
  required String conversationId,
  required String callerUserId,
  required bool audioOnly,
}) {
  final mediaType = audioOnly ? 'voice' : 'video';
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$mediaType-$conversationId-$callerUserId-$timestamp';
}
