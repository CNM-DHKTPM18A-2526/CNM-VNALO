class AiCommandRouting {
  static String normalizeSystemAction(String command) {
    switch (command.trim().toUpperCase()) {
      case 'MỞ SETTINGS':
      case 'CÀI ĐẶT':
        return 'NAVIGATE_TO_SETTINGS';
      case 'MỞ DANH BẠ':
        return 'NAVIGATE_TO_CONTACTS';
      case 'MỞ CHAT':
        return 'NAVIGATE_TO_CHAT';
      case 'SEND_MESSAGE':
        return 'COMPOSE_MESSAGE';
      case 'RECALL_LAST_MESSAGE':
      case 'UNDO_LAST_MESSAGE':
        return 'RECALL_MESSAGE';
      default:
        return command.trim().toUpperCase();
    }
  }

  static Map<String, dynamic>? normalizeParams(dynamic rawParams) {
    if (rawParams == null) {
      return null;
    }
    if (rawParams is Map<String, dynamic>) {
      return rawParams;
    }
    if (rawParams is Map) {
      return rawParams.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  static String extractTargetName(Map<String, dynamic>? params) {
    return (params?['target'] ??
            params?['recipient'] ??
            params?['contactName'] ??
            params?['name'] ??
            '')
        .toString()
        .trim();
  }

  static String? extractPrefilledText(
    String command,
    Map<String, dynamic>? params,
  ) {
    final rawText =
        (params?['content'] ?? params?['messageText'] ?? params?['text'])
            ?.toString()
            .trim();
    if (normalizeSystemAction(command) != 'COMPOSE_MESSAGE') {
      return null;
    }
    if (rawText == null || rawText.isEmpty) {
      return null;
    }
    return rawText;
  }

  static bool shouldBlockOpenChat({
    required bool isAlreadyActiveConversation,
    required bool hasPendingAiNavigation,
  }) {
    return isAlreadyActiveConversation || hasPendingAiNavigation;
  }

  static bool shouldBlockCompose({required bool hasPendingAiNavigation}) {
    return hasPendingAiNavigation;
  }
}
