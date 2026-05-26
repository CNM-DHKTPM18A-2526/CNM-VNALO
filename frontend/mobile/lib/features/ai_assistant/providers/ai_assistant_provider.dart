import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/services/ai_stt_resilience_policy.dart';
import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/models/message_model.dart';
import 'package:vnalo_mobile/models/conversation_enums.dart';
import 'package:vnalo_mobile/services/ai_service.dart';
import 'package:vnalo_mobile/services/api_service.dart';

// ---------------------------------------------------------------------------
// Public enums
// ---------------------------------------------------------------------------

enum AiState { idle, listening, thinking, speaking }

enum AiThinkingPhase { idle, understanding, executingAction, composingResponse }

enum AiResponseSurface { bubble, conversation, contextual, voice }

// ---------------------------------------------------------------------------
// Text encoding normalization
// ---------------------------------------------------------------------------

String normalizeAiTextEncoding(String value) {
  var best = value;
  var bestScore = _mojibakeScore(best);

  for (var pass = 0; pass < 4; pass++) {
    final candidates = <String>{};

    final encodedBytes = _encodeWindows1252Bytes(best);
    if (encodedBytes != null) {
      candidates.add(utf8.decode(encodedBytes, allowMalformed: true));
    }

    final latin1Bytes = _encodeLatin1Bytes(best);
    if (latin1Bytes != null) {
      candidates.add(utf8.decode(latin1Bytes, allowMalformed: true));
    }

    String? improvedCandidate;
    var improvedScore = bestScore;

    for (final candidate in candidates) {
      if (candidate.trim().isEmpty || candidate == best) {
        continue;
      }

      final candidateScore = _mojibakeScore(candidate);
      if (candidateScore < improvedScore) {
        improvedCandidate = candidate;
        improvedScore = candidateScore;
      }
    }

    if (improvedCandidate == null) {
      break;
    }

    best = improvedCandidate;
    bestScore = improvedScore;
  }

  return best;
}

int _mojibakeScore(String value) {
  var score = 0;
  const markers = [
    '\u00C3',
    '\u00C4',
    '\u00C2',
    '\u00C6',
    '\u00C5',
    '\u00D0',
    '\u00E2\u20AC',
    '\u00E2\u20AC\u2122',
    '\u00E2\u20AC\u0153',
    '\u00E2\u20AC\u009d',
    '\u00F0\u0178',
    '\u00E1\u00BA',
    '\u00E1\u00BB',
    '\u00C4\u2018',
    '\u00C6\u00B0',
    '\u00C6\u00A1',
  ];

  for (final marker in markers) {
    score += marker.allMatches(value).length * 4;
  }

  for (final rune in value.runes) {
    if (rune == 0xfffd) {
      score += 10;
    } else if (rune >= 0x80 && rune <= 0x9f) {
      score += 6;
    }
  }

  return score - _vietnameseCharacterBonus(value);
}

List<int>? _encodeWindows1252Bytes(String value) {
  const cp1252Map = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune <= 0xff) {
      bytes.add(rune);
      continue;
    }

    final mapped = cp1252Map[rune];
    if (mapped == null) {
      return null;
    }
    bytes.add(mapped);
  }
  return bytes;
}

List<int>? _encodeLatin1Bytes(String value) {
  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune > 0xff) {
      return null;
    }
    bytes.add(rune);
  }
  return bytes;
}

int _vietnameseCharacterBonus(String value) {
  var bonus = 0;
  for (final rune in value.runes) {
    if (_isVietnameseCodePoint(rune)) {
      bonus += 1;
    }
  }
  return bonus.clamp(0, 24);
}

bool _isVietnameseCodePoint(int rune) {
  return rune == 0x0111 ||
      rune == 0x0110 ||
      (rune >= 0x0102 && rune <= 0x0103) ||
      (rune >= 0x01A0 && rune <= 0x01B0) ||
      (rune >= 0x1EA0 && rune <= 0x1EF9);
}

// ---------------------------------------------------------------------------
// Supporting data classes
// ---------------------------------------------------------------------------

enum AiConversationRole { user, assistant, system }

class AiConversationEntry {
  final String entryId;
  final AiConversationRole role;
  final String text;
  final String source;
  final DateTime createdAt;

  const AiConversationEntry({
    required this.entryId,
    required this.role,
    required this.text,
    required this.source,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'clientEntryId': entryId,
    'role': role.name,
    'content': text,
    'source': source,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory AiConversationEntry.fromJson(Map<String, dynamic> json) {
    final roleName = (json['role'] ?? 'assistant').toString();
    final resolvedRole = AiConversationRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => AiConversationRole.assistant,
    );

    final content = normalizeAiTextEncoding(
      (json['content'] ?? json['text'] ?? '').toString(),
    );
    final rawCreatedAt = (json['createdAt'] ?? '').toString();
    final parsedCreatedAt =
        DateTime.tryParse(rawCreatedAt)?.toUtc() ?? DateTime.now().toUtc();
    final rawEntryId = (json['entryId'] ?? json['clientEntryId'])?.toString();

    return AiConversationEntry(
      entryId:
          rawEntryId != null && rawEntryId.isNotEmpty
              ? rawEntryId
              : _legacyEntryId(resolvedRole, content, parsedCreatedAt),
      role: resolvedRole,
      text: content,
      source: (json['source'] ?? 'assistant_chat').toString(),
      createdAt: parsedCreatedAt,
    );
  }

  static String _legacyEntryId(
    AiConversationRole role,
    String content,
    DateTime createdAt,
  ) {
    var hash = 2166136261;
    final seed =
        '${role.name}|${createdAt.toUtc().microsecondsSinceEpoch}|$content';
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return 'legacy_${hash.toRadixString(16)}';
  }
}

class AiCommand {
  final String command;
  final dynamic params;
  final String commandId;
  final String traceId;
  final DateTime createdAt;

  AiCommand({
    required this.command,
    this.params,
    String? commandId,
    String? traceId,
    DateTime? createdAt,
  }) : commandId = commandId ?? const Uuid().v4(),
       traceId = traceId ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toLogMap() => {
    'command': command,
    'commandId': commandId,
    'traceId': traceId,
    'createdAt': createdAt.toIso8601String(),
  };
}

class AiDisambiguationSelection {
  final String selectedName;
  final String source;
  final DateTime createdAt;

  const AiDisambiguationSelection({
    required this.selectedName,
    required this.source,
    required this.createdAt,
  });
}

class AiClarificationState {
  final String message;
  final String source;
  final List<String> candidates;
  final DateTime createdAt;

  const AiClarificationState({
    required this.message,
    required this.source,
    required this.candidates,
    required this.createdAt,
  });

  bool get isAmbiguous => source.startsWith('ai_action_ambiguity');
  bool get isMissingTarget => source.startsWith('ai_action_missing');
}

// ---------------------------------------------------------------------------
// AiAssistantProvider
//
// Architecture notes (not enforced via mixins to avoid Dart mixin conflicts):
// - AiSessionController responsibilities: state management, STT/TTS lifecycle,
//   sound level, listen guard timer
// - AiSurfaceController responsibilities: visibility state, auto-hide timer,
//   surface routing (bubble vs conversation vs contextual)
// - AiHistoryStore responsibilities: conversation history, cloud backup/sync
// - AiCommandRouter responsibilities: stateless — delegates to MainShell via
//   systemActionStream. Shared helpers live here; routing logic lives in
//   MainShell._handleAiSystemAction()
// ---------------------------------------------------------------------------

class AiAssistantProvider with ChangeNotifier {
  // ------------------------- Constants ---------------------------------------
  static const String _visibilityPrefKey = 'vnalo_ai_is_visible';
  static const String _mascotPrefKey = 'vnalo_ai_mascot_id';
  static const String _historyPrefKey = 'vnalo_ai_history_v1';
  static const String _conversationCreatedPrefKey =
      'vnalo_ai_conversation_created';
  static const String _cloudBackupPrefKey = 'vnalo_ai_cloud_backup_enabled';
  static const String _serverConversationIdPrefKey =
      'vnalo_ai_server_conversation_id';
  static const String _syncedEntryIdsPrefKey = 'vnalo_ai_synced_entry_ids_v1';
  static const String _guestScopeKey = 'guest';
  static const String _defaultLocaleId = 'vi_VN';
  static const Duration _aiTimeout = Duration(seconds: 25);
  static const Duration _sttListenFor = Duration(seconds: 10);
  static const Duration _sttPauseFor = Duration(seconds: 10);
  static const Duration _idleAutoHideDelay = Duration(seconds: 12);
  static const Duration _emptySummonAutoHideDelay = Duration(seconds: 10);
  static const int _maxConversationEntries = 200;
  static const String aiConversationId = '00000000-0000-0000-0000-000000000000';
  static const String _legacyAiConversationId = 'AI_ASSISTANT_LOCAL';

  static bool isAiConversationId(String? conversationId) {
    return conversationId == aiConversationId ||
        conversationId == _legacyAiConversationId;
  }

  // ------------------------- Dependencies ------------------------------------
  final AiService _aiService;
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  final Uuid _uuid = const Uuid();

  // ------------------------- Session state (AiSessionController) --------------
  AiState _state = AiState.idle;
  String _lastWords = '';
  String _lastUserPrompt = '';
  String _aiResponse = '';
  String _currentEmotion = 'neutral';
  AiThinkingPhase _thinkingPhase = AiThinkingPhase.idle;
  bool _isResponseDegraded = false;
  String _providerStatus = 'LIVE_PROVIDER_ACTIVE';
  double _soundLevel = 0;
  bool _isSessionActive = false;
  bool _isSttInitialized = false;
  bool _isPipelineLocked = false;
  int _operationToken = 0;
  String _activeTraceId = '';
  String? _resolvedLocaleId;
  Timer? _listenGuardTimer;
  Timer? _sttRestartTimer;
  DateTime? _listenStartedAt;
  DateTime? _lastFinalResultAt;
  String _lastFinalResultText = '';
  DateTime? _lastSoundLevelNotifyAt;

