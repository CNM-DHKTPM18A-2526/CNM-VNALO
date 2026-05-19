import 'package:vnalo_mobile/models/message_model.dart';

class AiRecallMessageSelector {
  static Message? selectLatestRecallableMessage({
    required Iterable<Message> messages,
    required String? currentUserId,
  }) {
    final userId = currentUserId?.trim();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    Message? latest;
    for (final message in messages) {
      if (!_isRecallableByUser(message, userId)) {
        continue;
      }
      if (latest == null || _isNewer(message, latest)) {
        latest = message;
      }
    }
    return latest;
  }

  static bool _isRecallableByUser(Message message, String currentUserId) {
    return message.senderId == currentUserId &&
        !message.isRecalled &&
        !message.isSystemMessage;
  }

  static bool _isNewer(Message candidate, Message current) {
    final candidateSeq = candidate.serverSeq;
    final currentSeq = current.serverSeq;
    if (candidateSeq != null && currentSeq != null) {
      return candidateSeq > currentSeq;
    }
    if (candidateSeq != null && currentSeq == null) {
      return true;
    }
    if (candidateSeq == null && currentSeq != null) {
      return false;
    }
    return candidate.createdAt.isAfter(current.createdAt);
  }
}
