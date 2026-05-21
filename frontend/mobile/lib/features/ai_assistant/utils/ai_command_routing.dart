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
      case 'CREATE_GROUP':
      case 'CREATE_GROUP_DRAFT':
        return 'CREATE_GROUP';
      case 'MUTE_CHAT':
      case 'MUTE_GROUP':
      case 'MUTE_CONVERSATION':
        return 'MUTE_CONVERSATION';
      case 'UNMUTE_CHAT':
      case 'UNMUTE_GROUP':
      case 'UNMUTE_CONVERSATION':
        return 'UNMUTE_CONVERSATION';
      case 'PIN_LAST_MESSAGE':
        return 'PIN_MESSAGE';
      case 'UNPIN_LAST_MESSAGE':
        return 'UNPIN_MESSAGE';
      case 'OPEN_GROUP_SETTING':
      case 'OPEN_GROUP_SETTINGS':
        return 'OPEN_GROUP_SETTINGS';
      case 'OPEN_USER_PROFILE':
      case 'OPEN_FRIEND_PROFILE':
        return 'OPEN_PROFILE';
      case 'ADD_FRIEND':
      case 'SEND_FRIEND_REQUEST':
        return 'SEND_FRIEND_REQUEST';
      case 'BLOCK_CONTACT':
        return 'BLOCK_USER';
      case 'UNBLOCK_CONTACT':
        return 'UNBLOCK_USER';
      case 'RENAME_GROUP':
      case 'CHANGE_GROUP_NAME':
        return 'CHANGE_GROUP_NAME';
      case 'ADD_MEMBER':
      case 'ADD_GROUP_MEMBER':
        return 'ADD_GROUP_MEMBER';
      case 'REMOVE_MEMBER':
      case 'REMOVE_GROUP_MEMBER':
        return 'REMOVE_GROUP_MEMBER';
      case 'TRANSFER_OWNER':
      case 'TRANSFER_GROUP_OWNER':
        return 'TRANSFER_GROUP_OWNER';
      case 'LEAVE_GROUP':
        return 'LEAVE_GROUP';
      case 'DELETE_GROUP':
      case 'DISBAND_GROUP':
        return 'DISBAND_GROUP';
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

  static String extractGroupName(Map<String, dynamic>? params) {
    return (params?['groupName'] ??
            params?['groupTitle'] ??
            params?['title'] ??
            params?['name'] ??
            '')
        .toString()
        .trim();
  }

  static List<String> extractMemberNames(Map<String, dynamic>? params) {
    final raw =
        params?['members'] ?? params?['memberNames'] ?? params?['users'];
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(RegExp(r'[,;|]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    final single =
        (params?['member'] ?? params?['memberName'] ?? '').toString().trim();
    return single.isEmpty ? const <String>[] : <String>[single];
  }

  static String? extractConversationName(Map<String, dynamic>? params) {
    final value =
        (params?['conversation'] ??
                params?['conversationName'] ??
                params?['group'] ??
                params?['groupName'])
            ?.toString()
            .trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? extractNewTitle(Map<String, dynamic>? params) {
    final value =
        (params?['newTitle'] ??
                params?['newName'] ??
                params?['title'] ??
                params?['groupName'])
            ?.toString()
            .trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? extractFriendRequestMessage(Map<String, dynamic>? params) {
    final value =
        (params?['message'] ?? params?['note'] ?? params?['content'])
            ?.toString()
            .trim();
    return value == null || value.isEmpty ? null : value;
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