  // ------------------------- Surface state (AiSurfaceController) -------------
  bool _persistentEnabled = false;
  bool _provisionallyVisible = false;
  AiResponseSurface _activeSurface = AiResponseSurface.bubble;
  AiResponseSurface _lastResponseSurface = AiResponseSurface.bubble;
  DateTime? _keepVisibleUntil;
  Timer? _idleAutoHideTimer;

  // ------------------------- History state (AiHistoryStore) ------------------
  bool _conversationCreated = false;
  bool _cloudBackupEnabled = false;
  String? _serverConversationId;
  String _activeScopeKey = _guestScopeKey;
  final Set<String> _syncedEntryIds = <String>{};
  final List<AiConversationEntry> _conversationHistory = [];
  final List<Map<String, String>> _sessionHistory = [];
  Timer? _cloudBackupDebounceTimer;
  int _historyClearGeneration = 0;

  // ------------------------- Other ------------------------------------------
  MascotMetadata _currentMascot = MascotMetadata.defaultMascots.first;
  final bool _enableDeepSummary = false;
  final bool _enableFlowLogging;
  final StreamController<AiCommand> _systemActionController =
      StreamController<AiCommand>.broadcast();
  final StreamController<AiDisambiguationSelection>
  _disambiguationSelectionController =
      StreamController<AiDisambiguationSelection>.broadcast();
  AiClarificationState? _clarificationState;
  bool _isDisposed = false;

  // ------------------------- Construction -----------------------------------
  AiAssistantProvider(this._aiService, {bool enableFlowLogging = true})
    : _enableFlowLogging = enableFlowLogging {
    _activeTraceId = _uuid.v4();
    _initTts();
    unawaited(_initPersistence());
  }

  String get _scopedHistoryPrefKey => _scopedPrefKey(_historyPrefKey);
  String get _scopedConversationCreatedPrefKey =>
      _scopedPrefKey(_conversationCreatedPrefKey);
  String get _scopedCloudBackupPrefKey => _scopedPrefKey(_cloudBackupPrefKey);
  String get _scopedServerConversationIdPrefKey =>
      _scopedPrefKey(_serverConversationIdPrefKey);
  String get _scopedSyncedEntryIdsPrefKey =>
      _scopedPrefKey(_syncedEntryIdsPrefKey);

  String _scopedPrefKey(String baseKey) => '${baseKey}_$_activeScopeKey';

  String _resolveScopeKey(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _guestScopeKey;
    }
    return normalized;
  }

  // ------------------------- Public getters ---------------------------------
  MascotMetadata get currentMascot => _currentMascot;
  AiState get state => _state;
  String get lastWords => _lastWords;
  String get lastUserPrompt => _lastUserPrompt;
  String get aiResponse => _aiResponse;
  bool get isResponseDegraded => _isResponseDegraded;
  String get providerStatus => _providerStatus;
  AiResponseSurface get lastResponseSurface => _lastResponseSurface;
  bool get shouldBubbleAutoShowResponse =>
      _lastResponseSurface == AiResponseSurface.bubble ||
      _lastResponseSurface == AiResponseSurface.voice ||
      _lastResponseSurface == AiResponseSurface.contextual;
  String get currentEmotion => _currentEmotion;
  AiThinkingPhase get thinkingPhase => _thinkingPhase;
  bool get isProviderUnavailable =>
      _providerStatus == 'AI_PROVIDER_UNAVAILABLE';
  bool get isFallbackProviderActive =>
      _providerStatus == 'FALLBACK_PROVIDER_ACTIVE';
  bool get isAssistantGenerating => _state == AiState.thinking;
  String get assistantActivityLabel {
    if (_state == AiState.listening) {
      return 'Đang lắng nghe...';
    }
    if (_state == AiState.speaking) {
      return 'Đang phản hồi...';
    }
    if (_state != AiState.thinking) {
      return 'Đang hoạt động';
    }

    return switch (_thinkingPhase) {
      AiThinkingPhase.understanding => 'Đang hiểu yêu cầu...',
      AiThinkingPhase.executingAction => 'Đang thực hiện thao tác...',
      AiThinkingPhase.composingResponse => 'Đang soạn phản hồi...',
      AiThinkingPhase.idle => 'Đang xử lý...',
    };
  }

  double get soundLevel => _soundLevel;

  bool get persistentEnabled => _persistentEnabled;
  bool get provisionallyVisible => _provisionallyVisible;
  bool get isSessionActive => _isSessionActive;
  bool get cloudBackupEnabled => _cloudBackupEnabled;
  bool get hasConversation =>
      _conversationCreated || _conversationHistory.isNotEmpty;
  List<AiConversationEntry> get conversationHistory =>
      List.unmodifiable(_conversationHistory);
  AiConversationEntry? get lastConversationEntry =>
      _conversationHistory.isEmpty ? null : _conversationHistory.last;
  DateTime? get lastConversationAt => lastConversationEntry?.createdAt;
  String get lastConversationPreview {
    final entry = lastConversationEntry;
    if (entry == null) {
      return 'Bắt đầu hội thoại với trợ lý AI';
    }

    final prefix =
        entry.role == AiConversationRole.user
            ? 'Bạn: '
            : entry.role == AiConversationRole.assistant
            ? 'AI: '
            : '';
    return '$prefix${entry.text.replaceAll('\n', ' ')}'.trim();
  }

  bool get isBusy => _state != AiState.idle || _isPipelineLocked;
  bool get isMascotVisible =>
      _activeSurface != AiResponseSurface.conversation &&
      (_persistentEnabled || _provisionallyVisible || _isSessionActive);

  Stream<AiCommand> get systemActionStream => _systemActionController.stream;
  Stream<AiDisambiguationSelection> get disambiguationSelectionStream =>
      _disambiguationSelectionController.stream;
  AiClarificationState? get clarificationState => _clarificationState;

  Future<void> bindAuthUser(String? userId) async {
    final nextScopeKey = _resolveScopeKey(userId);
    if (_activeScopeKey == nextScopeKey || _isDisposed) {
      return;
    }

    _cancelActiveOperation(reason: 'auth_scope_change');
    await _stopAllInteractions(
      reason: 'auth_scope_change',
      keepResponse: false,
    );
    _cancelIdleAutoHide();
    _cloudBackupDebounceTimer?.cancel();

    _activeScopeKey = nextScopeKey;
    _resetScopedConversationState(clearCurrentResponse: true);

    final prefs = await SharedPreferences.getInstance();
    await _loadScopedPersistence(prefs: prefs, notify: false);

    _logEvent(
      'AUTH_SCOPE_BOUND',
      data: {
        'scopeKey': _activeScopeKey,
        'historySize': _conversationHistory.length,
      },
    );
    notifyListeners();
  }

  void addActionFeedback(
    String message, {
    String source = 'ai_action_feedback',
    bool keepBubbleVisible = false,
    AiResponseSurface? responseSurface,
  }) {
    final normalized = normalizeAiTextEncoding(message).trim();
    if (normalized.isEmpty) {
      return;
    }

    final resolvedSurface =
        responseSurface ??
        (keepBubbleVisible && _activeSurface != AiResponseSurface.conversation
            ? _activeSurface
            : AiResponseSurface.conversation);

    _aiResponse = normalized;
    _lastResponseSurface = resolvedSurface;
    if (source.startsWith('ai_action_ambiguity') ||
        source.startsWith('ai_action_missing')) {
      _clarificationState = AiClarificationState(
        message: normalized,
        source: source,
        candidates: AiCommandRouting.parseAmbiguityCandidatesFromSource(source),
        createdAt: DateTime.now().toUtc(),
      );
    }
    _addConversationEntry(
      role: AiConversationRole.assistant,
      text: normalized,
      source: source,
    );

    if (keepBubbleVisible && _activeSurface != AiResponseSurface.conversation) {
      _setProvisionallyVisible(true, reason: '$source.visible');
      _scheduleIdleAutoHide(reason: source);
    }
  }

