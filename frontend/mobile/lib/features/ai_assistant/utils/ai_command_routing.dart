class AiCommandRouting {
  static const Map<String, String> _vietnameseCharMap = {
    '\u00E0': 'a',
    '\u00E1': 'a',
    '\u1EA1': 'a',
    '\u1EA3': 'a',
    '\u00E3': 'a',
    '\u00E2': 'a',
    '\u1EA7': 'a',
    '\u1EA5': 'a',
    '\u1EAD': 'a',
    '\u1EA9': 'a',
    '\u1EAB': 'a',
    '\u0103': 'a',
    '\u1EB1': 'a',
    '\u1EAF': 'a',
    '\u1EB7': 'a',
    '\u1EB3': 'a',
    '\u1EB5': 'a',
    '\u00E8': 'e',
    '\u00E9': 'e',
    '\u1EB9': 'e',
    '\u1EBB': 'e',
    '\u1EBD': 'e',
    '\u00EA': 'e',
    '\u1EC1': 'e',
    '\u1EBF': 'e',
    '\u1EC7': 'e',
    '\u1EC3': 'e',
    '\u1EC5': 'e',
    '\u00EC': 'i',
    '\u00ED': 'i',
    '\u1ECB': 'i',
    '\u1EC9': 'i',
    '\u0129': 'i',
    '\u00F2': 'o',
    '\u00F3': 'o',
    '\u1ECD': 'o',
    '\u1ECF': 'o',
    '\u00F5': 'o',
    '\u00F4': 'o',
    '\u1ED3': 'o',
    '\u1ED1': 'o',
    '\u1ED9': 'o',
    '\u1ED5': 'o',
    '\u1ED7': 'o',
    '\u01A1': 'o',
    '\u1EDD': 'o',
    '\u1EDB': 'o',
    '\u1EE3': 'o',
    '\u1EDF': 'o',
    '\u1EE1': 'o',
    '\u00F9': 'u',
    '\u00FA': 'u',
    '\u1EE5': 'u',
    '\u1EE7': 'u',
    '\u0169': 'u',
    '\u01B0': 'u',
    '\u1EEB': 'u',
    '\u1EE9': 'u',
    '\u1EF1': 'u',
    '\u1EED': 'u',
    '\u1EEF': 'u',
    '\u1EF3': 'y',
    '\u00FD': 'y',
    '\u1EF5': 'y',
    '\u1EF7': 'y',
    '\u1EF9': 'y',
    '\u0111': 'd',
  };

  static String normalizeSearchText(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return '';

    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_vietnameseCharMap[char] ?? char);
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9+]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> tokenizeSearchText(String value) {
    final normalized = normalizeSearchText(value);
    if (normalized.isEmpty) return const <String>[];
    return normalized.split(' ');
  }

  static bool isFlexibleNameMatch(String label, String query) {
    final normalizedLabel = normalizeSearchText(label);
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedLabel.isEmpty || normalizedQuery.isEmpty) {
      return false;
    }
    if (normalizedLabel == normalizedQuery ||
        normalizedLabel.contains(normalizedQuery)) {
      return true;
    }

    final labelTokens = normalizedLabel.split(' ');
    final queryTokens = normalizedQuery.split(' ');
    if (queryTokens.isEmpty || queryTokens.length > labelTokens.length) {
      return false;
    }

    var cursor = 0;
    for (final queryToken in queryTokens) {
      var found = false;
      while (cursor < labelTokens.length) {
        final labelToken = labelTokens[cursor++];
        if (labelToken == queryToken || labelToken.startsWith(queryToken)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  static int computeNameMatchScore(String label, String query) {
    final normalizedLabel = normalizeSearchText(label);
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedLabel.isEmpty || normalizedQuery.isEmpty) {
      return -1;
    }
    if (normalizedLabel == normalizedQuery) {
      return 1000;
    }
    if (normalizedLabel.startsWith('$normalizedQuery ')) {
      return 920;
    }
    if (normalizedLabel.endsWith(' $normalizedQuery')) {
      return 910;
    }
    if (normalizedLabel.contains(normalizedQuery)) {
      return 860;
    }
    if (!isFlexibleNameMatch(normalizedLabel, normalizedQuery)) {
      return -1;
    }

    final labelTokens = tokenizeSearchText(normalizedLabel);
    final queryTokens = tokenizeSearchText(normalizedQuery);
    var score = 720;
    score += queryTokens.length * 20;

    if (labelTokens.isNotEmpty &&
        queryTokens.isNotEmpty &&
        labelTokens.first == queryTokens.first) {
      score += 30;
    }
    if (labelTokens.isNotEmpty &&
        queryTokens.isNotEmpty &&
        labelTokens.last == queryTokens.last) {
      score += 40;
    }

    final gapPenalty = labelTokens.length - queryTokens.length;
    score -= gapPenalty * 8;
    return score;
  }

  static String normalizeSystemAction(String command) {
    final normalizedLocalized = normalizeSearchText(command);
    switch (normalizedLocalized) {
      case 'mo settings':
      case 'cai dat':
        return 'NAVIGATE_TO_SETTINGS';
      case 'mo danh ba':
        return 'NAVIGATE_TO_CONTACTS';
      case 'mo chat':
        return 'NAVIGATE_TO_CHAT';
    }

    switch (command.trim().toUpperCase()) {
      case 'OPEN_CHAT':
      case 'OPEN_CONVERSATION':
      case 'GO_TO_CHAT':
        return 'OPEN_CHAT';
      case 'START_CALL':
      case 'CALL_CONTACT':
      case 'VOICE_CALL':
      case 'MAKE_CALL':
      case 'AUDIO_CALL':
      case 'START_VOICE_CALL':
      case 'VIDEO_CALL':
      case 'START_VIDEO_CALL':
        return 'START_CALL';
      case 'SEND_MESSAGE':
      case 'COMPOSE_MESSAGE':
      case 'MESSAGE_CONTACT':
      case 'SEND_TEXT':
      case 'SEND_CHAT':
      case 'TEXT_CONTACT':
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

  static String buildAmbiguousTargetFeedback({
    required String targetName,
    required Iterable<String> candidates,
    String actionLabel = 'tiếp tục',
  }) {
    final cleanTarget = targetName.trim();
    final uniqueCandidates = candidates
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(4)
        .toList(growable: false);

    if (uniqueCandidates.isEmpty) {
      return 'Có nhiều kết quả khớp "$cleanTarget". Hãy nói rõ hơn để trợ lý $actionLabel.';
    }

    return 'Mình tìm thấy nhiều kết quả cho "$cleanTarget": ${uniqueCandidates.join(', ')}. Bạn muốn chọn ai?';
  }

  static String buildMissingTargetFeedback({
    required String targetName,
    String targetType = 'người hoặc cuộc trò chuyện',
  }) {
    final cleanTarget = targetName.trim();
    if (cleanTarget.isEmpty) {
      return 'Mình chưa xác định được $targetType. Hãy nói rõ tên để trợ lý tiếp tục.';
    }
    return 'Mình chưa tìm thấy $targetType "$cleanTarget". Hãy kiểm tra lại tên hoặc thử nói rõ hơn.';
  }

  static String buildMissingTargetFeedbackForCommand({
    required String command,
    required String targetName,
  }) {
    final normalizedCommand = normalizeSystemAction(command);
    final targetType = switch (normalizedCommand) {
      'START_CALL' => 'liên hệ trong danh bạ',
      'COMPOSE_MESSAGE' => 'người nhận trong danh bạ',
      'OPEN_CHAT' => 'liên hệ hoặc cuộc trò chuyện',
      'OPEN_PROFILE' => 'liên hệ trong danh bạ',
      'SEND_FRIEND_REQUEST' => 'người dùng',
      'BLOCK_USER' || 'UNBLOCK_USER' => 'người dùng',
      _ => 'người hoặc cuộc trò chuyện',
    };

    return buildMissingTargetFeedback(
      targetName: targetName,
      targetType: targetType,
    );
  }

  static String buildMissingTargetFeedbackSourceForCommand(String command) {
    final normalizedCommand = normalizeSystemAction(command);
    return switch (normalizedCommand) {
      'START_CALL' ||
      'COMPOSE_MESSAGE' ||
      'OPEN_PROFILE' => 'ai_action_missing.contact',
      'SEND_FRIEND_REQUEST' ||
      'BLOCK_USER' ||
      'UNBLOCK_USER' => 'ai_action_missing.user',
      _ => 'ai_action_missing.conversation',
    };
  }

  static String buildAmbiguityFeedbackSource({
    required String scope,
    required Iterable<String> candidates,
  }) {
    final normalizedScope = scope.trim().isEmpty ? 'generic' : scope.trim();
    final encodedCandidates = candidates
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(6)
        .map(Uri.encodeComponent)
        .join(',');
    if (encodedCandidates.isEmpty) {
      return 'ai_action_ambiguity.$normalizedScope';
    }
    return 'ai_action_ambiguity.$normalizedScope::$encodedCandidates';
  }

  static List<String> parseAmbiguityCandidatesFromSource(String? source) {
    if (source == null || source.isEmpty) return const <String>[];
    final separatorIndex = source.indexOf('::');
    if (separatorIndex < 0 || separatorIndex == source.length - 1) {
      return const <String>[];
    }
    final payload = source.substring(separatorIndex + 2);
    return payload
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(Uri.decodeComponent)
        .toList(growable: false);
  }
}
