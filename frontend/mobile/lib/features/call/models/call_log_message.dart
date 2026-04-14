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
    if (content == null) return null;

    final index = content.indexOf(_prefix);
    if (index == -1) return null;

    try {
      // Tìm phần nội dung sau tiền tố
      String jsonPart = content.substring(index + _prefix.length).trim();
      
      // Tìm vị trí của dấu { đầu tiên và } cuối cùng để trích xuất JSON sạch
      final start = jsonPart.indexOf('{');
      final end = jsonPart.lastIndexOf('}');
      if (start == -1 || end == -1 || start >= end) return null;
      
      jsonPart = jsonPart.substring(start, end + 1);
      
      // Unescape toàn diện (loại bỏ \" và các ký tự escape lồng nhau)
      jsonPart = jsonPart.replaceAll('\\"', '"').replaceAll('\\\\', '\\');

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
        CallOutcome.answered,
      );

      return CallLogMessage(
        callId: map['callId'] ?? '',
        conversationId: map['conversationId'] ?? '',
        callerId: map['callerId'] ?? '',
        calleeId: map['calleeId'] ?? '',
        mediaType: mediaType,
        outcome: outcome,
        durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
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