  void submitDisambiguationSelection(
    String selectedName, {
    String source = 'ai_disambiguation_chip',
  }) {
    final normalized = normalizeAiTextEncoding(selectedName).trim();
    if (normalized.isEmpty) {
      return;
    }
    _recordUserHistory(
      text: 'Mình muốn chọn $normalized',
      source: source,
      entryId: _newEntryId(),
    );
    _clarificationState = null;
    if (!_disambiguationSelectionController.isClosed) {
      _disambiguationSelectionController.add(
        AiDisambiguationSelection(
          selectedName: normalized,
          source: source,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  List<Message> getHistoryAsMessages(
    String currentUserId, {
    String? userAvatarUrl,
  }) {
    return _conversationHistory.map((entry) {
      final isUser = entry.role == AiConversationRole.user;
      return Message(
        id: 'ai_msg_${entry.entryId}',
        conversationId: aiConversationId,
        senderId: isUser ? currentUserId : 'ai_assistant',
        senderName: isUser ? 'Bạn' : currentMascot.name,
        senderAvatarUrl: isUser ? userAvatarUrl : currentMascot.previewImageUrl,
        clientMessageId: entry.source,
        content: entry.text,
        messageType: MessageType.TEXT,
        status: MessageStatus.SENT,
        createdAt: entry.createdAt,
      );
    }).toList();
  }

  // ==================== SURFACE HELPERS =================================
  // (AiSurfaceController responsibilities)

  AiResponseSurface _surfaceForSource(String source) {
    final normalized = source.trim().toLowerCase();

    if (normalized == 'ai_conversation_screen' ||
        normalized.startsWith('ai_conversation_') ||
        normalized.contains('conversation_screen') ||
        normalized.contains('conversation')) {
      return AiResponseSurface.conversation;
    }
    if (normalized.contains('voice') ||
        normalized.contains('stt') ||
        normalized.contains('mic')) {
      return AiResponseSurface.voice;
    }
    if (normalized.contains('contextual')) {
      return AiResponseSurface.contextual;
    }
    return AiResponseSurface.bubble;
  }

  AiResponseSurface _resolveSurface(
    String source, {
    AiResponseSurface? explicitSurface,
  }) {
    return explicitSurface ?? _surfaceForSource(source);
  }

  void enterConversationSurface({String reason = 'conversation_open'}) {
    _cancelIdleAutoHide();
    _keepVisibleUntil = null;
    _activeSurface = AiResponseSurface.conversation;
    if (_provisionallyVisible) {
      _provisionallyVisible = false;
    }
    _logEvent('SURFACE_ENTER_CONVERSATION', data: {'reason': reason});
    notifyListeners();
  }

  void leaveConversationSurface({String reason = 'conversation_close'}) {
    if (_activeSurface != AiResponseSurface.conversation) {
      return;
    }
    _activeSurface = AiResponseSurface.bubble;
    if (_persistentEnabled || _isSessionActive || _aiResponse.isNotEmpty) {
      _provisionallyVisible = true;
      if (!_persistentEnabled &&
          _state == AiState.idle &&
          _aiResponse.isEmpty &&
          !_isSessionActive) {
        _scheduleIdleAutoHide(reason: reason);
      }
    }
    _logEvent('SURFACE_LEAVE_CONVERSATION', data: {'reason': reason});
    notifyListeners();
  }

  void _setProvisionallyVisible(bool visible, {required String reason}) {
    if (_provisionallyVisible == visible) {
      return;
    }
    _provisionallyVisible = visible;
    _logEvent(
      'VISIBILITY_CONTEXTUAL_SET',
      data: {'visible': visible, 'reason': reason},
    );
    notifyListeners();
  }

  void _scheduleIdleAutoHide({required String reason}) {
    _idleAutoHideTimer?.cancel();
    if (_persistentEnabled) {
      return;
    }

    _idleAutoHideTimer = Timer(_idleAutoHideDelay, () {
      // HARDEN(late-callback): guard against timer firing after dispose
      if (_isDisposed ||
          _persistentEnabled ||
          _isSessionActive ||
          _state != AiState.idle ||
          _aiResponse.isNotEmpty ||
          !_provisionallyVisible) {
        return;
      }

      _provisionallyVisible = false;
      _logEvent(
        'VISIBILITY_AUTO_HIDE',
        data: {'reason': reason, 'delayMs': _idleAutoHideDelay.inMilliseconds},
      );
      notifyListeners();
    });
  }

  void _cancelIdleAutoHide() {
    _idleAutoHideTimer?.cancel();
    _idleAutoHideTimer = null;
  }

  void _syncVisibilityAfterSession() {
    if (_isSessionActive) {
      return;
    }
    if (!_persistentEnabled &&
        _aiResponse.isEmpty &&
        _keepVisibleUntil != null &&
        DateTime.now().isBefore(_keepVisibleUntil!) &&
        _activeSurface != AiResponseSurface.conversation) {
      _scheduleIdleAutoHide(reason: 'keep_visible_window');
      return;
    }
    if (!_persistentEnabled && _aiResponse.isEmpty) {
      _provisionallyVisible = false;
    }
  }

  // ==================== SESSION HELPERS ==================================
  // (AiSessionController responsibilities)

  void _transitionTo(
    AiState next, {
    required String reason,
    String? traceId,
    bool notify = true,
  }) {
    final previous = _state;
    _state = next;

    if (next != AiState.thinking) {
      _thinkingPhase = AiThinkingPhase.idle;
    }

    _logEvent(
      'STATE_CHANGE',
      traceId: traceId,
      data: {'from': previous.name, 'to': next.name, 'reason': reason},
    );

    if (notify) {
      notifyListeners();
    }
  }

  void _startListenGuard({required int token, required String traceId}) {
    _cancelListenGuard();
    _listenGuardTimer = Timer(
      _sttListenFor,
      () =>
          unawaited(_handleListenGuardTimeout(token: token, traceId: traceId)),
    );
  }

  void _cancelListenGuard() {
    _listenGuardTimer?.cancel();
    _listenGuardTimer = null;
    _sttRestartTimer?.cancel();
    _sttRestartTimer = null;
  }

  Duration _elapsedListeningTime() {
    final startedAt = _listenStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  bool _hasCapturedFinalTranscript() {
    return _lastFinalResultAt != null && _lastFinalResultText.trim().isNotEmpty;
  }

  bool _shouldIgnorePrematureSttEnd({required bool isPermanentError}) {
    return AiSttResiliencePolicy.shouldHoldListening(
      isListening: _state == AiState.listening,
      isPipelineLocked: _isPipelineLocked,
      hasCapturedFinalTranscript: _hasCapturedFinalTranscript(),
      elapsed: _elapsedListeningTime(),
      minimumListenFor: _sttListenFor,
      isPermanentError: isPermanentError,
    );
  }

  void _restartListeningUntilGuardWindow({
    required String reason,
    required int token,
    required String traceId,
  }) {
    if (!_shouldIgnorePrematureSttEnd(isPermanentError: false)) {
      return;
    }

    _sttRestartTimer?.cancel();
    _sttRestartTimer = Timer(const Duration(milliseconds: 180), () async {
      if (!_isCurrentOperation(token) ||
          _state != AiState.listening ||
          _isPipelineLocked ||
          !_shouldIgnorePrematureSttEnd(isPermanentError: false)) {
        return;
      }

      try {
        await _stt.listen(
          onResult:
              (result) =>
                  _handleSpeechResult(result, token: token, traceId: traceId),
          onSoundLevelChange: _handleSoundLevelChange,
          listenFor: _sttListenFor,
          pauseFor: _sttPauseFor,
          localeId: _resolvedLocaleId ?? _defaultLocaleId,
          listenOptions: SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
            listenMode: ListenMode.dictation,
          ),
        );
        _logEvent(
          'STT_LISTEN_RESTARTED',
          traceId: traceId,
          data: {
            'reason': reason,
            'elapsedMs': _elapsedListeningTime().inMilliseconds,
            'minimumMs': _sttListenFor.inMilliseconds,
          },
        );
      } catch (error) {
        _logEvent(
          'STT_RESTART_ERROR',
          traceId: traceId,
          level: 'WARN',
          data: {'error': error.toString(), 'reason': reason},
        );
      }
    });
  }

  void _handleSpeechResult(
    dynamic result, {
    required int token,
    required String traceId,
  }) {
    if (!_isCurrentOperation(token)) {
      return;
    }

    _lastWords = result.recognizedWords.trim();
    notifyListeners();

    if (result.finalResult &&
        _lastWords.isNotEmpty &&
        !_isDuplicateFinalResult(_lastWords)) {
      _lastFinalResultAt = DateTime.now();
      _lastFinalResultText = _lastWords;
      _lastResponseSurface = _activeSurface;
      unawaited(_handleCommand(_lastWords, parentTraceId: traceId));
    }
  }

  void _handleSttTerminalStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if ((normalized != 'done' && normalized != 'notlistening') ||
        _state != AiState.listening ||
        _isPipelineLocked) {
      return;
    }

    if (_shouldIgnorePrematureSttEnd(isPermanentError: false)) {
      _logEvent(
        'STT_EARLY_DONE_IGNORED',
        data: {
          'status': normalized,
          'elapsedMs': _elapsedListeningTime().inMilliseconds,
          'minimumMs': _sttListenFor.inMilliseconds,
          'hasFinalTranscript': _hasCapturedFinalTranscript(),
          'lastWordsLength': _lastWords.length,
        },
      );
      _restartListeningUntilGuardWindow(
        reason: 'terminal_status:$normalized',
        token: _operationToken,
        traceId: _activeTraceId,
      );
      return;
    }

    _finishListeningFromStt(reason: 'stt_done_status');
  }

  void _finishListeningFromStt({required String reason}) {
    _cancelListenGuard();
    _listenStartedAt = null;
    _isSessionActive = false;
    _soundLevel = 0;
    _transitionTo(AiState.idle, reason: reason, notify: false);
    if (_lastWords.isEmpty) {
      _aiResponse = '';
      _scheduleIdleAutoHide(reason: '${reason}_no_words');
    }
    _syncVisibilityAfterSession();
    notifyListeners();
  }

  void _handleSoundLevelChange(double rawLevel) {
    if (_state != AiState.listening) {
      return;
    }

    final normalized = (((rawLevel + 2) / 12).clamp(0.0, 1.0)).toDouble();
    final smoothed = (_soundLevel * 0.64) + (normalized * 0.36);

    if ((_soundLevel - smoothed).abs() < 0.008) {
      return;
    }

    _soundLevel = smoothed;
    final now = DateTime.now();
    if (_lastSoundLevelNotifyAt == null ||
        now.difference(_lastSoundLevelNotifyAt!) >=
            const Duration(milliseconds: 50)) {
      _lastSoundLevelNotifyAt = now;
      notifyListeners();
    }
  }

  int _beginOperation({required String traceId}) {
    _operationToken += 1;
    _activeTraceId = traceId;
    return _operationToken;
  }

  void _cancelActiveOperation({required String reason}) {
    _operationToken += 1;
    _isPipelineLocked = false;
    _cancelListenGuard();
    _listenStartedAt = null;
    _logEvent('PIPELINE_CANCELLED', level: 'WARN', data: {'reason': reason});
  }

  bool _isCurrentOperation(int token) => token == _operationToken;

  // ==================== PERSISTENCE =======================================

  Future<void> _initPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadMascot(prefs: prefs);
    _persistentEnabled = prefs.getBool(_visibilityPrefKey) ?? false;
    await _loadScopedPersistence(prefs: prefs, notify: false);

    _logEvent(
      'PERSISTENCE_LOADED',
      data: {
        'persistentEnabled': _persistentEnabled,
        'scopeKey': _activeScopeKey,
        'mascotId': _currentMascot.id,
        'cloudBackupEnabled': _cloudBackupEnabled,
        'hasConversation': hasConversation,
        'historySize': _conversationHistory.length,
        'serverConversationId': _serverConversationId,
      },
    );
    notifyListeners();
  }

  Future<void> _loadScopedPersistence({
    required SharedPreferences prefs,
    bool notify = true,
  }) async {
    _cloudBackupEnabled = prefs.getBool(_scopedCloudBackupPrefKey) ?? false;
    _conversationCreated =
        prefs.getBool(_scopedConversationCreatedPrefKey) ?? false;
    _serverConversationId = prefs.getString(_scopedServerConversationIdPrefKey);
    await _loadConversationHistory(prefs: prefs);
    _loadSyncedEntryIds(prefs: prefs);

    if (_cloudBackupEnabled && _serverConversationId != null) {
      unawaited(_restoreConversationHistoryFromServer());
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _loadConversationHistory({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_scopedHistoryPrefKey);
    _conversationHistory.clear();
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _conversationHistory
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map((item) {
              final casted = item.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              return AiConversationEntry.fromJson(casted);
            }).toList(),
          );
      }
    } catch (error) {
      _logEvent(
        'CONVERSATION_HISTORY_LOAD_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  void _loadSyncedEntryIds({required SharedPreferences prefs}) {
    final ids =
        prefs.getStringList(_scopedSyncedEntryIdsPrefKey) ?? const <String>[];
    _syncedEntryIds
      ..clear()
      ..addAll(ids.where((id) => id.trim().isNotEmpty));
  }

  void _resetScopedConversationState({bool clearCurrentResponse = false}) {
    _conversationHistory.clear();
    _syncedEntryIds.clear();
    _conversationCreated = false;
    _cloudBackupEnabled = false;
    _sessionHistory.clear();
    _lastUserPrompt = '';
    _serverConversationId = null;
    _clarificationState = null;
    if (clearCurrentResponse) {
      _aiResponse = '';
    }
  }

  Future<void> _loadMascot({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final mascotId = store.getString(_mascotPrefKey);
    if (mascotId == null) {
      return;
    }

    final found = MascotMetadata.defaultMascots.firstWhere(
      (m) => m.id == mascotId,
      orElse: () => MascotMetadata.defaultMascots.first,
    );
    _currentMascot = found;
  }

  // ==================== LIFECYCLE ==========================================

  @override
  void dispose() {
    _isDisposed = true;
    _cancelListenGuard();
    _cancelIdleAutoHide();
    _cloudBackupDebounceTimer?.cancel();
    unawaited(_stt.cancel());
    unawaited(_tts.stop());
    _systemActionController.close();
    _disambiguationSelectionController.close();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }
    super.notifyListeners();
  }

  // ==================== PUBLIC API ========================================

  Future<void> setMascot(MascotMetadata mascot) async {
    _currentMascot = mascot;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mascotPrefKey, mascot.id);

    _logEvent(
      'MASCOT_SET',
      data: {'mascotId': mascot.id, 'renderMode': mascot.renderMode.name},
    );
    notifyListeners();
  }

  Future<void> toggleMascot() async {
    await setPersistentEnabled(!_persistentEnabled, reason: 'toggle');
  }

  Future<void> setPersistentEnabled(
    bool enabled, {
    String reason = 'user_intent',
  }) async {
    _persistentEnabled = enabled;
    if (!enabled && !_isSessionActive && _aiResponse.isEmpty) {
      _provisionallyVisible = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibilityPrefKey, enabled);

    _logEvent(
      'VISIBILITY_PERSISTENT_SET',
      data: {'enabled': enabled, 'reason': reason},
    );
    notifyListeners();
  }

  Future<void> setCloudBackupEnabled(
    bool enabled, {
    String reason = 'settings',
  }) async {
    _cloudBackupEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedCloudBackupPrefKey, enabled);

    _logEvent('CLOUD_BACKUP_SET', data: {'enabled': enabled, 'reason': reason});

    if (enabled) {
      _scheduleCloudBackup();
      if (_conversationHistory.isEmpty && _serverConversationId != null) {
        unawaited(_restoreConversationHistoryFromServer());
      }
    }

    notifyListeners();
  }

  Future<void> clearConversationHistory({
    bool clearCurrentResponse = false,
    String reason = 'manual',
  }) async {
    final serverConversationIdToDelete = _serverConversationId;
    _historyClearGeneration++;
    _cloudBackupDebounceTimer?.cancel();
    _cancelActiveOperation(reason: 'history_clear:$reason');
    await _stopAllInteractions(
      reason: 'history_clear:$reason',
      keepResponse: !clearCurrentResponse,
    );

    _conversationHistory.clear();
    _syncedEntryIds.clear();
    _conversationCreated = false;
    _sessionHistory.clear();
    _lastUserPrompt = '';
    _serverConversationId = null;

    if (clearCurrentResponse) {
      _aiResponse = '';
      _scheduleIdleAutoHide(reason: 'conversation_history_cleared');
      _syncVisibilityAfterSession();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedHistoryPrefKey);
    await prefs.remove(_scopedServerConversationIdPrefKey);
    await prefs.remove(_scopedSyncedEntryIdsPrefKey);
    await prefs.setBool(_scopedConversationCreatedPrefKey, false);

    _logEvent(
      'CONVERSATION_HISTORY_CLEARED',
      data: {'reason': reason, 'clearCurrentResponse': clearCurrentResponse},
    );
    notifyListeners();

    if (serverConversationIdToDelete != null &&
        serverConversationIdToDelete.isNotEmpty) {
      unawaited(_deleteCloudConversationHistory(serverConversationIdToDelete));
    }
  }

  Future<void> _deleteCloudConversationHistory(String conversationId) async {
    try {
      await _aiService.deleteConversationHistory(
        conversationId: conversationId,
      );
    } catch (error) {
      _logEvent(
        'CLOUD_HISTORY_DELETE_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  Future<void> deleteMessage(String messageId) {
    _logEvent(
      'AI_MESSAGE_DELETE_IGNORED',
      level: 'WARN',
      data: {'messageId': messageId, 'reason': 'per_message_delete_disabled'},
    );
    return Future<void>.value();
  }

  Future<void> hideMascot({String reason = 'user_hide'}) async {
    _cancelIdleAutoHide();
    _cancelActiveOperation(reason: reason);
    await _stopAllInteractions(reason: reason, keepResponse: false);

    _persistentEnabled = false;
    _provisionallyVisible = false;
    _aiResponse = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibilityPrefKey, false);

    _logEvent('MASCOT_HIDE', data: {'reason': reason});
    notifyListeners();
  }

  /// Summons the mascot bubble. If `persist` is true the bubble stays visible
  /// persistently; otherwise it is shown provisionally and auto-hides after
  /// [_emptySummonAutoHideDelay] if no interaction occurs.
  ///
  /// HARDEN(flow-discover): sets _provisionallyVisible + _keepVisibleUntil
  /// before starting listening so the bubble is guaranteed visible at summon
  /// time. This prevents the bubble from disappearing before it even renders.
  Future<void> summonMascot({
    bool startListening = true,
    bool persist = false,
    String source = 'discover',
    AiResponseSurface? startListeningSurface,
  }) async {
    if (persist) {
      await setPersistentEnabled(true, reason: '$source.persist');
    } else {
      _provisionallyVisible = true;
      final summonHoldWindow =
          startListening ? _sttListenFor : _emptySummonAutoHideDelay;
      _keepVisibleUntil = DateTime.now().add(summonHoldWindow);
      _logEvent(
        'VISIBILITY_SUMMON_CONTEXTUAL',
        data: {
          'source': source,
          'autoHideMs': summonHoldWindow.inMilliseconds,
          'startListening': startListening,
        },
      );
      notifyListeners();
    }

    if (startListening) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (_isDisposed || _state == AiState.listening) {
        return;
      }
      await onPrimaryAction(
        source: '$source.auto_listen',
        surface: startListeningSurface,
      );
    }
  }

  Future<void> onPrimaryAction({
    String source = 'bubble',
    AiResponseSurface? surface,
  }) async {
    final resolvedSurface = _resolveSurface(source, explicitSurface: surface);
    final keepBubbleVisible = resolvedSurface != AiResponseSurface.conversation;

    if (_state == AiState.listening) {
      await stopListening(
        reason: '$source.toggle_stop',
        keepBubbleVisible: keepBubbleVisible,
      );
      return;
    }

    if (_state == AiState.thinking || _state == AiState.speaking) {
      await stopCurrentPipeline(reason: '$source.interrupt');
      return;
    }

    await startListening(source: source, surface: resolvedSurface);
  }

  // ==================== STT / TTS ========================================

  void _initTts() {
    unawaited(_tts.awaitSpeakCompletion(true));
    unawaited(_tts.setLanguage('vi-VN'));
    unawaited(_tts.setPitch(1.0));
    unawaited(_tts.setSpeechRate(0.5));

    _tts.setStartHandler(() {
      _logEvent('TTS_START');
    });
    _tts.setCompletionHandler(() {
      _logEvent('TTS_COMPLETE');
    });
    _tts.setCancelHandler(() {
      _logEvent('TTS_CANCEL', level: 'WARN');
    });
    _tts.setErrorHandler((message) {
      _logEvent('TTS_ERROR', level: 'ERROR', data: {'message': message});
      // HARDEN(late-callback): guard against TTS callback after dispose
      if (_isDisposed) return;
      if (_state == AiState.speaking) {
        _transitionTo(AiState.idle, reason: 'tts_error');
        _isSessionActive = false;
        _syncVisibilityAfterSession();
      }
    });
  }

  Future<void> startListening({
    String source = 'bubble',
    AiResponseSurface? surface,
  }) async {
    if (_state == AiState.listening) {
      _logEvent(
        'STT_START_SKIPPED',
        data: {'reason': 'already_listening', 'source': source},
      );
      return;
    }

    if (_isPipelineLocked) {
      _logEvent(
        'STT_START_SKIPPED',
        level: 'WARN',
        data: {'reason': 'pipeline_locked', 'source': source},
      );
      return;
    }

    final resolvedSurface = _resolveSurface(source, explicitSurface: surface);
    _activeSurface = resolvedSurface;
    _lastResponseSurface = resolvedSurface;

    final traceId = _newTraceId('stt');
    final token = _beginOperation(traceId: traceId);
    await _ensureConversationCreated(source: '$source.voice_interaction');

    _cancelIdleAutoHide();
    _cancelListenGuard();
    _soundLevel = 0;
    _lastFinalResultAt = null;
    _lastFinalResultText = '';
    if (resolvedSurface != AiResponseSurface.conversation) {
      _setProvisionallyVisible(true, reason: 'stt_start:$source');
    }

    try {
      await _tts.stop();
    } catch (error) {
      _logEvent(
        'TTS_STOP_ERROR',
        traceId: traceId,
        level: 'WARN',
        data: {'error': error.toString(), 'source': source},
      );
    }

    final available = await _ensureSttInitialized();
    if (!_isCurrentOperation(token)) {
      return;
    }

    // HARDEN(mic-permission): when mic unavailable/permission denied, the
    // bubble stays visible (not stuck) and shows an error message. State is
    // always reset to idle — no orphan listening states.
    if (!available) {
      _cancelActiveOperation(reason: 'stt_unavailable:$source');
      _isSessionActive = false;
      _aiResponse = 'Thiết bị chưa sẵn sàng micro để nghe lệnh.';
      _transitionTo(AiState.idle, reason: 'stt_unavailable', traceId: traceId);
      if (resolvedSurface != AiResponseSurface.conversation) {
        _setProvisionallyVisible(true, reason: 'stt_unavailable_visible');
        _scheduleIdleAutoHide(reason: 'stt_unavailable');
      }
      notifyListeners();
      return;
    }

    _isSessionActive = true;
    _lastWords = '';
    _listenStartedAt = DateTime.now();
    _transitionTo(
      AiState.listening,
      reason: 'start_listening',
      traceId: traceId,
      notify: false,
    );
    notifyListeners();

    try {
      _startListenGuard(token: token, traceId: traceId);
      await _stt.listen(
        onResult:
            (result) =>
                _handleSpeechResult(result, token: token, traceId: traceId),
        onSoundLevelChange: _handleSoundLevelChange,
        listenFor: _sttListenFor,
        pauseFor: _sttPauseFor,
        localeId: _resolvedLocaleId ?? _defaultLocaleId,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );

      _logEvent(
        'STT_LISTEN_STARTED',
        traceId: traceId,
        data: {
          'localeId': _resolvedLocaleId ?? _defaultLocaleId,
          'listenForMs': _sttListenFor.inMilliseconds,
          'pauseForMs': _sttPauseFor.inMilliseconds,
        },
      );
    } catch (error) {
      // HARDEN(mic-permission): catch listen() throwing (not just returning
      // false from initialize) — ensures state is always cleaned up.
      if (!_isCurrentOperation(token)) {
        return;
      }
      _cancelListenGuard();

      _logEvent(
        'STT_LISTEN_ERROR',
        traceId: traceId,
        level: 'ERROR',
        data: {'error': error.toString()},
      );
      _cancelActiveOperation(reason: 'stt_listen_error:$source');
      _isSessionActive = false;
      _soundLevel = 0;
      _aiResponse = 'Không thể bắt đầu thu âm. Bạn thử lại hoặc nhập tin nhắn.';
      _transitionTo(
        AiState.idle,
        reason: 'stt_listen_error',
        traceId: traceId,
        notify: false,
      );
      if (resolvedSurface != AiResponseSurface.conversation) {
        _setProvisionallyVisible(true, reason: 'stt_listen_error_visible');
        _scheduleIdleAutoHide(reason: 'stt_listen_error');
      }
      notifyListeners();
    }
  }

  Future<void> stopListening({
    String reason = 'manual',
    bool keepBubbleVisible = true,
  }) async {
    _cancelListenGuard();
    _listenStartedAt = null;
    try {
      await _stt.stop();
    } catch (error) {
      _logEvent(
        'STT_STOP_ERROR',
        level: 'WARN',
        data: {'error': error.toString(), 'reason': reason},
      );
    }
    _isSessionActive = false;
    _soundLevel = 0;
    _transitionTo(AiState.idle, reason: reason, notify: false);

    if (keepBubbleVisible) {
      _setProvisionallyVisible(true, reason: '$reason.keep_visible');
      _scheduleIdleAutoHide(reason: reason);
    } else {
      _keepVisibleUntil = null;
      _syncVisibilityAfterSession();
    }

    notifyListeners();
  }

  Future<bool> _ensureSttInitialized() async {
    if (_isSttInitialized) {
      return true;
    }

    try {
      _isSttInitialized = await _stt.initialize(
        onStatus: (status) {
          // HARDEN(late-callback): guard STT status callback after dispose
          if (_isDisposed) return;
          _logEvent('STT_STATUS', data: {'status': status});
          _handleSttTerminalStatus(status);
        },
        onError: (error) {
          // HARDEN(late-callback): guard STT error callback after dispose
          if (_isDisposed) return;
          final normalizedError = error.errorMsg.trim().toLowerCase();
          _logEvent(
            'STT_ERROR',
            level: 'ERROR',
            data: {'error': error.toString(), 'errorMsg': error.errorMsg},
          );
          final isPermanentError = AiSttResiliencePolicy.isPermanentError(
            normalizedError,
          );
          final isTransientError = AiSttResiliencePolicy.isTransientError(
            normalizedError,
          );
          if (_shouldIgnorePrematureSttEnd(
            isPermanentError: isPermanentError,
          )) {
            _logEvent(
              'STT_TRANSIENT_ERROR_IGNORED',
              level: 'WARN',
              data: {
                'errorMsg': error.errorMsg,
                'elapsedMs': _elapsedListeningTime().inMilliseconds,
                'minimumMs': _sttListenFor.inMilliseconds,
                'isTransientError': isTransientError,
                'isPermanentError': isPermanentError,
              },
            );
            _restartListeningUntilGuardWindow(
              reason: 'transient_error:${error.errorMsg}',
              token: _operationToken,
              traceId: _activeTraceId,
            );
            return;
          }
          if (_state == AiState.listening && !_isPipelineLocked) {
            _cancelListenGuard();
            _listenStartedAt = null;
            _isSessionActive = false;
            _soundLevel = 0;
            _transitionTo(AiState.idle, reason: 'stt_error', notify: false);
            _aiResponse =
                'Không thể tiếp tục thu âm. Bạn kiểm tra quyền micro và thử lại.';
            if (_activeSurface != AiResponseSurface.conversation) {
              _setProvisionallyVisible(true, reason: 'stt_error_visible');
              _scheduleIdleAutoHide(reason: 'stt_error');
            } else {
              _syncVisibilityAfterSession();
            }
            notifyListeners();
          }
        },
      );

      if (_isSttInitialized) {
        await _resolveListeningLocale();
      }

      _logEvent(
        'STT_INITIALIZED',
        data: {'available': _isSttInitialized, 'localeId': _resolvedLocaleId},
      );
      return _isSttInitialized;
    } catch (error) {
      _logEvent(
        'STT_INIT_ERROR',
        level: 'ERROR',
        data: {'error': error.toString()},
      );
      return false;
    }
  }

  Future<void> _safeSpeak(
    String text, {
    required int token,
    required String traceId,
  }) async {
    if (text.trim().isEmpty || !_isCurrentOperation(token)) {
      return;
    }

    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      _logEvent(
        'TTS_SPEAK_DISPATCHED',
        traceId: traceId,
        data: {'result': result},
      );
    } catch (error) {
      _logEvent(
        'TTS_SPEAK_ERROR',
        traceId: traceId,
        level: 'ERROR',
        data: {'error': error.toString()},
      );
      if (_isCurrentOperation(token)) {
        _transitionTo(AiState.idle, reason: 'tts_exception', traceId: traceId);
      }
    }
  }

