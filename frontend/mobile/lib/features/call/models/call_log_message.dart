import 'dart:convert';

enum CallMediaType { voice, video }

enum CallOutcome { answered, declined, missed, busy, canceled, failed }

class CallLogMessage {
  static const String _prefix = 'CALL_LOG::';

  final String callId;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallMediaType mediaType;
  final CallOutcome outcome;
  final int durationSeconds;
  final DateTime createdAt;

  const CallLogMessage({
    required this.callId,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.mediaType,
    required this.outcome,
    required this.durationSeconds,
    required this.createdAt,
  });

  String toMessageContent() {
    final payload = {
      'v': 1,
      'callId': callId,
      'conversationId': conversationId,
      'callerId': callerId,
      'calleeId': calleeId,
      'mediaType': mediaType.name,
      'outcome': outcome.name,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
    return '$_prefix${jsonEncode(payload)}';
  }

  static CallLogMessage? tryParse(String? content) {
    if (content == null || !content.startsWith(_prefix)) return null;

    try {
      final jsonPart = content.substring(_prefix.length);
      final decoded = jsonDecode(jsonPart);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      final mediaType = _enumOrDefault(
        CallMediaType.values,
        map['mediaType']?.toString(),
        CallMediaType.voice,
      );
      final outcome = _enumOrDefault(
        CallOutcome.values,
        map['outcome']?.toString(),
        CallOutcome.failed,
      );

      return CallLogMessage(
        callId: map['callId']?.toString() ?? '',
        conversationId: map['conversationId']?.toString() ?? '',
        callerId: map['callerId']?.toString() ?? '',
        calleeId: map['calleeId']?.toString() ?? '',
        mediaType: mediaType,
        outcome: outcome,
        durationSeconds:
            int.tryParse(map['durationSeconds']?.toString() ?? '') ?? 0,
        createdAt:
            DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static T _enumOrDefault<T>(List<T> values, String? value, T fallback) {
    if (value == null || value.isEmpty) return fallback;
    for (final item in values) {
      if (item.toString().split('.').last == value) return item;
    }
    return fallback;
  }
}
