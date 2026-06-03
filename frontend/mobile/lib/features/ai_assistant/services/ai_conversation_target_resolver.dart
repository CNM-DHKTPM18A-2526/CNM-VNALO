import 'package:vnalo_mobile/features/ai_assistant/services/ai_action_context_store.dart';
import 'package:vnalo_mobile/models/conversation_model.dart';

class AiConversationTargetResolver {
  const AiConversationTargetResolver._();

  static String? directPeerUserId(
    Conversation conversation,
    String currentUserId,
  ) {
    if (conversation.type.name != 'DIRECT') return null;
    for (final member in conversation.members) {
      if (member.userId != currentUserId) {
        return member.userId;
      }
    }
    return null;
  }

  static Conversation? preferConversationFromContext(
    Iterable<Conversation> matches, {
    required AiTargetContext? context,
    required String currentUserId,
  }) {
    if (context == null) return null;

    final conversationId = context.conversationId?.trim();
    if (conversationId != null && conversationId.isNotEmpty) {
      for (final conversation in matches) {
        if (conversation.id == conversationId) {
          return conversation;
        }
      }
    }

    final peerUserId = context.peerUserId?.trim();
    if (peerUserId == null || peerUserId.isEmpty) {
      return null;
    }

    for (final conversation in matches) {
      if (directPeerUserId(conversation, currentUserId) == peerUserId) {
        return conversation;
      }
    }
    return null;
  }

  static Conversation? directConversationForUser(
    Iterable<Conversation> conversations, {
    required String currentUserId,
    required String userId,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    for (final conversation in conversations) {
      if (conversation.type.name == 'DIRECT' &&
          directPeerUserId(conversation, currentUserId) == normalizedUserId) {
        return conversation;
      }
    }
    return null;
  }
}