  // ==================== TEXT PROMPT ======================================

  /// HARDEN(flow-conversation): only sets provisional visibility for
  /// non-conversation surfaces. When source is 'ai_conversation_screen',
  /// _provisionallyVisible is NOT set, preventing the floating bubble from
  /// appearing after the conversation screen closes.
  Future<void> submitTextPrompt(
    String text, {
    String source = 'chat_board',
    AiResponseSurface? surface,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }
    _clarificationState = null;

    final responseSurface = _resolveSurface(source, explicitSurface: surface);
    _activeSurface = responseSurface;
    _lastResponseSurface = responseSurface;

    unawaited(_ensureConversationCreated(source: '$source.text_interaction'));

    _cancelIdleAutoHide();
    if (responseSurface != AiResponseSurface.conversation) {
      _setProvisionallyVisible(true, reason: '$source.visible');
    }

    if (_state == AiState.listening) {
      final keepBubbleVisible =
          responseSurface != AiResponseSurface.conversation;
      _cancelListenGuard();
      _listenStartedAt = null;
      _isSessionActive = false;
      _soundLevel = 0;
      _transitionTo(
        AiState.idle,
        reason: '$source.stop_listening_preempt',
        notify: false,
      );
      notifyListeners();

      unawaited(
        stopListening(
          reason: '$source.stop_listening',
          keepBubbleVisible: keepBubbleVisible,
        ),
      );
    }

    if (_state == AiState.thinking || _state == AiState.speaking) {
      await stopCurrentPipeline(reason: '$source.preempt');
    }

    await _handleCommand(normalized, parentTraceId: _newTraceId(source));
  }

