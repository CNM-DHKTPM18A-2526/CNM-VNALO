class AiTargetContext {
  final String targetName;
  final String? conversationId;
  final String? peerUserId;
  final DateTime updatedAt;

  const AiTargetContext({
    required this.targetName,
    this.conversationId,
    this.peerUserId,
    required this.updatedAt,
  });
}

class AiPendingAction {
  final String command;
  final Map<String, dynamic>? params;
  final String scope;
  final DateTime updatedAt;

  const AiPendingAction({
    required this.command,
    required this.params,
    required this.scope,
    required this.updatedAt,
  });
}

class AiActionContextStore {
  AiActionContextStore({
    Duration targetContextTtl = const Duration(minutes: 12),
    Duration pendingActionTtl = const Duration(minutes: 5),
  }) : _targetContextTtl = targetContextTtl,
       _pendingActionTtl = pendingActionTtl;

  final Duration _targetContextTtl;
  final Duration _pendingActionTtl;

  AiTargetContext? _targetContext;
  AiPendingAction? _pendingAction;

  void rememberTarget({
    required String targetName,
    String? conversationId,
    String? peerUserId,
    DateTime? now,
  }) {
    final normalizedTarget = targetName.trim();
    if (normalizedTarget.isEmpty) {
      return;
    }

    _targetContext = AiTargetContext(
      targetName: normalizedTarget,
      conversationId: conversationId?.trim(),
      peerUserId: peerUserId?.trim(),
      updatedAt: now ?? DateTime.now(),
    );
  }

  AiTargetContext? activeTarget({DateTime? now}) {
    final current = _targetContext;
    if (current == null) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(current.updatedAt) > _targetContextTtl) {
      _targetContext = null;
      return null;
    }
    return current;
  }

  void rememberPendingAction({
    required String command,
    required String scope,
    Map<String, dynamic>? params,
    DateTime? now,
  }) {
    _pendingAction = AiPendingAction(
      command: command,
      params: params == null ? null : Map<String, dynamic>.from(params),
      scope: scope,
      updatedAt: now ?? DateTime.now(),
    );
  }

  AiPendingAction? activePendingAction({DateTime? now}) {
    final current = _pendingAction;
    if (current == null) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(current.updatedAt) > _pendingActionTtl) {
      _pendingAction = null;
      return null;
    }
    return current;
  }

  void clearPendingAction() {
    _pendingAction = null;
  }

  Map<String, dynamic> injectSelectedNameIntoPendingParams(
    AiPendingAction pending,
    String selectedName,
  ) {
    final next =
        pending.params == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(pending.params!);

    switch (pending.scope) {
      case 'conversation':
        next['conversation'] = selectedName;
        next['conversationName'] = selectedName;
        next['group'] ??= selectedName;
        if (pending.command == 'OPEN_CHAT' ||
            pending.command == 'COMPOSE_MESSAGE' ||
            pending.command == 'START_CALL') {
          next['target'] = selectedName;
          next['recipient'] ??= selectedName;
        }
        break;
      case 'user':
      case 'contact':
      default:
        next['target'] = selectedName;
        next['recipient'] = selectedName;
        next['contactName'] = selectedName;
        next['name'] = selectedName;
        break;
    }

    return next;
  }
}