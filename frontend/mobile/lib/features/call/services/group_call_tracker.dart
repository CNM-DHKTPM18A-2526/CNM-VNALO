import 'package:flutter/foundation.dart';

class ActiveCallInfo {
  final String callId;
  final String conversationId;
  final String conversationName;
  final String? conversationAvatarUrl;
  final bool audioOnly;
  final bool isCaller;
  final DateTime startedAt;
  final Set<String> participantUserIds;

  ActiveCallInfo({
    required this.callId,
    required this.conversationId,
    required this.conversationName,
    this.conversationAvatarUrl,
    required this.audioOnly,
    required this.isCaller,
    required this.startedAt,
    required this.participantUserIds,
  });

  ActiveCallInfo copyWith({
    String? callId,
    String? conversationId,
    String? conversationName,
    String? conversationAvatarUrl,
    bool? audioOnly,
    bool? isCaller,
    DateTime? startedAt,
    Set<String>? participantUserIds,
  }) {
    return ActiveCallInfo(
      callId: callId ?? this.callId,
      conversationId: conversationId ?? this.conversationId,
      conversationName: conversationName ?? this.conversationName,
      conversationAvatarUrl: conversationAvatarUrl ?? this.conversationAvatarUrl,
      audioOnly: audioOnly ?? this.audioOnly,
      isCaller: isCaller ?? this.isCaller,
      startedAt: startedAt ?? this.startedAt,
      participantUserIds: participantUserIds ?? this.participantUserIds,
    );
  }
}

class GroupCallTracker extends ChangeNotifier {
  ActiveCallInfo? _activeCall;

  ActiveCallInfo? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;

  String? get activeCallId => _activeCall?.callId;
  String? get activeConversationId => _activeCall?.conversationId;

  void startCall(ActiveCallInfo info) {
    _activeCall = info;
    notifyListeners();
  }

  void updateParticipants(Set<String> userIds) {
    if (_activeCall != null) {
      _activeCall = _activeCall!.copyWith(participantUserIds: userIds);
      notifyListeners();
    }
  }

  void addParticipant(String userId) {
    if (_activeCall != null) {
      final updated = Set<String>.from(_activeCall!.participantUserIds)..add(userId);
      _activeCall = _activeCall!.copyWith(participantUserIds: updated);
      notifyListeners();
    }
  }

  void removeParticipant(String userId) {
    if (_activeCall != null) {
      final updated = Set<String>.from(_activeCall!.participantUserIds)..remove(userId);
      _activeCall = _activeCall!.copyWith(participantUserIds: updated);
      notifyListeners();
    }
  }

  void endCall() {
    _activeCall = null;
    notifyListeners();
  }

  void endCallForConversation(String conversationId) {
    if (_activeCall?.conversationId == conversationId) {
      _activeCall = null;
      notifyListeners();
    }
  }
}