  Future<void> stopCurrentPipeline({String reason = 'manual'}) async {
    _cancelActiveOperation(reason: reason);
    await _stopAllInteractions(reason: reason, keepResponse: true);
  }

  // ==================== COMMAND PIPELINE ==================================

  Future<void> _handleCommand(String text, {String? parentTraceId}) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (_isPipelineLocked) {
      _logEvent(
        'PIPELINE_DROP',
        level: 'WARN',
        data: {'reason': 'pipeline_locked', 'text': normalized},
      );
      return;
    }

    _isPipelineLocked = true;
    final traceId = parentTraceId ?? _newTraceId('voice_command');
    final token = _beginOperation(traceId: traceId);

    _lastUserPrompt = normalized;
    _soundLevel = 0;
    _cancelListenGuard();
    _cancelIdleAutoHide();
    _isSessionActive = true;
    _thinkingPhase = AiThinkingPhase.understanding;
    _transitionTo(
      AiState.thinking,
      reason: 'command_received',
      traceId: traceId,
    );

    final userEntryId = _newEntryId();
    final assistantEntryId = _newEntryId();
    final List<Map<String, dynamic>> structuredHistory = [];
    final historySubset =
        _conversationHistory.length > 10
            ? _conversationHistory.sublist(_conversationHistory.length - 10)
            : _conversationHistory;
    for (final entry in historySubset) {
      final role = entry.role == AiConversationRole.user ? 'user' : 'assistant';
      structuredHistory.add({
        'role': role,
        'content': entry.text,
        'createdAt': entry.createdAt.toUtc().toIso8601String(),
        'clientEntryId': entry.entryId,
      });
    }

    _recordUserHistory(
      text: normalized,
      source: 'assistant_chat',
      entryId: userEntryId,
    );

    try {
      await _stt.stop();
    } catch (error) {
      _logEvent(
        'STT_STOP_ERROR',
        traceId: traceId,
        level: 'WARN',
        data: {'error': error.toString(), 'reason': 'command_received'},
      );
    }

    try {
      final response = await _aiService
          .chat(
            normalized,
            contextId: _serverConversationId ?? aiConversationId,
            analyzeIntent: true,
            enableDeepSummary: _enableDeepSummary,
            history: structuredHistory,
            clientUserEntryId: userEntryId,
            clientAssistantEntryId: assistantEntryId,
          )
          .timeout(_aiTimeout);

      if (!_isCurrentOperation(token)) {
        return;
      }

      _aiResponse =
          normalizeAiTextEncoding(
            (response['textReply'] ?? '').toString(),
          ).trim();
      _currentEmotion = (response['emotion'] ?? 'neutral').toString();
      _updateProviderRuntimeState(
        degraded: response['degraded'] == true,
        providerStatus:
            (response['providerStatus'] ?? 'LIVE_PROVIDER_ACTIVE').toString(),
      );
      final actionCommand = response['actionCommand']?.toString();
      final actionParams = response['actionParams'];

      if (response['conversationId'] != null) {
        _serverConversationId = response['conversationId'].toString();
      }

      _recordAssistantHistory(
        text: _aiResponse,
        source: 'assistant_chat',
        entryId: response['assistantEntryId']?.toString() ?? assistantEntryId,
      );
      _trimSessionHistory();

      if (actionCommand != null && actionCommand.isNotEmpty) {
        _thinkingPhase = AiThinkingPhase.executingAction;
        notifyListeners();
        _executeSystemAction(actionCommand, actionParams, traceId: traceId);
      }

      if (_aiResponse.isNotEmpty) {
        _thinkingPhase = AiThinkingPhase.composingResponse;
        _transitionTo(
          AiState.speaking,
          reason: 'speak_response',
          traceId: traceId,
        );
        notifyListeners();
        await _safeSpeak(_aiResponse, token: token, traceId: traceId);
      }
    } on TimeoutException {
      if (_isCurrentOperation(token)) {
        await _handleFailure(
          token: token,
          traceId: traceId,
          event: 'AI_TIMEOUT',
          fallbackMessage: 'AI đang phản hồi chậm, vui lòng thử lại sau.',
          userText: normalized,
          source: 'assistant_chat',
          recordUserInHistory: false,
          userEntryId: userEntryId,
          assistantEntryId: assistantEntryId,
        );
      }
    } catch (error) {
      if (_isCurrentOperation(token)) {
        await _handleFailure(
          token: token,
          traceId: traceId,
          event: 'AI_ERROR',
          fallbackMessage: _resolveAssistantErrorMessage(
            error,
            fallbackMessage: 'Xin lỗi, tôi đang gặp chút trục trặc mạng.',
          ),
          error: error,
          userText: normalized,
          source: 'assistant_chat',
          recordUserInHistory: false,
          userEntryId: userEntryId,
          assistantEntryId: assistantEntryId,
        );
      }
    } finally {
      if (_isCurrentOperation(token)) {
        _isPipelineLocked = false;
        _isSessionActive = false;
        _cancelListenGuard();
        _currentEmotion = 'neutral';
        _transitionTo(
          AiState.idle,
          reason: 'pipeline_complete',
          traceId: traceId,
          notify: false,
        );
        _syncVisibilityAfterSession();
        if (!_persistentEnabled && _aiResponse.isEmpty) {
          _scheduleIdleAutoHide(reason: 'pipeline_complete_empty');
        }
        notifyListeners();
      }
    }
  }

  // ==================== CONTEXTUAL PROMPTS ================================

  Future<void> analyzeMessageContext(Message message) async {
    final content = message.content?.trim();
    if (content == null || content.isEmpty) {
      return;
    }

    await _runContextualPrompt(
      source: 'analyze_message',
      prompt:
          'Hãy giải thích hoặc tóm tắt ngắn gọn tin nhắn này cho tôi: "$content"',
      fallbackMessage: 'Tôi không thể phân tích tin nhắn này lúc này.',
    );
  }

  Future<void> translateMessage(Message message) async {
    final content = message.content?.trim();
    if (content == null || content.isEmpty) {
      return;
    }

    await _runContextualPrompt(
      source: 'translate_message',
      prompt:
          'Hãy dịch tin nhắn sau đây sang tiếng Việt một cách tự nhiên và chính xác nhất: "$content"',
      fallbackMessage: 'Tôi không thể dịch tin nhắn này lúc này.',
    );
  }

  Future<void> summarizeVideo(Message message) async {
    final videoUrl = (message.mediaUrl ?? message.content ?? '').trim();
    if (videoUrl.isEmpty) {
      return;
    }

    await _runContextualPrompt(
      source: 'summarize_video',
      prompt:
          'Hãy đóng vai một trợ lý thông minh, xem xét nội dung (nếu là video nội bộ) hoặc URL video này: $videoUrl. Hãy tóm tắt nội dung chính hoặc cho tôi biết đây là loại video gì. Trả lời ngắn gọn.',
      fallbackMessage: 'Tôi gặp khó khăn khi truy cập video này.',
    );
  }

  /// HARDEN(flow-contextual): contextual prompts (analyze/translate/summarize)
  /// set _activeSurface to contextual (not conversation) so responses can
  /// appear in the bubble board. This is intentional — context analysis is
  /// driven by the bubble mascot experience.
  Future<void> _runContextualPrompt({
    required String source,
    required String prompt,
    required String fallbackMessage,
  }) async {
    if (_isPipelineLocked) {
      _logEvent(
        'CONTEXT_PROMPT_SKIPPED',
        level: 'WARN',
        data: {'reason': 'pipeline_locked', 'source': source},
      );
      return;
    }

    _isPipelineLocked = true;
    final traceId = _newTraceId(source);
    final token = _beginOperation(traceId: traceId);

    _activeSurface = AiResponseSurface.contextual;
    _lastResponseSurface = AiResponseSurface.contextual;
    _cancelListenGuard();
    _cancelIdleAutoHide();
    _setProvisionallyVisible(true, reason: '$source.contextual_visible');
    _isSessionActive = true;
    _transitionTo(
      AiState.thinking,
      reason: '$source.thinking',
      traceId: traceId,
    );

    final userEntryId = _newEntryId();
    final assistantEntryId = _newEntryId();

    try {
      await _stt.stop();
      final response = await _aiService
          .chat(
            prompt,
            contextId: _serverConversationId ?? aiConversationId,
            analyzeIntent: false,
            clientUserEntryId: userEntryId,
            clientAssistantEntryId: assistantEntryId,
          )
          .timeout(_aiTimeout);

      if (!_isCurrentOperation(token)) {
        return;
      }

      _aiResponse =
          normalizeAiTextEncoding(
            (response['textReply'] ?? '').toString(),
          ).trim();
      _updateProviderRuntimeState(
        degraded: response['degraded'] == true,
        providerStatus:
            (response['providerStatus'] ?? 'LIVE_PROVIDER_ACTIVE').toString(),
      );
      if (_aiResponse.isEmpty) {
        _aiResponse = fallbackMessage;
      }

      if (response['conversationId'] != null) {
        _serverConversationId = response['conversationId'].toString();
      }

      _recordHistory(
        userText: _contextPromptLabel(source),
        aiText: _aiResponse,
        source: source,
        userEntryId: response['userEntryId']?.toString() ?? userEntryId,
        assistantEntryId:
            response['assistantEntryId']?.toString() ?? assistantEntryId,
      );

      _transitionTo(
        AiState.speaking,
        reason: '$source.speaking',
        traceId: traceId,
      );
      notifyListeners();
      await _safeSpeak(_aiResponse, token: token, traceId: traceId);
    } on TimeoutException {
      if (_isCurrentOperation(token)) {
        await _handleFailure(
          token: token,
          traceId: traceId,
          event: 'CONTEXT_TIMEOUT',
          fallbackMessage: fallbackMessage,
          userText: _contextPromptLabel(source),
          source: source,
          userEntryId: userEntryId,
          assistantEntryId: assistantEntryId,
        );
      }
    } catch (error) {
      if (_isCurrentOperation(token)) {
        await _handleFailure(
          token: token,
          traceId: traceId,
          event: 'CONTEXT_ERROR',
          fallbackMessage: fallbackMessage,
          error: error,
          userText: _contextPromptLabel(source),
          source: source,
          userEntryId: userEntryId,
          assistantEntryId: assistantEntryId,
        );
      }
    } finally {
      if (_isCurrentOperation(token)) {
        _isPipelineLocked = false;
        _isSessionActive = false;
        _cancelListenGuard();
        _currentEmotion = 'neutral';
        _transitionTo(
          AiState.idle,
          reason: '$source.complete',
          traceId: traceId,
          notify: false,
        );
        _syncVisibilityAfterSession();
        notifyListeners();
      }
    }
  }

  Future<void> _handleFailure({
    required int token,
    required String traceId,
    required String event,
    required String fallbackMessage,
    Object? error,
    String? userText,
    String source = 'assistant_chat',
    bool recordUserInHistory = true,
    String? userEntryId,
    String? assistantEntryId,
  }) async {
    if (event == 'AI_TIMEOUT' || event == 'AI_ERROR') {
      _updateProviderRuntimeState(
        degraded: true,
        providerStatus: 'AI_PROVIDER_UNAVAILABLE',
      );
    }

    _logEvent(
      event,
      traceId: traceId,
      level: 'ERROR',
      data: {'error': error?.toString()},
    );

    _aiResponse = fallbackMessage;
    _currentEmotion = 'neutral';
    if (userText != null && userText.trim().isNotEmpty) {
      if (recordUserInHistory) {
        _recordUserHistory(
          text: userText,
          source: source,
          entryId: userEntryId,
        );
      }
      _recordAssistantHistory(
        text: _aiResponse,
        source: source,
        entryId: assistantEntryId,
      );
      _trimSessionHistory();
    }
    _transitionTo(AiState.speaking, reason: 'fallback_speak', traceId: traceId);
    notifyListeners();
    await _safeSpeak(_aiResponse, token: token, traceId: traceId);
  }

  void _updateProviderRuntimeState({
    required bool degraded,
    required String providerStatus,
    bool notify = false,
  }) {
    _isResponseDegraded = degraded;
    _providerStatus =
        providerStatus.trim().isEmpty
            ? 'LIVE_PROVIDER_ACTIVE'
            : providerStatus.trim();
    if (notify) {
      notifyListeners();
    }
  }

  String _resolveAssistantErrorMessage(
    Object error, {
    required String fallbackMessage,
  }) {
    if (error is ApiException) {
      final normalizedMessage = normalizeAiTextEncoding(error.message).trim();
      if (normalizedMessage.isNotEmpty) {
        return normalizedMessage;
      }

      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }

      if (error.statusCode == 429) {
        return 'Bạn đang gửi quá nhanh. Vui lòng thử lại sau ít giây.';
      }
    }

    return fallbackMessage;
  }

  Future<void> _stopAllInteractions({
    required String reason,
    required bool keepResponse,
  }) async {
    _cancelListenGuard();
    _listenStartedAt = null;
    try {
      await _stt.stop();
    } catch (error) {
      _logEvent(
        'STT_STOP_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }

    try {
      await _tts.stop();
    } catch (error) {
      _logEvent(
        'TTS_STOP_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }

    _isPipelineLocked = false;
    _isSessionActive = false;
    _soundLevel = 0;
    _currentEmotion = 'neutral';
    _transitionTo(AiState.idle, reason: reason, notify: false);

    if (!keepResponse) {
      _aiResponse = '';
    }

    _syncVisibilityAfterSession();
    notifyListeners();
  }

  // ==================== HISTORY ==========================================

  void _recordHistory({
    required String userText,
    required String aiText,
    String source = 'assistant_chat',
    String? userEntryId,
    String? assistantEntryId,
  }) {
    _recordUserHistory(text: userText, source: source, entryId: userEntryId);
    _recordAssistantHistory(
      text: aiText,
      source: source,
      entryId: assistantEntryId,
    );
    _trimSessionHistory();
  }

  void _recordUserHistory({
    required String text,
    required String source,
    String? entryId,
  }) {
    final normalized = normalizeAiTextEncoding(text).trim();
    if (normalized.isEmpty) {
      return;
    }

    _sessionHistory.add({'role': 'User', 'text': normalized});
    _addConversationEntry(
      role: AiConversationRole.user,
      text: normalized,
      source: source,
      entryId: entryId,
    );
  }

  void _recordAssistantHistory({
    required String text,
    required String source,
    String? entryId,
  }) {
    final normalized = normalizeAiTextEncoding(text).trim();
    if (normalized.isEmpty) {
      return;
    }

    _sessionHistory.add({'role': 'AI', 'text': normalized});
    _addConversationEntry(
      role: AiConversationRole.assistant,
      text: normalized,
      source: source,
      entryId: entryId,
    );
  }

  void _trimSessionHistory() {
    if (_sessionHistory.length > 10) {
      _sessionHistory.removeRange(0, _sessionHistory.length - 10);
    }
  }

  Future<void> _ensureConversationCreated({required String source}) async {
    if (_conversationCreated) {
      return;
    }

    _conversationCreated = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedConversationCreatedPrefKey, true);
    _logEvent('CONVERSATION_CREATED', data: {'source': source});
    notifyListeners();
  }

  void _addConversationEntry({
    required AiConversationRole role,
    required String text,
    required String source,
    String? entryId,
    DateTime? createdAt,
  }) {
    final normalized = normalizeAiTextEncoding(text).trim();
    if (normalized.isEmpty) {
      return;
    }

    _conversationCreated = true;
    _conversationHistory.add(
      AiConversationEntry(
        entryId: entryId ?? _newEntryId(),
        role: role,
        text: normalized,
        source: source,
        createdAt: (createdAt ?? DateTime.now()).toUtc(),
      ),
    );

    if (_conversationHistory.length > _maxConversationEntries) {
      final overflow = _conversationHistory.length - _maxConversationEntries;
      final removedIds = _conversationHistory
          .take(overflow)
          .map((entry) => entry.entryId)
          .toList(growable: false);
      _conversationHistory.removeRange(0, overflow);
      _syncedEntryIds.removeAll(removedIds);
      unawaited(_persistSyncedEntryIds());
    }

    unawaited(_persistConversationHistory());
    _scheduleCloudBackup();
    notifyListeners();
  }

  Future<void> _persistConversationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _scopedConversationCreatedPrefKey,
        _conversationCreated,
      );
      if (_serverConversationId != null) {
        await prefs.setString(
          _scopedServerConversationIdPrefKey,
          _serverConversationId!,
        );
      } else {
        await prefs.remove(_scopedServerConversationIdPrefKey);
      }
      await prefs.setString(
        _scopedHistoryPrefKey,
        jsonEncode(
          _conversationHistory.map((entry) => entry.toJson()).toList(),
        ),
      );
    } catch (error) {
      _logEvent(
        'CONVERSATION_HISTORY_PERSIST_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  Future<void> _persistSyncedEntryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _syncedEntryIds.toList(growable: false)..sort();
      await prefs.setStringList(_scopedSyncedEntryIdsPrefKey, ids);
    } catch (error) {
      _logEvent(
        'SYNCED_ENTRY_IDS_PERSIST_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  void _scheduleCloudBackup() {
    _cloudBackupDebounceTimer?.cancel();

    if (!_cloudBackupEnabled || _conversationHistory.isEmpty) {
      return;
    }

    _cloudBackupDebounceTimer = Timer(const Duration(seconds: 2), () {
      // HARDEN(late-callback): guard against timer firing after dispose
      if (_isDisposed) return;
      unawaited(_syncConversationHistoryToCloud());
    });
  }

  Future<void> _restoreConversationHistoryFromServer() async {
    final targetId = _serverConversationId;
    if (targetId == null || targetId.isEmpty) return;
    final restoreGeneration = _historyClearGeneration;

    try {
      final entries = await _aiService.restoreConversationHistory(
        conversationId: targetId,
      );
      if (_isDisposed ||
          restoreGeneration != _historyClearGeneration ||
          targetId != _serverConversationId) {
        _logEvent(
          'CLOUD_HISTORY_RESTORE_DROPPED',
          data: {'reason': 'stale_restore', 'conversationId': targetId},
        );
        return;
      }
      if (entries.isNotEmpty) {
        final List<AiConversationEntry> merged = List.from(
          _conversationHistory,
        );
        final existingIds = merged.map((entry) => entry.entryId).toSet();
        final restoredIds = <String>{};
        final limitedEntries =
            entries.length > _maxConversationEntries
                ? entries.sublist(entries.length - _maxConversationEntries)
                : entries;

        for (final map in limitedEntries) {
          final roleStr = map['role']?.toString() ?? 'user';
          final content = normalizeAiTextEncoding(
            map['content']?.toString() ?? '',
          );
          if (content.trim().isEmpty) {
            continue;
          }
          final provider = map['provider']?.toString();
          final rawEntryId =
              (map['clientEntryId'] ?? map['entryId'])?.toString().trim();
          final entryId =
              rawEntryId != null && rawEntryId.isNotEmpty ? rawEntryId : null;
          final rawCreatedAt = map['createdAt']?.toString();
          final parsedCreatedAt =
              rawCreatedAt != null
                  ? (DateTime.tryParse(rawCreatedAt)?.toUtc() ??
                      DateTime.now().toUtc())
                  : DateTime.now().toUtc();

          final role =
              roleStr == 'user'
                  ? AiConversationRole.user
                  : AiConversationRole.assistant;

          final exists =
              entryId != null
                  ? existingIds.contains(entryId)
                  : merged.any(
                    (local) =>
                        local.role == role &&
                        local.text.trim() == content.trim() &&
                        (local.createdAt
                                .difference(parsedCreatedAt)
                                .abs()
                                .inSeconds <
                            3),
                  );

          if (!exists) {
            final resolvedEntryId = entryId ?? _newEntryId();
            merged.add(
              AiConversationEntry(
                entryId: resolvedEntryId,
                role: role,
                text: content,
                source: provider ?? 'restored',
                createdAt: parsedCreatedAt,
              ),
            );
            existingIds.add(resolvedEntryId);
            restoredIds.add(resolvedEntryId);
          } else if (entryId != null) {
            restoredIds.add(entryId);
          }
        }

        merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (merged.length > _maxConversationEntries) {
          final overflow = merged.length - _maxConversationEntries;
          final removedIds = merged
              .take(overflow)
              .map((entry) => entry.entryId)
              .toList(growable: false);
          merged.removeRange(0, overflow);
          _syncedEntryIds.removeAll(removedIds);
          restoredIds.removeAll(removedIds);
        }

        if (_isDisposed ||
            restoreGeneration != _historyClearGeneration ||
            targetId != _serverConversationId) {
          _logEvent(
            'CLOUD_HISTORY_RESTORE_DROPPED',
            data: {'reason': 'stale_merge', 'conversationId': targetId},
          );
          return;
        }

        _conversationHistory
          ..clear()
          ..addAll(merged);

        await _persistConversationHistory();
        _syncedEntryIds.addAll(restoredIds);
        unawaited(_persistSyncedEntryIds());
        notifyListeners();
        _logEvent(
          'CLOUD_HISTORY_RESTORED',
          data: {'entries': _conversationHistory.length},
        );
      }
    } catch (e) {
      _logEvent(
        'CLOUD_HISTORY_RESTORE_ERROR',
        level: 'WARN',
        data: {'error': e.toString()},
      );
    }
  }

  Future<void> _syncConversationHistoryToCloud() async {
    if (!_cloudBackupEnabled || _conversationHistory.isEmpty) {
      return;
    }
    final syncGeneration = _historyClearGeneration;
    final conversationId = _serverConversationId ?? aiConversationId;

    final pendingEntries = _conversationHistory
        .where((entry) => !_syncedEntryIds.contains(entry.entryId))
        .toList(growable: false);
    if (pendingEntries.isEmpty) {
      return;
    }

    final payload = pendingEntries.map((entry) => entry.toJson()).toList();
    try {
      await _aiService.backupConversationHistory(
        conversationId: conversationId,
        entries: payload,
      );
      if (_isDisposed ||
          syncGeneration != _historyClearGeneration ||
          _conversationHistory.isEmpty) {
        final canSafelyRetryDelete =
            !_isPipelineLocked &&
            !_isSessionActive &&
            _conversationHistory.isEmpty &&
            _serverConversationId != conversationId;
        if (canSafelyRetryDelete) {
          unawaited(_deleteCloudConversationHistory(conversationId));
        }
        _logEvent(
          'CLOUD_BACKUP_SYNC_DROPPED',
          data: {'reason': 'stale_sync', 'conversationId': conversationId},
        );
        return;
      }
      _syncedEntryIds.addAll(pendingEntries.map((entry) => entry.entryId));
      unawaited(_persistSyncedEntryIds());
      _logEvent('CLOUD_BACKUP_SYNCED', data: {'entries': payload.length});
    } catch (error) {
      _logEvent(
        'CLOUD_BACKUP_SYNC_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  String _contextPromptLabel(String source) {
    return switch (source) {
      'analyze_message' => '[Phân tích tin nhắn]',
      'translate_message' => '[Dịch tin nhắn]',
      'summarize_video' => '[Tóm tắt video]',
      _ => '[Yêu cầu AI]',
    };
  }

  // ==================== STT CALLBACKS =====================================

  Future<void> _handleListenGuardTimeout({
    required int token,
    required String traceId,
  }) async {
    // HARDEN(late-callback): guard against timer firing after dispose
    if (_isDisposed ||
        !_isCurrentOperation(token) ||
        _state != AiState.listening) {
      return;
    }

    _logEvent(
      'STT_GUARD_TIMEOUT',
      traceId: traceId,
      level: 'WARN',
      data: {'lastWordsLength': _lastWords.length},
    );

    try {
      await _stt.stop();
    } catch (error) {
      _logEvent(
        'STT_STOP_ERROR',
        traceId: traceId,
        level: 'WARN',
        data: {'error': error.toString(), 'reason': 'listen_guard_timeout'},
      );
    }
    if (!_isCurrentOperation(token)) {
      return;
    }

    _cancelListenGuard();
    _listenStartedAt = null;
    _isSessionActive = false;
    _soundLevel = 0;
    _transitionTo(
      AiState.idle,
      reason: 'stt_guard_timeout',
      traceId: traceId,
      notify: false,
    );

    if (_lastWords.isEmpty) {
      _aiResponse = '';
      _scheduleIdleAutoHide(reason: 'stt_guard_timeout');
    }

    _syncVisibilityAfterSession();

    notifyListeners();
  }

  Future<void> _resolveListeningLocale() async {
    try {
      final locales = await _stt.locales();
      if (locales.isEmpty) {
        _resolvedLocaleId = _defaultLocaleId;
        return;
      }

      LocaleName? exact;
      LocaleName? vietnamese;
      for (final locale in locales) {
        final localeId = locale.localeId.toLowerCase();
        if (exact == null && localeId == _defaultLocaleId.toLowerCase()) {
          exact = locale;
        }
        if (vietnamese == null && localeId.startsWith('vi')) {
          vietnamese = locale;
        }
      }

      _resolvedLocaleId =
          exact?.localeId ?? vietnamese?.localeId ?? locales.first.localeId;
      _logEvent('STT_LOCALE_RESOLVED', data: {'localeId': _resolvedLocaleId});
    } catch (error) {
      _resolvedLocaleId = _defaultLocaleId;
      _logEvent(
        'STT_LOCALE_RESOLVE_ERROR',
        level: 'WARN',
        data: {'error': error.toString()},
      );
    }
  }

  // ==================== UTILITIES =========================================

  bool _isDuplicateFinalResult(String text) {
    final now = DateTime.now();
    final normalized = text.trim().toLowerCase();
    final isDuplicate =
        normalized == _lastFinalResultText &&
        _lastFinalResultAt != null &&
        now.difference(_lastFinalResultAt!) < const Duration(milliseconds: 900);

    _lastFinalResultText = normalized;
    _lastFinalResultAt = now;
    return isDuplicate;
  }

  String _newTraceId(String scope) => '${scope}_${_uuid.v4()}';

  String _newEntryId() => _uuid.v4();

  void _logEvent(
    String event, {
    String level = 'INFO',
    String? traceId,
    Map<String, dynamic>? data,
  }) {
    if (!_enableFlowLogging) {
      return;
    }
    final payload = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'scope': 'AI_ASSISTANT',
      'level': level,
      'event': event,
      'traceId': traceId ?? _activeTraceId,
      'state': _state.name,
      'persistentEnabled': _persistentEnabled,
      'provisionallyVisible': _provisionallyVisible,
      'sessionActive': _isSessionActive,
      'data': _sanitizeData(data),
    };

    debugPrint('[AI_FLOW] ${jsonEncode(payload)}');
  }

  Map<String, dynamic> _sanitizeData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const {};
    }

    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      const sensitiveKeys = {
        'text',
        'prompt',
        'content',
        'aiText',
        'userText',
        'entries',
        'history',
      };
      if (sensitiveKeys.contains(key)) {
        sanitized[key] = '<redacted>';
        return;
      }
      if (value == null || value is num || value is bool || value is String) {
        sanitized[key] = value;
      } else {
        sanitized[key] = value.toString();
      }
    });
    return sanitized;
  }

  void _executeSystemAction(
    String command,
    dynamic params, {
    required String traceId,
  }) {
    if (_isDisposed || _systemActionController.isClosed) {
      _logEvent(
        'AI_COMMAND_DROPPED',
        traceId: traceId,
        level: 'WARN',
        data: {'reason': 'controller_closed', 'command': command},
      );
      return;
    }

    final aiCommand = AiCommand(
      command: command,
      params: params,
      traceId: traceId,
    );
    _logEvent(
      'AI_COMMAND_EMIT',
      traceId: traceId,
      data: {'command': command, 'commandId': aiCommand.commandId},
    );
    _systemActionController.add(aiCommand);
  }

  void clearAiResponse({bool keepBubbleVisible = true}) {
    _aiResponse = '';
    if (keepBubbleVisible && !_persistentEnabled) {
      _setProvisionallyVisible(true, reason: 'response_cleared.keep_visible');
      _scheduleIdleAutoHide(reason: 'response_cleared');
    } else {
      _scheduleIdleAutoHide(reason: 'response_cleared');
      _syncVisibilityAfterSession();
    }
    _logEvent('AI_RESPONSE_CLEARED');
    notifyListeners();
  }
}
